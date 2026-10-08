# syntax=docker/dockerfile:1.7
# check=error=true

# sets postgres:16-alpine as the base
FROM postgres:16-alpine

# image metadata
LABEL org.opencontainers.image.title="faraja-db"
LABEL org.opencontainers.image.description="Faraja PostgreSQL database"
LABEL org.opencontainers.image.source="https://github.com/Abdirahman-Maalim/faraja"

# defaults for local development
# POSTGRES_PASSWORD is intentionally NOT set here — it must be provided at runtime
ENV POSTGRES_DB=faraja \
    POSTGRES_USER=postgres

# exposes port 5432
EXPOSE 5432

# container healthcheck
HEALTHCHECK --interval=10s --timeout=5s --start-period=20s --retries=5 \
  CMD pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" || exit 1