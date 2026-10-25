#!/bin/bash
# Sobe (ou atualiza) Prometheus + Grafana na VM. Idempotente: pode rodar quantas vezes quiser.
# Recria um container só se a imagem ou os arquivos de configuração dele mudaram.
set -euo pipefail

exec 9>/var/lock/monitoring-up.lock
flock -n 9 || exit 0

MON_DIR=/opt/monitoring
ENV_FILE=/etc/app/monitoring.env
PROM_IMAGE="prom/prometheus:v3.5.0"
GRAFANA_IMAGE="grafana/grafana:12.2.0"

# DOMAIN vem do deploy.conf (o mesmo do app-deploy.sh)
source /etc/app/deploy.conf
DOMAIN="${DOMAIN:-}"
COOKIE_SECURE=false
ROOT_URL="http://localhost:3000/grafana/"
if [ -n "$DOMAIN" ]; then
  ROOT_URL="https://$DOMAIN/grafana/"
  COOKIE_SECURE=true
fi

# Precisa recriar? (container ausente, parado, outra imagem ou outra configuração)
needs_recreate() { # nome imagem hash
  local cur
  cur=$(docker inspect --format '{{.Config.Image}}|{{index .Config.Labels "cfg"}}|{{.State.Running}}' "$1" 2>/dev/null || echo none)
  [ "$cur" != "$2|$3|true" ]
}

# Senha do admin do Grafana: gerada uma vez, nunca vai para o repositório
if [ ! -f "$ENV_FILE" ]; then
  mkdir -p "$(dirname "$ENV_FILE")"
  ( umask 077
    printf 'GF_SECURITY_ADMIN_PASSWORD=%s\n' "$(openssl rand -base64 24 | tr -d '/+=')" > "$ENV_FILE" )
  echo "senha do Grafana gerada em $ENV_FILE (usuário: admin)"
fi

docker network inspect web2 >/dev/null 2>&1 || docker network create web2 >/dev/null
docker volume create prometheus_data >/dev/null
docker volume create grafana_data >/dev/null

# Prometheus (privado: só a rede docker web2 enxerga)
PROM_HASH=$(sha256sum "$MON_DIR/prometheus.yml" | cut -c1-12)
if needs_recreate prometheus "$PROM_IMAGE" "$PROM_HASH"; then
  docker rm -f prometheus >/dev/null 2>&1 || true
  docker run -d --name prometheus --restart unless-stopped --network web2 --memory 512m \
    --label cfg="$PROM_HASH" \
    -v "$MON_DIR/prometheus.yml":/etc/prometheus/prometheus.yml:ro \
    -v prometheus_data:/prometheus \
    --log-opt max-size=10m --log-opt max-file=3 \
    "$PROM_IMAGE" \
    --config.file=/etc/prometheus/prometheus.yml \
    --storage.tsdb.retention.time=15d --storage.tsdb.retention.size=5GB >/dev/null
  echo "prometheus: (re)criado"
else
  echo "prometheus: ok"
fi

# Grafana (só em 127.0.0.1:3000; o público entra pelo Caddy em /grafana)
GRAFANA_HASH=$( { echo "$ROOT_URL"; find "$MON_DIR/grafana" -type f | sort | xargs cat; } | sha256sum | cut -c1-12 )
if needs_recreate grafana "$GRAFANA_IMAGE" "$GRAFANA_HASH"; then
  docker rm -f grafana >/dev/null 2>&1 || true
  docker run -d --name grafana --restart unless-stopped --network web2 --memory 512m \
    --label cfg="$GRAFANA_HASH" \
    -p 127.0.0.1:3000:3000 \
    --env-file "$ENV_FILE" \
    -e GF_USERS_ALLOW_SIGN_UP=false \
    -e GF_ANALYTICS_REPORTING_ENABLED=false \
    -e GF_SERVER_ROOT_URL="$ROOT_URL" \
    -e GF_SERVER_SERVE_FROM_SUB_PATH=true \
    -e GF_SECURITY_COOKIE_SECURE="$COOKIE_SECURE" \
    -v grafana_data:/var/lib/grafana \
    -v "$MON_DIR/grafana/provisioning":/etc/grafana/provisioning:ro \
    -v "$MON_DIR/grafana/dashboards":/etc/grafana/dashboards:ro \
    --log-opt max-size=10m --log-opt max-file=3 \
    "$GRAFANA_IMAGE" >/dev/null
  echo "grafana: (re)criado"
else
  echo "grafana: ok"
fi
