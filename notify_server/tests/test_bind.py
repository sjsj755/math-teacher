"""绑定接口测试：绑定码生成 / 确认 / 状态 / 解绑。"""

from __future__ import annotations

from app.domain.entities import (
    ERROR_ALREADY_BOUND,
    ERROR_BIND_CODE_INVALID,
    ERROR_DEVICE_MISMATCH,
    ERROR_NOT_BOUND,
)


def _generate_code(client) -> str:
    resp = client.post("/api/v1/bind-code", json={"device_id": "device-1"})
    assert resp.status_code == 200
    return resp.json()["bind_code"]


def test_generate_bind_code(client):
    resp = client.post("/api/v1/bind-code", json={"device_id": "device-1"})
    assert resp.status_code == 200
    body = resp.json()
    assert body["bind_code"].startswith("MATH-")
    assert len(body["bind_code"]) == 9
    assert body["expires_at"]


def test_bind_code_missing_parameter(client):
    resp = client.post("/api/v1/bind-code", json={})
    assert resp.status_code == 422


def test_confirm_bind_before_parent_sends(client):
    code = _generate_code(client)
    resp = client.post(
        "/api/v1/bind", json={"bind_code": code, "device_id": "device-1"}
    )
    assert resp.status_code == 404
    assert resp.json()["detail"]["code"] == ERROR_NOT_BOUND


def test_full_bind_flow(client, repository):
    code = _generate_code(client)
    # 家长在 QQ 发送绑定指令
    callback = client.post(
        "/api/v1/qq/callback",
        json={"message": f"绑定 {code}", "openid": "openid-parent"},
    )
    assert callback.status_code == 200
    assert callback.json()["handled"] is True
    # 学生端确认（幂等返回已绑定）
    resp = client.post(
        "/api/v1/bind", json={"bind_code": code, "device_id": "device-1"}
    )
    assert resp.status_code == 200
    assert resp.json()["status"] == "bound"
    assert repository.get_binding("device-1").openid == "openid-parent"


def test_confirm_bind_invalid_code(client):
    resp = client.post(
        "/api/v1/bind", json={"bind_code": "MATH-XXXX", "device_id": "device-1"}
    )
    assert resp.status_code == 404
    assert resp.json()["detail"]["code"] == ERROR_BIND_CODE_INVALID


def test_confirm_bind_device_mismatch(client):
    code = _generate_code(client)
    client.post(
        "/api/v1/qq/callback", json={"message": f"绑定 {code}", "openid": "openid-parent"}
    )
    resp = client.post(
        "/api/v1/bind", json={"bind_code": code, "device_id": "device-other"}
    )
    assert resp.status_code == 409
    assert resp.json()["detail"]["code"] == ERROR_DEVICE_MISMATCH


def test_bind_code_already_bound(client, repository):
    code = _generate_code(client)
    client.post(
        "/api/v1/qq/callback", json={"message": f"绑定 {code}", "openid": "openid-parent"}
    )
    resp = client.post("/api/v1/bind-code", json={"device_id": "device-1"})
    assert resp.status_code == 409
    assert resp.json()["detail"]["code"] == ERROR_ALREADY_BOUND


def test_status_unbound(client):
    resp = client.get("/api/v1/status", params={"device_id": "device-1"})
    assert resp.status_code == 200
    body = resp.json()
    assert body["bound"] is False
    assert body["push_time"] == "21:30"


def test_status_bound_after_bind(client):
    code = _generate_code(client)
    client.post(
        "/api/v1/qq/callback", json={"message": f"绑定 {code}", "openid": "openid-parent"}
    )
    resp = client.get("/api/v1/status", params={"device_id": "device-1"})
    assert resp.status_code == 200
    assert resp.json()["bound"] is True
    assert resp.json()["daily_enabled"] is True
    assert resp.json()["last_push_at"] is None


def test_unbind(client, repository):
    code = _generate_code(client)
    client.post(
        "/api/v1/qq/callback", json={"message": f"绑定 {code}", "openid": "openid-parent"}
    )
    resp = client.post("/api/v1/unbind", json={"device_id": "device-1"})
    assert resp.status_code == 200
    assert resp.json()["status"] == "unbound"
    assert repository.get_binding("device-1") is None
    resp = client.get("/api/v1/status", params={"device_id": "device-1"})
    assert resp.json()["bound"] is False
