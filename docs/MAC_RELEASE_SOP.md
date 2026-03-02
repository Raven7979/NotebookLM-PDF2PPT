# Mac App 发布标准操作流程 (MAC_RELEASE_SOP)

本手册规定了从 Xcode 编译到生成 DMG、签名、公证并推送到生产更新后台的完整流程。

---

## 1. 编译与打包 (Build & Package)

### 环境准备
- 确保已选择正确的 **Team ID** 和 **Provisioning Profile**。
- 确保 `Info.plist` 中的 `CFBundleVersion (Build)` 已递增。

### 编译 Release 版本
为避免本地缓存干扰，必须执行以下命令：
```bash
xcodebuild -scheme PDFtoPPTX -project "PDFtoPPTX 1.2.xcodeproj" -configuration Release -derivedDataPath build_output clean build
```

### 生成 DMG
执行打包脚本：
```bash
bash package_b9.sh
```
*该脚本会将 `build_output` 里的产物封装，并包含静默安装所需的脚本。*

---

## 2. 签名与公证 (Sign & Notarize)
**重要**: 若不进行公证，用户在安装时会看到“无法验证开发者”的危险提示。

### 签名产物
```bash
codesign --force --options runtime --deep --sign "Developer ID Application: Your Name (TeamID)" "NotePDF2PPT_v1.0.2_b9.dmg"
```

### 提交公证
```bash
xcrun notarytool submit "NotePDF2PPT_v1.0.2_b9.dmg" --apple-id "your@email.com" --password "app-specific-password" --team-id "TeamID" --wait
```

### 嵌入公证票据 (Staple)
```bash
xcrun stapler staple "NotePDF2PPT_v1.0.2_b9.dmg"
```

---

## 3. 发布到后台 (Push to Backend)
**目标**: 更新 API 接口，触发客户端自动更新。

### 发布流程
1. 进入管理后台 (或其他方式) 调用 `POST /api/v1/misc/app/versions`。
2. 填写 `version` (1.0), `build` (9), `force_update` (true)。
3. 上传公证过的 `NotePDF2PPT_v1.0.2_b9.dmg`。
4. **校验**: 访问 `https://ehotapp.xyz/api/v1/misc/app/latest` 确认返回 Build 9。

---

## 4. 更新失败恢复 (Fallout Recovery)
- **运维侧**: 若 Build 9 有 Bug，立即在数据库中删除该记录或将 Build 8 重新标记为最新版。
- **用户侧**: 引导用户去应用官网重新下载 DMG 覆盖安装。

---
版本: 1.0
更新日期: 2026-02-28
