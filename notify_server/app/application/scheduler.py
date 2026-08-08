"""APScheduler 每日定时推送（默认 21:30）。"""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from app.application.digester import DigestSender
from app.infrastructure.channels.qq_bot import PushChannel
from app.infrastructure.repository import Repository


def parse_push_time(push_time: str) -> tuple[int, int]:
    hour, _, minute = push_time.partition(":")
    return int(hour), int(minute)


def push_today_digests(
    repo: Repository,
    channel: PushChannel,
    attempts: int = 3,
    today: Optional[str] = None,
) -> dict:
    """为所有已绑定设备推送当日摘要；无摘要则跳过。"""

    today = today or datetime.now().strftime("%Y-%m-%d")
    results = {"pushed": 0, "failed": 0, "skipped": 0}
    sender = DigestSender(repo, channel, attempts=attempts)
    for binding in repo.list_bound_devices():
        if not binding.daily_enabled:
            results["skipped"] += 1
            continue
        digest = repo.get_digest(binding.device_id, today)
        if digest is None:
            results["skipped"] += 1
            continue
        if sender.send(digest, binding):
            results["pushed"] += 1
        else:
            results["failed"] += 1
    return results


def start_scheduler(repo: Repository, channel: PushChannel, push_time: str, attempts: int = 3):
    """启动后台调度器；返回可 stop 的 BackgroundScheduler。"""

    from apscheduler.schedulers.background import BackgroundScheduler
    from apscheduler.triggers.cron import CronTrigger

    hour, minute = parse_push_time(push_time)
    scheduler = BackgroundScheduler(timezone="Asia/Shanghai")
    scheduler.add_job(
        push_today_digests,
        CronTrigger(hour=hour, minute=minute),
        args=[repo, channel],
        kwargs={"attempts": attempts},
        id="daily_push",
        replace_existing=True,
        misfire_grace_time=3600,
    )
    scheduler.start()
    return scheduler
