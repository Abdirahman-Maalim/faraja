# Faraja - Project Summary
Faraja is a web application for tracking public infrastructure projects like road construction, water systems, or schools. Each project has:

- A name, description, county, and constituency
- A budget (allocated vs. spent)
- Start and target-end dates
- A status: planned, in_progress, delayed, completed, or cancelled
- An implementing agency and a lead politician responsible for it
  
## Team Members

| Name              | GitHub                                                     | Role     |
| ----------------- | ---------------------------------------------------------- | -------- |
| Abdirahman Maalim | [@Abdirahman-Maalim](https://github.com/Abdirahman-Maalim) | Backend  |
| Eva Muthoni       | [@teqeva](https://github.com/teqeva)                       | Frontend |
| Karen Ngugi       | [@KarenNgugi](https://github.com/KarenNgugi)               | Backend  |

## Table of Contents

1. [Running the App Locally](#part-1-running-the-app-locally)

2. [Running Everything with Docker](#part-2-running-everything-with-docker)

3. [Deploying to Kubernetes](#part-3---deploying-to-kubernetes)

4. [Monitoring (Prometheus + Grafana)](#part-4-monitoring-prometheus--grafana)

5. [Git Branching Best Practices](#git-branching-best-practices)

6. [Thank You](#6-thank-you)


Each project can have milestones - smaller checkpoints within the project, each with their own due date and status (not_started, in_progress, done, blocked).

The app has two separate pieces that talk to each other:
1. Backend: the "brain." Built with FastAPI (a Python web framework) SQLModel (a library for talking to the database). It exposes an API - a set of URLs that return data as JSON, like /projects or /milestones.
2. Frontend: the part people actually see and click on in a browser. Built with Next.js (a React-based framework).  

---

## Part 1: Running the App Locally

### Prerequisites

Before cloning the repository, ensure you have:

* Git installed (`git --version`)
* A GitHub account with access to the repository

### Clone the Repository

Using HTTPS:

```bash
git clone https://github.com/Abdirahman-Maalim/faraja.git
```

Using SSH:

```bash
git clone git@github.com:Abdirahman-Maalim/faraja.git
```
---

### Step 2: Set up the backend

```bash

cd backend
python3 -m venv .venv
```

- This creates a virtual environment - a self-contained folder holding its own copy of Python and its own set of installed packages.

```bash

source .venv/bin/activate
```

- This "activates" that virtual environment - it uses the versions inside .venv, not your computer's system-wide Python.

  
```bash

pip install -r requirements.txt
```


- pip install -r reads that list and installs everything along with their exact version.

  
```bash

cp .env.example .env
```


- env.example is a template showing what values are expected copied to .env gives you a starting point so you can then edit with real values for your machine.
- 
```bash

uvicorn app.main:app --reload --port 8000
```

- This starts the backend server. uvicorn is the program that actually runs a FastAPI app. --reload means it automatically restarts whenever you save a code change.
  
---

### Step 3: Set up the frontend

In a separate terminal window (leave the backend running in the first one):

```bash

cd frontend
npm install
```

- npm install reads package.json  and downloads every JavaScript package into a folder called node_modules.
  
```bash

cp .env.local.example .env.local
npm run dev -- -p 3001
```

- npm run dev starts the frontend's development server; -p 3001 tells it to use port 3001 

- Visit http://localhost:3001 - that's the actual app you can click through.

### Step 4: Set up the database

The backend needs a running PostgreSQL database to store data in. 

install PostgreSQL directly on your machine:

```bash

sudo systemctl start postgresql        # Linux
# brew services start postgresql       # macOS

sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'postgres';"
sudo -u postgres psql -c "CREATE DATABASE faraja OWNER postgres;"
```

This starts the PostgreSQL service, sets a password for the default postgres user (matching what's in .env). The and creates an empty database called faraja.

---

## Part 2: Running everything with Docker

Docker lets you package an application together with everything it needs to run into a single unit called an image. 

---

### Building images individually

Each part of the project has its own Dockerfile - backend, frontend and database

- docker build reads the Dockerfile in the current directory (.) and builds an image from it. -t faraja-backend:latest gives that image a name (faraja-backend) and a tag (latest)

  
i) Backend
```bash

cd backend
docker build -t faraja-backend:latest .
```



ii) Frontend:

```bash

cd frontend
docker build -t faraja-frontend:latest .
```

> **Note:** You can use `--build-arg` to pass the backend API URL during the Docker build. Without it, the Dockerfile uses the default API URL.
>
> ```bash
> docker build --build-arg API_URL=http://localhost:8000 -t faraja-frontend:latest .
> ```

---

### Running Everything Together with Docker Compose

The yaml file describes all your services and how they connect.It defines:

    - Services: The containers to run (frontend, backend, database)
    
    - Networks: How they communicate with each other
    
    - Volumes: Where data is stored persistently
    
    - Environment variables: Configuration for each service

Command to start everything:

```bash

docker-compose up -d
```

- -d means "detached": it runs in the background. 

Common Docker Compose Useful commands:
```bash

# 1. Start everything
docker-compose up -d

# 2. Check everything is running
docker-compose ps

# 3. Check logs if something is wrong
docker-compose logs backend

# 4. Stop everything (keep data)
docker-compose down

# 5. Start again (with existing data)
docker-compose up -d

# 6. Wipe everything and start fresh
docker-compose down -v
docker-compose up -d --build

```

## Part 3 - Deploying to Kubernetes

Kubernetes manages containerized applications by handling pod restarts, scaling, networking, and updates.

For this project, we use **Minikube** to run Kubernetes locally.


## Folder Structure

The Kubernetes manifests are stored in the `k8s/` directory:

```text
k8s/
├── namespace.yaml                # Creates the Faraja namespace
├── configmap.yaml                # Stores non-sensitive configuration
├── backend-deployment.yaml       # Deploys the backend pods
├── frontend-deployment.yaml      # Deploys the frontend pods
├── backend-service.yaml          # Provides networking for the backend
├── frontend-service.yaml         # Provides access to the frontend
├── postgres-statefulset.yaml     # Deploys PostgreSQL with stable identity
├── postgres-service.yaml         # Provides networking for PostgreSQL
├── persistentvolume.yaml         # Defines persistent storage
└── persistentvolumeclaim.yaml    # Requests persistent storage
```

---

### 1. Build and Load Images

Build the application images:

```bash
docker build -t faraja-backend:latest ./backend
docker build -t faraja-frontend:latest ./frontend
```

Load them into Minikube:

```bash
minikube image load faraja-backend:latest
minikube image load faraja-frontend:latest
```

> The deployments use `imagePullPolicy: Never`, so the images must already exist inside Minikube.

---

### 2. Dry-Run Before Deployment

Before applying the manifests, validate them using a server-side dry run:

```bash
kubectl apply -f k8s/ --dry-run=server
```

If everything is valid, Kubernetes will report the resources without actually creating them.

You can also check the YAML locally with:

```bash
kubectl apply -f k8s/ --dry-run=client
```

> **Recommended workflow:** Always dry-run first, then apply.

---

### 3. Deploy Everything

Once the dry run succeeds:

```bash
kubectl apply -f k8s/
```

Check the deployment:

```bash
kubectl get all -n faraja-ns
```

---

## Important Configuration Checks

### Namespace

All namespaced resources should use:

```yaml
namespace: faraja-ns
```

### Service Selectors

Service selectors must match the **labels on the Pods**.

```yaml
# Deployment
labels:
  app: backend

# Service
selector:
  app: backend
```

### PostgreSQL

The PostgreSQL Service selector must match the PostgreSQL **Pod labels**, not the container name.

### Storage

The PVC must request storage that can be satisfied by the available PV.

Check:

```bash
kubectl get pv
kubectl get pvc -n faraja-ns
```

The PVC should show:

```text
STATUS: Bound
```

---

### 4. Verify the Deployment

Check Pods:

```bash
kubectl get pods -n faraja-ns
```

Check Services:

```bash
kubectl get services -n faraja-ns
```

Check logs:

```bash
kubectl logs <pod-name> -n faraja-ns
```

Debug a pod:

```bash
kubectl describe pod <pod-name> -n faraja-ns
```

Access the frontend:

```bash
minikube service frontend-service -n faraja-ns
```

---

### 5. After Code Changes

Rebuild and reload the affected image:

```bash
docker build -t faraja-backend:latest ./backend
minikube image load faraja-backend:latest
kubectl rollout restart deployment backend-deployment -n faraja-ns
```

For the frontend:

```bash
docker build -t faraja-frontend:latest ./frontend
minikube image load faraja-frontend:latest
kubectl rollout restart deployment frontend-deployment -n faraja-ns
```

---

## Troubleshooting

### Check pod status

```bash
kubectl get pods -n faraja-ns
```

### Image error

```bash
minikube image load faraja-backend:latest
minikube image load faraja-frontend:latest
```

### Pod crashing

```bash
kubectl logs <pod-name> -n faraja-ns
kubectl describe pod <pod-name> -n faraja-ns
```
## Cleanup

```bash
kubectl delete -f k8s/
```

---

## Part 4: Monitoring (Prometheus + Grafana)

### How it works

```text
Backend app → /metrics → Prometheus → Grafana
                 ↓
          PrometheusRule (alerts)
```

The backend publishes metrics at `/metrics`. Prometheus collects them every 15 seconds and stores the data. Grafana uses Prometheus data to create dashboards and graphs.

**Metric types used:**

* **Counter** — keeps increasing, such as total requests
* **Gauge** — can increase or decrease, such as the number of projects
* **Histogram** — measures values such as request latency

### 1. Backend Exposes Metrics

Add these packages to `backend/requirements.txt`:

```text
prometheus-fastapi-instrumentator==7.0.0
prometheus-client==0.20.0
```

In `backend/app/main.py`:

```python
from prometheus_fastapi_instrumentator import Instrumentator
from prometheus_client import Gauge

Instrumentator().instrument(app).expose(app, endpoint="/metrics")

projects_total = Gauge("faraja_projects_total", "Total number of projects")
```

The instrumentator automatically tracks requests and their duration. Custom gauges are used for Faraja-specific metrics.

**Check that it works:**

```bash
kubectl port-forward svc/faraja-backend-svc -n faraja-ns 8000:8000
curl http://localhost:8000/metrics
```

Look for metrics such as:

```text
faraja_projects_total 5.0
```

---

### 2. Install Prometheus + Grafana
Make sure Minikube, kubectl, and Helm are installed and that Minikube is running:

```bash
minikube start
kubectl get nodes
helm version
```

Helm can install Prometheus, Grafana, Alertmanager, and other monitoring components together.

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create namespace monitoring

helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.adminPassword=admin \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
```

Check that the monitoring pods are running:

```bash
kubectl get pods -n monitoring
```

### 3. Connect Prometheus to the Backend

Create `k8s/servicemonitor.yaml`:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: faraja-backend-monitor
  namespace: monitoring
  labels:
    release: monitoring
spec:
  namespaceSelector:
    matchNames:
      - faraja-ns
  selector:
    matchLabels:
      app: faraja
  endpoints:
    - port: http
      path: /metrics
      interval: 15s
```

The `selector` matches the labels on the **backend Service**.

Make sure `backend-service.yaml` contains:

```yaml
metadata:
  labels:
    app: faraja
```

Apply the ServiceMonitor:
```bash
kubectl apply -f k8s/servicemonitor.yaml
```

Check that it was created:
```bash
kubectl get servicemonitor -n monitoring
```

Check Prometheus:

```bash
kubectl port-forward svc/monitoring-kube-prometheus-prometheus -n monitoring 9090:9090
```

Open `http://localhost:9090/targets` and search for `faraja`. The target should show **UP**.

### 4. Configure Alerts

Create `monitoring/alert-rules.yaml` and add the Faraja alert rules:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: faraja-alerts
  namespace: monitoring
  labels:
    release: monitoring
spec:
  groups:
    - name: faraja.golden-signals
      rules:
        - alert: FarajaHighErrorRate
          expr: |
            sum(rate(http_requests_total{status=~"5.."}[5m]))
            / sum(rate(http_requests_total[5m])) * 100 > 1
          for: 5m
          labels:
            severity: critical
            team: backend
          annotations:
            summary: "Faraja API error rate above 1%"
            description: "More than 1% of requests are failing."
```

* `expr` — the PromQL query used to detect the problem
* `for: 5m` — requires the condition to remain true for 5 minutes
* `severity` / `team` — labels used to organize alerts

Apply the alert:

```bash
kubectl apply -f monitoring/alert-rules.yaml
kubectl get prometheusrule -n monitoring
```

### 5. Grafana Dashboard

Grafana is used to visualize the metrics collected by Prometheus through dashboards and panels.

#### Accessing Grafana

Start port forwarding:

```bash
kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80
```

Keep the terminal running, then open:

```text
http://localhost:3000
```

#### Logging In

**Username:**

```text
admin
```

**Password:**

If you set the password during installation using:

```bash
--set grafana.adminPassword=admin
```

then use:

```text
admin
```

If you did not set it or forgot it, retrieve the password from the Kubernetes Secret:

```bash
kubectl get secret monitoring-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 -d ; echo
```

This decodes the password stored by Kubernetes. The username is `admin` unless it was changed.

### Working Inside the Grafana UI

#### Creating a Panel

1. Open the dashboard.
2. Select **Edit → Add panel**.
3. Set the query editor to **Code** instead of **Builder**.
4. Select **Prometheus** as the data source.
5. Enter the PromQL query.
6. Click **Run queries**.
7. Set the panel title and visualization type.
8. Click **Apply**.
9. Click **Save dashboard**.

#### Adding Multiple Queries to One Panel

To display multiple metrics in the same panel:

1. Open the panel editor.
2. Enter the first query.
3. Click **+ Query**.
4. Enter the second query.
5. Run the queries.

Both queries can then be displayed in the same panel.

### Adding a Namespace Variable

A namespace variable allows the dashboard to filter metrics by Kubernetes namespace.

1. Open **Dashboard settings**.
2. Select **Variables**.
3. Click **Add variable**.
4. Set **Name** to:

```text
namespace
```

5. Set **Type** to **Query**.
6. Set the data source to **Prometheus**.
7. Enter:

```text
label_values(kube_pod_info, namespace)
```

8. Click **Apply** and return to the dashboard.

### Faraja Overview Dashboard

The **Faraja Overview** dashboard contains the following panels:

| Panel            | Query                                                                                          |
| ---------------- | ---------------------------------------------------------------------------------------------- |
| Request Rate     | `sum(rate(http_requests_total[5m])) by (handler, status)`                                      |
| Error Rate       | `sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) * 100` |
| P95 Latency      | `histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))`        |
| Business Metrics | `faraja_projects_total`, `faraja_milestones_total`                                             |
| Memory per Pod   | `container_memory_working_set_bytes{namespace="faraja-ns"}`                                    |
| CPU per Pod      | `rate(container_cpu_usage_seconds_total{namespace="faraja-ns"}[5m])`                           |

### Exporting the Dashboard

To save the dashboard configuration to the project:

1. Open **Dashboard settings**.
2. Select **JSON Model** or **Export**, depending on the Grafana version.
3. Copy or export the dashboard JSON.
4. Save it as:

```text
monitoring/dashboards/faraja-overview.json
```

### Common Issue: Blank Panels

If a query returns no results, Grafana may display a blank panel instead of `0`. This is normal Prometheus behavior.

For example, an error-rate query may return no series when there are currently no errors.

To display `0` instead, use:

```promql
(sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) * 100) or vector(0)
```

This returns `0` when the original query has no results.

## Git Branching Best Practices

We follow a structured branching strategy to keep development organized and protect the main codebase.

### Branch Structure

* `main` — Stable, production-ready code.
* `develop` — Integration branch where completed features are combined and tested.
* `feature/*` — Used for developing individual features or tasks.
* `fix/*` — Used for fixing bugs and issues.

### Branching Workflow

1. Start from the latest `develop` branch.
2. Create a separate branch for your task.
3. Make and test your changes.
4. Commit changes with clear, meaningful messages.
5. Push the branch to GitHub.
6. Open a Pull Request into `develop`.
7. Request a review from another team member.
8. Address review comments and push additional commits if needed.
9. Merge only after approval and successful CI checks.
10. Delete the feature/fix branch after merging.

### Example

```bash
git checkout develop
git pull origin develop

git checkout -b feature/frontend-dashboard

# Make changes

git add .
git commit -m "feat: add project dashboard"
git push -u origin feature/frontend-dashboard
```

After the Pull Request is approved:

```bash
git checkout develop
git pull origin develop
git branch -d feature/frontend-dashboard
git push origin --delete feature/frontend-dashboard
```

### Branch Naming

Use descriptive names based on the work being done:

```text
feature/frontend-dashboard
feature/project-api
feature/kubernetes-deployment
fix/database-connection
fix/frontend-api-url
docs/update-readme
```

 
## 6. Thank You

Thank you for contributing to Faraja!

We appreciate every contribution, whether it is a new feature, bug fix, documentation improvement, or code review.

For questions or suggestions, please open an issue or discuss them with the project team. 