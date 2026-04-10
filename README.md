# 🐾 OpenClaw Troubleshooting Hub

> **The definitive collection of OpenClaw troubleshooting guides, scripts, and solutions for macOS users.**

[![OpenClaw](https://img.shields.io/badge/OpenClaw-2026.4.9-blue)](https://openclaw.ai)
[![macOS](https://img.shields.io/badge/macOS-Apple%20Silver-orange)](https://www.apple.com/macos)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Bilingual](https://img.shields.io/badge/内容-双语%20(Bilingual)-brightgreen)](README_zh.md)

**This repository** contains practical, battle-tested solutions for common OpenClaw issues—from installation errors and API key management to network proxy configurations and GPU optimization. Each guide includes step-by-step instructions, troubleshooting flows, and reusable scripts.

---

## 📚 Quick Navigation

| Issue Category | Document | Language |
|----------------|----------|----------|
| **🔐 API Key Management** | [DeepSeek API Key Rotation & Security](./problem-solving-notes/OpenClaw-DeepSeek-API-Key-替换流程与安全注意事项.md) | 中文 |
| | [DeepSeek API Key Rotation & Security (EN)](./problem-solving-notes/OpenClaw-DeepSeek-API-Key-Rotation-and-Security.en.md) | English |
| | [Claude API Key Rotation & Security](./problem-solving-notes/OpenClaw-Claude-API-Key-替换流程与安全注意事项.md) | 中文 |
| **🌐 Network & Proxy** | [LLM Request Timeout Troubleshooting](./problem-solving-notes/OpenClaw-DeepSeek-LLM请求超时排查与解决.md) | 中文 |
| | [LLM Request Timeout (EN)](./problem-solving-notes/OpenClaw-DeepSeek-LLM-Request-Timed-Out-Troubleshooting.en.md) | English |
| | [Anthropic API Proxy via launchd plist](./problem-solving-notes/OpenClaw-launchd-代理配置-plist注入方案.md) | 中文 |
| | [Anthropic API Proxy (EN)](./problem-solving-notes/OpenClaw-launchd-Proxy-Configuration-and-plist-Injection.en.md) | English |
| **🛠️ Installation & Upgrade** | [npm Global Installation Troubleshooting](./problem-solving-notes/OpenClaw-npm全局安装问题排查-EACCES-ENOTEMPTY-SSL证书.md) | 中文 |
| | [npm Global Installation (EN)](./problem-solving-notes/OpenClaw-npm-Global-Installation-Troubleshooting.en.md) | English |
| | [**Auto-upgrade Script**](./scripts/update-openclaw.sh) – One‑click OpenClaw upgrade | Bash |
| **⚡ Performance & GPU** | [Ollama GPU 100% Usage Troubleshooting](./problem-solving-notes/OpenClaw-Ollama-GPU占用排查与解决.md) | 中文 |
| | [Ollama GPU Usage (EN)](./problem-solving-notes/OpenClaw-Ollama-GPU-Usage-Troubleshooting.en.md) | English |

---

## 🚀 Featured Script: One‑Click OpenClaw Upgrade

The `scripts/update-openclaw.sh` script provides a **colorful, real‑time progress** upgrade experience:

```bash
# Make executable and run
chmod +x scripts/update-openclaw.sh
./scripts/update-openclaw.sh
```

**What it does:**
- Fixes npm cache permissions (EACCES)
- Stops & restarts the OpenClaw gateway service
- Cleans old installation directories (ENOTEMPTY)
- Installs the latest OpenClaw with `--progress --loglevel http` (live download feedback)
- Validates the version and prints a completion summary

**Features:**
- 🎨 **Colored output** with timestamps for each step
- 📊 **Real‑time npm progress** – see each package downloading
- ⏱️ **Total elapsed time** displayed at the end
- ✅ **Automatic validation** of the installed version

---

## 🎯 Who Is This For?

- **OpenClaw users on macOS** (especially Apple Silicon)
- **Developers** who self‑host LLM agents and need reliable operation
- **DevOps / SREs** managing local AI infrastructure
- **Anyone** struggling with OpenClaw installation, API keys, or network issues

---

## 🔍 How to Use This Repository

### 1. Browse by Problem
Check the [Problem‑Solving Notes](./problem-solving-notes/) directory for detailed, bilingual guides on specific issues.

### 2. Use the Upgrade Script
Keep your OpenClaw installation up‑to‑date with the automated script in `scripts/`.

### 3. Search Keywords
Common keywords in this repo:
- `EACCES`, `ENOTEMPTY` – npm installation errors
- `401`, `403` – API authentication failures  
- `LLM request timed out` – network/timeout issues
- `GPU 100%` – Ollama GPU utilization
- `launchd plist` – macOS service configuration
- `auth-profiles.json` – OpenClaw API key cache

---

## 📁 Repository Structure

```
openclaw/
├── problem-solving-notes/     # Bilingual troubleshooting guides
│   ├── *.md                   # Chinese documentation
│   └── *.en.md               # English counterparts
├── scripts/                   # Reusable automation scripts
│   └── update-openclaw.sh    # One‑click upgrade with progress
└── README.md                 # This file
```

All Chinese guides have English counterparts (same filename with `.en.md`).

---

## 🛡️ Security Note

**All API keys in this repository are placeholders** (`sk‑YOUR_KEY`, `sk‑ant‑api03‑新key`).  
No real credentials have ever been committed. If you find any actual keys, please report them immediately.

---

## 🤝 Contributing

Found a solution not listed here? Fixed a bug in a script?

1. **Fork** this repository
2. **Create** a new branch (`git checkout -b fix/your-fix`)
3. **Commit** your changes (`git commit -m 'Add fix for ...'`)
4. **Push** (`git push origin fix/your-fix`)
5. **Open a Pull Request**

Please keep documentation bilingual (Chinese + English) when possible.

---

## 📄 License

This repository is licensed under the **MIT License**.  
See the [LICENSE](LICENSE) file for details.

---

## ⭐ Support & Recognition

If this repository helped you solve an OpenClaw problem:

1. **Star** this repo on GitHub ⭐
2. **Share** it with others facing similar issues
3. **Contribute** your own solutions

---

**Maintained by** [Changyu Xu](https://github.com/changyu87) · **Last Updated:** 2026‑04‑10

*OpenClaw is an open‑source personal AI assistant platform. This repository is community‑maintained and not officially affiliated with the OpenClaw project.*