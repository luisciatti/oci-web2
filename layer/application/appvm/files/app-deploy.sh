#!/bin/bash
set -euo pipefail

# Só uma execução por vez (se o timer disparar enquanto outra roda, sai quieto)
exec 9>/var/lock/app-deploy.lock
flock -n 9 || exit 0

# Config escrita no primeiro boot: DB_HOST, DB_SECRET_ID, JWT_SECRET_ID, IMAGE_REPO, DOMAIN, ACME_STAGING
source /etc/app/deploy.conf
IMAGE="$IMAGE_REPO:prod"
FAILED_FILE=/var/lib/app-deploy.failed
DOMAIN="${DOMAIN:-}"
ACME_STAGING="${ACME_STAGING:-false}"
CADDY_IMAGE="caddy:2-alpine"
CADDY_DIR=/etc/app/caddy

get_secret() {
  for i in $(seq 1 5); do
    if /opt/oci-cli/bin/oci --auth instance_principal secrets secret-bundle get \
         --secret-id "$1" --query 'data."secret-bundle-content".content' \
         --raw-output | base64 -d; then
      return 0
    fi
    sleep 10
  done
  return 1
}

run_app() {
  docker rm -f app 2>/dev/null || true
  docker run -d --name app --restart unless-stopped --network web2 -p 8080:8080 \
    --log-opt max-size=10m --log-opt max-file=3 \
    --env-file /etc/app/app.env "$1"
}

healthy() {
  for i in $(seq 1 45); do
    curl -fs localhost:8080/actuator/health >/dev/null && return 0
    sleep 2
  done
  return 1
}

# Escreve o Caddyfile a partir de DOMAIN/ACME_STAGING; marca CADDY_CHANGED se mudou.
# Usa "cat >" (mesmo arquivo) e monta o diretório no container, para o reload enxergar a mudança.
write_caddyfile() {
  local tmp
  tmp=$(mktemp)
  {
    if [ "$ACME_STAGING" = "true" ]; then
      printf '{\n\tacme_ca https://acme-staging-v02.api.letsencrypt.org/directory\n}\n\n'
    fi
        printf '%s {\n\tencode zstd gzip\n\thandle /actuator/* {\n\t\trespond 404\n\t}\n\thandle {\n\t\treverse_proxy app:8080\n\t}\n}\n' "$DOMAIN"
  } > "$tmp"
  mkdir -p "$CADDY_DIR"
  if ! cmp -s "$tmp" "$CADDY_DIR/Caddyfile"; then
    cat "$tmp" > "$CADDY_DIR/Caddyfile"
    CADDY_CHANGED=1
  fi
  rm -f "$tmp"
}

# Sobe (ou recarrega) o Caddy. Se DOMAIN não estiver definido, não faz nada.
ensure_front() {
  [ -n "$DOMAIN" ] || return 0
  CADDY_CHANGED=0
  write_caddyfile
  if [ "$(docker inspect --format '{{.State.Running}}' caddy 2>/dev/null || echo false)" != "true" ]; then
    docker image inspect "$CADDY_IMAGE" >/dev/null 2>&1 || docker pull -q "$CADDY_IMAGE" >/dev/null
    docker rm -f caddy >/dev/null 2>&1 || true
    docker run -d --name caddy --restart unless-stopped --network web2 \
      -p 80:80 -p 443:443 \
      -v "$CADDY_DIR":/etc/caddy:ro -v caddy_data:/data -v caddy_config:/config \
      --log-opt max-size=10m --log-opt max-file=3 "$CADDY_IMAGE" >/dev/null
  elif [ "$CADDY_CHANGED" = "1" ]; then
    docker exec caddy caddy reload --config /etc/caddy/Caddyfile
  fi
}

# 0. rede dos containers e proxy HTTPS (falha do Caddy não impede o deploy do app)
docker network inspect web2 >/dev/null 2>&1 || docker network create web2 >/dev/null
ensure_front || echo "aviso: falha ao preparar o Caddy (veja: docker logs caddy)"

# 1. baixa e compara
docker pull -q "$IMAGE" >/dev/null
NEW=$(docker image inspect --format '{{.Id}}' "$IMAGE")
CUR=$(docker inspect --format '{{.Image}}' app 2>/dev/null || true)
RUNNING=$(docker inspect --format '{{.State.Running}}' app 2>/dev/null || echo false)
ON_NET=$(docker inspect --format '{{if index .NetworkSettings.Networks "web2"}}yes{{end}}' app 2>/dev/null || true)

if [ "$NEW" = "$CUR" ] && [ "$RUNNING" = "true" ] && [ "$ON_NET" = "yes" ]; then
  exit 0   # já está na versão certa e na rede certa
fi

# Esta versão já falhou antes: não tenta de novo até sair outra
if [ -f "$FAILED_FILE" ] && [ "$(cat "$FAILED_FILE")" = "$NEW" ]; then
  echo "versão $NEW já falhou antes, ignorando até sair outra"
  exit 0
fi

# 2. guarda a atual para rollback
if [ -n "$CUR" ]; then docker tag "$CUR" web2-backend:previous; fi

# 3. relê segredos e gera o env
DB_PASSWORD=$(get_secret "$DB_SECRET_ID")
JWT_SECRET=$(get_secret "$JWT_SECRET_ID")
umask 077
mkdir -p /etc/app
{
  printf 'DB_URL=jdbc:mysql://%s:3306/diagramcode\n' "$DB_HOST"
  printf 'DB_USERNAME=diagramcode_app\n'
  printf 'DB_PASSWORD=%s\n' "$DB_PASSWORD"
  printf 'JWT_SECRET=%s\n' "$JWT_SECRET"
} > /etc/app/app.env

# 4. sobe a nova e confere a saúde
run_app "$IMAGE"
if healthy; then
  echo "deploy ok: $NEW"
  rm -f "$FAILED_FILE"
  docker image prune -f >/dev/null
  exit 0
fi

# 5. falhou: marca a versão e faz rollback
echo "deploy FALHOU, voltando para a versão anterior"
echo "$NEW" > "$FAILED_FILE"
if [ -n "$CUR" ]; then run_app web2-backend:previous; fi
exit 1