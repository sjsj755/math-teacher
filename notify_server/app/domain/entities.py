"""通知域领域实体：绑定码、绑定、摘要与推送日志。"""

from __future__ import annotations

import secrets
from dataclasses import dataclass
from datetime import datetime
from typing import Optional

# 业务错误码（对应开发文档 5.1）
ERROR_BIND_CODE_INVALID = "BIND_CODE_INVALID"
ERROR_ALREADY_BOUND = "ALREADY_BOUND"
ERROR_DEVICE_MISMATCH = "DEVICE_MISMATCH"
ERROR_NOT_BOUND = "NOT_BOUND"


class BusinessError(Exception):
    """携带 HTTP 状态码与业务错误码的领域异常。"""

    def __init__(self, code: str, message: str, http_status: int):
        super().__init__(message)
        self.code = code
        self.message = message
        self.http_status = http_status


@dataclass
class BindCode:
    """学生端生成的绑定码（24 小时有效）。"""

    code: str
    device_id: str
    expires_at: datetime
    openid: Optional[str] = None


@dataclass
class Binding:
    """设备与家长 openid 的绑定关系。"""

    device_id: str
    openid: str
    parent_nick: Optional[str] = None
    bound_at: Optional[datetime] = None
    daily_enabled: bool = True
    push_time: str = "21:30"


@dataclass
class DigestRecord:
    """每日摘要记录（digest_log 行）。"""

    id: Optional[int]
    device_id: str
    date: str
    payload: dict


def generate_bind_code() -> str:
    """生成形如 MATH-8F3K 的绑定码（排除易混淆字符）。"""

    alphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    return "MATH-" + "".join(secrets.choice(alphabet) for _ in range(4))


def is_code_expired(expires_at: datetime, now: datetime) -> bool:
    return expires_at <= now
