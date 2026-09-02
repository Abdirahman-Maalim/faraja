import threading
import time

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from prometheus_fastapi_instrumentator import Instrumentator
from prometheus_client import Gauge
from sqlmodel import Session, select, func

from app.api.milestones import router as milestones_router
from app.api.projects import router as projects_router
from app.core.config import settings
from app.db.session import create_db_and_tables, engine
from app.models.project import Project, ProjectStatus
from app.models.milestone import Milestone

app = FastAPI(title=settings.app_name, version=settings.app_version)

allowed_origins = [
    origin.strip()
    for origin in settings.frontend_origin.split(",")
    if origin.strip()
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Prometheus: standard HTTP metrics ──
# Creates http_requests_total and http_request_duration_seconds automatically
Instrumentator().instrument(app).expose(app, endpoint="/metrics")

# ── Prometheus: business metrics ──
projects_total = Gauge(
    "faraja_projects_total",
    "Total number of projects in the database",
)
milestones_total = Gauge(
    "faraja_milestones_total",
    "Total number of milestones in the database",
)
projects_delayed_total = Gauge(
    "faraja_projects_delayed_total",
    "Total number of projects currently marked as delayed",
)


def refresh_business_metrics(interval_seconds: int = 30) -> None:
    """Runs in a background thread, refreshing gauges from the DB every 30s."""
    while True:
        try:
            with Session(engine) as session:
                projects_total.set(
                    session.exec(select(func.count()).select_from(Project)).one()
                )
                milestones_total.set(
                    session.exec(select(func.count()).select_from(Milestone)).one()
                )
                projects_delayed_total.set(
                    session.exec(
                        select(func.count())
                        .select_from(Project)
                        .where(Project.status == ProjectStatus.delayed)
                    ).one()
                )
        except Exception as exc:
            # Don't crash the background thread on a transient DB hiccup —
            # just skip this refresh cycle and try again next interval
            print(f"[metrics] failed to refresh business metrics: {exc}")
        time.sleep(interval_seconds)


@app.on_event("startup")
def on_startup() -> None:
    create_db_and_tables()
    thread = threading.Thread(target=refresh_business_metrics, daemon=True)
    thread.start()


@app.get("/health")
def health_check():
    return {"status": "ok"}


app.include_router(projects_router)
app.include_router(milestones_router)