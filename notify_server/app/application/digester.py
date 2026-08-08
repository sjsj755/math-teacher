"""日报摘要消息编排与失败重试。"""

from __future__ import annotations

import json
from datetime import datetime

from app.domain.entities import Binding, DigestRecord
from app.infrastructure.channels.qq_bot import PushChannel
from app.infrastructure.repository import Repository


def _format_date(date_text: str) -> str:
    """2026-08-07 → 8月7日；非法输入原样返回。"""

    try:
        parsed = datetime.strptime(date_text, "%Y-%m-%d")
        return f"{parsed.month}月{parsed.day}日"
    except ValueError:
        return date_text


def build_digest_message(payload: dict) -> str:
    """按开发文档 5.4.1 模板生成日报文本。"""

    date = _format_date(str(payload.get("date", "")))
    practice_count = int(payload.get("practice_count", 0))
    correct_count = int(payload.get("correct_count", 0))
    error_count = int(payload.get("error_count", 0))
    minutes = int(payload.get("minutes", 0))
    streak_days = int(payload.get("streak_days", 0))
    rate = round(correct_count / practice_count * 100) if practice_count else 0

    names = payload.get("weak_point_names") or payload.get("weak_points") or []
    lines = [f"【数学学习日报】{date}"]
    lines.append(f"今日完成 {practice_count} 题 · 正确率 {rate}%")
    if error_count > 0:
        detail = "、".join(str(n) for n in names[:3]) if names else "详情见 App 错题本"
        lines.append(f"错题 {error_count} 道：{detail}")
    else:
        lines.append("今日无错题，继续保持！")
    lines.append(f"学习时长 {minutes} 分钟 · 连续打卡 {streak_days} 天")
    lines.append("明日建议：先重做错题本中的题，再完成推荐练习。")
    return "\n".join(lines)


class DigestSender:
    """推送器：失败重试 attempts 次，每次尝试都记录 push_log。"""

    def __init__(self, repo: Repository, channel: PushChannel, attempts: int = 3):
        self.repo = repo
        self.channel = channel
        self.attempts = attempts

    def send(self, digest: DigestRecord, binding: Binding) -> bool:
        payload = digest.payload if isinstance(digest.payload, dict) else json.loads(digest.payload)
        message = build_digest_message(payload)
        last_error: str | None = None
        for _ in range(self.attempts):
            try:
                if self.channel.send(binding.openid, message):
                    self.repo.add_push_log(digest.id, self.channel.name, "success")
                    return True
                last_error = "通道返回失败"
            except Exception as exc:  # noqa: BLE001 - 通道异常统一记录
                last_error = str(exc)
            self.repo.add_push_log(digest.id, self.channel.name, "failed", last_error)
        return False
