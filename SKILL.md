---
name: xhs-image-note-extractor
description: >-
  从小红书 H5 笔记链接提取标题、正文线索与配图 URL，对「正文在图片里」的备忘录长图做 OCR 并输出结构化总结。
  当用户提供小红书 explore 链接并要求识别内容、总结、提炼观点，或提到 xhs-image-note-extractor、小红书图文提取、笔记 OCR 时使用。
  常规抓取若仅得到壳页面或「仅 APP 内查看」，应按本 skill 使用带 xsec_token 的分享 URL 与后续 OCR 流程。
---

# 小红书笔记：页面抓取 + 图片 OCR

## 目标

在**合规与用户授权**前提下，对单篇笔记：

1. 尽量从 H5 内嵌状态中取到 **标题、描述、有序图片 URL**。
2. 若描述为空或不足以支撑总结，对图片做 **OCR**（优先首图判定是否「图片正文型」）。
3. 按固定骨架输出：**判定、提取状态、内容总结、不确定性、来源**。

## 不触发（避免误用）

- 仅检查链接是否有效、不要正文。
- 仅要作者/标题等元信息、不要总结。
- 用户已提供完整文字稿，只需润色。
- 非小红书链接且用户未要求通用「图片 OCR + 总结」。

## 标准流程

### 1) 拉取 HTML

- 使用 **移动端 User-Agent**（如 iPhone Safari）与 `Accept-Language: zh-CN`。
- **优先使用用户提供的完整分享 URL**（含 `xsec_token`、`xsec_source` 等查询参数）。无 token 时经常出现「当前内容仅支持在小红书 APP 内查看」且 `noteData` 为空。
- 工具示例：`curl -sL -A "<mobile UA>" -H "Accept-Language: zh-CN,zh;q=0.9" "<url>"`

### 2) 解析 `window.__INITIAL_STATE__`

- 在 HTML 中定位 `window.__INITIAL_STATE__=` 到紧随其后的 `</script>` 之间的片段。
- 内联 JSON 中可能含 JavaScript 的 `undefined`，**不能直接 `JSON.parse`**。先做替换再解析：
  - `:undefined` → `:null`（后接 `,` `}` `]`）
  - `,undefined` → `,null`（同上）
- 笔记字段路径以 **当前 H5 为准**，常见为：

  `parsed.noteData.data.noteData`

  从中读取：`title`、`desc`、`type`、`imageList`。

- `imageList[i]` 的图片地址优先取 `url`，或 `infoList` 中 `imageScene` 为 `H5_DTL` 的项；下载时把 `http://` 改为 **`https://`**。

### 3) 首图 OCR 判定（再决定是否全量 OCR）

- 先只对 **第 1 张图** OCR。
- **强倾向「图片正文型」**：首图 OCR 汉字约 **≥120** 且至少 **3** 句完整句子；或出现「全文xxxx字」「阅读需x分钟」、备忘录长文样式；或网页 `desc` 空而图多张。
- **强倾向「非图片正文型」**：首图文字 **<40** 汉字且无连续段落，且 `desc`/可抓取正文已足够总结。
- **40–120** 汉字：结合 `desc` 与后续图数量保守判定。

判定为图片正文型后：对 **全部配图** 逐张 OCR，并保留 `IMG1…IMGN` 与页码对应关系。

- **临时文件清理规则（强制）**：OCR 完成后，删除本次流程下载到本地的临时图片（如 `.tmp-xhs/img*.jpg`）；只保留最终结构化结果与必要日志。若有失败页需复核，可在输出中注明并由用户确认后再保留该页。

### 4) OCR 实现建议

- 本 skill 采用：**纯 JS 脚本 + 系统 `tesseract` CLI**（`scripts/ocr-image.mjs`），默认语言 **`chi_sim+eng`**（简体 + 英文）。
- 该实现无 `npm install` 依赖，直接调用本地 `tesseract` 命令进行 OCR。
- 前置条件：系统已安装 `tesseract` 二进制及对应语言数据（至少 `chi_sim`、`eng`）。
- OCR 结果仅作「可见文本」依据：**不编造** OCR 未出现的事实；错字、专名错误需在「不确定性」中说明。

### 5) 输出模板（固定骨架）

1. **判定**：`该笔记主要内容在图片中` 或 `该笔记并非主要依赖图片承载正文`，附 1–2 条依据（首图密度、页面 `desc` 等）。
2. **提取状态**：图片总数、OCR 成功页数、缺页/低质量页。
3. **内容总结**：**5–8 条** 核心观点（主论点、论据、态度、建议等）。
4. **不确定性**：OCR 噪声、token 失效、结构变更对结论的影响。
5. **来源**：用户提供的原始链接（完整 URL）。

### 6) 质量闸门（交付前自检）

- 图片正文型时：图片数与 OCR 页数一致，或说明差异原因。
- 明确写出判定 + 依据；不编造未在 OCR/正文出现的信息。
- 总结与原文语义一致。
- 已执行临时文件清理：下载图片在 OCR 完成后已删除（或明确说明保留原因）。

### 7) 失败回退

- 若 `noteData` 为空或仅壳页：说明可能原因（**token 过期**、风控、仅 App 可见），并请求用户提供**带完整查询参数的分享链接**或**截图/本地图片**后继续 OCR。
- 若仅部分图下载失败：已确认信息 + 缺页说明 + 请用户补图。

### 8) 稳定性预期（对齐用户预期）

- **非生产级稳定**：`xsec_token` 会过期；H5 内嵌 JSON 路径可能随改版变化；OCR 对版式敏感。
- 自动化场景需：**重试、空数据检测、明确错误分类、降级**（换 OCR 引擎或人工校对）。

## 仓库内辅助脚本（可选）

解析已保存的 H5 HTML，打印标题、描述与图片 URL（无第三方依赖）：

```bash
node .claude/skills/xhs-image-note-extractor/scripts/parse-xhs-page.mjs /path/to/page.html
```

对本地图片 OCR（纯 JS 包装；依赖系统已安装 `tesseract`）：

```bash
node .claude/skills/xhs-image-note-extractor/scripts/ocr-image.mjs /path/to/image.jpg
```

完整 pipeline 仍为：**curl 抓页 → 上式或等效逻辑解析 → curl 下图为本地文件 → tesseract OCR**。

## 合规

- 仅处理用户**本人有权访问**的笔记或已获授权的内容；遵守平台服务条款与当地法律；不对抗风控或绕过鉴权作「批量爬取」用途指导。
