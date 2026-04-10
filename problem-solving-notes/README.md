# OpenClaw 问题排查文档库

macOS 上安装和调试 OpenClaw 过程中遇到的问题记录与解决方案汇总。

**环境**：macOS (Apple Silicon M4) · OpenClaw 2026.3.13 / 2026.4.5 · LLM: DeepSeek / Anthropic Claude

---

## 文档索引

| 文档 | 问题类型 | 关键词 |
|------|---------|--------|
| [LLM 请求超时排查与解决](./OpenClaw-DeepSeek-LLM请求超时排查与解决.md) | 网络 / 配置 | `authHeader`、CA 证书、`auth-profiles.json`、401 |
| [DeepSeek API Key 替换流程与安全注意事项](./OpenClaw-DeepSeek-API-Key-替换流程与安全注意事项.md) | 安全 / 配置 | API key 轮换、多层级缓存、401、先验证后删除 |
| [Claude API Key 替换流程与安全注意事项](./OpenClaw-Claude-API-Key-替换流程与安全注意事项.md) | 安全 / 配置 | Anthropic key 轮换、代理验证、403 vs 401 |
| [Anthropic API 代理配置（plist 注入）](./OpenClaw-launchd-代理配置-plist注入方案.md) | 网络 / 代理 | 403、ClashX、launchd plist、`EnvironmentVariables` |
| [npm 全局安装问题排查](./OpenClaw-npm全局安装问题排查-EACCES-ENOTEMPTY-SSL证书.md) | 安装 / 升级 | `EACCES`、`ENOTEMPTY`、SSL 证书、sudo、Homebrew |
| [Ollama GPU 100% 占用排查与解决](./OpenClaw-Ollama-GPU占用排查与解决.md) | 资源 / 配置 | GPU 占用、LaunchAgent、Ollama 自动启动、models.json |

---

## 快速参考

### Gateway 常用命令

```bash
# 启动（launchctl，推荐）
launchctl load ~/Library/LaunchAgents/ai.openclaw.gateway.plist

# 停止
launchctl unload ~/Library/LaunchAgents/ai.openclaw.gateway.plist

# 重启
launchctl unload ~/Library/LaunchAgents/ai.openclaw.gateway.plist
launchctl load ~/Library/LaunchAgents/ai.openclaw.gateway.plist

# 从终端手动启动（需显式带 CA 证书变量）
NODE_EXTRA_CA_CERTS=/etc/ssl/cert.pem NODE_USE_SYSTEM_CA=1 openclaw gateway run --log-level debug

# 查看日志
tail -f ~/.openclaw/logs/gateway.log
tail -f ~/.openclaw/logs/gateway.err.log
```

### 关键配置文件

| 文件 | 用途 |
|------|------|
| `~/.openclaw/openclaw.json` | OpenClaw 主配置（providers、models） |
| `~/Library/LaunchAgents/ai.openclaw.gateway.plist` | Gateway 服务配置（环境变量注入） |
| `~/.openclaw/agents/main/agent/models.json` | Agent 模型缓存 |
| `~/.openclaw/agents/main/agent/auth-profiles.json` | API Key 认证缓存（优先级高于主配置） |
| `~/.zshrc` | Shell 环境变量（`NODE_EXTRA_CA_CERTS` 等） |

### 常见错误速查

| 错误 | 可能原因 | 参考文档 |
|------|---------|---------|
| `LLM request timed out` | 缺少 `authHeader: true` 或 CA 证书变量 | 超时排查 |
| `HTTP 401 Authentication Fails` | `auth-profiles.json` 未更新 | API Key 替换 / 超时排查 |
| `HTTP 403 Forbidden` | Gateway 缺少代理环境变量 | 代理配置 |
| `npm EACCES` | npm cache 有 root 遗留文件 | npm 安装排查 |
| `npm ENOTEMPTY` | 旧目录残留，无法原子替换 | npm 安装排查 |
| GPU 100% 占用 | OpenClaw 配置了 Ollama 本地模型 | Ollama GPU 排查 |

---

> 最后更新：2026-04-08
