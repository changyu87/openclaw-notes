# 🐾 OpenClaw 故障排查中心

> **OpenClaw 故障排查指南、脚本和解决方案的权威合集，专为 macOS 用户打造。**

[![OpenClaw](https://img.shields.io/badge/OpenClaw-2026.4.9-blue)](https://openclaw.ai)
[![macOS](https://img.shields.io/badge/macOS-Apple%20Silver-orange)](https://www.apple.com/macos)
[![License: MIT](https://img.shields.io/badge/许可证-MIT-yellow.svg)](LICENSE)
[![双语](https://img.shields.io/badge/Content-双语%20(Bilingual)-brightgreen)](README.md)

**本仓库**收录了经过实战检验的 OpenClaw 常见问题解决方案——从安装错误、API 密钥管理到网络代理配置和 GPU 优化。每篇指南都包含分步说明、排查流程图和可复用的脚本。

---

## 📚 快速导航

| 问题类别 | 文档 | 语言 |
|----------------|----------|----------|
| **🔐 API 密钥管理** | [DeepSeek API 密钥轮换与安全](./problem-solving-notes/OpenClaw-DeepSeek-API-Key-替换流程与安全注意事项.md) | 中文 |
| | [DeepSeek API 密钥轮换与安全（英文）](./problem-solving-notes/OpenClaw-DeepSeek-API-Key-Rotation-and-Security.en.md) | English |
| | [Claude API 密钥轮换与安全](./problem-solving-notes/OpenClaw-Claude-API-Key-替换流程与安全注意事项.md) | 中文 |
| **🌐 网络与代理** | [LLM 请求超时排查与解决](./problem-solving-notes/OpenClaw-DeepSeek-LLM请求超时排查与解决.md) | 中文 |
| | [LLM 请求超时排查（英文）](./problem-solving-notes/OpenClaw-DeepSeek-LLM-Request-Timed-Out-Troubleshooting.en.md) | English |
| | [Anthropic API 代理配置（plist 注入）](./problem-solving-notes/OpenClaw-launchd-代理配置-plist注入方案.md) | 中文 |
| | [Anthropic API 代理配置（英文）](./problem-solving-notes/OpenClaw-launchd-Proxy-Configuration-and-plist-Injection.en.md) | English |
| **🛠️ 安装与升级** | [npm 全局安装问题排查](./problem-solving-notes/OpenClaw-npm全局安装问题排查-EACCES-ENOTEMPTY-SSL证书.md) | 中文 |
| | [npm 全局安装问题排查（英文）](./problem-solving-notes/OpenClaw-npm-Global-Installation-Troubleshooting.en.md) | English |
| | [**自动升级脚本**](./scripts/update-openclaw.sh) – 一键升级 OpenClaw | Bash |
| **⚡ 性能与 GPU** | [Ollama GPU 100% 占用排查与解决](./problem-solving-notes/OpenClaw-Ollama-GPU占用排查与解决.md) | 中文 |
| | [Ollama GPU 占用排查（英文）](./problem-solving-notes/OpenClaw-Ollama-GPU-Usage-Troubleshooting.en.md) | English |

---

## 🚀 特色脚本：一键升级 OpenClaw

`scripts/update-openclaw.sh` 脚本提供 **彩色、实时进度显示** 的升级体验：

```bash
# 设为可执行并运行
chmod +x scripts/update-openclaw.sh
./scripts/update-openclaw.sh
```

**功能包括：**
- 修复 npm cache 权限（EACCES）
- 停止并重启 OpenClaw gateway 服务
- 清理旧安装目录（ENOTEMPTY）
- 使用 `--progress --loglevel http` 安装最新 OpenClaw（实时下载反馈）
- 验证版本并打印完成摘要

**特点：**
- 🎨 **彩色输出**，每个步骤带时间戳
- 📊 **实时 npm 进度** – 查看每个包的下载过程
- ⏱️ **显示总耗时**
- ✅ **自动验证** 安装版本

---

## 🎯 目标用户

- **macOS 上的 OpenClaw 用户**（特别是 Apple Silicon）
- **自托管 LLM 代理的开发者**，需要稳定运行
- **管理本地 AI 基础设施的 DevOps / SRE**
- **遇到 OpenClaw 安装、API 密钥或网络问题的任何人**

---

## 🔍 如何使用本仓库

### 1. 按问题浏览
查看 [故障排查笔记](./problem-solving-notes/) 目录，了解具体问题的详细双语指南。

### 2. 使用升级脚本
使用 `scripts/` 中的自动化脚本保持 OpenClaw 安装最新。

### 3. 搜索关键词
本仓库常见关键词：
- `EACCES`、`ENOTEMPTY` – npm 安装错误
- `401`、`403` – API 认证失败
- `LLM request timed out` – 网络/超时问题
- `GPU 100%` – Ollama GPU 占用
- `launchd plist` – macOS 服务配置
- `auth-profiles.json` – OpenClaw API 密钥缓存

---

## 📁 仓库结构

```
openclaw/
├── problem-solving-notes/     # 双语故障排查指南
│   ├── *.md                   # 中文文档
│   └── *.en.md               # 英文对应文档
├── scripts/                   # 可复用自动化脚本
│   └── update-openclaw.sh    # 带进度显示的一键升级脚本
└── README.md                 # 本文件（英文）
└── README_zh.md             # 中文说明
```

所有中文指南都有英文对应版本（相同文件名加上 `.en.md`）。

---

## 🛡️ 安全声明

**本仓库中所有 API 密钥均为占位符**（`sk‑YOUR_KEY`、`sk‑ant‑api03‑新key`）。  
从未提交过真实凭证。如发现任何真实密钥，请立即报告。

---

## 🤝 贡献指南

发现未列出的解决方案？修复了脚本中的 bug？

1. **Fork** 本仓库
2. **创建** 新分支（`git checkout -b fix/your-fix`）
3. **提交** 更改（`git commit -m '修复...'`）
4. **推送**（`git push origin fix/your-fix`）
5. **创建 Pull Request**

请尽量保持文档双语（中文 + 英文）。

---

## 📄 许可证

本仓库采用 **MIT 许可证**。  
详见 [LICENSE](LICENSE) 文件。

---

## ⭐ 支持与认可

如果本仓库帮助您解决了 OpenClaw 问题：

1. **给仓库点星** ⭐
2. **分享** 给遇到类似问题的其他人
3. **贡献** 您自己的解决方案

---

**维护者**：[徐长宇 (Changyu Xu)](https://github.com/changyu87) · **最后更新：** 2026‑04‑10

*OpenClaw 是一个开源个人 AI 助手平台。本仓库由社区维护，与 OpenClaw 项目无官方关联。*