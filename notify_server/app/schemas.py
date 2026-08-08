"""API 请求/响应模型（对应开发文档第五章接口）。"""

from __future__ import annotations

from typing import Optional

from pydantic import BaseModel, Field


class BindCodeRequest(BaseModel):
    device_id: str = Field(min_length=1, max_length=64)


class BindCodeResponse(BaseModel):
    bind_code: str
    expires_at: str


class BindRequest(BaseModel):
    bind_code: str
    device_id: str


class BindResponse(BaseModel):
    status: str
    parent_nick: Optional[str] = None


class UnbindRequest(BaseModel):
    device_id: str


class UnbindResponse(BaseModel):
    status: str


class StatusResponse(BaseModel):
    bound: bool
    last_push_at: Optional[str] = None
    daily_enabled: bool = True
    push_time: str = "21:30"


class DigestRequest(BaseModel):
    device_id: str
    date: str
    practice_count: int = 0
    correct_count: int = 0
    error_count: int = 0
    minutes: int = 0
    weak_points: list[str] = []
    weak_point_names: list[str] = []
    streak_days: int = 0


class DigestResponse(BaseModel):
    accepted: bool


class ErrorResponse(BaseModel):
    code: str
    message: str
