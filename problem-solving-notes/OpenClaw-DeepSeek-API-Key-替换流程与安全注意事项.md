# OpenClaw DeepSeek API Key 替换流程与安全注意事项

> **平台**: macOS (Apple Silicon M4) | **OpenClaw**: 2026.3.13 | **状态**: ✅ 已解决 | **时间**: 2026-04-06

---

## 事件概述
**时间**: 2026年4月6日 17:38-18:04
**问题**: 需要替换已暴露的 DeepSeek API key
**风险**: 旧 key 已明文暴露，存在安全风险
**处理**: 旧 key 已删除，新 key 已在各层级配置文件中更新

## 问题诊断过程

### 1. 初始错误：直接删除旧 key
**错误操作**: 在浏览器中创建新 key 后，立即删除了旧 key，未验证新 key 是否可用  
**风险**: 如果新 key 配置失败，OpenClaw 将完全失去可用模型，用户无法调试

### 2. 配置层级的复杂性
OpenClaw 的 API key 管理涉及多个层级，需要全部更新：

#### 层级 1: 环境变量 (`.zshrc`)
```bash
# 旧（已删除）
export DEEPSEEK_API_KEY="sk-YOUR_OLD_API_KEY"

# 新
export DEEPSEEK_API_KEY="sk-YOUR_NEW_API_KEY"
```

#### 层级 2: Launchd 服务配置 (`~/Library/LaunchAgents/ai.openclaw.gateway.plist`)
```xml
<key>EnvironmentVariables</key>
<dict>
    <!-- ... 其他环境变量 ... -->
    <key>DEEPSEEK_API_KEY</key>
    <string>sk-YOUR_NEW_API_KEY</string>
</dict>
```

**注意**: plist 中存在 HTTP 代理设置（`http_proxy`、`https_proxy` 等），**不要移除这些变量**，这是 Claude (Anthropic) 模型正常工作所必需的（国内直连 `api.anthropic.com` 会被地区限制拒绝）。替换 key 时只更新 `DEEPSEEK_API_KEY` 字段，代理变量保持不变。

#### 层级 3: OpenClaw 认证缓存 (`~/.openclaw/agents/main/agent/auth-profiles.json`)
```json
{
  "deepseek:default": {
    "type": "api_key",
    "provider": "deepseek",
    "key": "sk-YOUR_NEW_API_KEY"  // 必须更新
  }
}
```

**关键发现**: OpenClaw **不是**直接从环境变量读取 API key，而是从这个 JSON 缓存文件中读取。这是导致多次重启后仍报 401 的根本原因。

### 3. 验证步骤缺失
**正确流程应包含**:
1. 创建新 key → 2. 更新配置 → 3. 验证新 key 可用 → 4. 删除旧 key → **5. 删除后再次验证**

**实际错误流程**:
1. 创建新 key → 2. 删除旧 key → 3. 更新配置 → 4. 发现新 key 不可用 → 5. 无法调试

**补充教训（2026-04-08）**：即使验证通过再删除旧 key，删除后也要再次验证。原因：某些平台在两个 key 共存时可能用旧 key 响应请求，删除旧 key 后才会暴露新 key 的配置问题（参见 Claude API key 替换事件）。

## 正确的 API Key 替换流程

### 阶段 1: 准备新 Key
1. **创建新 API key** (DeepSeek 平台)
   - 名称: `openclaw-YYYYMMDD`
   - 保存完整 key 到安全位置
   - **不要立即删除旧 key**

2. **验证新 key 有效性**
   ```bash
   curl -s https://api.deepseek.com/v1/models \
     -H "Authorization: Bearer sk-新key"
   ```
   预期返回: `{"object":"list","data":[{"id":"deepseek-chat",...}]}`

### 阶段 2: 更新 OpenClaw 配置
#### 2.1 更新环境变量
```bash
# 编辑 ~/.zshrc
vim ~/.zshrc
# 更新 DEEPSEEK_API_KEY 变量
source ~/.zshrc
echo $DEEPSEEK_API_KEY  # 验证
```

#### 2.2 更新 Launchd plist
```bash
# 用 PlistBuddy 精确替换，避免意外修改其他字段（如代理配置）
/usr/libexec/PlistBuddy -c \
  "Set :EnvironmentVariables:DEEPSEEK_API_KEY sk-新key" \
  ~/Library/LaunchAgents/ai.openclaw.gateway.plist
```

> ⚠️ **不要** 手动 vim 编辑整个 plist，容易误删代理变量（`http_proxy` 等），导致 Claude 模型报 403。

#### 2.3 更新 OpenClaw 认证缓存
```bash
# 编辑认证缓存文件
vim ~/.openclaw/agents/main/agent/auth-profiles.json
# 更新 deepseek:default.key 字段
```

### 阶段 3: 重启与验证
#### 3.1 重启 Gateway
```bash
# 完全停止
killall -9 openclaw-gateway 2>/dev/null

# 清理可能的缓存
rm -rf ~/.openclaw/agents/*/auth-cache* 2>/dev/null

# 重新启动
launchctl stop ai.openclaw.gateway
sleep 2
launchctl start ai.openclaw.gateway

# 验证进程
ps aux | grep openclaw-gateway | grep -v grep
```

