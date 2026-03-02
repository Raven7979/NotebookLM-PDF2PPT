# 运维与可观测性手册 (OPS_MONITORING)

本手册详细记录了系统的日志分布、监控指标以及常见事故的快速止血方案。

---

## 1. 日志位置总表 (Logs Inventory)

| 模块 | 位置 | 说明 |
| :--- | :--- | :--- |
| API Backend (StdOut) | `/var/log/pdf_to_ppt.out.log` | 访问日志、应用 `print` 数据 |
| API Backend (StdErr) | `/var/log/pdf_to_ppt.err.log` | Python 报错、Traceback、启动失败日志 |
| Nginx Access | `/var/log/nginx/access.log` | HTTP 请求流水 |
| Nginx Error | `/var/log/nginx/error.log` | 413、502、SSL 颗粒度错误 |
| Supervisor | `/var/log/supervisor/supervisord.log` | 进程管理自身日志 |

---

## 2. 基础监控指标 (Monitoring & Alerts)

| 指标 | 告警阈值 | 建议动作 |
| :--- | :--- | :--- |
| HTTP 5xx Rate | > 5% / 5min | 检查后端的 `err.log` 或 `nginx.log` |
| API Latency | > 30s (Convert) | 检查服务器 CPU 负载及 Nano API 响应 |
| Disk Usage | > 85% | 清理 `uploads/` 和 `generated_pptx/` 目录 |
| Memory Usage | > 90% | 重启服务 `supervisorctl restart pdf_to_ppt` |

---

## 3. 常见事故止血方案 (Runbook)

### A. 移动端/App 上传 413 错误
- **现象**: 用户上传转换文件时显示服务器错误，Nginx 日志显示 413。
- **止血**: 运行修复脚本 `python3 2.\ 后端最终版\ v1.0/API_Backend/fix_nginx_413.py`。

### B. 短信发送失败
- **现象**: 登录界面长时间拿不到验证码。
- **止血**: 检查 `aliyun_code` 表确保验证码已生成。若为 Aliyun 余额不足或 Key 失效，临时在 `routers/auth.py` 中将 `code == "888888"` 的权限下放给所有用户作为备用。

### C. 积分扣减异常 (Over-deduction)
- **现象**: 用户反馈积分扣多了，或转换失败仍扣费。
- **止血**: 在 `sql_app.db` 的 `users` 表上手动更正 `credits` 字段。
  ```bash
  sqlite3 sql_app.db "UPDATE users SET credits = credits + 10 WHERE phone_number = '138...';"
  ```

---
版本: 1.0
更新日期: 2026-02-28
