# Faraja

Faraja is a web application for tracking public infrastructure projects such as road construction, water systems, or schools. Each project has:

- A name, description, county, and constituency
- A budget (allocated vs. spent)
- Start and target-end dates
- A status: `planned`, `in_progress`, `delayed`, `completed`, or `cancelled`
- An implementing agency and a lead politician responsible for it

Each project can also have **milestones**: smaller checkpoints with their own due date and status (`not_started`, `in_progress`, `done`, `blocked`).

The app has three pieces that talk to each other:

1. **Backend**: the "brain". Built with FastAPI (a Python web framework) and SQLModel (a library for talking to the database). It exposes an API: a set of URLs that return JSON, like `/projects` or `/milestones`.
2. **Frontend**: the part people see and click on in a browser. Built with Next.js (a React-based framework).
3. **Database**: PostgreSQL, where all the data is stored.

## Team

| Name              | GitHub                                                     | Role     |
| ----------------- | ---------------------------------------------------------- | -------- |
| Abdirahman Maalim | [@Abdirahman-Maalim](https://github.com/Abdirahman-Maalim) | Backend  |
| Eva Muthoni       | [@teqeva](https://github.com/teqeva)                       | Frontend |
| Karen Ngugi       | [@KarenNgugi](https://github.com/KarenNgugi)               | Backend  |

## Table of Contents

1. [Running the app locally](#part-1-running-the-app-locally)
2. [Running everything with Docker](#part-2-running-everything-with-docker)
3. [Deploying to Kubernetes (Minikube + Gateway API)](#part-3-deploying-to-kubernetes-minikube--gateway-api)
4. [Monitoring (Prometheus + Grafana)](#part-4-monitoring-prometheus--grafana)
5. [Git branching best practices](#git-branching-best-practices)
6. [Thank you](#thank-you)

---

## Part 1: Running the app locally

### Prerequisites

- Git (`git --version`)
- A GitHub account with access to the repository
- Python 3, Node.js and npm

### Step 1: Clone the repository

```bash
# HTTPS
git clone https://github.com/Abdirahman-Maalim/faraja.git

# or SSH
git clone git@github.com:Abdirahman-Maalim/faraja.git

cd faraja
```

### Step 2: Set up the backend

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --reload --port 8000
```

What each command does:

| Command | What it does |
| ------- | ------------ |
| `python3 -m venv .venv` | Creates a virtual environment: a folder with its own copy of Python and its own packages. |
| `source .venv/bin/activate` | Switches your shell to use that environment instead of the system Python. |
| `pip install -r requirements.txt` | Installs every package listed in `requirements.txt`, at the exact versions listed. |
| `cp .env.example .env` | `.env.example` is a template. Your copy, `.env`, holds the real values for your machine. It is ignored by git. |
| `uvicorn app.main:app --reload --port 8000` | Starts the backend. `--reload` restarts it every time you save a code change. |

### Step 3: Set up the frontend

In a **second terminal** (leave the backend running):

```bash
cd frontend
npm install
cp .env.local.example .env.local
npm run dev -- -p 3001
```

- `npm install` downloads every JavaScript package listed in `package.json` into `node_modules/`.
- `npm run dev -- -p 3001` starts the dev server on port 3001.
- Open <http://localhost:3001>.

### Step 4: Set up the database

The backend needs a running PostgreSQL database. Install it on your machine, then:

```bash
sudo systemctl start postgresql        # Linux
# brew services start postgresql       # macOS

sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'postgres';"
sudo -u postgres psql -c "CREATE DATABASE faraja OWNER postgres;"
```

This starts PostgreSQL, sets a password for the default `postgres` user (matching what is in `.env`), and creates an empty database called `faraja`.

---

## Part 2: Running everything with Docker

Docker packages an application with everything it needs to run into a single unit called an **image**. A running copy of an image is a **container**.

### Building images individually

Each part of the project has its own `Dockerfile`. `docker build` reads it and builds an image; `-t faraja-backend:latest` gives the image a name (`faraja-backend`) and a tag (`latest`).

```bash
# Backend
docker build -t faraja-backend:latest ./backend

# Frontend
docker build --build-arg NEXT_PUBLIC_API_BASE_URL=/api -t faraja-frontend:latest ./frontend
```

> **Why does the frontend need a build argument?**
> Next.js copies every `NEXT_PUBLIC_*` variable into the JavaScript bundle **while the image is being built**. Changing the variable later, when the container starts, has no effect. So the API URL has to be passed with `--build-arg` at build time.
>
> We build with `/api`, a *relative* URL. The browser then calls the same address it loaded the page from, e.g. `http://<host>/api/projects`, and the Gateway (Part 3) forwards it to the backend. Do **not** hardcode an IP or `localhost:8000` here, or the app breaks as soon as it runs anywhere else.

### Running everything together with Docker Compose

`docker-compose.yml` describes all the services (frontend, backend, database), how they connect, where data is stored, and the environment variables each one gets.

```bash
# 1. Start everything (-d = run in the background)
docker-compose up -d

# 2. Check everything is running
docker-compose ps

# 3. Read logs if something is wrong
docker-compose logs backend

# 4. Stop everything (keeps data)
docker-compose down

# 5. Wipe everything, including data, and start fresh
docker-compose down -v
docker-compose up -d --build
```

---

## Part 3: Deploying to Kubernetes (Minikube + Gateway API)

Kubernetes (K8s) runs containers for you: it restarts crashed ones, scales them, and handles networking between them. We use **Minikube** to run a small Kubernetes cluster on our own laptops.

### The big picture

```text
                       Minikube cluster
   ┌───────────────────────────────────────────────────────────┐
   │                                                           │
Browser ──► Gateway (port 80)                                  │
   │          │                                                │
   │          ├─ /api/*  ─► faraja-backend-svc:8000 ─► backend pods (x2)
   │          │              (the /api prefix is stripped)       │
   │          │                                    └─► faraja-db-svc:5432 ─► Postgres pod
   │          │                                                │
   │          └─ /       ─► frontend:3001 ─► frontend pods (x2) │
   └───────────────────────────────────────────────────────────┘
```

**Why a Gateway?** Without it, every service needs its own exposed port. With the Gateway API there is **one entry point** and rules that send traffic to the right place by URL path. The same manifests also work on EKS later.

**Why strip `/api`?** The frontend calls `/api/projects`, but the backend serves `/projects` (no prefix). The route rewrites `/api/projects` to `/projects` before it reaches the backend.

### Folder structure

```text
k8s/
├── namespace.yaml                  # Creates the faraja-ns namespace
├── configmap.yaml                  # Non-secret config (DB host, ports, API_INTERNAL_URL)
├── persistentvolume.yaml           # Storage for Postgres data
├── persistentvolumeclaim.yaml      # Claim on that storage
├── postgres-headless-service.yaml  # Headless Service required by the StatefulSet
├── postgres-service.yaml           # faraja-db-svc: what the backend connects to
├── postgres-statefulset.yaml       # The Postgres pod
├── postgres-secret.yaml.example    # Template for the DB Secret (placeholders only)
├── backend-deployment.yaml         # Backend pods
├── backend-service.yaml            # faraja-backend-svc
├── frontend-deployment.yaml        # Frontend pods
├── frontend-service.yaml           # frontend
├── gateway.yaml                    # The Gateway (entry point on port 80)
└── httproute.yaml                  # Routing rules: /api -> backend, / -> frontend
```

> `kubectl apply -f k8s/` only reads `.yaml`, `.yml` and `.json` files, so `postgres-secret.yaml.example` is safely ignored.

### Names you will see in commands

| Thing | Name | Port |
| ----- | ---- | ---- |
| Namespace | `faraja-ns` | |
| Postgres StatefulSet | `faraja-db-sts` | |
| Postgres Service | `faraja-db-svc` | 5432 |
| Backend Deployment | `faraja-backend-deployment` | |
| Backend Service | `faraja-backend-svc` | 8000 |
| Frontend Deployment | `frontend` | |
| Frontend Service | `frontend` | 3001 |
| Gateway | `faraja-gateway` | 80 |
| HTTPRoute | `faraja-route` | |
| Gateway's nginx Service | `faraja-gateway-nginx` | NodePort |

### Step 1: Start Minikube

```bash
minikube start --cpus=4 --memory=6144 --driver=docker
kubectl get nodes
```

The node should show `Ready`. We ask for 4 CPUs and 6 GB because the app, the Gateway and the monitoring stack together do not fit in Minikube's small defaults, and pods stay `Pending`.

### Step 2: Get the images into Minikube

Minikube runs its **own** Docker daemon. An image built on your laptop's Docker is invisible to the cluster. The Deployments use `imagePullPolicy: Never`, so the images must already be inside Minikube. There are two ways.

**Option A: build directly inside Minikube**

```bash
eval $(minikube docker-env)       # point your docker command at Minikube's daemon

docker build -t faraja-backend:latest ./backend
docker build --build-arg NEXT_PUBLIC_API_BASE_URL=/api -t faraja-frontend:latest ./frontend
docker pull postgres:16-alpine

eval $(minikube docker-env --unset)   # back to your normal Docker
```

**Option B: build normally, then copy the images in**

```bash
docker build -t faraja-backend:latest ./backend
docker build --build-arg NEXT_PUBLIC_API_BASE_URL=/api -t faraja-frontend:latest ./frontend
docker pull postgres:16-alpine

minikube image load faraja-backend:latest
minikube image load faraja-frontend:latest
minikube image load postgres:16-alpine
```

Either way, check they arrived:

```bash
minikube image ls | grep -E 'faraja|postgres'
```

**Check the frontend really has `/api` baked in** (this saves a lot of debugging later):

```bash
docker run --rm faraja-frontend:latest \
  sh -c "grep -R 'localhost:8000' /app/.next/static 2>/dev/null || true"
```

No output means no stale `localhost:8000` is in the bundle, which is what you want.

### Step 3: Create the namespace and the database Secret

Apply the namespace **first**. If you apply everything at once, resources can fail with `namespaces "faraja-ns" not found` because they were created before the namespace existed.

```bash
kubectl apply -f k8s/namespace.yaml
```

The database password and connection string live in a Kubernetes **Secret** that is **never committed to git**. Create it with `kubectl`:

```bash
kubectl create secret generic faraja-db-secret -n faraja-ns \
  --from-literal=POSTGRES_PASSWORD='<choose-a-password>' \
  --from-literal=DATABASE_URL='postgresql+psycopg://postgres:<choose-a-password>@faraja-db-svc:5432/faraja'
```

Things to notice:

- Use the **same password** in both lines.
- The URL scheme is `postgresql+psycopg://`, which is what the backend expects.
- The host is `faraja-db-svc`, the Postgres **Service** name. Do **not** use `localhost`: inside a pod, `localhost` is the pod itself, not the database.
- `k8s/postgres-secret.yaml.example` shows the keys with placeholder values.

Check it exists:

```bash
kubectl get secret faraja-db-secret -n faraja-ns
```

### Step 4: Validate, then deploy the app

Dry-run first. This checks the manifests without creating anything:

```bash
kubectl apply -f k8s/ --dry-run=server
```

> Do the dry-run **after** Step 3. Before the namespace exists, a server dry-run reports misleading `not found` errors.

Then apply:

```bash
kubectl apply -f k8s/
kubectl get pods -n faraja-ns -w      # Ctrl+C when settled
```

You should end up with:

| Pod | Count | Status |
| --- | ----- | ------ |
| `faraja-db-sts-0` | 1 | `Running` |
| `faraja-backend-deployment-...` | 2 | `Running` |
| `frontend-...` | 2 | `Running` |

Also check storage and Services:

```bash
kubectl get svc,pvc -n faraja-ns
```

The PVC `faraja-pvc` should be `Bound`.

### Step 5: Install the Gateway API and NGINX Gateway Fabric

Two things get installed. The **Gateway API CRDs** teach Kubernetes what a `Gateway` and an `HTTPRoute` are. **NGINX Gateway Fabric** is the controller that actually acts on them.

> **Check for new releases first.** These commands pin **v2.7.2**, the latest at the time of writing. See <https://github.com/nginx/nginx-gateway-fabric/releases>.

```bash
# 1. Gateway API CRDs (standard channel)
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.7.2" | kubectl apply -f -

# 2. The controller
helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
  --version 2.7.2 \
  --create-namespace -n nginx-gateway \
  --set nginx.service.type=NodePort
```

`--set nginx.service.type=NodePort` matters on Minikube. The default type, `LoadBalancer`, stays `<pending>` forever unless you run `minikube tunnel`.

Verify:

```bash
kubectl get pods -n nginx-gateway     # controller pod Running
kubectl get gatewayclass              # 'nginx' with ACCEPTED = True
```

### Step 6: Create the Gateway and the route

These are already in `k8s/` (`gateway.yaml` and `httproute.yaml`), so Step 4's `kubectl apply -f k8s/` created them. If the Gateway CRDs were not installed yet at that point, apply them now:

```bash
kubectl apply -f k8s/gateway.yaml -f k8s/httproute.yaml
kubectl get gateway,httproute -n faraja-ns
kubectl get pods,svc -n faraja-ns | grep gateway
```

You want the Gateway to show `PROGRAMMED: True`, an nginx pod `Running` (`faraja-gateway-nginx-...`), and a Service `faraja-gateway-nginx`.

The route in short:

```yaml
rules:
  - matches: [{ path: { type: PathPrefix, value: /api } }]
    filters:
      - type: URLRewrite
        urlRewrite:
          path: { type: ReplacePrefixMatch, replacePrefixMatch: / }   # /api/projects -> /projects
    backendRefs: [{ name: faraja-backend-svc, port: 8000 }]
  - matches: [{ path: { type: PathPrefix, value: / } }]
    backendRefs: [{ name: frontend, port: 3001 }]
```

### Step 7: Open the app

```bash
minikube service faraja-gateway-nginx -n faraja-ns --url
```

This prints a URL, e.g. `http://192.168.49.2:30299`. On the Docker driver the command may need to stay running; if it does, use a second terminal. Open the URL in your browser, then test the API through the Gateway:

```bash
curl -i <that-url>/api/health          # expect HTTP 200
curl -i <that-url>/api/projects        # expect HTTP 200 and [] on a fresh database
```

An empty list `[]` is a **good** result: the whole path (Gateway, route, backend, Postgres) works, there are just no projects yet. Create one in the UI, refresh, and confirm it is still there.

If the NodePort URL is not reachable from your machine, use a port-forward instead:

```bash
kubectl port-forward -n faraja-ns svc/faraja-gateway-nginx 8080:80
# then open http://localhost:8080
```

### How the frontend knows where the backend is

`frontend/lib/api.ts` uses a **different URL in the browser and on the server**:

| Where the code runs | URL used | Why |
| ------------------- | -------- | --- |
| Browser | `NEXT_PUBLIC_API_BASE_URL` (`/api`) | Same origin as the page. The Gateway routes it. |
| Server (Next.js rendering the page) | `API_INTERNAL_URL` | Node cannot fetch a relative URL like `/api`. It calls the backend Service directly. |

`API_INTERNAL_URL` is set in `k8s/configmap.yaml` to `http://faraja-backend-svc:8000` (and in `docker-compose.yml` to `http://backend:8000`). This is why the backend logs show `GET /projects` coming from the frontend pods' IPs, as well as `/api/projects` coming through the Gateway.

### After code changes

```bash
# Backend
docker build -t faraja-backend:latest ./backend
minikube image load faraja-backend:latest
kubectl rollout restart deployment faraja-backend-deployment -n faraja-ns

# Frontend (always keep the build arg)
docker build --build-arg NEXT_PUBLIC_API_BASE_URL=/api -t faraja-frontend:latest ./frontend
minikube image load faraja-frontend:latest
kubectl rollout restart deployment frontend -n faraja-ns
```

> `minikube image load` of an image that already exists under the same tag can keep serving the old copy. If your change does not show up, remove the old image inside Minikube first with `minikube image rm faraja-frontend:latest`, then load again.

### Troubleshooting

Always start with:

```bash
kubectl get pods -n faraja-ns
kubectl describe pod <pod-name> -n faraja-ns     # read the Events section at the bottom
kubectl logs <pod-name> -n faraja-ns
kubectl logs <pod-name> -n faraja-ns --previous  # logs from the run that crashed
```

Problems we actually hit, and the fix for each:

| Symptom | Cause | Fix |
| ------- | ----- | --- |
| `namespaces "faraja-ns" not found` on apply | Resources applied before the namespace existed | `kubectl apply -f k8s/namespace.yaml` first, then apply the rest |
| `CreateContainerConfigError` on the DB or backend pod | The pod references a Secret or ConfigMap that does not exist yet (`secret "faraja-db-secret" not found`) | Create the Secret (Step 3). The `describe pod` Events show the exact missing name or key. |
| Backend pod `Error` / `CrashLoopBackOff` right after the first deploy | Backend started before Postgres was ready and exited | Once the DB pod is `Running`: `kubectl rollout restart deployment faraja-backend-deployment -n faraja-ns` |
| `ImagePullBackOff` / `ErrImageNeverPull` | The image is not inside Minikube | Redo Step 2, then `minikube image ls` |
| Browser calls `localhost:8000` or an IP and fails | Frontend image was built without `--build-arg NEXT_PUBLIC_API_BASE_URL=/api` | Rebuild with the build arg and reload the image |
| `curl http://faraja-backend-svc:8000` fails from your terminal with "Could not resolve host" | Service names are cluster-internal DNS. Only pods can resolve them. | Use `kubectl port-forward svc/faraja-backend-svc 8000:8000 -n faraja-ns` and curl `localhost:8000` |
| Gateway not `PROGRAMMED`, or no `faraja-gateway-nginx` pod | Controller or CRDs missing | Redo Step 5, then `kubectl describe gateway faraja-gateway -n faraja-ns` |
| `/api/...` returns 404 from the backend | The prefix is not being stripped | Check the `URLRewrite` filter in `httproute.yaml` |

### Cleanup

```bash
kubectl delete -f k8s/                                   # the app and the Gateway
kubectl delete secret faraja-db-secret -n faraja-ns      # the Secret was created by hand
helm uninstall ngf -n nginx-gateway                      # the Gateway controller
minikube stop                                            # or: minikube delete
```

> Postgres data lives on the PersistentVolume. If you recreate the database but keep old data, Postgres **ignores** the new `POSTGRES_PASSWORD` because the data directory already exists. A "password authentication failed" error after changing the password means you need to wipe the volume.

---

## Part 4: Monitoring (Prometheus + Grafana)

### How it works

```text
Backend app ──► /metrics ──► Prometheus ──► Grafana
                                 │
                          PrometheusRule (alerts)
```

The backend publishes metrics at `/metrics`. Prometheus collects them every 15 seconds and stores them. Grafana uses Prometheus as a data source to draw dashboards.

**Metric types used:**

- **Counter**: only goes up, e.g. total requests
- **Gauge**: goes up and down, e.g. the number of projects
- **Histogram**: measures a distribution, e.g. request latency

### 1. Backend exposes metrics

Add to `backend/requirements.txt`:

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

The instrumentator tracks requests and their duration automatically. Custom gauges hold Faraja-specific numbers.

Check it works:

```bash
kubectl port-forward svc/faraja-backend-svc -n faraja-ns 8000:8000
curl http://localhost:8000/metrics
```

Look for lines like `faraja_projects_total 5.0`.

### 2. Install Prometheus + Grafana

Make sure Minikube is running and Helm is installed:

```bash
minikube start
kubectl get nodes
helm version
```

Helm can install Prometheus, Grafana, and Alertmanager together with one chart:

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
kubectl create namespace monitoring

helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.adminPassword=admin \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
```

> `adminPassword=admin` is fine on a laptop. Never use it on a shared or cloud cluster.

Check the pods (this takes a few minutes; several images are pulled):

```bash
kubectl get pods -n monitoring
```

### 3. Connect Prometheus to the backend

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

The `selector` must match the **labels on the backend Service**, and `port: http` must match a **named port** on that Service. `backend-service.yaml` needs both:

```yaml
metadata:
  labels:
    app: faraja
spec:
  ports:
    - name: http
      port: 8000
```

Apply and check:

```bash
kubectl apply -f k8s/servicemonitor.yaml
kubectl get servicemonitor -n monitoring

kubectl port-forward svc/monitoring-kube-prometheus-prometheus -n monitoring 9090:9090
```

Open <http://localhost:9090/targets> and search for `faraja`. The target should show **UP**.

### 4. Configure alerts

Create `monitoring/alert-rules.yaml`:

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

- `expr`: the PromQL query that detects the problem
- `for: 5m`: the condition must stay true for 5 minutes before the alert fires
- `severity` / `team`: labels for organizing alerts

```bash
kubectl apply -f monitoring/alert-rules.yaml
kubectl get prometheusrule -n monitoring
```

### 5. Grafana dashboard

#### Open Grafana

```bash
kubectl port-forward svc/monitoring-grafana -n monitoring 3000:80
```

Keep that terminal open and go to <http://localhost:3000>. Username `admin`; password `admin` if you used `--set grafana.adminPassword=admin`. If you forgot it:

```bash
kubectl get secret monitoring-grafana -n monitoring -o jsonpath="{.data.admin-password}" | base64 -d ; echo
```

#### Create a panel

1. Open the dashboard.
2. Select **Edit → Add panel**.
3. Switch the query editor to **Code** (not Builder).
4. Choose **Prometheus** as the data source.
5. Enter the PromQL query and click **Run queries**.
6. Set the panel title and visualization type.
7. Click **Apply**, then **Save dashboard**.

To show several metrics in one panel, click **+ Query** and add another.

#### Add a namespace variable

1. Open **Dashboard settings → Variables → Add variable**.
2. **Name**: `namespace`. **Type**: Query. **Data source**: Prometheus.
3. **Query**: `label_values(kube_pod_info, namespace)`
4. Click **Apply**.

#### Faraja Overview dashboard

| Panel | Query |
| ----- | ----- |
| Request Rate | `sum(rate(http_requests_total[5m])) by (handler, status)` |
| Error Rate | `sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) * 100` |
| P95 Latency | `histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))` |
| Business Metrics | `faraja_projects_total`, `faraja_milestones_total` |
| Memory per Pod | `container_memory_working_set_bytes{namespace="faraja-ns"}` |
| CPU per Pod | `rate(container_cpu_usage_seconds_total{namespace="faraja-ns"}[5m])` |

#### Export the dashboard

Open **Dashboard settings → JSON Model** (or **Export**), copy the JSON, and save it as `monitoring/dashboards/faraja-overview.json`.

#### Blank panels

If a query returns nothing, Grafana shows a blank panel instead of `0`. For example, the error rate returns no series when there are no errors. To show `0` instead:

```promql
(sum(rate(http_requests_total{status=~"5.."}[5m])) / sum(rate(http_requests_total[5m])) * 100) or vector(0)
```

---

## Git branching best practices

We use a structured branching strategy to keep development organized and protect the stable code.

### Branches

- `main`: stable, production-ready code
- `Developer`: integration branch where finished work is combined and tested
- `feat/*` or `feature/*`: one branch per feature or task
- `fix/*`: bug fixes
- `docs/*`: documentation changes

### Workflow

1. Start from the latest `Developer`.
2. Create a separate branch for your task.
3. Make and test your changes.
4. Commit in small, logical steps with clear messages.
5. Push the branch to GitHub.
6. Open a Pull Request into `Developer` and explain *what* changed and *why* in the description.
7. Ask a teammate for review.
8. Address comments with more commits.
9. Merge after approval.
10. Delete the branch after merging.

```bash
git checkout Developer
git pull origin Developer

git checkout -b feat/frontend-dashboard

# make changes, then stage only what belongs together
git add frontend/lib/api.ts
git commit -m "frontend: use different API base URLs for browser and server"
git push -u origin feat/frontend-dashboard
```

After the PR is approved and merged:

```bash
git checkout Developer
git pull origin Developer
git branch -d feat/frontend-dashboard
git push origin --delete feat/frontend-dashboard
```

### Good commits

- **One idea per commit.** Dependencies, then the code that uses them, then the Docker image, then the Kubernetes manifests. A reader can follow the story.
- **Use `git add <file>`, not `git add .`**, and check `git diff --cached --stat` before committing to see exactly what is staged.
- **Explain the why in the message body**, not only the what.
- **Never commit secrets.** Passwords, `.env` files, and real Secret manifests stay out of git. Commit an `.example` file with placeholders instead. If one slips in, deleting it later does **not** remove it from history, so rotate the credential.

### Branch naming

```text
feat/minikube-gateway-api
feat/project-api
fix/database-connection
fix/frontend-api-url
docs/update-readme
```

---

## Thank you

Thank you for contributing to Faraja! Every feature, bug fix, doc improvement, and code review makes the project better. For questions or suggestions, open an issue or talk to the team.