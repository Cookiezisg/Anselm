# Anselm

本地优先的 Agentic Workflow Platform — **Flutter 桌面 app**（macOS/Linux/Windows）+ Go 后端作 sidecar，单进程、单用户、SQLite 落盘，**不做 SaaS**。

核心心智:**Quadrinity 四项全能**（Function / Handler / Agent / Workflow）+ **Durable Execution**（节点结果记忆化 + 解释器幂等重走）。

## 快速开始

```bash
make setup             # 首次：安装 mise，并准备 Go / Flutter / Node / Playwright 的锁定依赖
make verify            # 全仓门禁：后端 + 前端 + 文档 + web demo
make -C frontend app   # 起桌面 app；自动起或复用本地后端
```

`make setup` 可重复运行。它使用 [mise](https://mise.jdx.dev/) 固定 Go、Flutter 和 Node；普通命令也会自动恢复本目录缺失的依赖，因此 `make clean` 后可直接继续 `make verify` 或日常开发。

> macOS 桌面真跑仍需完整 Xcode + CocoaPods（Apple 工具链，不由版本管理器安装）。执行 `make doctor` 查看本机前置条件。

## 命令

```bash
# 根目录：全仓操作
make setup                 # 准备全部锁定工具与依赖
make verify                # 后端 + 前端 + 文档 + web demo
make clean                 # 清全部可再生产物；不动源码、Git、全局缓存或用户数据
make doctor                # 检查 Flutter 原生桌面环境

# 后端
make -C backend run        # 起后端服务（:8742）
make -C backend stop       # SIGTERM 优雅关停
make -C backend format     # 写入 gofmt 格式
make -C backend verify     # 格式检查 + vet + build + unit tests
make -C backend testend    # 全功能黑盒验收（真二进制 + llmmock，分钟级）

# 前端（Flutter）
make -C frontend app       # 真 app + 真后端
make -C frontend demo      # fixture demo
make -C frontend gallery   # 组件画廊
make -C frontend verify    # codegen + analyze + test

# 文档与 web demo
make -C docs verify        # 文档规范门禁（GOVERNANCE §11）
make -C demo verify        # demo lint + Playwright matrix
```

## 环境一致性

| 文件 | 钉的内容 |
|---|---|
| `mise.toml` | 工具链版本（Go / Flutter / Node LTS）|
| `backend/go.mod` | Go 依赖 |
| `testend/go.mod` | 黑盒验收的独立 Go 依赖 |
| `frontend/pubspec.lock` | Flutter/Dart 依赖 |
| `demo/package-lock.json` | web demo 的 Node / Playwright 依赖 |

升级:改对应文件 → `mise install`（或 `flutter pub upgrade`）→ 提交。

## 文档

- 文档入口:[`docs/INDEX.md`](docs/INDEX.md)
- 愿景 / 架构 / 实体 / 引擎 / 路线:[`docs/concepts/architecture.md`](docs/concepts/architecture.md)
- 后端总览(第 0 篇):[`docs/references/backend/overview.md`](docs/references/backend/overview.md)
- 架构决策(ADR):[`docs/decisions/`](docs/decisions/)（含 [0004 前端 Flutter 架构](docs/decisions/0004-frontend-flutter-architecture.md) · [0005 工具链 mise](docs/decisions/0005-toolchain-mise.md)）
- 工程纪律:[`CLAUDE.md`](CLAUDE.md)
