# Anselm Frontend

Anselm 的 Flutter 桌面客户端。Go 后端以 localhost sidecar 运行并持有业务真相；本目录负责桌面壳、交互状态、Dart 契约投影与 macOS/Linux/Windows 原生宿主。

## 从哪里读

| 目标 | 入口 |
|---|---|
| 前端整体心智 | [`docs/references/frontend/overview.md`](../docs/references/frontend/overview.md) |
| 目录、分层、路由、装配 | [`docs/references/frontend/architecture.md`](../docs/references/frontend/architecture.md) |
| 设计令牌与 `An*` 原语 | [`docs/references/frontend/design-system.md`](../docs/references/frontend/design-system.md) |
| 后端 DTO 的 Dart 投影 | [`docs/references/frontend/contract.md`](../docs/references/frontend/contract.md) |
| 平台与 sidecar 能力 | [`docs/references/frontend/platform.md`](../docs/references/frontend/platform.md) |
| Chat / Entities / Library / Scheduler 等当前形态 | [`docs/references/frontend/features/`](../docs/references/frontend/features/) |

## 目录

| 路径 | 归属 |
|---|---|
| `lib/app/` | DI、路由、启动门控、唯一 `AppShell` |
| `lib/core/` | contract/net/SSE/process、design/UI、media/editor、平台适配与纯模型 |
| `lib/features/` | `chat`、`entities`、`library`、`notifications`、`scheduler`、`settings` |
| `lib/dev/` | gallery 与本地开发入口 |
| `lib/i18n/` | slang 源文案与生成代码 |
| `test/` | core、feature、gallery 与 guard 测试 |
| `third_party/` | 经 ADR 决定维护的 vendored 依赖 |
| `macos/`、`linux/`、`windows/` | Flutter 原生桌面宿主 |

## 命令

```bash
make setup       # 拉取锁定依赖
make quick       # diff 驱动的开发内环
make verify      # codegen + analyze + 分组测试
make gallery     # 原语目录
make demo        # 真壳 + fixtures
make app         # 真壳 + sidecar
make shots       # 无头截图
```

普通命令会恢复缺失依赖。默认设备是 macOS；可用 `DEVICE=<flutter-device>` 指定其他已安装桌面目标。macOS 宿主使用 Swift Package Manager，不需要 CocoaPods。
