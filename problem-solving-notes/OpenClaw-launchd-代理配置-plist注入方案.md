# OpenClaw + Anthropic API 代理问题排查与解决

> **平台**: macOS (Apple Silicon M4) | **OpenClaw**: 2026.3.13 | **状态**: ✅ 已解决 | **时间**: 2026-04-06

---

## 问题背景

在中国大陆网络环境下，`api.anthropic.com` 无法直连，需要通过代理访问。
使用 ClashX 代理客户端，节点在美国，HTTP 代理端口为 `127.0.0.1:7890`。

---

## 问题一：curl 直连被拒

### 现象

```bash
curl https://api.anthropic.com/v1/messages ...
# 返回：{"error": {"type": "forbidden", "message": "Request not allowed"}}
```

### 原因

curl 默认不走系统代理，直连 Anthropic API 被地区限制拒绝。

### 解决

临时指定代理测试连通性：

```bash
curl -x http://127.0.0.1:7890 https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{"model": "claude-haiku-4-5-20251001", "max_tokens": 64, "messages": [{"role": "user", "content": "hi"}]}'
```

---

## 问题二：OpenClaw Web UI 切换 Anthropic 模型报 403

### 现象

在 Web Console 切换到 `anthropic/claude-sonnet-4-6` 时返回 403 Forbidden。

### 原因

OpenClaw gateway 作为独立进程运行，启动时没有注入代理环境变量，
访问 `api.anthropic.com` 走直连被拒。

### 排查过程

1. **尝试在 `openclaw.json` 的 `gateway` 块加 `proxy` 字段** → 报错 `Unrecognized key: "proxy"`，不支持
2. **尝试在 `anthropic` provider 块加 `proxy` 字段** → 同样不支持
3. **最终方案**：在 launchctl plist 的 `EnvironmentVariables` 中注入代理变量

---

## 解决方案：配置 launchctl plist

OpenClaw gateway 通过 launchctl 管理，plist 文件位于：

```
~/Library/LaunchAgents/ai.openclaw.gateway.plist
```

在 `EnvironmentVariables` 字典中添加代理变量（同时加小写和大写，确保兼容性）：

```bash
/usr/libexec/PlistBuddy -c "Add :EnvironmentVariables:https_proxy string http://127.0.0.1:7890" \
  ~/Library/LaunchAgents/ai.openclaw.gateway.plist

/usr/libexec/PlistBuddy -c "Add :EnvironmentVariables:http_proxy string http://127.0.0.1:7890" \
  ~/Library/LaunchAgents/ai.openclaw.gateway.plist

/usr/libexec/PlistBuddy -c "Add :EnvironmentVariables:HTTPS_PROXY string http://127.0.0.1:7890" \
  ~/Library/LaunchAgents/ai.openclaw.gateway.plist

/usr/libexec/PlistBuddy -c "Add :EnvironmentVariables:HTTP_PROXY string http://127.0.0.1:7890" \
  ~/Library/LaunchAgents/ai.openclaw.gateway.plist
```

重载服务生效：

```bash
launchctl unload ~/Library/LaunchAgents/ai.openclaw.gateway.plist
launchctl load ~/Library/LaunchAgents/ai.openclaw.gateway.plist
```

### 为什么选这个方案

| 方案 | 结果 |
|------|------|
| 全局设置 `~/.zshrc` 代理 | 影响所有终端请求，不够精准 |
| `openclaw.json` 加 `proxy` 字段 | 不支持，报配置错误 |
| ClashX 规则分流 | 配置文件会被订阅覆盖，维护成本高 |
| **plist `EnvironmentVariables` 注入** | ✅ 仅影响 gateway 进程，重启后持久生效 |

---

## 附：手动启动时临时注入代理

如果不通过 launchctl 而是手动启动 gateway，在命令前加环境变量：

```bash
https_proxy=http://127.0.0.1:7890 openclaw gateway run
```

---

## 相关配置文件位置

| 文件 | 路径 |
|------|------|
| OpenClaw 主配置 | `~/.openclaw/openclaw.json` |
| Gateway plist | `~/Library/LaunchAgents/ai.openclaw.gateway.plist` |
| Gateway 日志 | `~/.openclaw/logs/gateway.log` |
| Gateway 错误日志 | `~/.openclaw/logs/gateway.err.log` |

---

## 附：profile=user 调试模式（暂撐置）

**结论**：`profile=user`（通过 Chrome DevTools MCP 连接已登录的 Chrome）配置较复杂，暂不使用。

**实际方案**：统一使用 OpenClaw 自带的独立浏览器（`profile=openclaw` 或不指定 profile），需要登录的网站在 OpenClaw 浏览器里手动登录一次即可。

**原因**：
- `profile=user` 需要 Chrome 以 `--remote-debugging-port=9222` 启动，且需要在 `chrome://inspect/#remote-debugging` 手动开启授权
- 每次 Chrome 重启都需要重新配置
- OpenClaw 自带浏览器 cookie 持久化，登录状态可以保留，使用体验一致
