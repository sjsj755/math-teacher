# 数学学习提升（个人版 MVP）

一名高中生的数学提分闭环：诊断 → 练习 → 错题 → 家长 QQ 日报。本仓库为单人项目，包含产品文档、学生端 App 与发布工具链。

## 仓库结构

```
├─ 数学学习提升App开发文档.docx       # 开发依据（架构/数据/接口/阶段步骤）
├─ 高中数学教学能力体系分析报告.docx   # 能力模型与产品设计依据
├─ build_dev_doc.py / build_report.py # 两个文档的生成脚本（python-docx）
├─ math_up_app/                       # Flutter 学生端
├─ scripts/validate_content.py        # 章节树/题库一致性校验（发布前基线）
└─ CHANGELOG.md                       # 版本变更记录
```

## 快速开始

1. 阅读《数学学习提升 App 开发文档》第九部分（开发步骤），当前进行到阶段 3 前。
2. App 开发与测试命令见 `math_up_app/README.md`。
3. 每次发布前：更新 CHANGELOG → `python scripts\validate_content.py` → `flutter test`。

## 文档更新方式

两个 docx 由 Python 脚本生成，修改后重新执行：

```powershell
python build_report.py
python build_dev_doc.py
```

需要 `python-docx` 环境（本机已配置）。
