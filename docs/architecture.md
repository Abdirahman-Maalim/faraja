# System Architecture

## Overview

Faraja is a three-tier web application composed of a **frontend**, **backend**, and **database**. The application follows a layered architecture that separates user interaction, business logic, and data persistence into independent components. Each tier is containerized using Docker, allowing the application to run consistently across different environments while simplifying deployment and dependency management.

The three tiers communicate through dedicated Docker bridge networks, ensuring that each component only has access to the services it requires. Docker Compose is used to orchestrate the containers, automatically creating the required networks and volumes while managing service startup.

---

# Architecture Diagram

![](https://github.com/Abdirahman-Maalim/faraja/blob/docs/architecture/docs/architecture.jpeg)

---

# Detailed Architecture Description

## Frontend Tier

The frontend is built using **Next.js (TypeScript)** and serves as the presentation layer of the application. It provides the user interface through which users interact with the system.

The frontend is exposed to the user's browser on **port 3001** and communicates exclusively with the backend API over the **frontend-network**. It does not communicate directly with the database, ensuring that all business logic and data access are handled by the backend.

### Responsibilities

* Present the user interface
* Handle user interactions
* Send API requests to the backend
* Display responses returned by the backend

---

## Backend Tier

The backend is developed using **FastAPI (Python)** and serves as the application's business logic layer.

It receives requests from the frontend, validates and processes them, interacts with the PostgreSQL database when necessary, and returns responses to the frontend.

The backend is connected to both Docker networks:

* **frontend-network** for communication with the frontend
* **backend-network** for communication with the database

This makes the backend the only component capable of accessing the database.

### Responsibilities

* Process business logic
* Expose REST API endpoints
* Validate incoming requests
* Communicate with the PostgreSQL database
* Return responses to the frontend

---

## Database Tier

The data layer uses **PostgreSQL** to provide persistent storage for application data.

The database container is connected only to the **backend-network**, preventing direct access from the frontend. This improves security by ensuring that all database interactions pass through the backend API.

To preserve application data across container restarts or recreation, the PostgreSQL container is attached to a Docker volume on the host machine.

### Responsibilities

* Store application data
* Process database queries
* Persist data independently of the container lifecycle

---

# Network Architecture

The application uses two Docker bridge networks to isolate communication between application components.

| Network              | Connected Containers | Purpose                                                              |
| -------------------- | -------------------- | -------------------------------------------------------------------- |
| **frontend-network** | frontend, backend    | Allows communication between the user interface and the backend API. |
| **backend-network**  | backend, database  | Allows the backend to communicate securely with the database.        |

By separating network communication in this way, the frontend cannot directly access the database. All data requests must pass through the backend, reinforcing the application's layered architecture and improving security.

---

# Port Exposure

| Service  | Internal Port |   Host Port | Purpose                         |
| -------- | ------------: | ----------: | ------------------------------- |
| Frontend |          3001 |        3001 | User access                     |
| Backend  |          8000 | Not exposed | Internal API communication      |
| Database |          5432 | Not exposed | Internal database communication |

Only the frontend is exposed to the host machine.

---

# Data Persistence

The PostgreSQL container uses a Docker volume mapped to the host machine.

Using a Docker volume ensures that application data remains available even if the database container is stopped, deleted, or recreated. This provides persistent storage independent of the container lifecycle and prevents accidental data loss during development.

---

# Communication Flow

The application processes requests using the following sequence:

1. A user accesses the frontend through a web browser on **port 3001**.
2. The frontend sends API requests to the backend over the **frontend-network**.
3. The backend receives and processes the request.
4. If data retrieval or storage is required, the backend communicates with the database over the **backend-network**.
5. The database returns the requested information to the backend.
6. The backend sends the response back to the frontend.
7. The frontend displays the resulting information to the user.

---

# Tools and Technologies

## Docker

Docker is used to package each application tier into isolated containers, ensuring that the application behaves consistently regardless of the host operating system.

**Reason for selection**

* Consistent execution environments
* Simplified dependency management
* Improved portability
* Standard container platform used throughout the industry

---

## Docker Compose

Docker Compose orchestrates the application's multi-container environment during development.

It automates the creation of Docker networks and volumes, builds the required images, and starts all application services using a single configuration file.

**Reason for selection**

* Simplifies multi-container deployments
* Automatically configures networking
* Manages persistent storage
* Reduces manual setup effort
* Improves development consistency

---

## Next.js

Next.js is used to build the frontend user interface.

**Reason for selection**

* Modern React framework
* Efficient rendering
* Good developer experience
* Strong TypeScript support

---

## FastAPI

FastAPI provides the application's REST API and business logic.

**Reason for selection**

* High-performance Python framework
* Lightweight and easy to develop
* Automatic API documentation
* Excellent support for RESTful services

---

## PostgreSQL

PostgreSQL provides the application's relational database.

**Reason for selection**

* Reliable and mature relational database
* Excellent SQL support
* Strong data integrity features
* Widely used in production environments

---

## Git

Git is used for version control throughout the project.

**Reason for selection**

* Tracks source code changes
* Supports collaborative development
* Enables branching and rollback

---

## GitHub

GitHub hosts the project repository and facilitates collaboration.

**Reason for selection**

* Centralized source code management
* Pull request workflow
* Code reviews
* Collaboration among team members

---

## Trello

Trello is used to manage project tasks and monitor team progress.

**Reason for selection**

* Simple task management
* Sprint planning
* Work tracking
* Team collaboration

---

# Design Decisions

Several architectural decisions were made during the containerization of the application:

* Separation of concerns through a three-tier architecture.
* Independent Docker containers for each application tier.
* Dedicated Docker networks to isolate frontend and database communication.
* Persistent storage using Docker volumes.
* Multi-container orchestration using Docker Compose.
* Modular architecture that can be migrated to Kubernetes in later phases of the project.

These decisions improve maintainability, portability, scalability, and security while preparing the application for future cloud-native deployment.

---

# Future Enhancements

The current implementation represents the containerization phase of the cloud-native transformation.

Future phases of the capstone project will extend this architecture by introducing:

* Kubernetes for container orchestration
* Prometheus for metrics collection
* Grafana for visualization and monitoring
* GitOps workflows using Argo CD

These enhancements will evolve the application into a production-ready cloud-native platform capable of secure, scalable, observable, and resilient deployments.
