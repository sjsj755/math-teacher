"""SQLite 仓储实现（绑定码 / 绑定 / 摘要 / 推送日志）。"""

from __future__ import annotations

import json
import sqlite3
from datetime import datetime, timedelta
from pathlib import Path
from typing import List, Optional

from app.domain.entities import (
    BindCode,
    Binding,
    DigestRecord,
    ERROR_ALREADY_BOUND,
    ERROR_BIND_CODE_INVALID,
    ERROR_DEVICE_MISMATCH,
    ERROR_NOT_BOUND,
    BusinessError,
    generate_bind_code,
    is_code_expired,
)

SCHEMA = """
CREATE TABLE IF NOT EXISTS bind_codes (
  code TEXT PRIMARY KEY,
  device_id TEXT NOT NULL,
  openid TEXT,
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS bindings (
  device_id TEXT PRIMARY KEY,
  openid TEXT NOT NULL,
  parent_nick TEXT,
  bound_at TEXT NOT NULL,
  daily_enabled INTEGER NOT NULL DEFAULT 1,
  push_time TEXT NOT NULL DEFAULT '21:30'
);

CREATE TABLE IF NOT EXISTS digest_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id TEXT NOT NULL,
  date TEXT NOT NULL,
  payload TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_digest_device_date ON digest_log(device_id, date);

CREATE TABLE IF NOT EXISTS push_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  digest_id INTEGER NOT NULL,
  channel TEXT NOT NULL,
  status TEXT NOT NULL,
  error TEXT,
  pushed_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_push_digest ON push_log(digest_id);
"""


