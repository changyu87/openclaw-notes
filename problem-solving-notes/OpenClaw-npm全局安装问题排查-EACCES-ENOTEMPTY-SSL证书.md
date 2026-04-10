# OpenClaw 重装问题排查与解决（EACCES / ENOTEMPTY / SSL 证书）

> **平台**: macOS (Apple Silicon M4) | **OpenClaw**: 2026.3.13 → 2026.4.5 | **状态**: ✅ 已解决 | **时间**: 2026-04-06

---

## 问题背景

从 OpenClaw 2026.3.13 升级到 2026.4.5，通过 gateway UI 触发自动更新（`update.run`）失败，原因是 npm cache 目录被 root 锁定（`EACCES`）。改为手动 `npm install -g openclaw@latest` 重装，过程中遇到多个权限、SSL 证书、npm registry、目录残留问题。

---

## 问题一：权限不足（EACCES）

### 现象

自动更新时报错：

```
npm error code EACCES
npm error path /Users/changyuxu/.npm/_cacache/tmp/...
npm error errno -13
npm error Your cache folder contains root-owned files
```

### 原因

npm cache 目录（`~/.npm`）中有 root 遗留文件，普通用户无法写入。

### 解决

```bash
sudo chown -R 501:20 "/Users/changyuxu/.npm"
```

之后手动安装需要加 `sudo`，因为 `/opt/homebrew/lib/node_modules/` 是 Homebrew 管理的目录，普通用户无写权限。

---

## 问题二：Node 版本偏低（EBADENGINE）

### 现象

```
npm warn EBADENGINE Unsupported engine {
  package: 'undici@8.0.2',
  required: { node: '>=22.19.0' },
  current: { node: 'v22.16.0' }
}
```

### 原因

openclaw 最新版依赖 `undici@8.0.2`，要求 Node >= 22.19.0，而系统通过 Homebrew 安装的 `node@22` 卡在 22.16.0。

### 结论

Homebrew 的 `node@22` 最新版就是 22.16.0，无法通过 `brew upgrade` 升级到 22.19.0。`EBADENGINE` 是 **warn 级别，不阻断安装**，openclaw 实际运行正常，忽略即可。

---

## 问题三：目录非空无法替换（ENOTEMPTY）

### 现象

```
npm error code ENOTEMPTY
npm error syscall rename
npm error path /opt/homebrew/lib/node_modules/openclaw
npm error dest /opt/homebrew/lib/node_modules/.openclaw-2N5mgx4q
npm error errno -66
npm error ENOTEMPTY: directory not empty
```

### 原因

npm 在安装时会先把旧目录移走，但旧目录非空且存在残留文件，rename 操作失败。

### 解决

手动删除旧目录后重装：

```bash
sudo rm -rf /opt/homebrew/lib/node_modules/openclaw
```

---

## 最终安装命令

```bash
# 1. 清理旧目录（必须，否则 ENOTEMPTY）
sudo rm -rf /opt/homebrew/lib/node_modules/openclaw
sudo rm -rf /opt/homebrew/lib/node_modules/.openclaw-*

# 2. 重装（指定官方 registry 和 CA 证书）
sudo NODE_EXTRA_CA_CERTS=/etc/ssl/cert.pem \
  npm install -g openclaw@latest \
  --registry https://registry.npmjs.org
```

- `sudo`：Homebrew 目录需要 root 权限
- `NODE_EXTRA_CA_CERTS`：sudo 环境下 SSL 证书不自动加载，需显式指定
- `--registry https://registry.npmjs.org`：root 的 npm 配置可能指向 npmmirror，国内 SSL 验证失败，需强制走官方
- 代理由 launchd plist 注入，sudo 环境下自动继承（已在 plist 中配置 `https_proxy`）

安装耗时约 5 分钟（全量下载，无缓存），完成后版本确认为 2026.4.5。

---

## 验证

```bash
openclaw --version
openclaw doctor
```

---

## 问题根因总结

| 问题 | 根因 | 解决 |
|------|------|------|
| `MODULE_NOT_FOUND` | 安装不完整，依赖缺失 | 重装 |
| `EACCES` | npm cache 有 root 遗留文件；Homebrew 目录需要 root | `sudo chown -R 501:20 ~/.npm`；安装用 `sudo` |
| `EBADENGINE` | Node 22.16.0 < 要求的 22.19.0 | 忽略（warn 级别，不影响运行） |
| `ENOTEMPTY` | 旧目录残留（中断安装留下半成品），npm 无法原子替换 | `sudo rm -rf` 旧目录后重装 |
