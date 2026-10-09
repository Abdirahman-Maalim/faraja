# Contributing to Faraja
\This guide outlines the workflow, coding practices, and collaboration standards that all contributors should follow.

---

# Table of Contents

1. [How to Clone the Repository](#1-how-to-clone-the-repository)
2. [Development Environment Setup](#2-development-environment-setup)
3. [Branch Naming Convention](#3-branch-naming-convention)
4. [Development Workflow](#4-development-workflow)
5. [Commit Message Guidelines](#5-commit-message-guidelines)
6. [Pull Request Guidelines](#6-pull-request-guidelines)
7. [Quick Git Reference](#7-quick-git-reference)

---

# 1. How to Clone the Repository

## Prerequisites

Before cloning the repository, ensure you have:

- Git installed
- A GitHub account with access to the repository

Verify Git is installed:

```bash
git --version
```

## Clone the Repository

Using HTTPS:

```bash
git clone https://github.com/Abdirahman-Maalim/faraja.git
```

Or using SSH:

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

# 2. Development Environment Setup

## Frontend Setup

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

---

## Backend Setup

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
source .venv/bin/activate
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

---

## Database Setup

Start PostgreSQL:

```bash
sudo systemctl start postgresql
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

# 3. Branch Naming Convention

## Branch Types

| Branch Type | Format | Example |
|--------------|----------------|---------------------------|
| Main | `main` | `main` |
| Development | `develop` | `develop` |
| Feature | `feature/name` | `feature/frontend-docker` |
| Fix | `fix/name` | `fix/login-error` |
| Documentation | `docs/name` | `docs/readme-update` |
| Chore | `chore/name` | `chore/docker-config` |

## Branch Rules

- Always create branches from `develop`.
- Use lowercase letters only.
- Separate words using hyphens (`-`).
- Keep branch names short and descriptive.

Example:

```bash
git checkout develop
git pull origin develop
git checkout -b feature/your-feature-name
```

---

# 4. Development Workflow

Follow this workflow whenever working on a task.

## Step 1: Update the Development Branch

```bash
git checkout develop
git pull origin develop
```

## Step 2: Create a Feature Branch

```bash
git checkout -b feature/your-task
```

## Step 3: Make Your Changes

Edit the necessary files.

## Step 4: Stage Your Changes

```bash
git add .
```

## Step 5: Commit Your Changes

```bash
git commit -m "feat: add your feature"
```

## Step 6: Push Your Branch

```bash
git push origin feature/your-task
```

## Step 7: Open a Pull Request

Create a Pull Request on GitHub.

- Base branch: `develop`
- Compare branch: `feature/your-task`

## Step 8: After Merge

```bash
git checkout develop
git pull origin develop
git branch -D feature/your-task
```

---

# 5. Commit Message Guidelines
## Commit Types

| Type | Description |
|------|-------------|
| `feat:` | New feature |
| `fix:` | Bug fix |
| `docs:` | Documentation changes |
| `chore:` | Maintenance tasks |
| `refactor:` | Code refactoring |
| `test:` | Tests |

## Examples

```bash
feat: add Dockerfile for frontend

fix: correct port mapping in docker-run.sh

docs: update README with setup instructions

chore: add .dockerignore for Node.js

refactor: simplify authentication middleware

test: add API endpoint tests
```

---

# 6. Pull Request Guidelines

Before opening a Pull Request, ensure your branch is up to date.

```bash
git checkout develop
git pull origin develop

git checkout feature/your-branch

git merge develop

git push origin feature/your-branch
```

## Pull Request Requirements

- Use a clear title following the commit message format.
- Include a summary of the changes.
- Describe what was added, changed, or fixed.
- Assign at least one reviewer.
- Resolve merge conflicts before requesting review.
- Wait for approval before merging.
- Delete your branch after merging.

## Pull Request Template

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

# 7. Quick Git Reference

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

---

