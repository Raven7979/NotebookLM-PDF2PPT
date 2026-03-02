# 密钥轮换与安全治理手册 (SECRETS_ROTATION_RUNBOOK)

本手册规定了系统密钥的轮换周期、泄漏后的处置方案以及安全加固措施。

---

## 1. 密钥泄漏处置方案 (Leak Disposal)
**现状**: 历史脚本 (`run_setup.py`, `sync_env.py` 等) 中曾硬编码服务器 SSH 密码。目前 `MIGRATION_SUMMARY.md` 中也留有密钥备份。

### 紧急响应步骤 (SOP)
1. **立即更改 SSH 密码**: `passwd root` 更改生产/准生产服务器密码。
2. **清理 Git 历史记录**: 使用 `bfg-repo-cleaner` 或 `git-filter-repo` 彻底从历史记录中擦除 `.env` 和敏感脚本。
   ```bash
   git filter-repo --path 2.\ 后端最终版\ v1.0/API_Backend/.env --invert-paths
   ```
3. **轮换第三方密钥**: 分别前往 Nano Banana、阿里云、虎皮椒后台生成新密钥。
4. **重新部署**: 更新服务器端 `.env` 并重启服务。

---

## 2. 密钥轮换周期表 (Rotation Schedule)
| 密钥类型 | 建议周期 | 操作入口 |
| :--- | :--- | :--- |
| SSH Password | 90 天 | 服务器 `passwd` |
| Nano API Key | 180 天 | https://nanobanana.pro/dashboard |
| Aliyun AccessKey| 180 天 | 阿里云 RAM 控制台 |
| Hupijiao Secret | 不定期 | 虎皮椒商户后台 |

---

## 3. 安全加固 (Hardening)
### A. 后端 API 鉴权加固
目前采用 `dummy-token`，建议尽快迁移到 **JWT (JSON Web Token)**。
- **任务**: 在 `routers/auth.py` 中引入 `python-jose`，并为 `misc` 路由增加 `Depends(get_current_active_superuser)` 校验。

### B. 仓库扫描自动化
建议在 CI 流程中加入 **Gitleaks** 扫描：
```bash
# 本地执行
gitleaks detect --source . -v
```

---
版本: 1.0
更新日期: 2026-02-28
