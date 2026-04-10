#!/bin/bash
# OpenClaw 升级脚本
# 根据 problem-solving-notes/OpenClaw-npm全局安装问题排查 整理
# 用法：chmod +x update-openclaw.sh && ./update-openclaw.sh

set -e

# ── 颜色 & 格式 ──────────────────────────────────────────────
BOLD="\033[1m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
CYAN="\033[0;36m"
RESET="\033[0m"

# ── 工具函数 ─────────────────────────────────────────────────
ts() { date "+%H:%M:%S"; }

step() {
  echo ""
  echo -e "${BOLD}${CYAN}[$(ts)] $1${RESET}"
}

ok()   { echo -e "  ${GREEN}✓${RESET} $1"; }
warn() { echo -e "  ${YELLOW}⚠️ ${RESET} $1"; }
fail() { echo -e "  ${RED}✗${RESET} $1"; }

# spinner：在后台进程运行时显示转圈动画
spinner_start() {
  local msg="$1"
  # 把 spinner PID 存到全局
  (
    local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    while true; do
      printf "\r  ${CYAN}%s${RESET}  %s " "${frames[$((i % 10))]}" "$msg"
      i=$((i + 1))
      sleep 0.1
    done
  ) &
  SPINNER_PID=$!
}

spinner_stop() {
  if [[ -n "$SPINNER_PID" ]]; then
    kill "$SPINNER_PID" 2>/dev/null
    wait "$SPINNER_PID" 2>/dev/null
    printf "\r\033[2K"   # 清除当前行
    SPINNER_PID=""
  fi
}

# ── 开始 ─────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}════════════════════════════════════════${RESET}"
echo -e "${BOLD}  🐾 OpenClaw 升级脚本${RESET}"
echo -e "${BOLD}════════════════════════════════════════${RESET}"
START_TS=$(date +%s)

# ── 步骤 1：修复 npm cache 权限 ──────────────────────────────
step "[1/5] 修复 npm cache 权限（避免 EACCES）"
if [ -d "$HOME/.npm" ]; then
  sudo chown -R "$(id -u):$(id -g)" "$HOME/.npm"
  ok "~/.npm 权限已修复"
else
  ok "~/.npm 不存在，跳过"
fi

# ── 步骤 2：停止 gateway ──────────────────────────────────────
step "[2/5] 停止 openclaw gateway"
if launchctl unload ~/Library/LaunchAgents/ai.openclaw.gateway.plist 2>/dev/null; then
  ok "gateway 已停止"
else
  ok "gateway 未在运行（或 plist 不存在），继续"
fi

# ── 步骤 3：清理旧目录 ────────────────────────────────────────
step "[3/5] 清理旧 openclaw 安装目录"
sudo rm -rf /opt/homebrew/lib/node_modules/openclaw
sudo rm -rf /opt/homebrew/lib/node_modules/.openclaw-*
ok "旧目录已清理"

# ── 步骤 4：安装最新版（实时进度）────────────────────────────
step "[4/5] 安装 openclaw@latest"
echo -e "  ${YELLOW}提示：安装通常需要 3–8 分钟，每行代表一个网络请求${RESET}"
echo ""

# --progress=true  → 显示 npm 内置进度条（npm v7+）
# --loglevel http  → 实时打印每条 HTTP 请求（能看到下载哪些包）
# --timing         → 最后打印每步耗时
sudo NODE_EXTRA_CA_CERTS=/etc/ssl/cert.pem \
  npm install -g openclaw@latest \
  --registry https://registry.npmjs.org \
  --progress=true \
  --loglevel http

ok "安装完成（$(ts)）"

# ── 步骤 5：重启 gateway ──────────────────────────────────────
step "[5/5] 重启 openclaw gateway"
if launchctl load ~/Library/LaunchAgents/ai.openclaw.gateway.plist 2>/dev/null; then
  ok "gateway 已重启"
else
  warn "plist 不存在，请手动启动 gateway"
fi

# ── 完成摘要 ──────────────────────────────────────────────────
END_TS=$(date +%s)
ELAPSED=$((END_TS - START_TS))
echo ""
echo -e "${BOLD}════════════════════════════════════════${RESET}"
echo -e "${BOLD}  ✅ 升级完成  耗时 ${ELAPSED}s${RESET}"
echo ""
echo -e "  ${BOLD}版本验证：${RESET}"
openclaw --version | sed 's/^/    /'
echo ""
echo -e "  如有问题，运行：${CYAN}openclaw doctor${RESET}"
echo -e "${BOLD}════════════════════════════════════════${RESET}"
echo ""
