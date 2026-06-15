# Foryx

本地优先的 Agentic Workflow Platform — **Flutter 桌面 app**（macOS/Linux/Windows）+ Go 后端作 sidecar，单进程、单用户、SQLite 落盘，**不做 SaaS**。

核心心智:**Quadrinity 四项全能**（Function / Handler / Agent / Workflow）+ **Durable Execution**（节点结果记忆化 + 解释器幂等重走）。

## 快速开始

```bash
make setup             # 首次:装 mise（pin 的 go + flutter）
make server            # 起后端（FORYX_DEV，:8742）
# 另开一个终端跑前端（dev 挂到已跑后端）:
make fe-gen            # 首次/改注解后:codegen（freezed/json/slang）
make fe-run            # 起桌面 app（FORYX_BACKEND_URL 挂到 :8742）
```

mise 进仓库目录自动激活（fish 自动;bash/zsh 把 `eval "$(mise activate <shell>)"` 加进 profile），go/flutter 直接上 PATH。
> macOS 桌面真跑需完整 Xcode + CocoaPods（Apple 工具链,任何版本管理器都给不了）。

## 命令

```bash
# 后端
make server      # 起后端服务（:8742）
make stop        # SIGTERM 优雅关停
make unit        # Go 单测
make testend     # 全功能黑盒验收（真二进制 + llmmock，分钟级）
make docs        # 文档规范门禁（GOVERNANCE §11）
make build       # 后端二进制 → backend/bin/foryx-server
make verify      # 后端 pre-push（gofmt+vet+build+unit+docs）

# 前端（Flutter）
make fe-gen      # codegen（freezed/json_serializable/slang）
make fe-analyze  # flutter analyze
make fe-test     # flutter 单测
make fe-verify   # 前端 pre-push（gen + analyze + test）

make clean       # 清 dev 数据目录
```

## 环境一致性

| 文件 | 钉的内容 |
|---|---|
| `mise.toml` | 工具链版本（go 1.25 / flutter 3.41.9）|
| `backend/go.mod` | Go 依赖 |
| `frontend/pubspec.lock` | Flutter/Dart 依赖 |

升级:改对应文件 → `mise install`（或 `flutter pub upgrade`）→ 提交。

## 文档

- 文档入口:[`docs/INDEX.md`](docs/INDEX.md)
- 愿景 / 架构 / 实体 / 引擎 / 路线:[`docs/concepts/architecture.md`](docs/concepts/architecture.md)
- 后端总览(第 0 篇):[`docs/references/backend/overview.md`](docs/references/backend/overview.md)
- 架构决策(ADR):[`docs/decisions/`](docs/decisions/)（含 [0004 前端 Flutter 架构](docs/decisions/0004-frontend-flutter-architecture.md) · [0005 工具链 mise](docs/decisions/0005-toolchain-mise.md)）
- 工程纪律:[`CLAUDE.md`](CLAUDE.md)
