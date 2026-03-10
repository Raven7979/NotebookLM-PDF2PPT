# NotebookLM PDF2PPT

<p align="center">
  <a href="#中文说明">中文</a> |
  <a href="#english">English</a>
</p>

将 PDF 智能转换为可编辑 PPTX 的 macOS 客户端工具。

---

## 中文说明

### 你能得到什么

- 保留原稿视觉风格：尽量还原 PDF 页面布局、字号、颜色与排版。
- 文本可编辑：输出的是可编辑文本框，不是纯截图拼贴。
- AI 去字修复：先去掉底图中的原始文字，再回填可编辑文本，减少重影。

### 下载 DMG

- Release 页面：`https://github.com/Raven7979/NotebookLM-PDF2PPT/releases`
- 网站下载：https://ehotapp.xyz
- 最终版（当前）：MAC 版，文件下载：[NotePDF2PPT_v1.2.2_b122.dmg](https://raw.githubusercontent.com/Raven7979/NotebookLM-PDF2PPT/main/3.%20%E6%89%93%E5%8C%85%E8%BE%93%E5%87%BA%20v1.0/NotePDF2PPT_v1.2.2_b122.dmg)
- Win 版下载：[NotePDF2PPT_Setup_v1.0.1.exe](publish/NotePDF2PPT_Setup_v1.0.1.exe)

### 样板案例

下面是 3 组样板（输入 PDF 与输出 PPTX 对照），可直接点击下载查看。  
转出什么样就什么样，没有调整过。

| 样板 | 输入 PDF | 输出 PPTX |
| --- | --- | --- |
| Sample 1 | [`sample-1-input.pdf`](samples/sample-1-input.pdf) | [`sample-1-output.pptx`](samples/sample-1-output.pptx) |
| Sample 2 | [`sample-2-input.pdf`](samples/sample-2-input.pdf) | [`sample-2-output.pptx`](samples/sample-2-output.pptx) |
| Sample 3 | [`sample-3-input.pdf`](samples/sample-3-input.pdf) | [`sample-3-output.pptx`](samples/sample-3-output.pptx) |

### 源码运行（可选）

后续我会准备一个可以填入 API key 的源码包给大家，目前这里仅供参考。

#### 启动前端（Mac App）

1. 使用 Xcode 打开 `1. 前端最终版 v1.0/Mac_App_Project/PDFtoPPTX 1.2.xcodeproj`
2. 选择 `PDFtoPPTX` Scheme
3. Build & Run
4. 若首次启动被 macOS 拦截，请到“系统设置 -> 隐私与安全性”中点击“仍要打开”或“允许”，再重新启动 App。

### 使用注意

1. **网络环境**：请在稳定网络下使用，建议不要开启 VPN，避免请求链路不稳定导致上传或渲染失败。
2. **费用说明**：转换过程调用 NanoBanana-pro 云端渲染，会产生算力成本，通常以积分或额度方式计费。
3. **AI 随机性**：AI 渲染存在一定“抽卡”波动，同一文件多次生成可能有细节差异。
4. **结果微调**：生成的 `.pptx` 在复杂版式场景下，仍可能需要手工微调，如对齐、换行、字号，特殊字体也可能无法准确识别。

**欢迎入群讨论**

<p align="center">
  <img src="微信群.jpg" alt="微信群" width="360" />
  <img src="小红书群.jpg" alt="小红书群" width="300" />
</p>

<table align="center">
  <tr>
    <td align="center">微信群</td>
    <td align="center">小红书群</td>
  </tr>
</table>

### 安全与配置

- 本仓库不包含后端及密钥配置文件。

### 适用场景

- 课程讲义或研究文档转演示文稿
- 咨询汇报材料快速可编辑化
- 知识整理与二次演讲改写

---

## English

A macOS client that converts PDFs into editable PPTX files.

### What You Get

- Preserve the original visual style by restoring page layout, font sizes, colors, and typography as closely as possible.
- Editable text output instead of screenshot-based slide stitching.
- AI text removal and repair: remove original text from the background first, then refill editable text to reduce ghosting.

### Download DMG

- Releases: [GitHub Releases](https://github.com/Raven7979/NotebookLM-PDF2PPT/releases)
- Website: [ehotapp.xyz](https://ehotapp.xyz)
- Current macOS build: [NotePDF2PPT_v1.2.2_b122.dmg](https://raw.githubusercontent.com/Raven7979/NotebookLM-PDF2PPT/main/3.%20%E6%89%93%E5%8C%85%E8%BE%93%E5%87%BA%20v1.0/NotePDF2PPT_v1.2.2_b122.dmg)
- Windows download: [NotePDF2PPT_Setup_v1.0.1.exe](publish/NotePDF2PPT_Setup_v1.0.1.exe)

### Sample Cases

Here are three sample pairs of input PDFs and output PPTX files. You can click and download them directly.  
They are shown exactly as generated, without manual cleanup or adjustment.

| Sample | Input PDF | Output PPTX |
| --- | --- | --- |
| Sample 1 | [`sample-1-input.pdf`](samples/sample-1-input.pdf) | [`sample-1-output.pptx`](samples/sample-1-output.pptx) |
| Sample 2 | [`sample-2-input.pdf`](samples/sample-2-input.pdf) | [`sample-2-output.pptx`](samples/sample-2-output.pptx) |
| Sample 3 | [`sample-3-input.pdf`](samples/sample-3-input.pdf) | [`sample-3-output.pptx`](samples/sample-3-output.pptx) |

### Run from Source (Optional)

I plan to prepare a source package with API key configuration later. For now, this section is for reference only.

#### Start the Frontend (Mac App)

1. Open `1. 前端最终版 v1.0/Mac_App_Project/PDFtoPPTX 1.2.xcodeproj` in Xcode.
2. Select the `PDFtoPPTX` scheme.
3. Build and run.
4. If macOS blocks the app on first launch, go to `System Settings -> Privacy & Security`, click `Open Anyway` or allow it, then relaunch the app.

### Notes

1. **Network**: use a stable network connection. It is recommended not to enable a VPN, to avoid unstable upload or rendering requests.
2. **Cost**: the conversion pipeline uses NanoBanana-pro cloud rendering, which incurs compute cost and is typically billed through credits or quota.
3. **AI variability**: AI rendering has some randomness, so repeated runs on the same file may produce small differences.
4. **Manual adjustments**: for complex layouts, the generated `.pptx` may still need minor manual edits such as alignment, line breaks, font size, or font replacement.

**Join the community**

<p align="center">
  <img src="微信群.jpg" alt="WeChat Group" width="360" />
  <img src="小红书群.jpg" alt="Xiaohongshu Group" width="300" />
</p>

<table align="center">
  <tr>
    <td align="center">WeChat Group</td>
    <td align="center">Xiaohongshu Group</td>
  </tr>
</table>

### Security and Configuration

- This repository does not include backend services or secret configuration files.

### Use Cases

- Turn lecture notes or research documents into presentation decks
- Quickly make consulting or reporting materials editable
- Reorganize knowledge content and adapt it into new presentations
