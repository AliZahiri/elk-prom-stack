# ELK and Prometheus Observability Stack

A Docker Compose lab for collecting host metrics and application logs with Elasticsearch, Kibana, Prometheus, Grafana, Alertmanager, and Node Exporter.

This repository is designed for local or isolated development environments. It is not a production-ready observability platform: authentication, TLS, network exposure, storage sizing, backups, upgrades, and alert delivery still require environment-specific engineering.

## Architecture

```text
host metrics ──> Node Exporter ──> Prometheus ──> Grafana
                                      │              │
                                      └──────────────> Alertmanager

application logs ──> optional Filebeat ──> Elasticsearch ──> Kibana
```

The Compose network is named `svc`. Elasticsearch and Kibana use the same pinned minor version. Prometheus and Grafana provide the metrics path; Filebeat is an explicit opt-in because installation changes the host package state.

See [docs/architecture.md](docs/architecture.md) for service ownership, data paths, and startup flow. See [docs/security.md](docs/security.md) before exposing any port beyond localhost.

## Requirements

- Linux host with Docker Engine and Docker Compose v2
- Root access for the current bootstrap script because it creates `/opt/elk` and `/opt/monitoring` bind-mount directories
- At least 4 GiB available to Elasticsearch, plus storage for persistent metrics and logs
- `curl` and `openssl` on the host

## Quick start

1. Create local credentials from the tracked template and replace every placeholder:

   ```bash
   cp .env.sample .env
   $EDITOR .env
   ```

2. Review the local Grafana and Alertmanager samples. The bootstrap copies them to ignored runtime files when they do not exist.

3. Start the stack from the repository directory:

   ```bash
   chmod +x runIT.sh
   sudo ./runIT.sh
   ```

   The script creates runtime configuration from the `*.sample` files, starts Elasticsearch first, waits up to three minutes for readiness, generates Kibana encryption keys and a service token, and then starts the remaining services.

4. Open the local endpoints:

   | Service | URL |
   | --- | --- |
   | Elasticsearch | `http://localhost:9200` |
   | Kibana | `http://localhost:5601` |
   | Prometheus | `http://localhost:9090` |
   | Grafana | `http://localhost:3000` |
   | Alertmanager | `http://localhost:9093` |

Filebeat is skipped by default. To opt in on a Debian/Ubuntu host, set `INSTALL_FILEBEAT=true` and provide `FILEBEAT_PASS` in `.env`, then rerun the bootstrap. The installer uses `sudo apt` and should be reviewed before execution.

## Runtime files and storage

The following generated files are intentionally ignored:

- `.env`
- `elk/kibana.yml`
- `monitoring/config.monitoring`
- `monitoring/prometheus.yml`
- `monitoring/alertmanager.yml`
- `monitoring/rules/*.yml`

Persistent bind mounts are created under `/opt/elk` and `/opt/monitoring`. Do not delete them as part of routine shutdown. Use `docker compose down` to stop services; remove data only as an explicit, reviewed maintenance action.

## Validation

The repository includes an offline GitHub Actions workflow that checks shell syntax and renders the Compose model using generated local sample files. Run the same checks locally with:

```bash
bash -n runIT.sh elk/install-filebeat.sh elk/install-filebeat.sh.sample
cp .env.sample .env
cp monitoring/config.monitoring.sample monitoring/config.monitoring
cp monitoring/prometheus.yml.sample monitoring/prometheus.yml
cp monitoring/alertmanager.yml.sample monitoring/alertmanager.yml
mkdir -p monitoring/rules
for sample in monitoring/rules/*.sample; do cp "$sample" "${sample%.sample}"; done
docker compose --env-file .env config --quiet
```

Do not commit the generated runtime files or real credentials.

## Limitations

- Compose publishes service ports on all host interfaces unless the port bindings are changed to `127.0.0.1`.
- The sample stack uses HTTP inside the local Docker network; TLS and an authenticated ingress are required for shared or production environments.
- The sample Alertmanager configuration contains placeholder SMTP values and is not a delivery-ready alert route.
- Images are not all pinned by digest; review and pin image references before using this as a controlled deployment input.
