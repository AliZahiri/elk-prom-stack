# Architecture

## Scope

This repository is a single-host Docker Compose observability lab. It separates the metrics path from the log path while keeping all services on the internal `svc` network.

## Components and ownership

| Component | Responsibility | Persistent state |
| --- | --- | --- |
| Elasticsearch | Stores and indexes Filebeat events | `/opt/elk/elasticsearch` |
| Kibana | Queries and visualizes Elasticsearch data | `/opt/elk/kibana` |
| Prometheus | Scrapes metrics and evaluates alert rules | `/opt/monitoring/prometheus` |
| Grafana | Builds dashboards over Prometheus data | `/opt/monitoring/grafana` |
| Alertmanager | Receives and routes Prometheus alerts | Container storage in this lab |
| Node Exporter | Exposes host metrics to Prometheus | None |
| Filebeat (optional) | Reads `/opt/*/logs/*.log` and writes Elasticsearch events | Host package/config state |

## Startup flow

1. `runIT.sh` loads `.env` and verifies the required Elasticsearch credentials.
2. Missing runtime configuration is copied from tracked samples; existing local configuration is preserved.
3. Elasticsearch starts first and is polled with a bounded readiness deadline.
4. A Kibana service token and encryption keys are generated locally and written to the ignored Kibana configuration.
5. The complete Compose stack starts. Filebeat installation runs only when `INSTALL_FILEBEAT=true`.

## Trust boundaries

- Host bind mounts are trusted inputs and must not be writable by arbitrary users.
- `.env`, generated Kibana configuration, Grafana credentials, and alert delivery credentials remain outside Git.
- Published ports are host-level exposure boundaries; the default Compose bindings are suitable only for an isolated host.
- Filebeat is a separate host mutation boundary because its optional installer adds an APT repository, packages, a system service, and an Elasticsearch user.

## Data flow

Metrics flow from Node Exporter to Prometheus, then to Grafana dashboards and Alertmanager notifications. Logs flow from application files through optional Filebeat into Elasticsearch and Kibana. No external provider or paid API is required by the default stack.
