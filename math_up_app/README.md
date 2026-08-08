# 数学学习提升 App（学生端）

个人版 MVP：诊断 → 练习 → 错题 → 家长 QQ 日报。内容基准为人教 A 版（2020 年 5 月第一版），面向四川新高考 II 卷。

## 当前进度

- 阶段 0/1（环境与工程骨架）✅
- 阶段 2（数据层与题库：章节树、77 题题库、SQLite 六表、导入管线）✅
- 视觉改版 v0.3.0（清新学习风·克制可爱版）✅
- 阶段 3（诊断与报告）待开发

## 技术栈

Flutter 3.44.9 / Dart 3.12.2；sqflite（本地 SQLite）、flutter_math_fork（公式渲染）、fl_chart（雷达图）、http（阶段 5 通知服务）。

## 目录结构

```
lib/
├─ main.dart / app.dart        # 入口与路由/主题
├─ core/
│  ├─ db/                      # database.dart + migrations/（001_init.sql）
│  ├─ domain/                  # Question 实体、仓储接口
│  ├─ infrastructure/          # 仓储实现、题库导入、app_config
│  ├─ application/             # 初始化用例（DbInitController）
│  ├─ ui/                      # 设计系统组件（AppCard/按钮/徽章/GeoSpirit 等）
│  └─ theme.dart               # 设计令牌与主题
└─ features/                   # home/onboarding/diagnosis/report/practice/errorbook/settings
assets/data/                   # content_index.json / chapters.json / questions.json
```

## 构建与测试

构建环境（Windows）：

- `ANDROID_HOME=D:\Android`（Android SDK）
- `PUB_CACHE=D:\pub-cache`（纯 ASCII 路径，规避中文用户名导致的原生库编译问题）
- `flutter test` 在 Windows 上需要 sqlite3.dll 可用（例如把 Python 的 `DLLs` 目录加入 PATH）

常用命令：

```powershell
flutter pub get
flutter test
flutter build apk --debug        # 或 --release
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

内容一致性校验（仓库根目录执行）：

```powershell
python scripts\validate_content.py
```

## 数据说明

- 章节树与题库见 `assets/data/`，字段规范见《数学学习提升 App 开发文档》4.1–4.2。
- SQLite 结构版本由 `lib/core/db/migrations/` 管理，App 启动时按 `PRAGMA user_version` 顺序迁移。
- 题库导入按 `content_version` 幂等：内容版本变化时仅重导题目表，不影响学习记录。

## 设计规范

清新学习风·克制可爱版（配色、组件、GeoSpirit 使用边界）见《数学学习提升 App 开发文档》附录 C。
