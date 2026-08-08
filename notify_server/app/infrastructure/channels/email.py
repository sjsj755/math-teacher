"""邮件通道（二线预案，预留实现）。"""

from __future__ import annotations

from app.infrastructure.channels.qq_bot import MockQQChannel, PushChannel


class EmailChannel(PushChannel):
    name = "email"

    def send(self, openid: str, message: str) -> bool:
        raise NotImplementedError("邮件通道为二线预案，尚未接入 SMTP 配置")


def make_channel(settings) -> PushChannel:
    """按配置构造推送通道：mock（默认）/ qq / email。"""

    if settings.push_channel == "qq" and settings.qq_app_id and settings.qq_app_secret:
        return QQBotChannel(
            settings.qq_app_id,
            settings.qq_app_secret,
            settings.qq_api_base,
            settings.request_timeout_seconds,
        )
    if settings.push_channel == "email":
        return EmailChannel()
    return MockQQChannel()
