# OpenClaw + Ollama：GPU 100% 占用问题排查与解决

> **平台**: macOS (Apple Silicon M4) | **OpenClaw**: 2026.3.13 | **状态**: ✅ 已解决 | **时间**: 2026-04-02

---

## 问题表现

### 症状
- 系统自动运行 Ollama，即使没有手动启动
- GPU 资源被持续占用接近 100%
- 系统负载高，响应变慢
- 进程不断自动重启，无法彻底停止

### 发现的问题进程
```
changyuxu        61864   2.4  0.6 442955280  93616   ??  S     9:30PM   0:50.10 /Applications/Ollama.app/Contents/Resources/ollama runner --ollama-engine --model /Users/changyuxu/.ollama/models/blobs/sha256-e6a7edc1a4d7d9b2de136a221a57336b76316cfe53a252aeba814496c5ae439d --port 60694
changyuxu        66449   0.1  0.2 436760688  26528   ??  S     9:47PM   0:00.35 ollama run deepseek-r1:8b
changyuxu        59923   0.0  0.5 436878528  83792   ??  S     9:21PM   0:11.08 /Applications/Ollama.app/Contents/Resources/ollama serve
```

## 根本原因分析

### 1. OpenClaw 配置问题（主要根源）
**关键发现**：OpenClaw 配置文件中包含了 Ollama 作为模型提供者

**配置文件位置**：
```
~/.openclaw/agents/main/agent/models.json
```

**问题配置**：
```json
"providers": {
  "ollama": {
    "baseUrl": "http://127.0.0.1:11434",
    "api": "ollama",
    "models": [
      {
        "id": "deepseek-r1:8b",
        "name": "deepseek-r1:8b",
        "reasoning": true,
        "input": ["text"],
        "contextWindow": 131072,
        "maxTokens": 8192
      }
    ],
    "apiKey": "ollama-local"
  }
}
```

### 2. 系统启动项问题
**启动守护程序**：
- `com.ollama.ollama` 作为 LaunchAgent 自动启动
- 即使禁用后，Ollama 应用本身仍有自动重启机制

### 3. 相互依赖关系
OpenClaw 配置 → 尝试连接 Ollama API → Ollama 自动启动 → GPU 占用 100%

## 解决方案

### 第一步：移除 OpenClaw 中的 Ollama 配置
```bash
# 编辑 models.json，删除 ollama 提供者配置
vim ~/.openclaw/agents/main/agent/models.json
```

**修改后**：
- 只保留 openai 和 deepseek 提供者
- 确保默认模型设置为 `deepseek/deepseek-chat`

### 第二步：禁用系统启动项
```bash
# 检查启动项状态
launchctl print gui/$(id -u) | grep -B 2 -A 2 "com.ollama.ollama"

# 禁用启动项
launchctl disable gui/$(id -u)/com.ollama.ollama
```

### 第三步：创建手动控制脚本
**脚本位置**：`~/.openclaw/workspace/ollama-control.sh`

```bash
#!/bin/bash
# Ollama 控制脚本
# 用法: ./ollama-control.sh [start|stop|status]

COMMAND=${1:-status}

case $COMMAND in
    start)
        echo "启动 Ollama..."
        open -a Ollama --background
        sleep 3
        echo "Ollama 已启动"
        ;;
    stop)
        echo "停止 Ollama..."
        pkill -9 -f "ollama" 2>/dev/null
        pkill -9 -f "Ollama.app" 2>/dev/null
        sleep 2
        echo "Ollama 已停止"
        ;;
    status)
        if ps aux | grep -i ollama | grep -v grep > /dev/null; then
            echo "Ollama 正在运行"
            ps aux | grep -i ollama | grep -v grep
        else
            echo "Ollama 未运行"
        fi
        ;;
    *)
        echo "用法: $0 [start|stop|status]"
        exit 1
        ;;
esac
```

**设置执行权限**：
```bash
chmod +x ~/.openclaw/workspace/ollama-control.sh
```

## 补充建议（Claude Haiku 4.5 审阅）

### 关键问题与风险

#### 🔴 **严重风险**

1. **LaunchAgent 禁用不完全**
   - **问题**: `launchctl disable` 仅禁用当前用户会话，系统更新后可能重新启用
   - **建议**: 同时删除 plist 文件或设置正确的启动权限配置
   - **改进步骤**:
     ```bash
     launchctl disable gui/$(id -u)/com.ollama.ollama
     rm -f ~/Library/LaunchAgents/com.ollama.ollama.plist
     ```

2. **使用 SIGKILL (-9) 的高强度进程终止**
   - **问题**: `pkill -9 -f "ollama"` 强制杀死进程，不给应用保存状态的机会，可能导致:
     - 模型缓存损坏
     - GPU 驱动状态不一致
     - 孤儿进程残留
   - **建议**: 先尝试温和终止，再使用强制杀死
   - **改进脚本**:
     ```bash
     # 先试温和终止
     killall ollama 2>/dev/null
     sleep 2
     # 若仍在运行则强制终止
     pkill -9 -f "ollama" 2>/dev/null || true
     ```

3. **缺少认证配置清理**
   - **问题**: 仅删除 Ollama 配置还不够，需要清理 OpenClaw 的认证缓存
   - **建议**: 清理以下文件中的 Ollama 相关认证:
     ```bash
     ~/.openclaw/agents/main/agent/auth-profiles.json
     ~/.openclaw/agents/main/sessions/sessions.json
     ```

#### 🟡 **中等风险**

