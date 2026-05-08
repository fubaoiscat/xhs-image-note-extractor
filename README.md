# xhs-image-note-extractor

从小红书分享页提取笔记信息与图片链接；当正文主要在图片中时，用本地 OCR 提取文字并做总结。

## 功能

- 解析 `window.__INITIAL_STATE__` 获取 `title`、`desc`、`imageList`
- 输出有序图片 URL（`IMG1...IMGN`）
- 使用本地 `tesseract` 进行 OCR（默认 `chi_sim+eng`）

## 环境要求

- 推荐 Node.js 22 LTS（最低 >= 18；可用安装脚本自动安装）
- 已安装 `tesseract` CLI（可用安装脚本自动安装）
- 语言包包含：`chi_sim`、`eng`

## 一键安装（开箱即用）

### macOS / Linux

```bash
curl -fsSL "https://raw.githubusercontent.com/fubaoiscat/xhs-image-note-extractor/main/scripts/install-skill.sh" | bash
```

默认会安装 **最新 release tag**。

### Windows PowerShell

```powershell
irm "https://raw.githubusercontent.com/fubaoiscat/xhs-image-note-extractor/main/scripts/install-skill.ps1" | iex
```

默认会安装 **最新 release tag**。

### 指定版本（推荐生产使用）

```bash
curl -fsSL "https://raw.githubusercontent.com/fubaoiscat/xhs-image-note-extractor/main/scripts/install-skill.sh" | \
  XHS_SKILL_REF=v0.1.0 bash
```

安装脚本会自动：

- 下载 skill 到 `~/.claude/skills/xhs-image-note-extractor`
- 优先安装 Node.js 22 LTS，并校验版本 >= 18
- 根据系统包管理器安装 `tesseract`
- 校验 `chi_sim` 与 `eng` 语言数据是否可用

## 快速开始

1) 抓取 H5 页面（建议用带 `xsec_token` 的完整分享链接）：

```bash
curl -sL \
  -A "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1" \
  -H "Accept-Language: zh-CN,zh;q=0.9" \
  "<XHS_SHARE_URL>" \
  -o /tmp/xhs-page.html
```

2) 解析页面：

```bash
node scripts/parse-xhs-page.mjs /tmp/xhs-page.html
```

3) OCR 单张图片：

```bash
node scripts/ocr-image.mjs /path/to/image.jpg
```

## 常见问题

- `noteData` 为空：通常是 token 过期或链接参数不完整，换最新分享链接重试。
- `tesseract CLI not found`：系统未安装或 PATH 不可见，先安装并执行 `tesseract --version` 验证。

## 说明

本仓库内的 `ocr-image.mjs` 是对系统 `tesseract` 的封装，不自带 OCR 引擎。
