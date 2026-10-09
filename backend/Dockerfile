# syntax=docker/dockerfile:1

# STAGE 1: dependencies
FROM python:3.12.13-slim-bookworm AS builder

# set working directory
WORKDIR /backend

# create a virtual environment so we can copy only the venv into the runtime stage
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# copies requirements.txt
COPY requirements.txt ./

# runs setup commands
RUN pip install --no-cache-dir --upgrade pip \
 && pip install --no-cache-dir -r requirements.txt



 # fresh python3.12-slim base 
FROM python:3.12.13-slim AS runtime

# image metadata (OCI standard labels)
LABEL org.opencontainers.image.title="faraja-backend"
LABEL org.opencontainers.image.description="Faraja FastAPI backend"
LABEL org.opencontainers.image.source="https://github.com/Abdirahman-Maalim/faraja"

# install curl (needed for the healthcheck below)
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl \
 && rm -rf /var/lib/apt/lists/*

# create a non-root user 
RUN useradd --create-home --uid 1001 appuser

# set working directory
WORKDIR /backend

# copy the venv built in stage 1 
COPY --from=builder /opt/venv /opt/venv

# put the venv on PATH and tune Python for container use
ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# copies project files, owned by appuser
COPY --chown=appuser:appuser . .

#run as appuser
USER appuser

# exposes port 8000
EXPOSE 8000

# container healthcheck hitting the FastAPI /health endpoint
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD curl -fsS http://localhost:8000/health || exit 1

# launches the app
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]