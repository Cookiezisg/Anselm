---
id: DOC-041
type: decision
status: active
owner: @weilin
created: 2026-06-14
reviewed: 2026-06-14
review-due: 2099-12-31
audience: [human, ai]
---

# 0005 — 工具链 devbox/nix → mise（supersede ADR 0004 §工具链）

## 背景

[ADR 0004](0004-frontend-flutter-architecture.md) 落地时把 Flutter 加入 devbox（nix）管理（与 `go`/`gnumake` 同管）。随后真跑桌面 app 时发现 **nixpkgs flutter 对 macOS 桌面构建结构性不兼容**,经验证如下:

1. nix 把所有包放在**永久只读**的 `/nix/store`,这是其可复现性的基石。
2. Flutter 的 macOS 构建必须把引擎 framework（`FlutterMacOS.framework`）**拷进 build/ 再用 `lipo` 改写瘦身**;来自只读 store 的拷贝**也是只读**,`lipo` 写临时文件 → `Permission denied` → 构建失败。手动 chmod 无效:`debug_unpack_macos` **每次构建都从只读 store 重拷**,当即覆盖。
3. 另一前置坑:`devbox run` 激活的 nix 环境注入 `DEVELOPER_DIR`/`SDKROOT`/`NIX_CFLAGS`/`CC`/`NIX_BINTOOLS` 指向 nix 假 Apple SDK,**劫持 xcodebuild** → `ld: unknown options`。

即 nix「一切只读不可变」与 Xcode「构建要改写 Flutter 文件」天生互斥,用 nix 提供的 Flutter 无法构建 macOS app。`devbox run` 处处包裹的体验也偏重。

## 决策

**全工具链由 [mise](https://mise.jdx.dev) 管理,移除 devbox/nix。** `mise.toml` 钉 `go = "1.25"` + `flutter = "3.41.9"`;mise 装的是**真·可写官方 SDK**（`flutter_macos_arm64_3.41.9-stable`,落 `~/.local/share/mise`,cache 可写）→ `lipo` 能写、构建通过。mise 不像 nix 注入编译器 wrapper,故 macOS 原生构建用**系统 Xcode 工具链**、环境干净。

- **版本钉死保留换机一致**（mise.toml,等价 devbox.lock 的角色）。
- **进目录自动激活**（fish 经 brew 自动;bash/zsh 加 `eval "$(mise activate <shell>)"`）→ go/flutter 直接上 PATH,**无 `devbox run` 包裹**。Makefile 用 `mise exec --`（不依赖 shell 激活）。
- 删 `devbox.json` / `devbox.lock` / `.devbox/`;`make setup` 改为装 mise + `mise install`;Makefile 全部 target 经 `mise exec --` 跑 go/flutter。
- macOS 真跑仍需完整 Xcode + CocoaPods（Apple 专有,任何工具链管理器都给不了）——这部分与 ADR 0004 一致。

## 取舍

**为何不选:**
- **devbox/nix 修补**（写可写 SDK 副本）:放弃。nixpkgs flutter 是「sdk-links」（符号链接进只读 store）,`cp -RL` 解引用 + chmod 既重又脆,且 wrapper 硬编码 nix `FLUTTER_ROOT`——治标不治本。
- **brew + fvm**:可行但 go 不钉版本（brew 给最新）、两个工具分管。mise 一个工具钉两者、DX 更佳。
- **保留 devbox 仅管 go + 官方 Flutter 管前端**:两套体系、心智重,且 devbox 体验本就是要弃的点。
- **官方 Flutter 用 git clone 直装**:可行但版本管理手搓;mise 钉版本 + 自动激活更省。

## 后果

- macOS 桌面 app **可构建可真跑**（验证:`flutter run -d macos` 出窗口、连本地后端 `/api/v1/health` 200）。
- 开发体验更轻:工具直接上 PATH,无 `devbox run --` 包裹。
- **状态文档同步**（本提交）:`CLAUDE.md` 前端节 + S22、`README`、`Makefile`、`.gitignore` 的 devbox 引用整体重述为 mise;ADR 0004 §工具链那一行由本篇 supersede（0004 不可变,不改）。
- **本 ADR 不可变**:后续调整新建 supersede 篇。
