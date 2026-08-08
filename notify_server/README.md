# 通知服务（阶段五）

面向家长的 QQ 日报通知服务：学生端上送当日学习摘要，服务端每日 21:30
定时推送日报到家长 QQ；推送失败自动重试 3 次。

## 快速开始

```bash
cd notify_server
python -m venv .venv
.venv\Scripts\activate        # Windows
pip install -r requirements-dev.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

默认使用 `mock` 推送通道（只记录不真发），适合本地联调与自动化测试。
配置真实 QQ 机器人：

```bash
set NOTIFY_PUSH_CHANNEL=qq
set QQ_APP_ID=你的AppID
set QQ_APP_SECRET=你的AppSecret
set QQ_APP_TOKEN=你的Token
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

> QQ 官方机器人 API 地址以 [QQ 开放平台文档](https://q.qq.com) 为准，
> 可用 `QQ_API_BASE` 环境变量覆盖；凭据请勿提交到仓库。

## 接口一览（`/api/v1` 前缀）

| 方法 | 路径 | 说明 |
| ---- | ---- | ---- |
| POST | `/bind-code` | 生成绑定码（默认 24 小时有效），请求 `{"device_id": "..."}` |
| POST | `/bind` | 学生端确认绑定，请求 `{"bind_code": "MATH-8F3K", "device_id": "..."}` |
| GET | `/status?device_id=...` | 查询绑定与推送状态（设置页每 30 秒轮询） |
| POST | `/unbind` | 学生端解绑，请求 `{"device_id": "..."}` |
| POST | `/daily-digest` | 上送当日摘要（未绑定返回 404 `NOT_BOUND`） |
| POST | `/qq/callback` | QQ 平台 Webhook：`绑定 MATH-8F3K` / `日报` / `解绑` |
| GET | `/ping` | 健康检查 |

业务错误码：`BIND_CODE_INVALID`（404）、`ALREADY_BOUND`（409）、
`DEVICE_MISMATCH`（409）、`NOT_BOUND`（404）。

## 数据表

- `bind_codes`：绑定码（device_id / openid / expires_at）
- `bindings`：设备 ↔ 家长 openid 绑定（daily_enabled / push_time）
- `digest_log`：每日摘要（device_id / date / payload）
- `push_log`：推送结果与失败重试记录（digest_id / channel / status / error）

## 测试

```bash
pytest -q
```

覆盖：绑定码生成与过期、完整绑定链路、错误码、状态查询、解绑、
摘要上送、QQ 回调三种指令、官方 v2 payload 兼容、日报模板、失败重试 3 次。

## 本地联调建议

1. `curl -X POST http://127.0.0.1:8000/api/v1/bind-code -H "Content-Type: application/json" -d "{\"device_id\": \"dev-1\"}"` 获取绑定码；
2. `curl -X POST http://127.0.0.1:8000/api/v1/qq/callback -H "Content-Type: application/json" -d "{\"message\": \"绑定 MATH-XXXX\", \"openid\": \"test-openid\"}"` 模拟家长发绑定指令；
3. 上送摘要后，家长在 QQ 发「日报」立即推送；或等待 21:30 定时任务。
