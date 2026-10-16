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
| Abdirahman Maalim | [@Abdirahman-Maalim](https://github.com/Abdirahman-Maalim) | Database |
| Eva Muthoni       | [@teqeva](https://github.com/teqeva)                       | Frontend |
| Karen Ngugi       | [@KarenNgugi](https://github.com/KarenNgugi)               | Backend  |

## Table of Contents

**Production (AWS EKS)**

1. [Production Overview](#production-overview-aws-eks)
2. [GitOps Deployment with ArgoCD](#gitops-deployment-with-argocd)
3. [Infrastructure as Code with Terraform](#infrastructure-as-code-with-terraform)
4. [Traffic Routing with Gateway API](#traffic-routing-with-gateway-api)
5. [CI/CD Pipeline (Jenkins and ArgoCD)](#cicd-pipeline-jenkins-and-argocd)
6. [Monitoring in Production](#monitoring-in-production-prometheus--grafana)
7. [Bootstrapping a New Cluster](#bootstrapping-a-new-cluster)
8. [Operations and Troubleshooting](#operations-and-troubleshooting)
9. [Roadmap](#roadmap)

**[Local development](#local-development)**

10. [Part 1: Running the App Locally](#part-1-running-the-app-locally)
11. [Part 2: Running Everything with Docker](#part-2-running-everything-with-docker)
12. [Part 3: Local Kubernetes with Minikube](#part-3-local-kubernetes-with-minikube)
13. [Part 4: Local Monitoring on Minikube](#part-4-local-monitoring-on-minikube-prometheus--grafana)

**Contributing**

14. [Git Branching Best Practices](#git-branching-best-practices)
15. [Thank You](#thank-you)

Each project can have milestones - smaller checkpoints within the project, each with their own due date and status (not_started, in_progress, done, blocked).

The app has three tiers that talk to each other:

1. **Database**: PostgreSQL stores the projects and milestones. It runs as a container locally and as a StatefulSet with a persistent EBS volume on EKS.
2. **Backend**: the "brain." Built with FastAPI (a Python web framework) and SQLModel (a library for talking to the database). It exposes an API - a set of URLs that return data as JSON, like /projects or /milestones.
3. **Frontend**: the part people actually see and click on in a browser. Built with Next.js (a React-based framework).

---

## Production Overview (AWS EKS)

The live deployment runs on **Amazon EKS**. Everything is code: the infrastructure is Terraform, the application is deployed by ArgoCD from this repository, and images are built and published by Jenkins.

```text
 Developer push
      |
      v
   GitHub (branch: eks-deployment) <--------------------------+
      |                                                       |
      |  polled every 2 min                                   | commit new image tags
      v                                                       |
   Jenkins ---- build + push images (tag = commit SHA) --> Amazon ECR
                                                              |
   ArgoCD (watches k8s/ on eks-deployment) -- sync ---------> EKS cluster
                                                              |
   Internet --> AWS load balancer --> NGINX Gateway Fabric ---+--> /api      -> backend  (FastAPI)
                                                              +--> /grafana  -> Grafana
                                                              +--> /         -> frontend (Next.js)
                                                                   backend --> PostgreSQL (EBS volume)
```

| Layer | Tool | Where it lives |
|---|---|---|
| Infrastructure | Terraform (S3 remote state) | `terraform/` |
| Cluster | EKS, 4 x t3.small nodes, EBS CSI driver (IRSA) | created by Terraform |
| Continuous delivery (CD) | ArgoCD, automated sync with prune and self-heal | `argocd/`, watches `k8s/` |
| Traffic | Gateway API with NGINX Gateway Fabric | `k8s/gateway.yaml`, `k8s/httproute.yaml` |
| Continuous integration (CI) | Jenkins builds and publishes images to Amazon ECR | `Jenkinsfile` |
| Observability | kube-prometheus-stack (Prometheus, Grafana, Alertmanager) | `monitoring/` |

**Key design choices**

- **Git is the source of truth.** Nobody runs `kubectl apply` for application changes. A change reaches the cluster only by landing on `eks-deployment`.
- **Jenkins never talks to the cluster.** It builds images and commits the new tag to Git. ArgoCD does the rollout. Rolling back is a `git revert`.
- **Images are tagged with the commit SHA**, never `latest`, so every running pod maps to exactly one commit.
- **Secrets are not in Git.** The database and Grafana credentials are created in the cluster by hand (see [Bootstrapping a New Cluster](#bootstrapping-a-new-cluster)).

**Find the public address**

```bash
kubectl get gateway faraja-gateway -n faraja-ns -o jsonpath='{.status.addresses[0].value}'; echo
# fallback: kubectl get svc -A | grep LoadBalancer
```

The app is served at `http://<address>/`, the API at `http://<address>/api`, and Grafana at `http://<address>/grafana/`. Prometheus and the ArgoCD UI are deliberately not exposed publicly (see below).

---

## GitOps Deployment with ArgoCD

Faraja is deployed using [ArgoCD](https://argo-cd.readthedocs.io/), a declarative GitOps continuous delivery tool for Kubernetes. Rather than deploying manifests manually, ArgoCD continuously reconciles the live state of the cluster against the manifests in this repository. Any drift between the two is corrected automatically.

### Environments

| Environment | Cluster | Branch | Manifest path | Purpose |
|---|---|---|---|---|
| **Cloud (primary)** | Amazon EKS | [`eks-deployment`](https://github.com/Abdirahman-Maalim/faraja/tree/eks-deployment/k8s) | `k8s/` | Production-style deployment on AWS |
| Local | Minikube | [`Developer`](https://github.com/Abdirahman-Maalim/faraja/tree/Developer/k8s) | `k8s/` | Local development and testing (Parts 3 and 4) |

The ArgoCD `Application` ([`argocd/faraja-app.yaml`](https://github.com/Abdirahman-Maalim/faraja/blob/eks-deployment/argocd/faraja-app.yaml)) points at one branch through `spec.source.targetRevision`. The two environments can therefore differ in storage, image registry and traffic routing while sharing the same application code.

### Sync policy

```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
  syncOptions:
    - CreateNamespace=true
```

- **`selfHeal`** reverts any manual change to the live cluster back to what Git declares.
- **`prune`** removes resources from the cluster when they are removed from Git, so the cluster mirrors the repository.
- **Secrets are excluded from pruning.** `faraja-db-secret` is created by hand (it is not in Git) and carries the annotation `argocd.argoproj.io/sync-options=Prune=false`, otherwise ArgoCD would delete it on the next sync.

### Environment-specific differences

The `Developer` and `eks-deployment` branches intentionally differ because a single-node local cluster and a multi-node cloud cluster have different needs:

- **Container images**: `Developer` uses images built into Minikube's Docker daemon. `eks-deployment` pulls from Amazon ECR, with tags written by Jenkins.
- **Persistent storage**: `Developer` uses a `hostPath` volume (single node only). `eks-deployment` uses the `ebs-sc` StorageClass (gp3, `WaitForFirstConsumer`, reclaim policy `Retain`) so data survives pod rescheduling across nodes.
- **Traffic**: `Developer` uses Minikube's service access. `eks-deployment` uses a Gateway and HTTPRoutes behind an AWS load balancer.
- **Database credentials**: read from a Kubernetes `Secret` in both, never from a `ConfigMap`.

### Accessing the ArgoCD UI

The ArgoCD UI is **not** exposed to the internet. Reach it through a tunnel from your own machine:

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open `https://localhost:8080` (accept the self-signed certificate warning) and sign in as `admin`. Retrieve the initial password once, then change it and delete the initial secret:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

## Infrastructure as Code with Terraform

The AWS infrastructure behind the `eks-deployment` environment is fully defined in [Terraform](https://www.terraform.io/), in [`terraform/`](https://github.com/Abdirahman-Maalim/faraja/tree/eks-deployment/terraform).

### Design

One module per logical resource group instead of one large configuration:

| Module | What it creates |
|---|---|
| `vpc` | VPC, subnets and routing |
| `iam` | IAM roles for the EKS control plane and worker nodes |
| `eks-cluster` | EKS control plane, endpoint access rules, control-plane logging |
| `eks-nodegroup` | Managed node group (4 x t3.small) |
| `irsa-ebs-csi` | IAM role for the EBS CSI driver, bound to a single service account (IRSA) |
| `ecr` | The `faraja-backend` and `faraja-frontend` image repositories |
| `jenkins-ci` | IAM user `jenkins-ci`, allowed to push to those two ECR repositories only |

### Remote state

State is stored in a versioned, encrypted S3 bucket with state locking through DynamoDB, created once by `terraform/bootstrap/`. No state file is committed to this repository.

### Security

- The EKS API public endpoint is limited to an explicit allow-list of CIDR blocks (`cluster_endpoint_public_access_cidrs`, set in the git-ignored `terraform.tfvars`) rather than `0.0.0.0/0`.
- Private endpoint access is enabled as well, so worker nodes reach the control plane over the VPC.
- Kubernetes Secrets are encrypted at rest by EKS's default envelope encryption. No customer-managed KMS key is configured.
- Control-plane logs (audit, API, authenticator) are shipped to CloudWatch (`enabled_cluster_log_types`).
- The Jenkins IAM user follows least privilege: ECR push on the two Faraja repositories, nothing else.
- No credentials are hard-coded; the AWS provider uses the standard credential chain.
- Every resource is tagged (`Project`, `Environment`, `ManagedBy`) through provider-level `default_tags`.

### Provisioning

```bash
cd terraform/bootstrap
terraform init
terraform apply        # creates the state bucket and lock table (once)

cd ..
terraform init
terraform plan
terraform apply
```

If the ECR repositories already exist, create the VPC first, then import them instead of recreating them:

```bash
terraform apply -target=module.vpc
terraform import module.ecr.aws_ecr_repository.backend faraja-backend
terraform import module.ecr.aws_ecr_repository.frontend faraja-frontend
terraform apply
```

### Connecting to the cluster

```bash
aws eks update-kubeconfig --region us-east-1 --name faraja-cluster
kubectl get nodes
```

If `kubectl` times out, your public IP is probably not in the allow-list. Add it to `cluster_endpoint_public_access_cidrs` in `terraform.tfvars` and run `terraform apply -target=module.eks_cluster`.

### Teardown

Order matters, otherwise `terraform destroy` hangs on resources Kubernetes created outside Terraform:

1. Turn off ArgoCD auto-sync, then delete the Gateway so the AWS load balancer is removed before the VPC:
   ```bash
   kubectl patch app faraja -n argocd --type merge -p '{"spec":{"syncPolicy":null}}'
   kubectl delete gateway faraja-gateway -n faraja-ns
   ```
   If the delete hangs on a finalizer, scale the NGF controller to zero (`kubectl scale deploy --all -n nginx-gateway --replicas=0`) and it completes.
2. To keep the container images, drop the ECR repositories from state first:
   `terraform state rm module.ecr.aws_ecr_repository.backend module.ecr.aws_ecr_repository.frontend`
3. Run `terraform destroy`.
4. The `ebs-sc` StorageClass uses reclaim policy `Retain`, so the database EBS volume survives. Delete it in the EC2 console (Volumes) if you do not need the data, otherwise it keeps costing money.

## Traffic Routing with Gateway API

Public traffic enters through the Kubernetes [Gateway API](https://gateway-api.sigs.k8s.io/), implemented by [NGINX Gateway Fabric](https://github.com/nginx/nginx-gateway-fabric) (NGF). The Gateway creates an AWS load balancer, and HTTPRoutes decide where each path goes.

| Path | Destination | Notes |
|---|---|---|
| `/api/*` | `faraja-backend-svc:8000` | The `/api` prefix is stripped before the request reaches the backend (`ReplacePrefixMatch`) |
| `/grafana/*` | `monitoring-grafana:80` | Route in `monitoring/grafana-httproute.yaml` |
| everything else | `frontend:3001` | Next.js frontend |

Manifests: [`k8s/gateway.yaml`](https://github.com/Abdirahman-Maalim/faraja/blob/eks-deployment/k8s/gateway.yaml) (the Gateway, class `nginx`, port 80) and [`k8s/httproute.yaml`](https://github.com/Abdirahman-Maalim/faraja/blob/eks-deployment/k8s/httproute.yaml). The Gateway only accepts routes from the `faraja-ns`, `monitoring` and `argocd` namespaces.

The browser calls the API on the same host at `/api`, so no CORS setup is needed. Server-side rendering calls the backend directly through the in-cluster address in `API_INTERNAL_URL`.

### One-time install per cluster

```bash
# 1. Gateway API CRDs (adds the Gateway and HTTPRoute resource types)
kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.7.2" \
  | kubectl apply --server-side -f -

# 2. The NGF controller
helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric \
  --version 2.7.2 --create-namespace -n nginx-gateway
```

What this does:

- **CRDs** are new resource *types*. A fresh cluster does not know what a `Gateway` or `HTTPRoute` is until they are registered. CRDs are cluster-wide and persist, so this is needed once per cluster (or when upgrading the version), not once per deploy.
- **`--server-side`** is used because the CRDs are large; a normal `kubectl apply` stores a copy of the whole object in an annotation and fails on the size limit.
- **The Helm install** runs the NGF controller. When it sees `k8s/gateway.yaml` it creates the NGINX data plane and a `LoadBalancer` Service, which AWS turns into the public load balancer.

Verify:

```bash
kubectl get gateway,httproute -A
kubectl get pods -n nginx-gateway
```

*Gateway API work contributed by [@teqeva](https://github.com/teqeva).*

## CI/CD Pipeline (Jenkins and ArgoCD)

The pipeline is split in two. **Jenkins does continuous integration**: it builds and publishes the images, then records the new version in Git. **ArgoCD does continuous delivery**: it rolls that version out to the cluster (see [GitOps Deployment with ArgoCD](#gitops-deployment-with-argocd)).

```text
git push -> Jenkins polls Git (every 2 min)
         -> builds backend and frontend images
         -> pushes them to ECR, tagged with the commit SHA
         -> commits the new tags to k8s/*-deployment.yaml on eks-deployment
         -> ArgoCD sees the commit and rolls out the new pods
```

Pipeline stages ([`Jenkinsfile`](https://github.com/Abdirahman-Maalim/faraja/blob/eks-deployment/Jenkinsfile)):

1. **Prepare**: compute the short commit SHA. If the last commit was made by `jenkins-ci`, skip the run (loop guard, otherwise Jenkins would trigger itself).
2. **Registry login**: install QEMU/binfmt (images are built for `amd64`) and log in to ECR.
3. **Backend image** and 4. **Frontend image**: build and push `<repo>:<sha>`. The frontend is built with `NEXT_PUBLIC_API_BASE_URL=/api`. Both pushes are wrapped in `retry(3)`.
5. **Deploy via GitOps**: write the new tags into `k8s/backend-deployment.yaml` and `k8s/frontend-deployment.yaml`, commit as `jenkins-ci`, and push to `eks-deployment`.

Setup details:

- Jenkins LTS runs on a VM (port 8090) and polls with `pollSCM('H/2 * * * *')`.
- AWS access is an IAM user (`jenkins-ci`, from the `jenkins-ci` Terraform module) that can only push to the two ECR repositories.
- Git access is a GitHub fine-grained personal access token with read/write access to this repository's contents, stored as a Jenkins credential (`github-token`).
- Expect **about 10 to 12 minutes** from `git push` to the change being live: image builds, ECR push, then ArgoCD sync and rolling update.
- **Because Jenkins pushes to `eks-deployment`, always run `git pull` before you push to it.** Otherwise Git rejects your push as non-fast-forward.

Roll back by reverting the tag commit: `git revert <commit>` and push. Same path, same audit trail.

## Monitoring in Production (Prometheus + Grafana)

Monitoring runs in the `monitoring` namespace using the [`kube-prometheus-stack`](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack) Helm chart (pinned to version `92.9.0`). Settings are in [`monitoring/helm/kube-prometheus-stack-values.yaml`](https://github.com/Abdirahman-Maalim/faraja/blob/eks-deployment/monitoring/helm/kube-prometheus-stack-values.yaml).

| Piece | How it is set up |
|---|---|
| **Grafana** | Served at `/grafana` through the Gateway. Sign-up and anonymous access are disabled. The admin password comes from the Secret `grafana-admin`, never from Git. Memory limit 512Mi. |
| **Prometheus** | Internal only (ClusterIP). Retention 2 days. Reach it with a port-forward. |
| **ServiceMonitor** | [`monitoring/servicemonitor.yaml`](https://github.com/Abdirahman-Maalim/faraja/blob/eks-deployment/monitoring/servicemonitor.yaml) (label `release: monitoring`) scrapes the backend's `/metrics`. |
| **Alert rule** | [`monitoring/alert-rules.yaml`](https://github.com/Abdirahman-Maalim/faraja/blob/eks-deployment/monitoring/alert-rules.yaml): `FarajaHighErrorRate` fires when more than 1% of requests fail for 5 minutes. |

Install:

```bash
kubectl create namespace monitoring
kubectl create secret generic grafana-admin -n monitoring \
  --from-literal=admin-user=admin \
  --from-literal=admin-password='<choose-a-strong-password>'

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install monitoring prometheus-community/kube-prometheus-stack \
  --version 92.9.0 -n monitoring -f monitoring/helm/kube-prometheus-stack-values.yaml

kubectl apply -f monitoring/
```

Notes:

- `root_url` in the values file contains the load balancer hostname. If the Gateway is ever recreated, the hostname changes: update `root_url` and run `helm upgrade`.
- Do not interrupt `helm install` with Ctrl+C; it leaves a half-created release that blocks the name.
- Reach Prometheus privately: `kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090`, then open `http://localhost:9090/targets`. The backend target should be **UP**.
- Team access: create one Grafana user per person under *Administration, Users* (role Viewer, or Editor to run queries) instead of sharing the admin password. Because the site is HTTP only for now, use passwords that are not reused anywhere else.

*ServiceMonitor and alert rules contributed by [@teqeva](https://github.com/teqeva).*

## Bootstrapping a New Cluster

Everything below happens once on a fresh cluster. After that, all application changes flow through Git.

1. **Infrastructure**: `terraform apply` (see [Provisioning](#provisioning)), then `aws eks update-kubeconfig --region us-east-1 --name faraja-cluster`.
2. **ArgoCD**: install it in the `argocd` namespace using the upstream manifests.
   ```bash
   kubectl create namespace argocd
   kubectl apply -n argocd --server-side --force-conflicts \
     -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   ```
3. **Gateway API and NGF**: see [One-time install per cluster](#one-time-install-per-cluster).
4. **Application secret** (not stored in Git): copy `k8s/postgres-secret.yaml.example`, fill in real values, apply it, and protect it from pruning.
   ```bash
   kubectl create namespace faraja-ns --dry-run=client -o yaml | kubectl apply -f -
   kubectl apply -f postgres-secret.yaml          # your filled-in copy, never committed
   kubectl annotate secret faraja-db-secret -n faraja-ns argocd.argoproj.io/sync-options=Prune=false
   ```
5. **Images and app**: make sure the images exist in ECR (on a new or emptied registry, run the Jenkins job once so the tags in `k8s/*-deployment.yaml` can be pulled). Then `kubectl apply -f argocd/faraja-app.yaml`, and ArgoCD creates everything under `k8s/`.
6. **Monitoring**: follow the install steps in [Monitoring in Production](#monitoring-in-production-prometheus--grafana).
7. **Jenkins**: point the pipeline job at this repository and `eks-deployment`, and add the AWS access key for `jenkins-ci` and the `github-token` credential.
8. **Check**: `kubectl get pods -A`, then open `http://<address>/` (address from [Production Overview](#production-overview-aws-eks)).

## Operations and Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `kubectl`: `You must be logged in to the server (Unauthorized)` | Clock on your machine or VM has drifted, so the AWS token is rejected | Sync the clock: `sudo chronyc makestep` |
| `kubectl`: `i/o timeout` | Your public IP is not in the API allow-list | Add it to `cluster_endpoint_public_access_cidrs`, `terraform apply -target=module.eks_cluster` |
| Site returns 503 for a moment during a deploy | Rolling update in progress | Wait about 20 seconds and refresh |
| Site root does not load but `/grafana` does | Gateway and load balancer are fine; the problem is behind the `/` route | `kubectl get pods -n faraja-ns`, `kubectl get httproute -A`, `kubectl get endpoints frontend -n faraja-ns`, and check the ArgoCD app is Synced |
| Grafana 503 or restarting | Container killed for memory (OOMKilled) or slow probes | Memory limit is 512Mi with relaxed probes in the Helm values |
| Backend in `CrashLoopBackOff` after a rebuild | `faraja-db-secret` is missing | Recreate it (step 4 of bootstrapping) |
| ArgoCD stuck on `Progressing` or a hung operation | A previous sync is blocking | In the UI, Refresh then Hard Refresh; terminate the running operation |
| Jenkins: ECR push fails with `network is unreachable` | IPv6 route failing on the Jenkins host | Disable IPv6 on the host and restart Docker; the pipeline already retries 3 times |
| Jenkins: `exec format error` while building | QEMU emulation not registered after a reboot | `docker run --privileged --rm tonistiigi/binfmt --install all` |

## Roadmap

- HTTPS and a real domain (`faraja.kubeverse.io`) using cert-manager and Let's Encrypt, once the DNS record is available.
- Image vulnerability scanning (Trivy) as a Jenkins stage.
- Move Terraform state locking from DynamoDB to S3 native locking (`use_lockfile = true`).
- Serve Grafana over HTTPS, and tighten the EKS API allow-list to a single IP once the setup is final.

---

## Local Development

The parts below run the application on your own machine: directly, with Docker, and on Minikube. They are for development; the production deployment is described above.

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

## Part 3: Local Kubernetes with Minikube

> **Local development only.** This part runs the app on Minikube with locally built images. The production deployment on EKS is described in [Production Overview](#production-overview-aws-eks), and its manifests differ (ECR images, EBS storage, Gateway API).

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

## Part 4: Local Monitoring on Minikube (Prometheus + Grafana)

> **Local development only.** This walkthrough installs a throw-away monitoring stack on Minikube (with a simple admin password). Monitoring in Production uses pinned Helm values and a Secret-based password; see [Monitoring in Production](#monitoring-in-production-prometheus--grafana).

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

* `Developer` — The default branch. Integration branch where completed features are combined and tested, and the branch used for local (Minikube) work.
* `eks-deployment` — The AWS EKS deployment: Terraform, Kubernetes manifests, Gateway, Jenkins and monitoring. This is what ArgoCD deploys. Jenkins also commits image tags here, so run `git pull` before every push.
* `feature/*` — Used for developing individual features or tasks.
* `fix/*` — Used for fixing bugs and issues.

### Branching Workflow

1. Start from the latest `Developer` branch.
2. Create a separate branch for your task.
3. Make and test your changes.
4. Commit changes with clear, meaningful messages.
5. Push the branch to GitHub.
6. Open a Pull Request into `Developer`.
7. Request a review from another team member.
8. Address review comments and push additional commits if needed.
9. Merge only after approval and successful CI checks.
10. Delete the feature/fix branch after merging.

### Example

```bash
git checkout Developer
git pull origin Developer

git checkout -b feature/frontend-dashboard

# Make changes

git add .
git commit -m "feat: add project dashboard"
git push -u origin feature/frontend-dashboard
```

After the Pull Request is approved:

```bash
git checkout Developer
git pull origin Developer
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

 
## Thank You

Thank you for contributing to Faraja!

We appreciate every contribution, whether it is a new feature, bug fix, documentation improvement, or code review.

For questions or suggestions, please open an issue or discuss them with the project team.
