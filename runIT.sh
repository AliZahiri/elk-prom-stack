#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "This bootstrap must run as root because it prepares /opt bind mounts." >&2
  exit 1
fi

# Load credentials from .env file
if [ -f .env ]; then
  # shellcheck source=/dev/null
  source .env
else
  echo "❌ .env file not found!"
  exit 1
fi

: "${ELASTIC_USER:?ELASTIC_USER must be set in .env}"
: "${ELASTIC_PASS:?ELASTIC_PASS must be set in .env}"

INSTALL_FILEBEAT="${INSTALL_FILEBEAT:-false}"
if [[ "$INSTALL_FILEBEAT" == "true" ]]; then
  : "${FILEBEAT_PASS:?FILEBEAT_PASS must be set when INSTALL_FILEBEAT=true}"
fi

KIBANA_YML_PATH="/opt/elk/kibana/kibana.yml"  


echo "🔧 Creating directories and files for Docker volumes..."

# Elasticsearch
mkdir -p /opt/elk/elasticsearch

# Kibana
mkdir -p /opt/elk/kibana
touch /opt/elk/kibana/kibana.yml

# Prometheus
mkdir -p /opt/monitoring/prometheus
mkdir -p ./monitoring/rules

copy_if_missing() {
  local sample="$1"
  local target="$2"
  if [[ ! -e "$target" ]]; then
    cp "$sample" "$target"
  fi
}

copy_if_missing monitoring/prometheus.yml.sample monitoring/prometheus.yml
copy_if_missing monitoring/rules/backend.yml.sample monitoring/rules/backend.yml
copy_if_missing monitoring/rules/node.yml.sample monitoring/rules/node.yml
copy_if_missing monitoring/rules/monitoring.yml.sample monitoring/rules/monitoring.yml

# Grafana
mkdir -p /opt/monitoring/grafana
mkdir -p /opt/monitoring/grafana/provisioning
copy_if_missing monitoring/config.monitoring.sample monitoring/config.monitoring

# Alertmanager
copy_if_missing monitoring/alertmanager.yml.sample monitoring/alertmanager.yml

# Keep host-mounted data private to root and the service users that need it.
chown -R 1000:0 /opt/elk
chown root:472 /opt/monitoring
chown -R 472:472 /opt/monitoring/grafana
chmod 0750 /opt/elk /opt/elk/elasticsearch /opt/elk/kibana /opt/monitoring
chmod 0750 /opt/monitoring/grafana /opt/monitoring/prometheus

echo "✅ All required directories and files created."


echo "🧨 Bringing down previous Docker Compose stack..."
docker compose down --remove-orphans

echo "🚀 Starting Elasticsearch only..."
docker compose up -d elasticsearch

echo "⏳ Waiting for Elasticsearch to be ready..."
deadline=$((SECONDS + 180))
until curl --fail --silent --show-error --max-time 5 \
  -u "$ELASTIC_USER:$ELASTIC_PASS" http://localhost:9200 >/dev/null; do
  if (( SECONDS >= deadline )); then
    echo "❌ Elasticsearch did not become ready within 180 seconds." >&2
    exit 1
  fi
  sleep 2
done
echo "✅ Elasticsearch is up."

echo "🧹 Cleaning up existing service token (if exists)..."
docker exec elasticsearch bin/elasticsearch-service-tokens delete elastic/kibana kibana-service-token || true

echo "🔐 Creating new service account token for Kibana..."
RAW_TOKEN=$(docker exec elasticsearch bin/elasticsearch-service-tokens create elastic/kibana kibana-service-token)
TOKEN_VALUE=$(echo "$RAW_TOKEN" | awk -F '= ' '{print $2}')

# Generate secure 32-character encryption keys
SEC_KEY=$(openssl rand -base64 24)
ENC_KEY=$(openssl rand -base64 24)
REP_KEY=$(openssl rand -base64 24)

echo "🔐 Generated encryption keys."

echo "📝 Writing kibana.yml with updated credentials..."
cat > "$KIBANA_YML_PATH" <<EOF
elasticsearch.hosts: ["http://elasticsearch:9200"]
elasticsearch.serviceAccountToken: "$TOKEN_VALUE"

server.host: "0.0.0.0"

xpack.security.encryptionKey: "$SEC_KEY"
xpack.encryptedSavedObjects.encryptionKey: "$ENC_KEY"
xpack.reporting.encryptionKey: "$REP_KEY"
EOF

echo "✅ kibana.yml updated successfully."

echo "🚀 Starting full stack..."
docker compose up -d

echo "🔁 Restarting Kibana to apply config..."
docker compose restart kibana

if [[ "$INSTALL_FILEBEAT" == "true" ]]; then
  bash ./elk/install-filebeat.sh
else
  echo "ℹ️ Filebeat installation skipped; set INSTALL_FILEBEAT=true to opt in."
fi

echo "✅ All done!"
