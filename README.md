# Anselm

Anselm 是本地优先的 Agentic Workflow Platform：Flutter 桌面客户端运行于
macOS、Linux 和 Windows，Go 后端作为单用户 sidecar，业务数据落在 SQLite
与 workspace 文件目录中。Function、Handler、Agent、Workflow 组成
Quadrinity；Durable Execution 以节点结果记忆化和解释器幂等重走实现。

本地 sidecar 持有产品与用户数据真相；已部署的 Anselm API 提供受管模型和媒体
能力。用户也可以配置 BYOK。完整边界见
[`managed-gateway.md`](docs/references/backend/managed-gateway.md)。

## 快速开始

```bash
make setup
make verify
make -C frontend app
```

`make setup` 安装或复用 mise，并准备锁定的 Go、Flutter、Node 与 Playwright
依赖。macOS 桌面真跑仍需要完整 Xcode；执行 `make doctor` 检查原生宿主前置条件。

## 仓库地图

| 路径 | 责任 |
|---|---|
| `backend/` | Go sidecar、HTTP/SSE、业务应用层、domain、infra/store |
| `frontend/` | Flutter 产品、共享地基、六个 feature 与三平台宿主 |
| `testend/` | 独立 Go module，通过真实二进制与 HTTP/SSE 做黑盒验收 |
| `docs/` | current reference、concept、ADR、how-to、working 与 archive |
| `demo/` | 独立静态 Web 原型与 Playwright 回归资产，不是当前产品事实源 |

## 常用命令

```bash
# 全仓
make setup
make verify
make clean
make doctor

# 后端
make -C backend run
make -C backend seed
make -C backend verify
make -C backend testend

# Flutter
make -C frontend quick
make -C frontend verify
make -C frontend gallery
make -C frontend demo
make -C frontend app

# 文档与静态 web demo
make -C docs verify
make -C demo verify
```

`make verify` 包含 backend、frontend、docs 与 web demo 四个静态/单元门禁，但
不运行分钟级 `testend`，也不会调用真实模型。真实模型验收必须显式运行
`make -C backend evals`；它会消耗额度，并只读取调用环境或根 `.env` 中的凭据。

工具链版本由 `mise.toml` 固定；依赖锁分别位于 `backend/go.mod`、
`testend/go.mod`、`frontend/pubspec.lock` 与 `demo/package-lock.json`。

## 文档入口

- 工程纪律：[`CLAUDE.md`](CLAUDE.md)
- 文档导航：[`docs/INDEX.md`](docs/INDEX.md)
- 系统架构：[`docs/concepts/architecture.md`](docs/concepts/architecture.md)
- 后端：[`docs/references/backend/overview.md`](docs/references/backend/overview.md)
- 前端：[`docs/references/frontend/overview.md`](docs/references/frontend/overview.md)
- 文档治理：[`docs/GOVERNANCE.md`](docs/GOVERNANCE.md)
