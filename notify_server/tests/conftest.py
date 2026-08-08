"""共享 fixture：临时数据库 + mock 通道 + 测试应用。"""

from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.config import Settings
from app.infrastructure.channels.qq_bot import MockQQChannel
from app.infrastructure.repository import Repository
from app.main import create_app


@pytest.fixture()
def repository(tmp_path):
    return Repository(str(tmp_path / "notify_test.sqlite3"))


@pytest.fixture()
def channel():
    return MockQQChannel()


@pytest.fixture()
def settings(tmp_path):
    return Settings(
        db_path=str(tmp_path / "notify_test.sqlite3"),
        push_channel="mock",
        disable_scheduler=True,
    )


@pytest.fixture()
def app(repository, channel, settings):
    return create_app(
        settings=settings,
        repository=repository,
        channel=channel,
        enable_scheduler=False,
    )


@pytest.fixture()
def client(app):
    return TestClient(app)
