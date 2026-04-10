# OpenClaw + DeepSeek on macOS: LLM Request Timed Out — Troubleshooting Guide

> **Platform**: macOS (Apple Silicon M4) | **OpenClaw**: 2026.3.13 | **LLM**: DeepSeek (`deepseek-chat`)
> **Status**: ✅ Resolved | **Date**: 2026-04-02

---

## Symptom

Every message sent via the OpenClaw Web UI triggers repeated timeout errors:

```
[agent/embedded] embedded run agent end: isError=true model=deepseek-chat provider=deepseek error=LLM request timed out.
[agent/embedded] embedded run failover decision: stage=assistant decision=surface_error reason=timeout
```

The agent retries 4 times within ~20 seconds, then surfaces the error to the user. Direct `curl` calls to the DeepSeek API work perfectly (~2–3 seconds response time).

---

## Background: Two Ways to Start the Gateway

On macOS, OpenClaw gateway can be started in two ways. They behave differently in terms of environment variable loading — understanding this is key to diagnosing the issues below.

### Option 1: Terminal (manual)

```bash
NODE_EXTRA_CA_CERTS=/etc/ssl/cert.pem NODE_USE_SYSTEM_CA=1 openclaw gateway run --log-level debug
```

`NODE_EXTRA_CA_CERTS` and `NODE_USE_SYSTEM_CA` **must** be explicitly set when launching from the terminal. Without them, TLS certificate handling differs from the launchctl environment, causing requests to time out.

To avoid typing them every time, add them permanently to `~/.zshrc`:

```zsh
# OpenClaw env vars
export NODE_EXTRA_CA_CERTS=/etc/ssl/cert.pem
export NODE_USE_SYSTEM_CA=1

# OpenClaw shell completion (must come after compinit)
autoload -Uz compinit && compinit
source "/Users/YOUR_USERNAME/.openclaw/completions/openclaw.zsh"
```

> **Note:** Do not use `echo 'export ...' >> ~/.zshrc` inside `.zshrc` itself — that appends a new line on every shell startup.

### Option 2: launchctl background service (recommended)

OpenClaw installs a launchd plist at:

```
~/Library/LaunchAgents/ai.openclaw.gateway.plist
```

This plist already includes `NODE_EXTRA_CA_CERTS` and `NODE_USE_SYSTEM_CA` in its `EnvironmentVariables` block, so this mode works out of the box.

```bash
# Start
launchctl load ~/Library/LaunchAgents/ai.openclaw.gateway.plist

# Stop
launchctl unload ~/Library/LaunchAgents/ai.openclaw.gateway.plist

# Restart
launchctl unload ~/Library/LaunchAgents/ai.openclaw.gateway.plist
launchctl load ~/Library/LaunchAgents/ai.openclaw.gateway.plist
```

Logs are written to:

```
~/.openclaw/logs/gateway.log
~/.openclaw/logs/gateway.err.log
```

---

## Root Causes & Fixes

This issue was caused by four compounding root causes, discovered in order.

### Cause 1: Missing `authHeader: true` in provider config

Without this field, OpenClaw does not correctly attach the `Authorization: Bearer <api_key>` header to outgoing requests. As a result:

- TLS handshake completes successfully
- Only ~1609 bytes are transmitted (a partial, unauthenticated request)
- The connection is immediately closed with `FIN` — no response data is received
- OpenClaw interprets the missing streaming response as a timeout

Confirmed via `tcpdump`: the client sends `[F.]` (FIN) immediately after the initial handshake, with no data from the server.

**Fix:** Add `"authHeader": true` to the DeepSeek provider block in `~/.openclaw/openclaw.json`:

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

### Cause 2: Stale API key in agent cache files

After rotating the API key, the launchctl-started gateway returned `HTTP 401: Authentication Fails`. OpenClaw caches provider config in agent-specific files that are **separate from `openclaw.json`** and must be updated independently.

Files that may contain a stale key:

```
~/.openclaw/agents/main/agent/models.json
~/.openclaw/agents/main/agent/auth-profiles.json
~/.openclaw/agents/main/sessions/sessions.json
~/.openclaw/agents/main/sessions/<session-id>.jsonl
~/.openclaw/openclaw.json.bak
```

**Fix:** Batch-replace the old key across all cache files, then restart the gateway:

```bash
OLD_KEY="sk-YOUR_OLD_KEY"
NEW_KEY="sk-YOUR_NEW_KEY"

sed -i.bak "s/$OLD_KEY/$NEW_KEY/g" ~/.openclaw/agents/main/agent/models.json
sed -i.bak "s/$OLD_KEY/$NEW_KEY/g" ~/.openclaw/agents/main/agent/auth-profiles.json
sed -i.bak "s/$OLD_KEY/$NEW_KEY/g" ~/.openclaw/agents/main/sessions/sessions.json
```

---

### Cause 3: Missing `deepseek:default` entry in `auth-profiles.json`

`~/.openclaw/agents/main/agent/auth-profiles.json` only contained an `openai:default` profile. Without a `deepseek:default` entry, the terminal-launched gateway cannot authenticate DeepSeek requests even if the key is correct in `openclaw.json`.

**Fix:** Edit `auth-profiles.json` and add the DeepSeek profile:

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

### Cause 4: Missing CA certificate env vars when launching from terminal

Even with all config correct, the terminal-launched gateway still timed out because it lacked the system CA certificate environment variables that launchctl injects automatically via the plist.

**Fix:** Always set these before starting the gateway from terminal, or add them permanently to `~/.zshrc`:

```bash
export NODE_EXTRA_CA_CERTS=/etc/ssl/cert.pem
export NODE_USE_SYSTEM_CA=1
```

---

## What Did NOT Work

The following approaches were tried and confirmed ineffective:

| Approach | Result |
|----------|--------|
| Changing `baseUrl` from `https://api.deepseek.com` to `https://api.deepseek.com/v1` | No effect |
| `NODE_OPTIONS="--dns-result-order=ipv4first"` | Rules out IPv6, but doesn't fix the timeout |
| Adding `"timeout"` field to provider config | Unsupported — `openclaw doctor` removes it automatically |
| Setting `LLM_REQUEST_TIMEOUT` environment variable | No effect on the underlying connection issue |
| Adding `"stream": false` to provider config | Unsupported — causes a config error |
| Clearing the session file (`> session.jsonl`) | Rules out corrupted session history, but doesn't fix the timeout |

---

## Diagnostic Commands

```bash
# Find all config files containing an API key
find ~/.openclaw -type f | xargs grep -l "sk-" 2>/dev/null

# Check the key currently in use
openclaw config get models.providers.deepseek.apiKey

# Test a streaming request directly (bypasses OpenClaw entirely)
curl -v -X POST https://api.deepseek.com/v1/chat/completions \
  -H "Authorization: Bearer sk-YOUR_KEY" \
  -H "Content-Type: application/json" \
  -H "Accept: text/event-stream" \
  -d '{"model":"deepseek-chat","messages":[{"role":"user","content":"hi"}],"stream":true,"max_tokens":50}'

# Monitor actual TCP traffic to DeepSeek
sudo tcpdump -i any host api.deepseek.com -n

# Increase agent timeout via CLI (cannot be set in JSON)
openclaw config set agents.defaults.timeoutSeconds 600
```

---

## Security Note

If your API key was exposed (e.g., pasted into a chat log, log file, or shared document), rotate it immediately in the [DeepSeek API console](https://platform.deepseek.com) and update all cache files listed in Cause 2. Treat any exposed key as compromised regardless of context.
