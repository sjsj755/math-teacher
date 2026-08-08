"""绑定接口：绑定码生成 / 确认绑定 / 状态查询 / 解绑。"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Request

from app.config import Settings
from app.domain.entities import BusinessError
from app.infrastructure.repository import Repository
from app.schemas import (
    BindCodeRequest,
    BindCodeResponse,
    BindRequest,
    BindResponse,
    StatusResponse,
    UnbindRequest,
    UnbindResponse,
)

router = APIRouter()


def _repo(request: Request) -> Repository:
    return request.app.state.repository


def _settings(request: Request) -> Settings:
    return request.app.state.settings


def _http_error(exc: BusinessError) -> HTTPException:
    return HTTPException(
        status_code=exc.http_status,
        detail={"code": exc.code, "message": exc.message},
    )


@router.post("/bind-code", response_model=BindCodeResponse, tags=["绑定"])
def create_bind_code(body: BindCodeRequest, request: Request):
    """生成绑定码（24 小时有效）。"""

    try:
        code = _repo(request).create_bind_code(
            body.device_id, _settings(request).bind_code_ttl_hours
        )
    except BusinessError as exc:
        raise _http_error(exc) from exc
    return BindCodeResponse(
        bind_code=code.code,
        expires_at=code.expires_at.strftime("%Y-%m-%d %H:%M:%S"),
    )


@router.post("/bind", response_model=BindResponse, tags=["绑定"])
def confirm_bind(body: BindRequest, request: Request):
    """学生端确认绑定码关联（幂等，已绑定直接返回）。"""

    try:
        binding = _repo(request).confirm_bind(body.bind_code, body.device_id)
    except BusinessError as exc:
        raise _http_error(exc) from exc
    return BindResponse(status="bound", parent_nick=binding.parent_nick)


@router.get("/status", response_model=StatusResponse, tags=["绑定"])
def get_status(device_id: str, request: Request):
    """查询绑定与推送状态（设置页每 30 秒轮询）。"""

    repo = _repo(request)
    binding = repo.get_binding(device_id)
    if binding is None:
        return StatusResponse(
            bound=False,
            push_time=_settings(request).push_time,
        )
    return StatusResponse(
        bound=True,
        last_push_at=repo.last_push_at(device_id),
        daily_enabled=binding.daily_enabled,
        push_time=binding.push_time,
    )


@router.post("/unbind", response_model=UnbindResponse, tags=["绑定"])
def unbind(body: UnbindRequest, request: Request):
    """学生端解绑。"""

    _repo(request).delete_binding(body.device_id)
    return UnbindResponse(status="unbound")
