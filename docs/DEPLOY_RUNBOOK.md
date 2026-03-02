# 部署操作手册 (DEPLOY_RUNBOOK)

本手册涵盖了从 0 到 1 部署 NotePDF 2 PPT 后端服务的完整流程。

---

## 1. 生产服务器初始化
**目标**: 安装系统级依赖（Python 3.12, Nginx, Supervisor）。

### 自动化执行
运行后端目录下的部署主脚本：
```bash
python3 run_setup.py
```
*注：需确保 `setup_server.sh` 位于同一目录。该脚本会执行：安装 Python 3.12、设置 Venv、配置 Nginx (80端口) 并安装 Supervisor。*

### 手动检查项 (Validation)
- 检查 Python 版本: `python3.12 --version`
- 检查 Nginx 状态: `systemctl status nginx`
- 检查 Supervisor 状态: `systemctl status supervisor`

---

## 2. 后端代码发布与更新
**目标**: 将最新代码同步并启动/重启服务。

### 发布步骤
1. **同步代码**: 使用 Git 或 SFTP 将 `2. 后端最终版 v1.0/API_Backend` 目录下的内容同步至服务器 `/var/www/note_pdf_to_ppt`。
2. **初始化环境**: 首次部署或依赖变更时运行：
   ```bash
   python3 run_finalize_v2.py
   ```
   该脚本会：创建 venv、安装 requirements、创建必要目录 (`uploads/`, `generated_pptx/`)、下发 Supervisor 配置。
3. **设置环境变量**: 确保服务器 `/var/www/note_pdf_to_ppt/.env` 已手动配置（参考 `.env.example`）。
4. **服务重启**:
   ```bash
   supervisorctl restart pdf_to_ppt
   ```

### 健康检查 (Health Check)
```bash
curl -I https://ehotapp.xyz/api/health
```
响应应为 `200 OK` 且包含 `{"status": "ok"}`。

---

## 3. 常见部署故障排查
- **413 Request Entity Too Large**: 运行 `python3 fix_nginx_413.py` 修复 Nginx 超大文件上传限制。
- **服务无法启动**: 检查日志 `/var/log/pdf_to_ppt.err.log`。通常是端口占用或 `.env` 缺失。
- **SSL 证书**: 目前使用 Nginx 反向代理配合 Certbot 维护。检查证书：`certbot certificates`。

---
版本: 1.0
更新日期: 2026-02-28
