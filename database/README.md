# Faraja Database (PostgreSQL)

This service provides a Dockerized PostgreSQL database for the Faraja project.

## Base Image
`postgres:16-alpine`

## Environment Variables
| Variable | Value |
|---|---|
| POSTGRES_DB | faraja |
| POSTGRES_USER | postgres |
| POSTGRES_PASSWORD | postgres |

These match the values in the project's `.env.example`.

## Build

    docker build -t faraja-db .

## Run

    docker run -d \
      --name faraja-db \
      -e POSTGRES_DB=faraja \
      -e POSTGRES_USER=postgres \
      -e POSTGRES_PASSWORD=postgres \
      -v faraja-db-data:/var/lib/postgresql/data \
      -p 5432:5432 \
      faraja-db

The `-v faraja-db-data:/var/lib/postgresql/data` flag persists data across container restarts.

## Schema

This container does not create any tables. Schema/tables are created by the backend service via SQLModel's `create_all()` on startup.
