# NotebookLM PDF2PPT

将 PDF 智能转换为可编辑 PPTX 的 macOS 客户端工具。

## 你能得到什么

- 保留原稿视觉风格：尽量还原 PDF 页面布局、字号、颜色与排版。
- 文本可编辑：输出的是可编辑文本框，不是纯截图拼贴。
- AI 去字修复：先去掉底图中的原始文字，再回填可编辑文本，减少重影。

## 下载 DMG

- Release 页面：`https://github.com/Raven7979/NotePDF2PPT/releases`
- 最终版（当前）：[`NotePDF2PPT_v1.1_b0.dmg`](https://github.com/Raven7979/NotePDF2PPT/releases/download/v1.1-b0/NotePDF2PPT_v1.1_b0.dmg)

## 源码运行（可选）

### 启动前端（Mac App）

1. 使用 Xcode 打开 `1. 前端最终版 v1.0/Mac_App_Project/PDFtoPPTX 1.2.xcodeproj`
2. 选择 `PDFtoPPTX` Scheme
3. Build & Run
4. 若首次启动被 macOS 拦截，请到“系统设置 -> 隐私与安全性”中点击“仍要打开”或“允许”，再重新启动 App。

## 使用注意

1. **网络环境**：请在稳定网络下使用，建议不要开启 VPN，避免请求链路不稳定导致上传/渲染失败。
2. **费用说明**：转换过程调用 NanoBanana-pro 云端渲染，会产生算力成本（通常以积分/额度方式计费）。
3. **AI 随机性**：AI 渲染存在一定“抽卡”波动；同一文件多次生成可能有细节差异。
4. **结果微调**：生成的 `.pptx` 在复杂版式场景下，仍可能需要手工微调（如对齐、换行、字号）。

## 安全与配置

- 本仓库不包含后端及密钥配置文件。

## 适用场景

- 课程讲义/研究文档转演示文稿
- 咨询汇报材料快速可编辑化
- 知识整理与二次演讲改写
