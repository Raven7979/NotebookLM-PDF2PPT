# NotePDF2PPT 迁移补漏清单（发给 Antigravity）

请基于当前仓库现状，按本清单补齐交接内容。目标是让新接手同学可以在不知道历史上下文的情况下，独立完成部署、发布、回滚和故障处理。

## 0) 输出要求

- 只补缺口，不重复已有内容。
- 每条必须包含：`现状` / `风险` / `修复步骤` / `验证命令` / `交付物路径`。
- 所有命令和路径必须可直接执行，不要写伪代码。

---

## 1) Security 与密钥治理（P0）

请补齐：

- 密钥泄露处置方案（当前文档和脚本中出现了真实密钥/密码）。
- 一份可提交到仓库的 `.env.example`（仅占位符，无真实值）。
- 生产密钥轮换 Runbook（Nano / 阿里云短信 / 支付 / SSH）。
- Git 历史与仓库扫描方案（例如 gitleaks/trufflehog）及执行结果记录模板。

重点核对文件（需在回复中逐一说明处理方式）：

- `MIGRATION_SUMMARY.md`
- `2. 后端最终版 v1.0/API_Backend/.env`
- `2. 后端最终版 v1.0/API_Backend/run_setup.py`
- `2. 后端最终版 v1.0/API_Backend/sync_env.py`
- `2. 后端最终版 v1.0/API_Backend/run_finalize_v2.py`
- `2. 后端最终版 v1.0/API_Backend/fix_nginx_413.py`

---

## 2) 文档与实际不一致修正（P0）

请补齐并修正：

- 数据库文件命名与路径（`database.db` vs `sql_app.db`）的唯一真相说明。
- 打包脚本路径说明（`/tmp/package_b9.sh` vs 仓库根目录 `package_b9.sh`）。
- 版本号/Build 对应关系的单一来源（防止口径冲突）。

要求：

- 给出最终统一口径。
- 给出对旧口径的兼容说明和迁移步骤。

---

## 3) 部署、回滚、备份 Runbook（P0）

请产出一份从 0 到上线再到回退的完整流程，至少覆盖：

- 新机器初始化（系统依赖、Python、Nginx、Supervisor）。
- 后端发布（代码同步、依赖安装、服务重启、健康检查）。
- 前端后台管理端发布（如有）。
- 数据库备份与恢复（执行前备份、恢复命令、校验方法）。
- 回滚触发条件与回滚脚本（例如错误率阈值、版本回退步骤）。

建议整合当前脚本：

- `2. 后端最终版 v1.0/API_Backend/setup_server.sh`
- `2. 后端最终版 v1.0/API_Backend/run_setup.py`
- `2. 后端最终版 v1.0/API_Backend/run_finalize_v2.py`
- `2. 后端最终版 v1.0/API_Backend/fix_nginx_413.py`
- `2. 后端最终版 v1.0/API_Backend/sync_env.py`

---

## 4) Mac 发布链路补齐（P1）

请补齐一套可执行的发布 SOP：

- App 签名流程（证书、权限、命令）。
- 公证流程（`notarytool`）、staple、校验命令。
- DMG 产物校验（哈希、可安装性、更新可用性）。
- 更新失败/安装失败恢复方案（用户侧和运维侧）。

重点关联：

- `package_b9.sh`
- `1. 前端最终版 v1.0/Mac_App_Project/PDFtoPPTX/Services/BackendAPIService.swift`

---

## 5) 后端鉴权与版本管理接口加固（P0）

请明确并补齐：

- `misc` 版本上传/删除接口当前未强鉴权的处理方案与时间表。
- 当前 `auth` 的临时策略（如 dummy token）如何迁移到正式 JWT/会话机制。
- 管理员权限边界（谁可上传版本、谁可删版本、审计日志如何记录）。

重点关联：

- `2. 后端最终版 v1.0/API_Backend/routers/misc.py`
- `2. 后端最终版 v1.0/API_Backend/routers/auth.py`

---

## 6) 可观测性与运维交接（P1）

请补齐：

- 日志位置总表（应用日志、Nginx、Supervisor）。
- 基础监控指标与告警阈值（错误率、延迟、CPU/内存、磁盘）。
- 常见事故 Runbook（上传 413、更新失败、积分扣减异常、短信发送失败）。

---

## 7) 交付物清单（必须给出）

请最终交付以下文件（可新建）：

- `docs/DEPLOY_RUNBOOK.md`
- `docs/ROLLBACK_RUNBOOK.md`
- `docs/SECRETS_ROTATION_RUNBOOK.md`
- `docs/MAC_RELEASE_SOP.md`
- `docs/OPS_MONITORING.md`
- `.env.example`

并在回复末尾附：

- 一条“5 分钟上线检查清单”（Checklist）
- 一条“故障 15 分钟止血清单”（Checklist）

---

## 8) 回复模板（请严格按此格式）

```md
### [条目名]
- 现状:
- 风险:
- 修复步骤:
  1.
  2.
  3.
- 验证命令:
  - `...`
  - `...`
- 交付物路径:
  - `...`
```
