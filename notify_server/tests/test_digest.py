"""日报摘要上送与推送状态测试。"""

from __future__ import annotations


def _bind(client) -> str:
    resp = client.post("/api/v1/bind-code", json={"device_id": "device-1"})
    code = resp.json()["bind_code"]
    client.post(
        "/api/v1/qq/callback", json={"message": f"绑定 {code}", "openid": "openid-parent"}
    )
    return code


def test_upload_digest_unbound(client):
    resp = client.post(
        "/api/v1/daily-digest",
        json={
            "device_id": "device-1",
            "date": "2026-08-08",
            "practice_count": 10,
            "correct_count": 8,
            "error_count": 2,
            "minutes": 45,
            "weak_points": ["A1-3-2"],
            "streak_days": 3,
        },
    )
    assert resp.status_code == 404
    assert resp.json()["detail"]["code"] == "NOT_BOUND"


def test_upload_digest_after_bind(client, repository):
    _bind(client)
    resp = client.post(
        "/api/v1/daily-digest",
        json={
            "device_id": "device-1",
            "date": "2026-08-08",
            "practice_count": 10,
            "correct_count": 8,
            "error_count": 2,
            "minutes": 45,
            "weak_points": ["A1-3-2"],
            "weak_point_names": ["函数单调性"],
            "streak_days": 3,
        },
    )
    assert resp.status_code == 200
    assert resp.json()["accepted"] is True
    digest = repository.get_digest("device-1", "2026-08-08")
    assert digest is not None
    assert digest.payload["practice_count"] == 10


def test_upload_digest_overwrites_same_date(client, repository):
    _bind(client)
    base = {
        "device_id": "device-1",
        "date": "2026-08-08",
        "practice_count": 5,
        "correct_count": 3,
        "error_count": 2,
        "minutes": 20,
        "weak_points": [],
        "streak_days": 1,
    }
    client.post("/api/v1/daily-digest", json=base)
    base["practice_count"] = 12
    resp = client.post("/api/v1/daily-digest", json=base)
    assert resp.status_code == 200
    digest = repository.get_digest("device-1", "2026-08-08")
    assert digest.payload["practice_count"] == 12


def test_push_after_upload(client, repository, channel):
    from app.application.scheduler import push_today_digests

    _bind(client)
    client.post(
        "/api/v1/daily-digest",
        json={
            "device_id": "device-1",
            "date": "2026-08-08",
            "practice_count": 10,
            "correct_count": 8,
            "error_count": 2,
            "minutes": 45,
            "weak_points": ["A1-3-2"],
            "weak_point_names": ["函数单调性"],
            "streak_days": 3,
        },
    )
    results = push_today_digests(repository, channel, today="2026-08-08")
    assert results["pushed"] == 1
    messages = [text for _, text in channel.sent]
    assert any(text.startswith("【数学学习日报】") for text in messages)
    message = next(text for text in messages if text.startswith("【数学学习日报】"))
    assert "【数学学习日报】8月8日" in message
    assert "今日完成 10 题 · 正确率 80%" in message
    assert "错题 2 道：函数单调性" in message
    assert "学习时长 45 分钟 · 连续打卡 3 天" in message
    assert repository.last_push_at("device-1") is not None
