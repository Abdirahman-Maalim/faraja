# Faraja Architecture

## 1. Overview

Faraja is a cloud-native public infrastructure tracking application designed to make infrastructure projects easier to monitor and understand.

The system uses **Terraform and AWS for infrastructure**, **Docker for containerization**, **Kubernetes for application orchestration**, **ArgoCD for GitOps deployment**, **PostgreSQL for data storage**, and **Prometheus and Grafana for monitoring**.

The architecture separates infrastructure management, application deployment, data storage, and observability.

---
## 2. High-Level Architecture

```text
                         Developer
                             |
              +--------------+--------------+
              |                             |
              v                             v
          Terraform                       Git
              |                             |
              v                             v
             AWS                         ArgoCD
              |                             |
              +-------------+---------------+
                            |
                            v
                       Kubernetes
                            |
              +-------------+-------------+
              |                           |
              v                           v
          FastAPI                    PostgreSQL
              |                           |
              |                       PV / PVC
              |
           /metrics
              |
              v
          Prometheus
              |
              v
           Grafana
```

---

## 3. Architecture Layers

The Faraja architecture is divided into the following layers:

1. **Infrastructure Layer** - AWS and Terraform
2. **Container Layer** - Docker and Docker Hub
3. **Orchestration Layer** - Kubernetes
4. **GitOps Layer** - ArgoCD
5. **Application Layer** - FastAPI and optional Next.js frontend
6. **Data Layer** - PostgreSQL and persistent storage
7. **Monitoring Layer** - Prometheus and Grafana

---

## 4. Infrastructure Layer

### Terraform

Terraform is used to define and provision cloud infrastructure as code.

Instead of manually creating AWS resources through the AWS Console, infrastructure can be described in Terraform configuration files and applied consistently.

```text
Terraform Configuration
        |
        v
terraform plan
        |
        v
terraform apply
        |
        v
AWS Infrastructure
```

Terraform can manage components such as:

* VPC and networking
* Subnets
* Security groups
* IAM resources
* Kubernetes-related cloud infrastructure
* Other AWS resources required by the deployment

The exact AWS resources depend on the Terraform configuration used by the project.

### AWS

AWS provides the cloud infrastructure on which the production environment can run.

The expected infrastructure structure is:

```text
AWS
 |
 +-- VPC
 |    |
 |    +-- Subnets
 |    +-- Route Tables
 |    +-- Internet/NAT connectivity
 |
 +-- Security Groups
 |
 +-- IAM
 |
 +-- Kubernetes Infrastructure
```

Terraform provides the reproducible definition of this infrastructure.

---

## 5. Container Layer

Faraja uses Docker to package the application and its dependencies into portable containers.

The main application components are:

* FastAPI backend
* PostgreSQL database
* Next.js frontend

The general image workflow is:

```text
Source Code
    |
    v
Docker Build
    |
    v
Container Image
    |
    v
Docker Hub
    |
    v
Kubernetes
```

Using containers ensures that the application runs with a consistent environment across development, testing, and deployment.

---

## 6. Kubernetes Layer

Kubernetes manages the application containers and provides service discovery, scaling, networking, and recovery.

Faraja uses the namespace:

```text
faraja-ns
```

The main Kubernetes resources include:

* Namespace
* Backend Deployment
* Backend Service
* Frontend Deployment
* Frontend Service
* PostgreSQL StatefulSet
* PersistentVolume
* PersistentVolumeClaim
* ConfigMaps and environment configuration

A simplified structure is:

```text
faraja-ns
 |
 +-- Frontend Deployment
 |       |
 |       v
 |    Frontend Service
 |
 +-- Backend Deployment
 |       |
 |       v
 |    Backend Service
 |
 +-- PostgreSQL StatefulSet
         |
         v
      Persistent Storage
```

### Backend

The FastAPI backend provides the application's API.

Important endpoints include:

```text
/projects
/milestones
/metrics
```

The backend communicates with PostgreSQL through the Kubernetes service rather than relying on hard-coded pod IP addresses.

### Frontend

The Next.js frontend provides the user-facing interface.

The frontend communicates with the backend through the Kubernetes service.

For server-side communication, an internal API address can be used, while browser requests use the public/client-side API configuration.

---

## 7. PostgreSQL and Persistent Storage

PostgreSQL is used as the primary database.

It runs as a Kubernetes **StatefulSet** because databases require stable identity and persistent storage.

The database pod follows a naming pattern such as:

```text
faraja-db-sts-0
```

Persistent storage is provided using:

```text
PostgreSQL
    |
    v
PersistentVolumeClaim
    |
    v
PersistentVolume
```

This prevents database data from depending entirely on the lifetime of an individual container.

Database backups are also supported through the project's backup scripts.

---

## 8. GitOps and ArgoCD

ArgoCD manages Kubernetes deployments using the GitOps approach.

The desired Kubernetes configuration is stored in Git, particularly under:

```text
k8s/
```

The deployment flow is:

```text
Developer
    |
    v
Git Repository
    |
    v
ArgoCD
    |
    v
Kubernetes
    |
    v
Faraja Application
```

ArgoCD watches the configured Git branch and synchronizes the Kubernetes manifests into:

```text
faraja-ns
```

### Self-Healing

ArgoCD can detect when the running Kubernetes state differs from the configuration stored in Git.

For example:

```text
Git: backend replicas = 2
          |
          v
     Kubernetes
          |
Manual change: replicas = 5
          |
          v
       ArgoCD
          |
          v
Restores desired state
          |
          v
Backend replicas = 2
```

This demonstrates GitOps reconciliation and Kubernetes self-healing.

