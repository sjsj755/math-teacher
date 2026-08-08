"""QQ 官方机器人推送通道。

注意：QQ 开放平台的机器人 API 地址与字段以官方文档为准，本实现提供
QQ_API_BASE 环境变量便于适配；未配置 AppID/AppSecret 时请使用 mock 通道。
"""

from __future__ import annotations

from typing import List, Tuple

import requests


class PushChannel:
    """推送通道协议：send 返回是否成功，异常视为失败。"""

    name = "base"

    def send(self, openid: str, message: str) -> bool:  # pragma: no cover
        raise NotImplementedError


class MockQQChannel(PushChannel):
    """本地模拟通道：记录消息供测试与演示，不真正发送。"""

    name = "mock"

    def __init__(self) -> None:
        self.sent: List[Tuple[str, str]] = []

    def send(self, openid: str, message: str) -> bool:
        self.sent.append((openid, message))
        return True


class QQBotChannel(PushChannel):
    """官方 QQ 机器人通道（C2C 单聊消息）。"""

    name = "qq"

    def __init__(
        self,
        app_id: str,
        app_secret: str,
        api_base: str,
        timeout: int = 8,
    ) -> None:
        self.app_id = app_id
        self.app_secret = app_secret
        self.api_base = api_base.rstrip("/")
        self.timeout = timeout
        self._token: str | None = None

    def _access_token(self) -> str:
        if self._token:
            return self._token
        resp = requests.get(
            f"{self.api_base}/appapi/v2/token",
            params={"appId": self.app_id, "clientSecret": self.app_secret},
            timeout=self.timeout,
        )
        resp.raise_for_status()
        data = resp.json()
        token = (data.get("data") or data).get("access_token") or data.get("access_token")
        if not token:
            raise RuntimeError(f"获取 QQ access_token 失败：{data}")
        self._token = str(token)
        return self._token

    def send(self, openid: str, message: str) -> bool:
        token = self._access_token()
        resp = requests.post(
            f"{self.api_base}/appapi/v2/c2c/messages",
            headers={"Authorization": f"QQBot {token}"},
            json={
                "msg_type": 1,
                "msg_seq": 1,
                "msg": {"content": message},
                "openid": openid,
            },
            timeout=self.timeout,
        )
        if resp.status_code >= 400:
            raise RuntimeError(f"QQ 推送失败：{resp.status_code} {resp.text}")
        return True
