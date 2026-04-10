# OpenClaw + DeepSeek on macOS：LLM 请求超时问题排查与解决

> **平台**: macOS (Apple Silicon M4) | **OpenClaw**: 2026.3.13 | **LLM**: DeepSeek (`deepseek-chat`)
> **状态**: ✅ 已解决 | **时间**: 2026-04-02

---

## 问题表现

通过 OpenClaw Web UI 发送的每条消息都会触发重复超时错误：

```
[agent/embedded] embedded run agent end: isError=true model=deepseek-chat provider=deepseek error=LLM request timed out.
[agent/embedded] embedded run failover decision: stage=assistant decision=surface_error reason=timeout
```

Agent 在约 20 秒内重试 4 次后将错误显示给用户。而直接用 `curl` 调用 DeepSeek API 完全正常（响应约 2–3 秒）。

---

## 背景：Gateway 的两种启动方式

macOS 上 OpenClaw gateway 有两种启动方式，在环境变量加载上行为不同，这是理解后续问题的基础。

### 方式一：终端手动启动

```bash
NODE_EXTRA_CA_CERTS=/etc/ssl/cert.pem NODE_USE_SYSTEM_CA=1 openclaw gateway run --log-level debug
```

`NODE_EXTRA_CA_CERTS` 和 `NODE_USE_SYSTEM_CA` 是终端启动时**必须**显式传入的环境变量，否则 TLS 证书处理方式与 launchctl 环境不一致，导致请求超时。

为避免每次手动输入，永久写入 `~/.zshrc`：

```zsh
# OpenClaw 环境变量
export NODE_EXTRA_CA_CERTS=/etc/ssl/cert.pem
export NODE_USE_SYSTEM_CA=1

# OpenClaw 自动补全（必须在 compinit 之后）
autoload -Uz compinit && compinit
source "/Users/YOUR_USERNAME/.openclaw/completions/openclaw.zsh"
```

> **注意**：不要在 `.zshrc` 内部用 `echo 'export ...' >> ~/.zshrc`，否则每次启动 shell 都会往文件里追加一行。

### 方式二：launchctl 后台服务（推荐）

OpenClaw 安装时会在以下位置创建 launchd plist：

```
~/Library/LaunchAgents/ai.openclaw.gateway.plist
```

该 plist 的 `EnvironmentVariables` 块中已内置 `NODE_EXTRA_CA_CERTS` 和 `NODE_USE_SYSTEM_CA`，因此此方式开箱即用。

```bash
# 启动
launchctl load ~/Library/LaunchAgents/ai.openclaw.gateway.plist

# 停止
launchctl unload ~/Library/LaunchAgents/ai.openclaw.gateway.plist

# 重启
launchctl unload ~/Library/LaunchAgents/ai.openclaw.gateway.plist
launchctl load ~/Library/LaunchAgents/ai.openclaw.gateway.plist
```

日志位置：

```
~/.openclaw/logs/gateway.log
~/.openclaw/logs/gateway.err.log
```

---

## 根本原因与修复方案

本次问题由四个相互叠加的根本原因导致，按发现顺序列出。

### 原因一：Provider 配置缺少 `authHeader: true`

缺少此字段时，OpenClaw 无法正确将 `Authorization: Bearer <api_key>` 请求头附加到出站请求，导致：

- TLS 握手成功完成
- 仅传输约 1609 字节（不完整的未认证请求）
- 连接立即以 `FIN` 关闭，服务端未返回任何数据
- OpenClaw 将"无流式响应"判断为超时

通过 `tcpdump` 抓包确认：客户端在初始握手后立即发送 `[F.]`（FIN），服务端无响应数据。

**修复**：在 `~/.openclaw/openclaw.json` 的 DeepSeek provider 块中添加 `"authHeader": true`：

```json
"models": {
  "providers": {
    "deepseek": {
      "baseUrl": "https://api.deepseek.com/v1",
      "apiKey": "sk-YOUR_API_KEY_HERE",
      "api": "openai-completions",
      "authHeader": true,
      "models": [
        {
          "id": "deepseek-chat",
          "name": "DeepSeek-V4",
          "contextWindow": 128000
        },
        {
          "id": "deepseek-reasoner",
          "name": "DeepSeek-R1",
          "contextWindow": 128000
        }
      ]
    }
  }
}
```

---

### 原因二：Agent 缓存文件中存有旧 API Key

轮换 API Key 后，launchctl 启动的 gateway 返回 `HTTP 401: Authentication Fails`。原因是 OpenClaw 将 provider 配置缓存在 **独立于 `openclaw.json`** 的 agent 专属文件中，必须单独更新。

