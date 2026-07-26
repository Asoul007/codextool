# Codex 用量

一个 macOS 菜单栏 + 桌面悬浮小工具，用来查看 Codex 用量快照。

## 功能

- 三种显示形态：悬浮球、开发者 HUD、菜单栏显示。
- 可选择展示三项核心指标：`5小时剩余`、`一周剩余`、`重置机会`。
- 默认显示悬浮球和菜单栏，默认菜单栏显示一周剩余和重置机会。
- 主题皮肤：流光能量、赛博蓝、霓虹紫、琥珀橙。
- 透明度：不透明、半透明、高透明、全透明。
- `流光能量` 主题会在开发者 HUD 中启用液态波形进度条。
- 每 30 秒自动同步一次本机 Codex 用量，打开菜单栏弹层时也会即时刷新。
- 一键打开官方 Codex Usage 页面。

## 隐私边界

应用会读取本机 `CODEX_HOME/auth.json` 或 `~/.codex/auth.json` 中已有的 Codex 登录态，只用于向 ChatGPT/Codex 用量接口请求当前用量。应用不持久化 token、账号 ID、原始接口响应或对话内容，只保存显示设置和最近一次解析后的用量快照。

如果官方用量接口不可用，应用会尝试从本机 Codex 会话记录中读取最近的用量事件作为兜底显示。

## 开发

```bash
swift test
swift build -c release
```

## 打包 DMG

```bash
./scripts/package_dmg.sh
```

输出：

- `dist/Codex 用量.app`
- `dist/CodexQuota.dmg`