#### 3.2 验证新配置生效
1. **检查进程环境变量**
   ```bash
   ps -p <PID> -e | xargs launchctl getenv DEEPSEEK_API_KEY
   ```

2. **测试 OpenClaw 连接**
   - 切换到 DeepSeek 模型
   - 发送测试消息
   - 确认无 401 错误

### 阶段 4: 清理旧 Key
**仅在确认新 key 完全可用后**:
1. 登录 DeepSeek 平台
2. 导航到 API keys 管理页面
3. 删除旧 key (`new api`)

## 安全注意事项

### 1. 永远保持至少一个可用模型
**黄金规则**: OpenClaw 运行时必须至少有一个可用的模型用于调试。

**错误做法**:
- 删除旧 key → 更新配置 → 测试新 key

**正确做法**:
- 更新配置 → 测试新 key → 确认可用 → 删除旧 key

### 2. 多层级配置验证
OpenClaw 的配置是分层的，必须验证每一层:
1. 环境变量层 (`.zshrc`)
2. 服务配置层 (`plist`)
3. 应用缓存层 (`auth-profiles.json`)
4. 运行时状态 (Gateway 进程)

### 3. 代理设置的影响
plist 中的代理变量（`http_proxy`、`https_proxy`、`HTTP_PROXY`、`HTTPS_PROXY`）是 Claude (Anthropic) 模型正常工作所必需的，**不要移除**。DeepSeek API 可以直连，代理对其无影响。

替换任何 provider 的 API key 时，修改 plist 后务必确认代理变量完好：
```bash
cat ~/Library/LaunchAgents/ai.openclaw.gateway.plist | grep -E "proxy|PROXY"
```

### 4. 缓存机制
OpenClaw 有强缓存机制:
- `auth-profiles.json` 是主要认证缓存
- 修改后必须重启 Gateway
- 可能需要清理其他缓存文件

## 故障排除检查清单

### 401 Authentication Fails 错误排查
1. [ ] 验证新 key 本身有效 (`curl` 测试)
2. [ ] 检查 `.zshrc` 环境变量已更新
3. [ ] 检查 plist 中 key 已更新（**且代理变量未被误删**）
4. [ ] 检查 `auth-profiles.json` 缓存已更新
5. [ ] 确认 Gateway 已完全重启 (PID 变化)
6. [ ] 检查 Gateway 日志 (`~/.openclaw/logs/gateway.err.log`)
7. [ ] 验证进程环境变量 (`launchctl getenv`)

### 403 Forbidden 错误排查（Claude 模型）
1. [ ] 确认 ClashX 正在运行，代理端口 7890 可用
2. [ ] 检查 plist 中 4 个代理变量是否完整（`http_proxy`、`https_proxy`、`HTTP_PROXY`、`HTTPS_PROXY`）
3. [ ] 重载 Gateway（`launchctl unload/load`）

### Gateway 重启步骤
```bash
# 完整重启流程
killall -9 openclaw-gateway
sleep 2
rm -rf ~/.openclaw/agents/main/agent/auth-cache* 2>/dev/null
launchctl stop ai.openclaw.gateway
sleep 2
launchctl start ai.openclaw.gateway
sleep 3
ps aux | grep openclaw-gateway
```

## 经验教训

### 1. 顺序至关重要
API key 替换必须遵循安全顺序，确保在删除旧 key 前新 key 100% 可用。

### 2. 理解 OpenClaw 架构
OpenClaw 不是简单的环境变量读取，而是:
- 启动时从环境变量加载配置
- 缓存到 `auth-profiles.json`
- 运行时从缓存读取认证信息
- 需要显式更新缓存文件

### 3. 测试驱动变更
每次配置变更后:
1. 用最简单的方法测试 (如 `curl`)
2. 在 OpenClaw 中测试
3. 确认功能正常后再进行下一步

### 4. 文档化配置
保持配置文档更新，特别是:
- API key 存储位置
- 服务配置路径
- 缓存文件位置
- 重启命令

## 附录：相关文件路径

### 配置文件
- `~/.zshrc` - Shell 环境变量
- `~/Library/LaunchAgents/ai.openclaw.gateway.plist` - Launchd 服务配置
- `~/.openclaw/openclaw.json` - OpenClaw 主配置
- `~/.openclaw/agents/main/agent/auth-profiles.json` - 认证缓存

### 日志文件
- `~/.openclaw/logs/gateway.err.log` - Gateway 错误日志
- `~/.openclaw/logs/gateway.log` - Gateway 标准日志

### 关键命令
```bash
# 检查服务状态
launchctl list | grep openclaw

# 检查进程环境变量
ps -p <PID> -e | xargs launchctl getenv DEEPSEEK_API_KEY

# 测试 API key
curl -s https://api.deepseek.com/v1/models -H "Authorization: Bearer sk-xxx"

# 查看认证缓存
cat ~/.openclaw/agents/main/agent/auth-profiles.json | jq .
```

