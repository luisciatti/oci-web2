#!/bin/bash
set -euo pipefail

# Só uma execução por vez (se o timer disparar enquanto outra roda, sai quieto)
exec 9>/var/lock/app-deploy.lock
flock -n 9 || exit 0

# Config escrita no primeiro boot: DB_HOST, DB_SECRET_ID, JWT_SECRET_ID, IMAGE_REPO
source /etc/app/deploy.conf
IMAGE="$IMAGE_REPO:prod"
FAILED_FILE=/var/lib/app-deploy.failed

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
  docker run -d --name app --restart unless-stopped -p 8080:8080 \
    --env-file /etc/app/app.env "$1"
}

healthy() {
  for i in $(seq 1 45); do
    curl -fs localhost:8080/actuator/health >/dev/null && return 0
    sleep 2
  done
  return 1
}

# 1. baixa e compara
docker pull -q "$IMAGE" >/dev/null
NEW=$(docker image inspect --format '{{.Id}}' "$IMAGE")
CUR=$(docker inspect --format '{{.Image}}' app 2>/dev/null || true)
RUNNING=$(docker inspect --format '{{.State.Running}}' app 2>/dev/null || echo false)

if [ "$NEW" = "$CUR" ] && [ "$RUNNING" = "true" ]; then
  exit 0   # já está na versão certa
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