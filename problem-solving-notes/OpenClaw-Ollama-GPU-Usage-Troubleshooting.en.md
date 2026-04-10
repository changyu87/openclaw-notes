# OpenClaw + Ollama: GPU 100% Usage Troubleshooting

> **Platform**: macOS (Apple Silicon M4) | **OpenClaw**: 2026.3.13 | **Status**: ✅ Resolved | **Date**: 2026-04-02

**Languages**: [English](#) | [中文 (Chinese)](./OpenClaw-Ollama-GPU-占用排查与解决.zh.md)

---

## Problem Symptoms

### Issues Observed
- Ollama runs automatically even without manual start
- GPU resources consistently near 100% utilization
- High system load, slow responsiveness
- Process continuously auto-restarts, cannot be stopped

### Problem Processes Found
```
changyuxu        61864   2.4  0.6 442955280  93616   ??  S     9:30PM   0:50.10 /Applications/Ollama.app/Contents/Resources/ollama runner --ollama-engine --model /Users/changyuxu/.ollama/models/bl[...]
changyuxu        66449   0.1  0.2 436760688  26528   ??  S     9:47PM   0:00.35 ollama run deepseek-r1:8b
changyuxu        59923   0.0  0.5 436878528  83792   ??  S     9:21PM   0:11.08 /Applications/Ollama.app/Contents/Resources/ollama serve
```

---

## Root Cause Analysis

### 1. OpenClaw Configuration Issue (Primary Root Cause)

**Key Finding**: OpenClaw config includes Ollama as model provider.

**Config File Location**:
```
~/.openclaw/agents/main/agent/models.json
```

**Problematic Configuration**:
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

### 2. System Startup Item Issue

**Auto-Launch Daemon**:
- `com.ollama.ollama` configured as LaunchAgent
- Auto-starts on system login
- Has built-in restart mechanism even when disabled

### 3. Circular Dependency

OpenClaw config → Attempts Ollama API connection → Ollama auto-starts → 100% GPU usage

---

## Solution

### Step 1: Remove Ollama from OpenClaw Configuration

```bash
# Edit models.json, delete ollama provider section
vim ~/.openclaw/agents/main/agent/models.json
```

**After modification**:
- Keep only openai and deepseek providers
- Set default model to `deepseek/deepseek-chat`

### Step 2: Disable System Launch Item

```bash
# Check launch item status
launchctl print gui/$(id -u) | grep -B 2 -A 2 "com.ollama.ollama"

# Disable launch item
launchctl disable gui/$(id -u)/com.ollama.ollama
```

### Step 3: Create Manual Control Script

**Script Location**: `~/.openclaw/workspace/ollama-control.sh`

```bash
#!/bin/bash
# Ollama control script
# Usage: ./ollama-control.sh [start|stop|status]

COMMAND=${1:-status}

case $COMMAND in
    start)
        echo "Starting Ollama..."
        open -a Ollama --background
        sleep 3
        echo "Ollama started"
        ;;
    stop)
        echo "Stopping Ollama..."
        pkill -9 -f "ollama" 2>/dev/null
        pkill -9 -f "Ollama.app" 2>/dev/null
        sleep 2
        echo "Ollama stopped"
        ;;
    status)
        if ps aux | grep -i ollama | grep -v grep > /dev/null; then
            echo "Ollama is running"
            ps aux | grep -i ollama | grep -v grep
        else
            echo "Ollama not running"
        fi
        ;;
    *)
        echo "Usage: $0 [start|stop|status]"
        exit 1
        ;;
esac
```

**Set execute permission**:
```bash
chmod +x ~/.openclaw/workspace/ollama-control.sh
```

---

## Additional Recommendations (Reviewed by Claude Haiku 4.5)

### 🔴 Critical Risks

1. **Incomplete LaunchAgent Disable**
   - **Issue**: `launchctl disable` only disables current session; system updates may re-enable
   - **Recommendation**: Also delete plist file or set proper startup permissions
   - **Improved Steps**:
     ```bash
     launchctl disable gui/$(id -u)/com.ollama.ollama
     rm -f ~/Library/LaunchAgents/com.ollama.ollama.plist
     ```

2. **SIGKILL (-9) Process Termination**
   - **Issue**: `pkill -9 -f "ollama"` forces kill without graceful shutdown, may cause:
     - Model cache corruption
     - GPU driver state inconsistency
     - Orphaned processes
   - **Recommendation**: Attempt graceful termination first
   - **Improved Script**:
     ```bash
     # Try graceful termination
     killall ollama 2>/dev/null
     sleep 2
     # Force kill if still running
     pkill -9 -f "ollama" 2>/dev/null || true
     ```

3. **Missing Authentication Cache Cleanup**
   - **Issue**: Deleting Ollama config insufficient; need to clear auth cache
   - **Recommendation**: Clean Ollama entries from:
     ```bash
     ~/.openclaw/agents/main/agent/auth-profiles.json
     ~/.openclaw/agents/main/sessions/sessions.json
     ```

### 🟡 Medium Risks

4. **Inaccurate GPU Monitoring**
   - **Issue**: `top -l 1 | grep -i gpu` doesn't detect GPU usage on Apple Silicon
   - **Recommendation**: Use proper tools:
     ```bash
     # Check GPU cores usage
     system_profiler SPDisplaysDataType | grep -i gpu
     
     # Or use third-party tool
     asitop
     ```

5. **Script Directory Permissions Unclear**
   - **Issue**: `.openclaw/workspace/` permissions and backup strategy undefined
   - **Recommendation**: Specify script storage with permissions:
     ```bash
     mkdir -p ~/.openclaw/scripts
     chmod 700 ~/.openclaw/scripts
     # Store scripts here, prevent accidental deletion
     ```

### 🟢 Minor Issues

6. Script lacks error handling → Add `set -e` and error messages
7. No logging mechanism → Record operations to log file
8. No model integrity verification after force-kill
9. Missing rollback plan if Ollama needs restoration
10. No OpenClaw config backup before modification

### Improved Stop Script Example

```bash
#!/bin/bash
set -e

log_file="$HOME/.openclaw/logs/ollama-control.log"
mkdir -p "$(dirname "$log_file")"

ollama_stop() {
    echo "[$(date)] Stopping Ollama..." | tee -a "$log_file"
    
    # Backup current state
    ps aux | grep -i ollama | grep -v grep >> "$log_file" 2>&1 || true
    
    # Graceful termination
    killall ollama 2>/dev/null || true
    sleep 2
    
    # Check if still running
    if pgrep -f ollama > /dev/null; then
        echo "[$(date)] Graceful termination failed, force killing..." | tee -a "$log_file"
        pkill -9 -f ollama || true
        sleep 1
    fi
    
    echo "[$(date)] Ollama stopped" | tee -a "$log_file"
}

ollama_stop
```

### Recommendations Summary

| Priority | Category | Recommendation |
|----------|----------|-----------------|
| 🔴 HIGH | Config | Delete LaunchAgent plist, not just disable |
| 🔴 HIGH | Script | Improve termination logic, graceful then force |
| 🔴 HIGH | Cleanup | Clear Ollama entries from auth cache |
| 🟡 MED | Monitoring | Use correct GPU tools (Apple Silicon-specific) |
| 🟡 MED | Storage | Specify script location with permissions |
| 🟢 LOW | Logging | Add operation logging |
| 🟢 LOW | Rollback | Document recovery steps |

---

## Usage Guide

### Normal Workflow

1. **Start when needed**:
   ```bash
   ~/.openclaw/workspace/ollama-control.sh start
   ``

2. **Use Ollama**:
   ```bash
   ollama run deepseek-r1:8b
   # or other models
   ```

3. **Stop after use**:
   ```bash
   ~/.openclaw/workspace/ollama-control.sh stop
   ```

### Check Status
```bash
~/.openclaw/workspace/ollama-control.sh status
```

---

## Prevention Measures

### 1. OpenClaw Configuration Audit

Regularly check these files for unexpected model providers:
- `~/.openclaw/agents/main/agent/models.json`
- `~/.openclaw/openclaw.json`

### 2. System Launch Item Monitoring

```bash
# Check for new auto-launch items
launchctl list | grep -i ollama
launchctl print gui/$(id -u) | grep ollama
```

### 3. Process Monitoring

```bash
# Periodically check for anomalous processes
ps aux | grep -i ollama | grep -v grep
top -l 1 | grep -i gpu
```

---

## Verification Results

### Success Indicators
1. ✅ Ollama no longer auto-starts
2. ✅ GPU usage returns to normal levels
3. ✅ Manual control over Ollama start/stop
4. ✅ OpenClaw runs normally without Ollama models

### Testing
1. Restart system, verify Ollama doesn't auto-start
2. Test control script start/stop functionality
3. Monitor GPU usage changes
4. Verify OpenClaw functionality with DeepSeek/Anthropic models

---

## Lessons Learned

### OpenClaw Configuration Insights
1. **Local model provider config requires caution**: Adding local model providers impacts system resources
2. **Default model selection matters**: Use cloud services by default unless specific local model need exists
3. **Configuration validation**: After config changes, verify system behavior matches expectations

### System Resource Management
1. **Local model risks**: Local LLMs continuously occupy GPU resources
2. **Auto-startup control**: Resource-intensive apps require strict auto-start management
3. **Monitoring discipline**: Establish regular checks to detect resource anomalies early

---

## Related Files
1. `~/.openclaw/agents/main/agent/models.json` - OpenClaw model configuration
2. `~/.openclaw/openclaw.json` - OpenClaw main configuration
3. `~/.openclaw/workspace/ollama-control.sh` - Control script
4. `~/.ollama/logs/` - Ollama log directory

---

## Future Recommendations
1. Consider Docker containerization for Ollama to isolate resources better
2. Implement resource usage monitoring and alerting for OpenClaw
3. Establish regular audit schedule for unused model configurations