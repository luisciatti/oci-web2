# Monitoramento (Prometheus + Grafana)

Roda na VM `vm-app`, na rede docker `web2`, ao lado do app e do Caddy.

| Peça | Onde | Acesso |
|---|---|---|
| Prometheus | container `prometheus` | privado (só a rede `web2`); coleta `app:8080/actuator/prometheus` a cada 15 s, guarda 15 dias |
| Grafana | container `grafana` | `https://<DOMAIN>/grafana/` (Caddy) ou túnel SSH em `localhost:3000/grafana/` |

O `/actuator/*` é bloqueado (404) no Caddy; o Prometheus fala direto com o app, sem passar pelo Caddy.

## Arquivos
- `monitoring-up.sh`: sobe/atualiza os dois containers (idempotente; recria só se imagem ou config mudou)
- `prometheus.yml`: o que coletar
- `grafana/provisioning/datasources/prometheus.yml`: fonte de dados
- `grafana/provisioning/dashboards/web2.yml`: pasta "Web2" lendo `/etc/grafana/dashboards`
- `grafana/dashboards/web2-api-dashboard.json`: dashboard "Web2 - API"

## Instalar / atualizar na VM
1. Copiar esta pasta para `/opt/monitoring` na VM.
2. `sudo /opt/monitoring/monitoring-up.sh`
3. A senha do `admin` fica em `/etc/app/monitoring.env` (gerada no primeiro uso, fora do Git).

## Mudar o dashboard
Edite no Grafana, `Export > Export as JSON`, substitua `grafana/dashboards/web2-api-dashboard.json`
no repo, copie para a VM e rode `monitoring-up.sh` de novo.
