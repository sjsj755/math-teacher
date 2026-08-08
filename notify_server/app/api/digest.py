"""日报摘要上送接口。"""

from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Request

from app.domain.entities import ERROR_NOT_BOUND
from app.infrastructure.repository import Repository
from app.schemas import DigestRequest, DigestResponse

router = APIRouter()


def _repo(request: Request) -> Repository:
    return request.app.state.repository


@router.post("/daily-digest", response_model=DigestResponse, tags=["摘要"])
def upload_daily_digest(body: DigestRequest, request: Request):
    """学生端上送当日日报摘要（仅已绑定设备可上送）。"""

    repo = _repo(request)
    if repo.get_binding(body.device_id) is None:
        raise HTTPException(
            status_code=404,
            detail={"code": ERROR_NOT_BOUND, "message": "设备未绑定"},
        )
    repo.save_digest(body.device_id, body.date, body.model_dump())
    return DigestResponse(accepted=True)
