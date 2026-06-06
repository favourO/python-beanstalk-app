from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from phora.api.routes import ai, auth, billing, cycle, growth, health, home, log, notifications, onboarding, predictions, sensor, user, watch, wearables
from phora.api.routes import admin, public
from phora.api.routes import wearable_commerce
from phora.core.config import get_settings
from phora.core.logging import configure_logging
from phora.db.base import Base
from phora.db.session import ensure_postgres_schemas, ensure_stage_wearable_inventory, get_engine, reset_db_state
from phora.models import *  # noqa: F403


@asynccontextmanager
async def lifespan(_: FastAPI):
    settings = get_settings()
    configure_logging()
    if settings.auto_create_tables:
        ensure_postgres_schemas()
        Base.metadata.create_all(bind=get_engine())
        ensure_stage_wearable_inventory()
    yield


def create_app() -> FastAPI:
    get_settings.cache_clear()
    reset_db_state()
    settings = get_settings()
    if settings.auto_create_tables:
        ensure_postgres_schemas()
        Base.metadata.create_all(bind=get_engine())
        ensure_stage_wearable_inventory()
    app = FastAPI(title=settings.app_name, lifespan=lifespan)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origins,
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.include_router(health.router, prefix=settings.api_prefix)
    app.include_router(auth.router, prefix=settings.api_prefix)
    app.include_router(billing.router, prefix=settings.api_prefix)
    app.include_router(billing.admin_router, prefix=settings.api_prefix)
    app.include_router(onboarding.router, prefix=settings.api_prefix)
    app.include_router(cycle.router, prefix=settings.api_prefix)
    app.include_router(log.router, prefix=settings.api_prefix)
    app.include_router(sensor.router, prefix=settings.api_prefix)
    app.include_router(watch.router, prefix=settings.api_prefix)
    app.include_router(wearables.router, prefix=settings.api_prefix)
    app.include_router(predictions.router, prefix=settings.api_prefix)
    app.include_router(home.router, prefix=settings.api_prefix)
    app.include_router(growth.router, prefix=settings.api_prefix)
    app.include_router(notifications.router, prefix=settings.api_prefix)
    app.include_router(user.router, prefix=settings.api_prefix)
    app.include_router(ai.router, prefix=settings.api_prefix)
    app.include_router(admin.router, prefix=settings.api_prefix)
    app.include_router(public.router, prefix=settings.api_prefix)
    app.include_router(wearable_commerce.router, prefix=settings.api_prefix)
    app.include_router(wearable_commerce.admin_router, prefix=settings.api_prefix)
    app.include_router(auth.router, prefix=settings.api_prefix_legacy)
    return app
