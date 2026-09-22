# Security and Operational Boundaries

## Local-only defaults

The samples are for an isolated development host. Before sharing the host or exposing the services, provide:

- TLS for client-facing endpoints and the Elasticsearch/Kibana path
- authenticated ingress or network policy
- non-placeholder Grafana and Alertmanager credentials
- a reviewed image version and digest policy
- storage capacity, backup, restore, and upgrade procedures

## Credentials and generated configuration

Never commit `.env`, `monitoring/config.monitoring`, generated `kibana.yml`, alert delivery credentials, service tokens, or Filebeat passwords. The repository tracks only templates with placeholders. Rotate any credential that was accidentally exposed.

## Filesystem permissions

The bootstrap requires root because it prepares host bind mounts. It assigns service-specific ownership where the container contract is known and avoids the previous recursive `chmod 777` behavior. Review UID/GID assumptions when changing image versions or moving the stack to another host.

## Network exposure

Compose currently binds Elasticsearch, Kibana, Prometheus, Grafana, and Alertmanager ports to the host. Restrict bindings to `127.0.0.1` for a single-user lab or place the stack behind a hardened, authenticated reverse proxy. Do not expose Elasticsearch directly to the public internet.

## Destructive operations

Routine shutdown does not remove volumes. Treat deletion of `/opt/elk` or `/opt/monitoring` as a data-destruction event and verify backups or disposable-environment intent first.

## Filebeat installer

Filebeat is opt-in because the installer changes host package state and creates a system service. Review `elk/install-filebeat.sh.sample` before enabling it. It should be run only on a supported Debian/Ubuntu host with a controlled APT trust and package policy.