---

## 9. Monitoring and Observability

Faraja uses **Prometheus and Grafana** for application monitoring.

The FastAPI backend exposes metrics through:

```text
/metrics
```

Prometheus periodically scrapes this endpoint.

```text
FastAPI
   |
   | /metrics
   v
Prometheus
   |
   v
Grafana
```

Prometheus can be used to monitor information such as:

* Request rates
* Application errors
* Response performance
* Service health
* Custom application metrics

Grafana uses the Prometheus data source to create dashboards and visualize system behavior.

---

## 10. Error Monitoring and Recovery

The architecture also supports failure testing.

For example, the PostgreSQL StatefulSet can be temporarily scaled down to simulate database unavailability.

```text
PostgreSQL
    |
    X
Database unavailable
    |
    v
Backend requests fail
    |
    v
Prometheus records metrics
    |
    v
Grafana displays the problem
```

After PostgreSQL is restored, the application can recover and ArgoCD continues maintaining the desired Kubernetes configuration.

This demonstrates how the system can be observed during failures rather than only during normal operation.

---

## 11. Database Backup

Database backups are handled separately from Kubernetes deployment.

The project includes backup functionality through the project scripts.

Conceptually:

```text
PostgreSQL
    |
    v
Backup Script
    |
    v
Backup File
```

This provides an additional recovery mechanism for application data.

---

## 12. Security Architecture

Security is considered across multiple layers.

### Infrastructure

AWS security groups and IAM control access to cloud resources.

### Kubernetes

Kubernetes namespaces and service configuration separate application resources.

### Application

The FastAPI application provides controlled API endpoints and database access.

### Secrets

Sensitive values such as database credentials should be supplied through Kubernetes Secrets or an appropriate secrets-management solution rather than being hard-coded into application source code.

### Network

Services communicate through controlled Kubernetes service discovery instead of exposing every component directly to the internet.

---

## 13. Local and Cloud Deployment

The same general architecture can be used in local development and cloud environments.

### Local Development

Minikube can be used to run Kubernetes locally:

```text
Developer Machine
       |
       v
Minikube
       |
       +-- FastAPI
       +-- PostgreSQL
       +-- Frontend
       +-- Monitoring
       +-- ArgoCD
```

### Cloud Deployment

AWS provides the infrastructure for a cloud deployment:

```text
AWS
 |
 v
Kubernetes
 |
 +-- FastAPI
 +-- PostgreSQL
 +-- Frontend
 +-- Monitoring
 +-- ArgoCD
```

Terraform makes the cloud infrastructure reproducible, while Kubernetes and ArgoCD manage the application layer.

---

## 14. Access and Port Forwarding

During local development, services can be accessed using Kubernetes port forwarding.

Common ports include:

| Service    | Local Port |
| ---------- | ---------: |
| FastAPI    |       8001 |
| ArgoCD     |       8080 |
| Grafana    |       3000 |
| Prometheus |       9090 |

Example:

```bash
kubectl port-forward svc/backend 8001:8000 -n faraja-ns
```

Other services can be exposed in a similar way depending on their Kubernetes service names.

---

## 15. Deployment Flow

The complete deployment process can be summarized as:

```text
1. Developer writes code
          |
          v
2. Docker builds application images
          |
          v
3. Images are pushed to Docker Hub
          |
          v
4. Kubernetes manifests are stored in Git
          |
          v
5. ArgoCD detects the desired configuration
          |
          v
6. ArgoCD deploys to Kubernetes
          |
          v
7. Kubernetes runs the application
          |
          v
8. PostgreSQL stores application data
          |
          v
9. FastAPI exposes application APIs
          |
          v
10. Prometheus collects metrics
          |
          v
11. Grafana visualizes system performance
```

Terraform operates alongside this process by provisioning the AWS infrastructure required by the cloud environment.

---

## 16. Terraform vs ArgoCD

Terraform and ArgoCD have different responsibilities.

| Tool       | Main Responsibility               |
| ---------- | --------------------------------- |
| Terraform  | Infrastructure provisioning       |
| ArgoCD     | Kubernetes application deployment |
| Kubernetes | Running and managing workloads    |
| Docker     | Packaging applications            |
| Prometheus | Collecting metrics                |
| Grafana    | Visualizing metrics               |

The key distinction is:

```text
Terraform
"What infrastructure should exist?"
             |
             v
            AWS


ArgoCD
"What application configuration should be running?"
             |
             v
        Kubernetes
```

This separation makes the architecture easier to manage and maintain.

---

## 17. Complete Architecture Summary

```text
                         GIT REPOSITORY
                              |
                 +------------+------------+
                 |                         |
                 v                         v
            Terraform                   ArgoCD
                 |                         |
                 v                         v
                AWS ----------------> Kubernetes
                                        |
                         +--------------+--------------+
                         |              |              |
                         v              v              v
                     Frontend        FastAPI       PostgreSQL
                                        |              |
                                        |              v
                                        |         PV / PVC
                                        |
                                     /metrics
                                        |
                                        v
                                   Prometheus
                                        |
                                        v
                                    Grafana
```

The architecture provides a clear separation of responsibilities:

* **Terraform** manages cloud infrastructure.
* **AWS** provides the underlying cloud environment.
* **Docker** packages the application.
* **Docker Hub** stores container images.
* **Kubernetes** runs and manages application workloads.
* **ArgoCD** continuously synchronizes Kubernetes with Git.
* **FastAPI** provides the backend API.
* **PostgreSQL** stores persistent application data.
* **Prometheus** collects system and application metrics.
* **Grafana** provides monitoring dashboards.

