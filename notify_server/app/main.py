"""通知服务入口：FastAPI 应用工厂与 uvicorn 启动。"""

from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.api.bind import router as bind_router
from app.api.digest import router as digest_router
from app.api.qq_callback import router as qq_callback_router
from app.application.scheduler import start_scheduler
from app.config import Settings
from app.infrastructure.channels.email import make_channel
from app.infrastructure.repository import Repository


def create_app(
    settings: Settings | None = None,
    repository: Repository | None = None,
    channel=None,
    enable_scheduler: bool = True,
) -> FastAPI:
    """应用工厂：测试可注入内存库 / mock 通道 / 关闭调度器。"""

    settings = settings or Settings()
    repo = repository or Repository(settings.db_path)
    channel = channel or make_channel(settings)

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        scheduler = None
        if enable_scheduler and not settings.disable_scheduler:
            scheduler = start_scheduler(repo, channel, settings.push_time)
            app.state.scheduler = scheduler
        yield
        if scheduler is not None:
            scheduler.shutdown(wait=False)

    app = FastAPI(
        title="数学学习提升通知服务",
        version="1.0.0",
        lifespan=lifespan,
    )
    app.state.repository = repo
    app.state.channel = channel
    app.state.settings = settings

    app.include_router(bind_router, prefix="/api/v1")
    app.include_router(digest_router, prefix="/api/v1")
    app.include_router(qq_callback_router, prefix="/api/v1")

    @app.get("/api/v1/ping", tags=["系统"])
    def ping():
        return {"status": "ok"}

    return app


app = create_app()


if __name__ == "__main__":
    import uvicorn

    settings = Settings()
    uvicorn.run(
        "app.main:app",
        host="0.0.0.0",
        port=8000,
        reload=False,
    )
