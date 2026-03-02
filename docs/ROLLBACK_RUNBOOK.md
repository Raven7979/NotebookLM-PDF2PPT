# 回滚操作手册 (ROLLBACK_RUNBOOK)

当生产环境出现严重 Bug、崩溃或性能骤降时，应执行本回滚方案。

---

## 1. 触发条件
- 转换成功率低于 50%
- 多用户报告无法登录 (Aliyun SMS 故障)
- 服务器内存/CPU 持续 100%
- 数据库损坏

---

## 2. 后端代码回滚
**目标**: 将代码恢复到上一稳定 Git 提交。

### 执行步骤
1. **获取稳定版本**: `git checkout v1.0.2_stable` (或对应的 Git Hash)。
2. **清除环境缓存**: `rm -rf venv/` && `python3 -m venv venv`。
3. **重新安装依赖**: `venv/bin/pip install -r requirements.txt`。
4. **服务重启**: `supervisorctl restart pdf_to_ppt`。

### 校验
```bash
supervisorctl status pdf_to_ppt
```

---

## 3. 数据库紧急恢复 (DR)
**目标**: 将 `sql_app.db` 恢复到最近一次备份。

### 执行步骤
1. **停止服务**: `supervisorctl stop pdf_to_ppt`。
2. **备份当前损坏 DB**: `cp sql_app.db sql_app.db.corrupted_$(date +%F)`。
3. **恢复备份**: `cp backups/sql_app.db.last_good sql_app.db`。
4. **验证 DB 完整性**: `sqlite3 sql_app.db "PRAGMA integrity_check;"` (预期应返回 `ok`)。
5. **启动服务**: `supervisorctl start pdf_to_ppt`。

---

## 4. Mac App 版核回退
**目标**: 将自动更新推送的版本回降。

### 执行步骤
1. **删除有 Bug 的版本**:
   ```bash
   # 手动调用接口或直接进 DB
   python3 -c "import sqlite3; conn=sqlite3.connect('sql_app.db'); conn.execute('DELETE FROM app_versions WHERE build=9'); conn.commit()"
   ```
2. **确认最新版本**: 访问 `https://ehotapp.xyz/api/v1/misc/app/latest` 确认返还的版本为修订前的稳定 Build（例如 Build 7）。
3. **通知用户**: 通过站内消息（如有）建议用户手动点“检查更新”或重新下载安装。

---
版本: 1.0
更新日期: 2026-02-28
