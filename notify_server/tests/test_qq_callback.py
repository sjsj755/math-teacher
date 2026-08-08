"""QQ 回调测试：绑定 / 日报 / 解绑指令。"""

from __future__ import annotations


def _bind_via_callback(client) -> str:
    resp = client.post("/api/v1/bind-code", json={"device_id": "device-1"})
    code = resp.json()["bind_code"]
    client.post(
        "/api/v1/qq/callback", json={"message": f"绑定 {code}", "openid": "openid-parent"}
    )
    return code


def test_callback_bind_immediately_binds(client, repository):
    resp = client.post("/api/v1/bind-code", json={"device_id": "device-1"})
    code = resp.json()["bind_code"]
    resp = client.post(
        "/api/v1/qq/callback", json={"message": f"绑定 {code}", "openid": "openid-parent"}
    )
    assert resp.status_code == 200
    assert resp.json()["handled"] is True
    binding = repository.get_binding("device-1")
    assert binding is not None
    assert binding.openid == "openid-parent"
    assert binding.parent_nick == "家长"


def test_callback_bind_invalid_code(client, channel):
    resp = client.post(
        "/api/v1/qq/callback", json={"message": "绑定 MATH-XXXX", "openid": "openid-parent"}
    )
    assert resp.status_code == 200
    assert resp.json()["handled"] is False
    assert channel.sent and "绑定码无效或已过期" in channel.sent[-1][1]


def test_callback_daily_command_pushes(client, repository, channel):
    _bind_via_callback(client)
    client.post(
        "/api/v1/daily-digest",
        json={
            "device_id": "device-1",
            "date": "2026-08-08",
            "practice_count": 6,
            "correct_count": 6,
            "error_count": 0,
            "minutes": 30,
            "weak_points": [],
            "streak_days": 2,
        },
    )
    resp = client.post(
        "/api/v1/qq/callback", json={"message": "日报", "openid": "openid-parent"}
    )
    assert resp.status_code == 200
    assert resp.json()["handled"] is True
    assert any("【数学学习日报】" in text for _, text in channel.sent)


def test_callback_daily_without_digest(client, channel):
    _bind_via_callback(client)
    resp = client.post(
        "/api/v1/qq/callback", json={"message": "日报", "openid": "openid-parent"}
    )
    assert resp.status_code == 200
    assert resp.json()["handled"] is False
    assert "还没有学习记录" in channel.sent[-1][1]


def test_callback_unbind(client, repository, channel):
    _bind_via_callback(client)
    resp = client.post(
        "/api/v1/qq/callback", json={"message": "解绑", "openid": "openid-parent"}
    )
    assert resp.status_code == 200
    assert resp.json()["handled"] is True
    assert repository.get_binding("device-1") is None


def test_callback_official_v2_payload_shape(client, repository):
    """兼容 QQ 官方机器人 v2 Webhook 的 payload 结构。"""

    resp = client.post("/api/v1/bind-code", json={"device_id": "device-9"})
    code = resp.json()["bind_code"]
    resp = client.post(
        "/api/v1/qq/callback",
        json={
            "eventType": "C2C_MSG_CREATE",
            "payload": {
                "msgId": "MSG123",
                "content": f"绑定 {code}",
                "sender": {"openid": "openid-v2", "nickname": "小明妈妈"},
            },
        },
    )
    assert resp.status_code == 200
    binding = repository.get_binding("device-9")
    assert binding is not None
    assert binding.parent_nick == "小明妈妈"
