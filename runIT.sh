#!/bin/bash
set -e

# Load credentials from .env file
if [ -f .env ]; then
  source .env
else
  echo "❌ .env file not found!"
  exit 1
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
touch ./monitoring/prometheus.yml
touch ./monitoring/rules/backend.yml
touch ./monitoring/rules/node.yml
touch ./monitoring/rules/monitoring.yml

# Grafana
mkdir -p /opt/monitoring/grafana
mkdir -p /opt/monitoring/grafana/provisioning
touch ./monitoring/config.monitoring

# Alertmanager
touch ./monitoring/alertmanager.yml

# Set permissions
chmod 777 -Rf /opt/elk
chmod 777 -Rf /opt/monitoring

echo "✅ All required directories and files created."


echo "🧨 Bringing down previous Docker Compose stack..."
docker compose down -v --volumes --remove-orphans

echo "🚀 Starting Elasticsearch only..."
docker compose up -d elasticsearch

echo "⏳ Waiting for Elasticsearch to be ready..."
until curl -u "$ELASTIC_USER:$ELASTIC_PASS" -s http://localhost:9200 >/dev/null; do
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

# Installing Filebeat service 
bash ./elk/install-filebeat.sh

echo "✅ All done!"
