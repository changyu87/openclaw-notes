# OpenClaw Claude (Anthropic) API Key 替换流程与安全注意事项

> **平台**: macOS (Apple Silicon M4) | **OpenClaw**: 2026.4.5 | **状态**: ✅ 已解决 | **时间**: 2026-04-08

---

## 事件概述

**时间**: 2026年4月8日 22:08-22:35  
**问题**: 需要替换已暴露的 Anthropic Claude API key  
**风险**: 旧 key 已明文暴露，存在安全风险  
**处理**: 旧 key 已删除，新 key 已在各层级配置文件中更新

---

## Claude API Key 与 DeepSeek 的配置差异

Claude (Anthropic) 的配置方式与 DeepSeek **不同**，主要区别：

| 项目 | DeepSeek | Claude (Anthropic) |
|------|----------|--------------------|
| 环境变量名 | `DEEPSEEK_API_KEY` | `ANTHROPIC_API_KEY` |
| auth-profiles.json | 有缓存 (`deepseek:default`) | **无缓存**，直接从环境变量读取 |
| API 直连 | 可直连 | **需要代理**（中国大陆地区限制） |
| 平台控制台 | platform.deepseek.com | console.anthropic.com |

---

## 正确的替换流程

### 阶段 1: 创建新 Key

1. 登录 [console.anthropic.com/settings/keys](https://console.anthropic.com/settings/keys)
2. 点击 **Create key**，命名格式：`openclaw-YYYYMMDD`
3. 复制完整 key（只显示一次）
4. **不要立即删除旧 key**

### 阶段 2: 更新配置

Claude key 只存在于两处，比 DeepSeek 简单：

#### 2.1 更新环境变量 (`~/.zshrc`)

```bash
# 编辑 ~/.zshrc，更新以下行
export ANTHROPIC_API_KEY="sk-ant-api03-新key"
```

#### 2.2 更新 Launchd plist

```bash
/usr/libexec/PlistBuddy -c \
  "Set :EnvironmentVariables:ANTHROPIC_API_KEY sk-ant-api03-新key" \
  ~/Library/LaunchAgents/ai.openclaw.gateway.plist
```

> ⚠️ **注意**：直接用 Set 命令，避免手动编辑 plist 时意外删除其他字段（如代理配置）

#### 2.3 重载 Gateway

```bash
launchctl unload ~/Library/LaunchAgents/ai.openclaw.gateway.plist
launchctl load ~/Library/LaunchAgents/ai.openclaw.gateway.plist
```

### 阶段 3: 验证新 Key（⚠️ 必须通过代理测试）

Anthropic API 在中国大陆需要代理才能访问，测试时必须指定代理：

```bash
curl -x http://127.0.0.1:7890 -s -o /dev/null -w "%{http_code}\n" \
  -X POST https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{"model": "claude-haiku-4-5-20251001", "max_tokens": 10, "messages": [{"role": "user", "content": "hi"}]}'
```

预期返回：`200`

> ⚠️ **如果不指定 `-x http://127.0.0.1:7890`，返回 401 不代表 key 无效，只代表请求被拒绝（地区限制）。这个坑很容易踩！**

### 阶段 4: 确认 Gateway 正在使用代理

检查 plist 中代理环境变量是否完整（替换 key 时容易误删）：

```bash
cat ~/Library/LaunchAgents/ai.openclaw.gateway.plist | grep -A4 "https_proxy\|http_proxy\|HTTPS_PROXY\|HTTP_PROXY"
```

预期应看到 4 个代理变量，值均为 `http://127.0.0.1:7890`。

**如果代理变量丢失**，用以下命令恢复：

```bash
/usr/libexec/PlistBuddy -c "Add :EnvironmentVariables:https_proxy string http://127.0.0.1:7890" \
  ~/Library/LaunchAgents/ai.openclaw.gateway.plist 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Set :EnvironmentVariables:https_proxy http://127.0.0.1:7890" \
  ~/Library/LaunchAgents/ai.openclaw.gateway.plist

/usr/libexec/PlistBuddy -c "Add :EnvironmentVariables:http_proxy string http://127.0.0.1:7890" \
  ~/Library/LaunchAgents/ai.openclaw.gateway.plist 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Set :EnvironmentVariables:http_proxy http://127.0.0.1:7890" \
  ~/Library/LaunchAgents/ai.openclaw.gateway.plist

/usr/libexec/PlistBuddy -c "Add :EnvironmentVariables:HTTPS_PROXY string http://127.0.0.1:7890" \
  ~/Library/LaunchAgents/ai.openclaw.gateway.plist 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Set :EnvironmentVariables:HTTPS_PROXY http://127.0.0.1:7890" \
  ~/Library/LaunchAgents/ai.openclaw.gateway.plist

/usr/libexec/PlistBuddy -c "Add :EnvironmentVariables:HTTP_PROXY string http://127.0.0.1:7890" \
  ~/Library/LaunchAgents/ai.openclaw.gateway.plist 2>/dev/null || \
  /usr/libexec/PlistBuddy -c "Set :EnvironmentVariables:HTTP_PROXY http://127.0.0.1:7890" \
  ~/Library/LaunchAgents/ai.openclaw.gateway.plist
```

然后重启 Gateway：

```bash
launchctl unload ~/Library/LaunchAgents/ai.openclaw.gateway.plist
launchctl load ~/Library/LaunchAgents/ai.openclaw.gateway.plist
```

### 阶段 5: 在 OpenClaw 中切换并验证

切换到 Claude 模型，发一条测试消息，确认无报错。

### 阶段 6: 删除旧 Key

**仅在确认 Claude 模型完全可用后**：

1. 登录 [console.anthropic.com/settings/keys](https://console.anthropic.com/settings/keys)
2. 找到旧 key（按创建时间区分）
3. 点击右侧 **More actions** → **Delete API key**
4. 弹窗确认删除

> 注意：Console 页面的删除入口在每行右侧的 **More actions** 按钮里，不是直接暴露的按钮。

---

## 安全注意事项

### 1. 先验证再删除
**黄金规则**：新 key 100% 可用后，才删除旧 key。

### 2. 验证必须经过代理
Anthropic API 在国内需代理。验证时直连返回的 `401` 不等于 key 无效，一定要用 `-x http://127.0.0.1:7890` 指定代理测试。

### 3. 替换 plist 时小心代理配置
手动编辑 plist 或使用 PlistBuddy `Set` 命令替换 key 后，需要**确认代理变量是否完好**。代理丢失会导致 Claude 模型报 403 Forbidden，现象与 key 无效完全不同。

### 4. 403 vs 401 快速区分

| 错误码 | 含义 | 排查方向 |
|--------|------|----------|
| `401 authentication_error` | key 无效或未配置 | 检查 key 是否正确，plist / .zshrc 是否更新 |
| `403 forbidden` | 地区限制，请求被拒 | 检查代理配置是否完整，Gateway 是否携带代理启动 |

---

## 故障排除检查清单

### 切换 Claude 模型后报 403
1. [ ] 确认 ClashX 正在运行，代理端口 7890 可用
2. [ ] 检查 plist 中 4 个代理变量是否存在
3. [ ] 重载 Gateway（`launchctl unload/load`）

### 切换 Claude 模型后报 401
1. [ ] 确认 `ANTHROPIC_API_KEY` 已在 `~/.zshrc` 更新
2. [ ] 确认 `ANTHROPIC_API_KEY` 已在 plist `EnvironmentVariables` 更新
3. [ ] 确认 Gateway 已重启（PID 变化）
4. [ ] 用代理 curl 直接测试 key 是否有效

---

## 附录：相关文件路径

| 文件 | 路径 |
|------|------|
| Shell 环境变量 | `~/.zshrc` |
| Gateway plist | `~/Library/LaunchAgents/ai.openclaw.gateway.plist` |
| OpenClaw 主配置 | `~/.openclaw/openclaw.json` |
| Gateway 日志 | `~/.openclaw/logs/gateway.log` |
| Gateway 错误日志 | `~/.openclaw/logs/gateway.err.log` |
| Anthropic Console | `https://console.anthropic.com/settings/keys` |
