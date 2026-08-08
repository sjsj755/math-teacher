"""摘要模板与失败重试测试。"""

from __future__ import annotations

import pytest

from app.application.digester import DigestSender, build_digest_message
from app.domain.entities import Binding, DigestRecord
from app.infrastructure.channels.qq_bot import PushChannel


def test_build_message_uses_names_when_present():
    payload = {
        "date": "2026-08-07",
        "practice_count": 10,
        "correct_count": 8,
        "error_count": 2,
        "minutes": 45,
        "weak_points": ["A1-3-2"],
        "weak_point_names": ["函数单调性", "指数运算"],
        "streak_days": 3,
    }
    message = build_digest_message(payload)
    assert message == (
        "【数学学习日报】8月7日\n"
        "今日完成 10 题 · 正确率 80%\n"
        "错题 2 道：函数单调性、指数运算\n"
        "学习时长 45 分钟 · 连续打卡 3 天\n"
        "明日建议：先重做错题本中的题，再完成推荐练习。"
    )


def test_build_message_falls_back_to_codes():
    payload = {
        "date": "2026-08-07",
        "practice_count": 5,
        "correct_count": 5,
        "error_count": 0,
        "minutes": 20,
        "weak_points": [],
        "streak_days": 1,
    }
    message = build_digest_message(payload)
    assert "今日完成 5 题 · 正确率 100%" in message
    assert "今日无错题，继续保持！" in message


class _FlakyChannel(PushChannel):
    """前 failures 次失败，之后成功。"""

    name = "flaky"

    def __init__(self, failures: int):
        self.failures = failures
        self.calls = 0

    def send(self, openid: str, message: str) -> bool:
        self.calls += 1
        if self.calls <= self.failures:
            raise RuntimeError("network down")
        return True


def test_retry_succeeds_after_two_failures(repository):
    digest = DigestRecord(id=1, device_id="device-1", date="2026-08-08", payload={})
    binding = Binding(device_id="device-1", openid="openid-parent")
    channel = _FlakyChannel(failures=2)
    sender = DigestSender(repository, channel, attempts=3)
    assert sender.send(digest, binding) is True
    assert channel.calls == 3

    with repository._connect() as conn:
        rows = conn.execute(
            "SELECT status FROM push_log WHERE digest_id = 1 ORDER BY id"
        ).fetchall()
    assert [row["status"] for row in rows] == ["failed", "failed", "success"]


def test_retry_exhausted_marks_failed(repository):
    digest = DigestRecord(id=2, device_id="device-1", date="2026-08-08", payload={})
    binding = Binding(device_id="device-1", openid="openid-parent")
    channel = _FlakyChannel(failures=99)
    sender = DigestSender(repository, channel, attempts=3)
    assert sender.send(digest, binding) is False
    assert channel.calls == 3

    with repository._connect() as conn:
        rows = conn.execute(
            "SELECT status FROM push_log WHERE digest_id = 2 ORDER BY id"
        ).fetchall()
    assert [row["status"] for row in rows] == ["failed", "failed", "failed"]
