# DevOps Docker Stack

This project sets up a local monitoring and observability stack using:

- **Elasticsearch**
- **Kibana**
- **Prometheus**
- **Grafana**
- **Alertmanager**
- **Node Exporter**

---

## 🚀 How to Run

### 1. Create your `.env` file

Before anything, copy the sample file and customize your credentials:

```bash
cp .env.sample .env
```

Update the `.env` file with your desired credentials (e.g., `ELASTIC_USER`, `ELASTIC_PASS`).

### 2. Optional: Configure Grafana admin user

```bash
cp monitoring/config.monitoring.sample monitoring/config.monitoring
```

Update the file with your Grafana admin credentials.

### 3. Run the stack

Use the provided setup script:

```bash
chmod +x runIT.sh
./runIT.sh
```

This script will:

- Create required local folders and volume files
- Spin up the services using Docker Compose
- Wait for Elasticsearch to be ready
- Generate and inject Kibana service token and encryption keys
- Restart Kibana to apply configuration

---

## 📁 Volume Directories

Data will be stored in the following directories on your local system:

- `/opt/elk/elasticsearch`
- `/opt/elk/kibana`
- `/opt/monitoring/prometheus`
- `/opt/monitoring/grafana`

These are bind-mounted for persistence.

---

## ⚠️ Do Not Commit

Make sure these files are **not committed to Git**:

- `.env`
- `monitoring/config.monitoring`
- Any files in `elk/` or `monitoring/` (except `.sample` files)

Already handled via `.gitignore`.

---

## 🛑 To Stop

```bash
docker compose down -v
```

---

Feel free to customize or expand this setup!
