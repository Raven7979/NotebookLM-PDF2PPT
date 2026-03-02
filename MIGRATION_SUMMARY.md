# NotePDF 2 PPT 开发与修改汇总报告 (Build 9)

本报告详细记录了近期针对 Mac App 的所有核心修改、后端配置变更以及自动化打包流程，旨在为后续的开发与维护提供完整的技术上下文。

---

## 1. 核心改进摘要
*   **版本号**: 1.0 (Build 9)
*   **状态**: 稳定。已解决所有已知的上传失败、API 报错以及静默更新问题。
*   **架构转变**: 从“本地 + 云端”混合模式全面转为**“纯云端转换模式”**。所有转换逻辑均须登录后通过服务器接口完成。

---

## 2. 后端 (Server-side) 修改记录

### Nginx 配置优化
*   **问题**: 之前上传 Build 6/7 的 DMG 时报错，原因是 Nginx 默认 `client_max_body_size` 过小。
*   **修改**: 将 `/etc/nginx/nginx.conf` 中的 `client_max_body_size` 提升至 `100M`。
*   **生效**: 已通过 `nginx -s reload` 生效。

### 数据库变更
*   **表**: `app_versions`
*   **修改**: 移除了 `version` 字段的 `UNIQUE` 唯一约束。
*   **原因**: 允许同一个版本号（如 v1.0.2）对应多个不同的 Build 构建（如 b8, b9...），便于精细化热更新管理。

### API 接口增强
*   提供了 `/api/v1/mac/inpaint` 并行图片处理接口，支持 Mac 客户端的高频并发请求。

---

## 3. 前端 App (Swift) 修改记录

### `ConversionViewModel.swift` (核心逻辑)
*   **逻辑重构**: 彻底删除了对 `NanoBananaProService` 的本地调用和 `fallback` 逻辑。
*   **强制上云**: 移除了界面上的“配置 API Key”黄色警告提示。
*   **流程优化**: 将文件处理流程简化为：预检查(含登录/积分) -> 页面切片 -> **并行请求云端 Inpaint** -> 本地 PPTX 合成。

### `ContentView.swift` (交互与 UI)
*   **安全加固**: 在“拖拽文件”和“点击选择文件”两个入口均加入了 `isLoggedIn` 强制校验，未登录会直接弹出登录框。
*   **清理**: 删除了所有过时的 `apiWarningText` 云端/本地切换提示。

### `UpdateService` (自动更新机制 - **重大重构**)
*   **静默下载**: 废弃了跳转浏览器的模式。改为使用 `URLSession` 在后台静默下载 `.dmg` 文件。
*   **自动重启安装**: 只要用户点“立即安装”，App 将会：
    1. 生成并执行一个 bash 脚本 (`install_update.sh`)。
    2. 静默挂载新版 DMG。
    3. 自动覆盖 `/Applications` 下的旧版二进制文件。
    4. 自动清除缓存并重新唤起新版 App。

---

## 4. 关键脚本与工具维护

### `package_b9.sh` 打包脚本
*   **路径校准**: 修正了从错误的 `DerivedData` 拷贝文件的 Bug。
*   **路径**: `/tmp/package_b9.sh`
*   **功能**: 自动生成符合 Release 规范的、带挂载背景和自动替换脚本的 DMG 安装包。

### 编译指令 (避免缓存问题)
为了确保每次打包都包含最新的代码，务必使用以下指令进行编译：
```bash
xcodebuild -scheme PDFtoPPTX -project "PDFtoPPTX 1.2.xcodeproj" -configuration Release -derivedDataPath build_output clean build
```

---

## 5. 后续接手注意事项
1.  **积分检查**: App 目前在后端进行真实的积分扣除，前端仅做 UI 层的预判 (`getCredits`)。
2.  **证书签名**: 目前 DMG 尚未进行 Apple 公证 (Notarization)，在非开发者机器上安装可能需要用户在“系统设置 -> 隐私与安全性”中手动允许。
3.  **日志调试**: 如果遇到新的上传/更新问题，可以在 Xcode Console 中观察 `[UpdateService]` 或 `[ConversionViewModel]` 的相关 `print` 输出。

---
## 6. 沟通与开发里程碑 (Milestones)

这里总结了我们合作解决的几个关键阶段，方便接手者了解业务背景：

1.  **阶段一：解决上传与部署障碍**
    *   通过调整 Nginx `client_max_body_size` 解决了大文件（DMG）上传 413 错误。
    *   移除了数据库版本唯一约束，支持多 Build 发布。

2.  **阶段二：App 纯云端化重构 (彻底解决 API Key 报错)**
    *   背景：用户在没有本地 Nano 密钥时会报错。
    *   方案：移除了所有本地 API 配置，强制走后端并行 Inpaint 接口。
    *   结果：任何电脑安装 Build 8+ 都不再需要手动配置，只需登录即可使用。

3.  **阶段三：实现无感静默更新**
    *   背景：之前的更新模式需要用户跳转浏览器手动下载挂载，体验断层。
    *   方案：引入 `UpdateService` 后台下载 + Shell 脚本静默替换重启。
    *   结果：实现了类似 Chrome/VSCode 的一键平滑重启升级体验。

4.  **阶段四：Build 8/9 的路径与缓存修正**
    *   背景：出现“改了代码但包里没生效”的灵异现象。
    *   方案：定位到 Xcode 编译目录不一致问题，通过 `clean Release build` 彻底根除。

---
## 7. 关键环境变量与机密信息治理 (Security & Secrets)

**重要**: 由于项目中曾出现硬编码密钥，我们已经执行了全系统的“脱敏”治理。

### 交付物
- **`.env.example`**: 后端根目录下提供了完整的占位符模板。迁移后请根据此模板填充生产密钥。
- **`docs/SECRETS_ROTATION_RUNBOOK.md`**: 详细记录了密钥泄漏后的处置 SOP 及定期轮换方案。

---
## 8. 辅助运维工具与归口 (Maintenance & Tools)

- **数据库真相**: 后端代码统一使用 **`sql_app.db`**。请忽略旧文档中的 `database.db` 描述。
- **打包归口**: 最新打包脚本为仓库根目录下的 `package_b9.sh`。它已经过修复，不再使用 Debug 缓存。
- **运维脚本**: 已修复所有位于 `API_Backend` 下的 `.py` 脚本，移除硬编码密码，改为支持环境变量读取。

---
报告生成日期: 2026-02-28
状态: 交付 Build 9 (OpenCode 补缺版)
