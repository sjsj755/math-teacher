"""QQ 平台 Webhook：家长文本指令（绑定 / 日报 / 解绑）。"""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Request
from pydantic import BaseModel

from app.application.digester import DigestSender
from app.domain.entities import BusinessError, ERROR_BIND_CODE_INVALID

router = APIRouter()


class QQCallbackRequest(BaseModel):
    """兼容 QQ 官方机器人 v2 Webhook 与简化调试格式。"""

    eventType: Optional[str] = None
    payload: Optional[dict] = None
    # 简化格式（本地调试 / 测试）
    message: Optional[str] = None
    openid: Optional[str] = None
    parent_nick: Optional[str] = None


def _extract_text(body: QQCallbackRequest) -> Optional[str]:
    if body.message:
        return body.message.strip()
    payload = body.payload or {}
    content = payload.get("content") or (payload.get("msg") or {}).get("content")
    if content:
        return str(content).strip()
    return None


def _extract_openid(body: QQCallbackRequest) -> Optional[str]:
    if body.openid:
        return body.openid
    payload = body.payload or {}
    return payload.get("openid") or (payload.get("sender") or {}).get("openid")


def _extract_nick(body: QQCallbackRequest) -> Optional[str]:
    if body.parent_nick:
        return body.parent_nick
    payload = body.payload or {}
    return (payload.get("sender") or {}).get("nickname")


@router.post("/qq/callback", tags=["QQ"])
def qq_callback(body: QQCallbackRequest, request: Request):
    """接收家长 QQ 文本指令：绑定 / 日报 / 解绑。"""

    repo = request.app.state.repository
    channel = request.app.state.channel
    text = _extract_text(body)
    openid = _extract_openid(body)
    if text is None or openid is None:
        # 非文本消息或缺少 openid：确认收到但不处理
        return {"ok": True, "handled": False}

    handled = False
    reply: Optional[str] = None

    if text.startswith("绑定"):
        code = text[len("绑定") :].strip()
        try:
            binding = repo.bind_from_qq(code, openid, _extract_nick(body))
            reply = f"绑定成功！{binding.parent_nick or '家长'}，每晚 {binding.push_time} 推送学习日报。"
            handled = True
        except BusinessError as exc:
            if exc.code == ERROR_BIND_CODE_INVALID:
                reply = "绑定失败：绑定码无效或已过期，请在 App 设置页重新生成。"
            else:
                reply = f"绑定失败：{exc.message}"

    elif text == "日报":
        binding = repo.get_binding_by_openid(openid)
        if binding is None:
            reply = "尚未绑定，请先发送“绑定 绑定码”。"
        else:
            today = datetime.now().strftime("%Y-%m-%d")
            digest = repo.get_digest(binding.device_id, today)
            if digest is None:
                reply = "今天还没有学习记录，完成练习后再来查看日报吧。"
            else:
                sender = DigestSender(repo, channel)
                if sender.send(digest, binding):
                    reply = "日报已发送，请查收。"
                    handled = True
                else:
                    reply = "日报发送失败，服务端稍后会自动重试。"

    elif text == "解绑":
        if repo.delete_binding_by_openid(openid):
            reply = "已解除绑定，可在 App 设置页重新生成绑定码。"
            handled = True
        else:
            reply = "当前未绑定。"

    if reply and channel.name == "mock":
        channel.send(openid, reply)
    return {"ok": True, "handled": handled}
