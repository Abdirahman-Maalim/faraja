# Faraja - Government Project Accountability Platform

Faraja is a fullstack application for tracking implementation of government projects and increasing public accountability.

The project currently has the following features:
- Create and list government projects
- Track budget allocated and spent
- Record project status and implementation ownership
- Milestone API endpoints for project progress tracking

## Tools & Technologies

- Frontend: Next.js (TypeScript)
- Backend: FastAPI (Python)
- Database: PostgreSQL
- Containerization: Docker
- Orchestration: Kubernetes
- Monitoring: Prometheus & Grafana

## Architecture
The project is a 3-tier application consisting of:
- The frontend (TypeScript Next.js)
- The backend (Python FastAPI)
- The database (PostgreSQL)

![](architecture.jpeg)

The project is organized in such a way that:
* The frontend and the user's browser can communicate with each other via port 3001
* The backend and the user's browser can communicate with each other via port 8000
* Both the frontend and the backend containers are in a network called `frontend-network`
* Both the database and the backend containers are in a network called `backend-network`
* The frontend and the database containers will not be able to access each other
* The database container is mapped to a volume on the host machine in order to ensure data persistence

## Project Structure*

- `frontend/`: Next.js dashboard for creating and viewing projects
- `backend/`: FastAPI API with project and milestone endpoints
- `database/`: *
- `kubernetes/`: *
- `monitoring/`: *
- `scripts/`: *
- `docs/`: *

## Project Setup
The project requires Docker to be installed in order to run the containers.

The steps to install Docker can be found in the [official Docker documentation guide](https://docs.docker.com/engine/install/).

## Running The Application
### 1. Running the native application
#### 1.1. Start PostgreSQL (Local Installation)

Install and start PostgreSQL locally (Ubuntu/Debian):

```bash
sudo apt update
sudo apt install -y postgresql postgresql-contrib
sudo systemctl enable --now postgresql
```

Create the application database and set the password for `postgres` role:

```bash
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'postgres';"
sudo -u postgres psql -c "CREATE DATABASE faraja OWNER postgres;"
```

If the database already exists, ignore the create database error.

From project root, copy base environment file:

```bash
cp .env.example .env
```

#### 1.2. Run Backend (FastAPI)

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --reload --port 8000
```

#### 1.3. Run Frontend (Next.js)

In a new terminal:

```bash
cd frontend
npm install
cp .env.local.example .env.local
npm run dev -- -p 3001
```

### 2. Running the application via Docker*

### 3. Running the application via Kubernetes*

App URLs:

- Frontend: http://localhost:3001
- Backend API: http://localhost:8000
- API docs: http://localhost:8000/docs

## Deploying to AWS*

## Suggested Next Steps

- Add authentication and role-based access control
- Add media evidence uploads and audit logs
- Add public scorecards and downloadable reports
- Add alerts for delayed projects and budget overruns


## Team Members
- [Abdirahman Maalim]((https://www.github.com/Abdirahman-Maalim))
- [Eva Muthoni](https://www.github.com/teqeva)
- [Karen Ngugi](https://www.github.com/KarenNgugi)
