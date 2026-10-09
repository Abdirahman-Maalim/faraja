# Contributing to Faraja

Thank you for your interest in contributing to **Faraja**! This guide outlines the workflow, coding practices, and collaboration standards that all contributors should follow.

---

## Team Members

| Name | GitHub | Role |
|------|--------|------|
| Abdirahman Maalim | [@Abdirahman-Maalim](https://github.com/Abdirahman-Maalim) | Backend |
| Eva Muthoni | [@teqeva](https://github.com/teqeva) | Frontend |
| Karen Ngugi | [@KarenNgugi](https://github.com/KarenNgugi) | Backend |


## Table of Contents

1. [How to Clone the Repository](#1-how-to-clone-the-repository)
2. [Prerequisites](#2-prerequisites)
3. [Development Environment Setup](#3-development-environment-setup)
   - [Frontend Setup](#frontend-setup)
   - [Backend Setup](#backend-setup)
   - [Database Setup](#database-setup)
4. [Docker Setup](#4-docker-setup)
   - [Building Docker Images](#building-docker-images)
   - [Running with Docker Compose](#running-with-docker-compose)
5. [Branch Naming Convention](#5-branch-naming-convention)
6. [Development Workflow](#6-development-workflow)
7. [Commit Message Guidelines](#7-commit-message-guidelines)
8. [Pull Request Guidelines](#8-pull-request-guidelines)
9. [Dockerfile Best Practices](#9-dockerfile-best-practices)
10. [Code Review Expectations](#10-code-review-expectations)
11. [Quick Git Reference](#11-quick-git-reference)
12. [Thank You](#12-thank-you)

---

## 1. How to Clone the Repository

### Prerequisites

Before cloning the repository, ensure you have:

- Git installed (`git --version`)
- A GitHub account with access to the repository

### Clone the Repository

Using HTTPS:

```bash
git clone https://github.com/Abdirahman-Maalim/faraja.git
```

Using SSH:

```bash
git clone git@github.com:Abdirahman-Maalim/faraja.git
```

Navigate into the project directory:

```bash
cd faraja
```

Fetch all available branches:

```bash
git fetch --all
```

---

## 2. Prerequisites

### Required Tools

| Tool | Version | Purpose |
|------|---------|---------|
| Git | 2.0+ | Version control |
| Docker | 20.0+ | Containerization |
| Docker Compose | 2.0+ | Multi-container orchestration |
| Node.js | 18.0+ | Frontend development |
| Python | 3.12+ | Backend development |
| PostgreSQL | 14.0+ | Local database (optional) |

### Verify Installations

```bash
git --version
docker --version
docker-compose --version
node --version
python3 --version
```

---

## 3. Development Environment Setup

### Frontend Setup

Navigate to the frontend directory:

```bash
cd frontend
```

Install project dependencies:

```bash
npm install
```

Create your environment file:

```bash
cp .env.local.example .env.local
```

Start the development server:

```bash
npm run dev -- -p 3001
```

The frontend will be available at: **http://localhost:3001**

### Backend Setup

Navigate to the backend directory:

```bash
cd backend
```

Create a virtual environment:

```bash
python3 -m venv .venv
```

Activate the environment:

```bash
source .venv/bin/activate  # On Linux/macOS
# .venv\Scripts\activate   # On Windows
```

Install Python dependencies:

```bash
pip install -r requirements.txt
```

Create the environment file:

```bash
cp .env.example .env
```

Run the backend server:

```bash
uvicorn app.main:app --reload --port 8000
```

The backend API will be available at: **http://localhost:8000**

### Database Setup

Start PostgreSQL:

```bash
sudo systemctl start postgresql  # Linux
# brew services start postgresql # macOS
```

Configure the default PostgreSQL user:

```bash
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'postgres';"
```

Create the project database:

```bash
sudo -u postgres psql -c "CREATE DATABASE faraja OWNER postgres;"
```

---

## 4. Docker Setup

### Base Images Used

| Service | Base Image | Port | Purpose |
|---------|------------|:----:|---------|
| **Frontend** | `node:18-alpine` (multi-stage) | 3001 | Next.js application |
| **Backend** | `python:3.12.13-slim` | 8000 | FastAPI application |
| **Database** | `postgres:16-alpine` | 5432 | PostgreSQL database |

### Building Docker Images

#### Frontend

```bash
cd frontend
docker build -t faraja-frontend:latest .
```

#### Backend

```bash
cd backend
docker build -t faraja-backend:latest .
```

#### Database

```bash
cd database
docker build -t faraja-db:latest .
```

### Running with Docker Compose

Create a `docker-compose.yml` file in the project root:

```yaml
version: '3.8'

services:
  db:
    image: postgres:16-alpine
    container_name: faraja-db
    environment:
      POSTGRES_DB: faraja
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres
    volumes:
      - faraja-db-data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    networks:
      - faraja-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  backend:
    build: ./backend
    container_name: faraja-backend
    environment:
      DATABASE_URL: postgresql://postgres:postgres@db:5432/faraja
    ports:
      - "8000:8000"
    depends_on:
      db:
        condition: service_healthy
    networks:
      - faraja-network

  frontend:
    build: ./frontend
    container_name: faraja-frontend
    environment:
      NEXT_PUBLIC_API_URL: http://backend:8000
    ports:
      - "3001:3001"
    depends_on:
      - backend
    networks:
      - faraja-network

networks:
  faraja-network:
    driver: bridge

volumes:
  faraja-db-data:
```

Run all services:

```bash
docker-compose up -d
```

Check status:

```bash
docker-compose ps
```

View logs:

```bash
docker-compose logs -f
```

Stop all services:

```bash
docker-compose down -v
```

---

## 5. Branch Naming Convention

### Branch Types

| Branch Type | Format | Example |
|-------------|--------|---------|
| Main | `main` | `main` |
| Development | `develop` | `develop` |
| Feature | `feature/name` | `feature/frontend-docker` |
| Fix | `fix/name` | `fix/login-error` |
| Documentation | `docs/name` | `docs/readme-update` |
| Chore | `chore/name` | `chore/docker-config` |

### Branch Rules

- Always create branches from `develop`
- Use lowercase letters only
- Separate words using hyphens (`-`)
- Keep branch names short and descriptive

Example:

```bash
git checkout develop
git pull origin develop
git checkout -b feature/your-feature-name
```

---

## 6. Development Workflow

Follow this workflow whenever working on a task.

### Step 1: Update the Development Branch

```bash
git checkout develop
git pull origin develop
```

### Step 2: Create a Feature Branch

```bash
git checkout -b feature/your-task
```

### Step 3: Make Your Changes

Edit the necessary files.

### Step 4: Stage Your Changes

```bash
git add .
```

### Step 5: Commit Your Changes

```bash
git commit -m "feat: add your feature"
```

### Step 6: Push Your Branch

```bash
git push origin feature/your-task
```

### Step 7: Open a Pull Request

Create a Pull Request on GitHub.

- Base branch: `develop`
- Compare branch: `feature/your-task`

### Step 8: After Merge

```bash
git checkout develop
git pull origin develop
git branch -D feature/your-task
```

---

## 7. Commit Message Guidelines

### Commit Types

| Type | Description |
|------|-------------|
| `feat:` | New feature |
| `fix:` | Bug fix |
| `docs:` | Documentation changes |
| `chore:` | Maintenance tasks |
| `refactor:` | Code refactoring |
| `test:` | Tests |
| `style:` | Code style (formatting) |

### Examples

```bash
feat: add Dockerfile for frontend tier
fix: correct port mapping in docker-run.sh
docs: update README with setup instructions
chore: add .dockerignore for Node.js
refactor: simplify authentication middleware
test: add API endpoint tests
```

---

## 8. Pull Request Guidelines

Before opening a Pull Request, ensure your branch is up to date:

```bash
git checkout develop
git pull origin develop
git checkout feature/your-branch
git merge develop
git push origin feature/your-branch
```

### Pull Request Requirements

- Use a clear title following the commit message format
- Include a summary of the changes
- Describe what was added, changed, or fixed
- Assign at least one reviewer
- Resolve merge conflicts before requesting review
- Wait for approval before merging
- Delete your branch after merging

### Pull Request Template

```markdown
## Summary

Brief description of the changes.

## Changes Made

- Added ...
- Updated ...
- Fixed ...

## Testing

- [ ] Tested locally
- [ ] All tests pass

## Checklist

- [ ] Code follows project standards
- [ ] Documentation updated
- [ ] No merge conflicts
```

---

## 9. Dockerfile Best Practices

All Dockerfiles in this project must follow these best practices:

### Checklist

- [ ] **Minimal base image** – Alpine or slim variant
- [ ] **Multi-stage build** – For frontend and backend where applicable
- [ ] **Dependencies first** – Install dependencies before copying source (layer caching)
- [ ] **Combine RUN commands** – To reduce image layers
- [ ] **Clean package manager cache** – In the same RUN step
- [ ] **.dockerignore file** – Exclude unnecessary files
- [ ] **Non-root user** – Run containers as a non-root user
- [ ] **Specific image tags** – Avoid `latest`; use specific versions
- [ ] **LABEL instructions** – Include maintainer information
- [ ] **HEALTHCHECK** – For production containers

### Frontend Dockerfile Example

```dockerfile
FROM node:18-alpine3.21 AS builder

WORKDIR /app

COPY package*.json ./
RUN npm ci --no-cache

COPY . .
RUN npm run build

FROM node:18-alpine3.21 AS runner

WORKDIR /app

RUN apk add --no-cache curl

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN addgroup --system --gid 1001 nodejs && \
    adduser --system --uid 1001 -G nodejs nextjs

COPY --from=builder --chown=nextjs:nodejs /app/.next ./.next
COPY --from=builder --chown=nextjs:nodejs /app/package*.json ./

RUN npm ci --omit=dev --no-cache

USER nextjs

EXPOSE 3001

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:3001 || exit 1

CMD ["npm", "start"]
```

---

## 10. Code Review Expectations

### Reviewer Responsibilities

- Review within **24 hours**
- Check code quality, logic, and readability
- Verify tests pass and functionality works
- Provide **constructive, actionable feedback**
- Approve or request changes with clear reasoning

### Developer Responsibilities

- Open PR with a clear description
- Keep PRs **small and focused**
- Address review feedback promptly
- Re-request review after addressing comments
- Merge only after receiving approval

### Approval Requirements

- **At least one approval** required
- All CI checks must pass
- No unresolved comments

---

## 11. Quick Git Reference

| Action | Command |
|--------|---------|
| Clone repository | `git clone <repository-url>` |
| Fetch branches | `git fetch --all` |
| Create feature branch | `git checkout -b feature/name` |
| Switch branches | `git checkout branch-name` |
| Check repository status | `git status` |
| Stage changes | `git add .` |
| Commit changes | `git commit -m "message"` |
| Push branch | `git push origin branch-name` |
| Pull latest changes | `git pull origin develop` |
| Delete local branch | `git branch -D branch-name` |
| Delete remote branch | `git push origin --delete branch-name` |
| Stash changes | `git stash` |
| Apply stash | `git stash pop` |

---

## 12. Thank You

Thank you for contributing to **Faraja**! 