def _iso(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%d %H:%M:%S")


def _parse_iso(raw: str) -> datetime:
    return datetime.strptime(raw, "%Y-%m-%d %H:%M:%S")


class Repository:
    """通知服务的数据仓储：每个方法使用独立连接，简单且线程安全。"""

    def __init__(self, db_path: str):
        self.db_path = db_path
        if db_path != ":memory:":
            parent = Path(db_path).parent
            if str(parent) not in ("", "."):
                parent.mkdir(parents=True, exist_ok=True)
        self._init_schema()

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path, check_same_thread=False)
        conn.row_factory = sqlite3.Row
        conn.execute("PRAGMA foreign_keys = ON")
        return conn

    def _init_schema(self) -> None:
        with self._connect() as conn:
            conn.executescript(SCHEMA)

    # ---------- 绑定码 ----------

    def create_bind_code(
        self, device_id: str, ttl_hours: int, now: Optional[datetime] = None
    ) -> BindCode:
        """为学生端生成绑定码；已绑定的设备返回 409 ALREADY_BOUND。"""

        if self.get_binding(device_id) is not None:
            raise BusinessError(
                ERROR_ALREADY_BOUND, "该设备已绑定，请先解绑", 409
            )
        now = now or datetime.now()
        expires_at = now + timedelta(hours=ttl_hours)
        for _ in range(10):
            code = generate_bind_code()
            with self._connect() as conn:
                try:
                    conn.execute(
                        "INSERT INTO bind_codes(code, device_id, expires_at, created_at)"
                        " VALUES (?, ?, ?, ?)",
                        (code, device_id, _iso(expires_at), _iso(now)),
                    )
                    return BindCode(code=code, device_id=device_id, expires_at=expires_at)
                except sqlite3.IntegrityError:
                    continue  # 撞码重试
        raise BusinessError(ERROR_BIND_CODE_INVALID, "绑定码生成失败，请重试", 500)

    def find_bind_code(self, code: str, now: Optional[datetime] = None) -> Optional[BindCode]:
        now = now or datetime.now()
        with self._connect() as conn:
            row = conn.execute(
                "SELECT code, device_id, openid, expires_at FROM bind_codes WHERE code = ?",
                (code,),
            ).fetchone()
        if row is None or is_code_expired(_parse_iso(row["expires_at"]), now):
            return None
        return BindCode(
            code=row["code"],
            device_id=row["device_id"],
            expires_at=_parse_iso(row["expires_at"]),
            openid=row["openid"],
        )

    def set_code_openid(self, code: str, openid: str) -> None:
        with self._connect() as conn:
            conn.execute(
                "UPDATE bind_codes SET openid = ? WHERE code = ?", (openid, code)
            )

    def delete_bind_code(self, code: str) -> None:
        with self._connect() as conn:
            conn.execute("DELETE FROM bind_codes WHERE code = ?", (code,))

    # ---------- 绑定 ----------

    def confirm_bind(
        self, code: str, device_id: str, now: Optional[datetime] = None
    ) -> Binding:
        """学生端确认绑定：校验绑定码有效、设备一致且家长已发送绑定指令。"""

        existing = self.get_binding(device_id)
        if existing is not None:
            return existing  # 幂等：已绑定则直接返回
        found = self.find_bind_code(code, now=now)
        if found is None:
            raise BusinessError(ERROR_BIND_CODE_INVALID, "绑定码无效或已过期", 404)
        if found.device_id != device_id:
            raise BusinessError(ERROR_DEVICE_MISMATCH, "绑定码与设备不匹配", 409)
        if not found.openid:
            raise BusinessError(
                ERROR_NOT_BOUND, "家长尚未发送“绑定 绑定码”指令", 404
            )
        now = now or datetime.now()
        with self._connect() as conn:
            conn.execute(
                "INSERT INTO bindings(device_id, openid, parent_nick, bound_at)"
                " VALUES (?, ?, ?, ?)",
                (device_id, found.openid, "家长", _iso(now)),
            )
        return Binding(
            device_id=device_id,
            openid=found.openid,
            parent_nick="家长",
            bound_at=now,
        )

    def bind_from_qq(
        self, code: str, openid: str, parent_nick: Optional[str], now: Optional[datetime] = None
    ) -> Binding:
        """家长在 QQ 发送“绑定 MATH-XXXX”：校验绑定码并立即建立绑定。"""

        found = self.find_bind_code(code, now=now)
        if found is None:
            raise BusinessError(ERROR_BIND_CODE_INVALID, "绑定码无效或已过期", 404)
        existing = self.get_binding(found.device_id)
        if existing is not None:
            self.set_code_openid(code, openid)
            return existing
        now = now or datetime.now()
        nick = parent_nick or "家长"
        with self._connect() as conn:
            conn.execute(
                "INSERT INTO bindings(device_id, openid, parent_nick, bound_at)"
                " VALUES (?, ?, ?, ?)",
                (found.device_id, openid, nick, _iso(now)),
            )
        return Binding(
            device_id=found.device_id,
            openid=openid,
            parent_nick=nick,
            bound_at=now,
        )

    def get_binding(self, device_id: str) -> Optional[Binding]:
        with self._connect() as conn:
            row = conn.execute(
                "SELECT device_id, openid, parent_nick, bound_at, daily_enabled, push_time"
                " FROM bindings WHERE device_id = ?",
                (device_id,),
            ).fetchone()
        if row is None:
            return None
        return Binding(
            device_id=row["device_id"],
            openid=row["openid"],
            parent_nick=row["parent_nick"],
            bound_at=_parse_iso(row["bound_at"]),
            daily_enabled=bool(row["daily_enabled"]),
            push_time=row["push_time"],
        )

    def get_binding_by_openid(self, openid: str) -> Optional[Binding]:
        with self._connect() as conn:
            row = conn.execute(
                "SELECT device_id, openid, parent_nick, bound_at, daily_enabled, push_time"
                " FROM bindings WHERE openid = ?",
                (openid,),
            ).fetchone()
        if row is None:
            return None
        return Binding(
            device_id=row["device_id"],
            openid=row["openid"],
            parent_nick=row["parent_nick"],
            bound_at=_parse_iso(row["bound_at"]),
            daily_enabled=bool(row["daily_enabled"]),
            push_time=row["push_time"],
        )

    def list_bound_devices(self) -> List[Binding]:
        with self._connect() as conn:
            rows = conn.execute(
                "SELECT device_id, openid, parent_nick, bound_at, daily_enabled, push_time"
                " FROM bindings"
            ).fetchall()
        return [
            Binding(
                device_id=row["device_id"],
                openid=row["openid"],
                parent_nick=row["parent_nick"],
                bound_at=_parse_iso(row["bound_at"]),
                daily_enabled=bool(row["daily_enabled"]),
                push_time=row["push_time"],
            )
            for row in rows
        ]

    def update_binding_settings(
        self, device_id: str, daily_enabled: Optional[bool] = None, push_time: Optional[str] = None
    ) -> None:
        fields: list[str] = []
        values: list[object] = []
        if daily_enabled is not None:
            fields.append("daily_enabled = ?")
            values.append(1 if daily_enabled else 0)
        if push_time is not None:
            fields.append("push_time = ?")
            values.append(push_time)
        if not fields:
            return
        values.append(device_id)
        with self._connect() as conn:
            conn.execute(
                f"UPDATE bindings SET {', '.join(fields)} WHERE device_id = ?", values
            )

    def delete_binding(self, device_id: str) -> bool:
        with self._connect() as conn:
            cur = conn.execute("DELETE FROM bindings WHERE device_id = ?", (device_id,))
        return cur.rowcount > 0

    def delete_binding_by_openid(self, openid: str) -> bool:
        with self._connect() as conn:
            cur = conn.execute("DELETE FROM bindings WHERE openid = ?", (openid,))
        return cur.rowcount > 0

    # ---------- 摘要与推送日志 ----------

    def save_digest(self, device_id: str, date: str, payload: dict) -> int:
        """保存当日摘要；同设备同日覆盖旧记录。"""

        payload_text = json.dumps(payload, ensure_ascii=False)
        with self._connect() as conn:
            existing = conn.execute(
                "SELECT id FROM digest_log WHERE device_id = ? AND date = ?",
                (device_id, date),
            ).fetchone()
            if existing is not None:
                conn.execute(
                    "UPDATE digest_log SET payload = ? WHERE id = ?",
                    (payload_text, existing["id"]),
                )
                return int(existing["id"])
            cur = conn.execute(
                "INSERT INTO digest_log(device_id, date, payload, created_at)"
                " VALUES (?, ?, ?, ?)",
                (device_id, date, payload_text, _iso(datetime.now())),
            )
            return int(cur.lastrowid)

    def get_digest(self, device_id: str, date: str) -> Optional[DigestRecord]:
        with self._connect() as conn:
            row = conn.execute(
                "SELECT id, device_id, date, payload FROM digest_log"
                " WHERE device_id = ? AND date = ?",
                (device_id, date),
            ).fetchone()
        if row is None:
            return None
        return DigestRecord(
            id=int(row["id"]),
            device_id=row["device_id"],
            date=row["date"],
            payload=json.loads(row["payload"]),
        )

    def add_push_log(self, digest_id: int, channel: str, status: str, error: Optional[str] = None) -> None:
        with self._connect() as conn:
            conn.execute(
                "INSERT INTO push_log(digest_id, channel, status, error, pushed_at)"
                " VALUES (?, ?, ?, ?, ?)",
                (digest_id, channel, status, error, _iso(datetime.now())),
            )

    def last_push_at(self, device_id: str) -> Optional[str]:
        """最近一次成功推送时间（未推送返回 None）。"""

        with self._connect() as conn:
            row = conn.execute(
                "SELECT MAX(p.pushed_at) AS at FROM push_log p"
                " JOIN digest_log d ON d.id = p.digest_id"
                " WHERE d.device_id = ? AND p.status = 'success'",
                (device_id,),
            ).fetchone()
        return row["at"] if row and row["at"] else None