可能含有旧 key 的文件：

```
~/.openclaw/agents/main/agent/models.json
~/.openclaw/agents/main/agent/auth-profiles.json
~/.openclaw/agents/main/sessions/sessions.json
~/.openclaw/agents/main/sessions/<session-id>.jsonl
~/.openclaw/openclaw.json.bak
```

**修复**：批量替换旧 key，然后重启 gateway：

```bash
OLD_KEY="sk-YOUR_OLD_KEY"
NEW_KEY="sk-YOUR_NEW_KEY"

sed -i.bak "s/$OLD_KEY/$NEW_KEY/g" ~/.openclaw/agents/main/agent/models.json
sed -i.bak "s/$OLD_KEY/$NEW_KEY/g" ~/.openclaw/agents/main/agent/auth-profiles.json
sed -i.bak "s/$OLD_KEY/$NEW_KEY/g" ~/.openclaw/agents/main/sessions/sessions.json
```

---

### 原因三：`auth-profiles.json` 缺少 `deepseek:default` 条目

`~/.openclaw/agents/main/agent/auth-profiles.json` 中只有 `openai:default`，没有 `deepseek:default`。即使 `openclaw.json` 中的 key 正确，终端启动的 gateway 也无法通过 DeepSeek 认证。

**修复**：编辑 `auth-profiles.json`，补充 DeepSeek 条目：

```json
{
  "version": 1,
  "profiles": {
    "openai:default": {
      "type": "api_key",
      "provider": "openai",
      "key": "sk-YOUR_OPENAI_KEY"
    },
    "deepseek:default": {
      "type": "api_key",
      "provider": "deepseek",
      "key": "sk-YOUR_DEEPSEEK_KEY"
    }
  },
  "usageStats": {
    "openai:default": { "errorCount": 0, "lastUsed": 0 },
    "deepseek:default": { "errorCount": 0, "lastUsed": 0 }
  }
}
```

---

### 原因四：终端启动时缺少 CA 证书环境变量

即使所有配置均正确，终端启动的 gateway 仍会超时——因为缺少 launchctl plist 自动提供的系统 CA 证书环境变量。

**修复**：终端启动前设置（或写入 `~/.zshrc` 永久生效）：

```bash
export NODE_EXTRA_CA_CERTS=/etc/ssl/cert.pem
export NODE_USE_SYSTEM_CA=1
```

---

## 无效方案记录

以下方法均经过验证，无法解决问题：

| 尝试方案 | 结果 |
|---------|------|
| 将 `baseUrl` 从 `https://api.deepseek.com` 改为 `https://api.deepseek.com/v1` | 无效 |
| `NODE_OPTIONS="--dns-result-order=ipv4first"` | 可排除 IPv6 问题，但不解决超时 |
| provider 配置中加 `"timeout"` 字段 | 不支持，`openclaw doctor` 会自动删除 |
| 设置 `LLM_REQUEST_TIMEOUT` 环境变量 | 无效，不能解决底层连接问题 |
| provider 配置中加 `"stream": false` | 不支持，会导致配置错误 |
| 清空 session 文件（`> session.jsonl`） | 可排除会话历史损坏，但不解决超时 |

---

## 诊断命令速查

```bash
# 查找所有含 API key 的配置文件
find ~/.openclaw -type f | xargs grep -l "sk-" 2>/dev/null

# 验证当前生效的 key
openclaw config get models.providers.deepseek.apiKey

# 直接测试流式请求（绕过 OpenClaw，验证 API 本身是否正常）
curl -v -X POST https://api.deepseek.com/v1/chat/completions \
  -H "Authorization: Bearer sk-YOUR_KEY" \
  -H "Content-Type: application/json" \
  -H "Accept: text/event-stream" \
  -d '{"model":"deepseek-chat","messages":[{"role":"user","content":"hi"}],"stream":true,"max_tokens":50}'

# 抓包监控到 DeepSeek 的实际 TCP 流量
sudo tcpdump -i any host api.deepseek.com -n

# 通过 CLI 调大 agent 超时时间（不能在 JSON 中设置）
openclaw config set agents.defaults.timeoutSeconds 600
```

---

## 安全提示

如果 API key 曾被泄露（如粘贴到聊天记录、日志或共享文档），请立即在 [DeepSeek API 控制台](https://platform.deepseek.com) 中轮换，并按原因二中的步骤更新所有缓存文件。轮换后旧 key 视为已失效，无论使用场景如何。