4. **GPU 监控命令不准确**
   - **问题**: `top -l 1 | grep -i gpu` 在 Apple Silicon Mac 上无法检测到 GPU 占用（需用 `ASITOP` 或系统预览）
   - **建议**: 使用更可靠的 GPU 监控方法:
     ```bash
     # 查看 GPU 核心使用率
     system_profiler SPDisplaysDataType | grep -i gpu
     
     # 或使用第三方工具（已安装）
     asitop
     ```

5. **控制脚本目录权限未明确**
   - **问题**: 脚本存储在 `.openclaw/workspace/` 但该目录的权限和备份机制未说明
   - **建议**: 指定脚本存储位置与权限:
     ```bash
     # 建议改为
     mkdir -p ~/.openclaw/scripts
     chmod 700 ~/.openclaw/scripts
     # 脚本放在这里，防止意外删除
     ```

#### 🟢 **轻微问题**

6. **脚本缺少错误处理**
   - 建议添加 `set -e` 和错误提示

7. **缺少日志记录机制**
   - 建议将操作记录到日志文件便于后续调查

8. **没有验证模型完整性的步骤**
   - 强制杀死后应验证 `~/.ollama/models/` 的完整性

9. **文档中没有回滚计划**
   - 若问题解决后需要恢复 Ollama 服务应提供步骤

10. **OpenClaw 配置修改缺少备份**
    - 编辑 `models.json` 前应备份原始版本

### 改进的解决方案

**完整的停止脚本示例**:
```bash
#!/bin/bash
set -e

log_file="$HOME/.openclaw/logs/ollama-control.log"
mkdir -p "$(dirname "$log_file")"

ollama_stop() {
    echo "[$(date)] 正在停止 Ollama..." | tee -a "$log_file"
    
    # 备份前状态
    ps aux | grep -i ollama | grep -v grep >> "$log_file" 2>&1 || true
    
    # 温和终止
    killall ollama 2>/dev/null || true
    sleep 2
    
    # 检查是否还在运行
    if pgrep -f ollama > /dev/null; then
        echo "[$(date)] 温和终止失败，使用强制杀死..." | tee -a "$log_file"
        pkill -9 -f ollama || true
        sleep 1
    fi
    
    echo "[$(date)] Ollama 已停止" | tee -a "$log_file"
}

ollama_stop
```

### 建议事项总结

| 优先级 | 类别 | 建议 |
|--------|------|------|
| 🔴 HIGH | 配置 | 删除 LaunchAgent plist 文件，不仅仅禁用 |
| 🔴 HIGH | 脚本 | 改进进程终止逻辑，先温和后强制 |
| 🔴 HIGH | 清理 | 清理 OpenClaw 认证缓存中的 Ollama 配置 |
| 🟡 MED | 监控 | 使用正确的 GPU 监控工具（Apple Silicon 特定） |
| 🟡 MED | 存储 | 指定脚本存储位置且设置正确权限 |
| 🟢 LOW | 日志 | 添加操作日志记录 |
| 🟢 LOW | 回滚 | 文档化恢复步骤 |

---

## 使用指南

### 正常使用流程
1. **需要时手动启动**：
   ```bash
   ~/.openclaw/workspace/ollama-control.sh start
   ```

2. **使用 Ollama**：
   ```bash
   ollama run deepseek-r1:8b
   # 或其他模型
   ```

3. **使用后停止**：
   ```bash
   ~/.openclaw/workspace/ollama-control.sh stop
   ```

### 检查状态
```bash
~/.openclaw/workspace/ollama-control.sh status
```

## 预防措施

### 1. OpenClaw 配置检查
定期检查以下文件，确保没有意外的模型提供者配置：
- `~/.openclaw/agents/main/agent/models.json`
- `~/.openclaw/openclaw.json`

### 2. 系统启动项监控
```bash
# 检查是否有新的自动启动项
launchctl list | grep -i ollama
launchctl print gui/$(id -u) | grep ollama
```

### 3. 进程监控
```bash
# 定期检查是否有异常进程
ps aux | grep -i ollama | grep -v grep
top -l 1 | grep -i gpu
```

## 验证结果

### 成功指标
1. ✅ Ollama 不再自动启动
2. ✅ GPU 占用恢复正常水平
3. ✅ 可以手动控制 Ollama 的启停
4. ✅ OpenClaw 正常运行，不使用 Ollama 模型

### 测试方法
1. 重启系统，检查 Ollama 是否自动启动
2. 运行控制脚本测试启停功能
3. 监控 GPU 使用率变化

## 经验教训

### 关于 OpenClaw 配置
1. **模型提供者配置需谨慎**：添加本地模型提供者时，要考虑其对系统资源的影响
2. **默认模型设置**：确保默认模型使用云端服务而非本地模型，除非有特定需求
3. **配置验证**：修改配置后，验证系统行为是否符合预期

### 关于系统资源管理
1. **本地模型的风险**：本地 LLM 模型会持续占用 GPU 资源
2. **自动启动控制**：对于资源密集型应用，必须严格控制自动启动
3. **监控机制**：建立定期检查机制，及时发现资源异常

## 相关文件
1. `~/.openclaw/agents/main/agent/models.json` - OpenClaw 模型配置
2. `~/.openclaw/openclaw.json` - OpenClaw 主配置
3. `~/.openclaw/workspace/ollama-control.sh` - 控制脚本
4. `~/.ollama/logs/` - Ollama 日志目录

## 后续建议
1. 考虑使用 Docker 容器运行 Ollama，实现更好的资源隔离
2. 为 OpenClaw 配置资源使用监控和告警
3. 定期审查和清理不再使用的模型配置

