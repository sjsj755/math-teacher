"""服务配置：全部通过环境变量注入，默认使用 mock 推送通道。"""

from __future__ import annotations

import os
from dataclasses import dataclass, field


def _env(name: str, default: str) -> str:
    return os.environ.get(name, default)


@dataclass(frozen=True)
class Settings:
    """服务端配置（QQ 凭据由使用者本地保管，勿提交仓库）。"""

    db_path: str = field(
        default_factory=lambda: _env("NOTIFY_DB_PATH", "notify_server.sqlite3")
    )
    bind_code_ttl_hours: int = field(
        default_factory=lambda: int(_env("NOTIFY_BIND_CODE_TTL_HOURS", "24"))
    )
    # mock | qq | email
    push_channel: str = field(
        default_factory=lambda: _env("NOTIFY_PUSH_CHANNEL", "mock")
    )
    qq_app_id: str = field(default_factory=lambda: _env("QQ_APP_ID", ""))
    qq_app_secret: str = field(default_factory=lambda: _env("QQ_APP_SECRET", ""))
    qq_app_token: str = field(default_factory=lambda: _env("QQ_APP_TOKEN", ""))
    # QQ 官方机器人 API 基址；以 QQ 开放平台文档为准，可通过环境变量覆盖。
    qq_api_base: str = field(
        default_factory=lambda: _env("QQ_API_BASE", "https://api.sgroup.qq.com")
    )
    push_time: str = field(default_factory=lambda: _env("NOTIFY_PUSH_TIME", "21:30"))
    disable_scheduler: bool = field(
        default_factory=lambda: _env("NOTIFY_DISABLE_SCHEDULER", "0") == "1"
    )
    request_timeout_seconds: int = field(
        default_factory=lambda: int(_env("NOTIFY_REQUEST_TIMEOUT", "8"))
    )
