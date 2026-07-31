# Web Demo 覆盖边界

本页只登记 `demo/` **实际可浏览和被 Playwright 覆盖的静态 surface**。它不是
Anselm 产品能力清单；当前产品能力见
[`frontend overview`](../docs/references/frontend/overview.md) 和各 feature reference。

## 已装配 surface

| Surface | 静态入口 | 数据与交互边界 |
|---|---|---|
| Chat | `features/chat/` | mock transcript、composer、右岛样本 |
| Entities | `features/entities/` | mock 实体登记、详情、动作与版本样本 |
| Scheduler | `features/scheduler/` | mock run board、图与节点调试样本 |
| Documents | `features/documents/` | 旧文档原型；当前 Flutter 对应 Library |
| Settings | `features/settings/` | mock 设置分类与 provider 样本 |
| Notifications | `features/notifications/rail.js` | 只有 rail / inbox 原型，没有独立 sea |
| Onboarding | `features/onboarding/onboarding.html` | 独立静态流程 |
| Graph editor | `features/graph-editor/` | mock workflow 图编辑交互 |
| Component reference | `features/reference/` | specimen catalog 与 stress cases |

所有数据都是固定 fixture。即使页面可操作，也不代表真实 HTTP、SSE、持久化、
错误恢复、权限或 provider 行为已经在此验证。

## 自动门禁覆盖

`make -C demo verify` 当前检查：

1. demo 源码规则与 token 使用；
2. `reference.html` catalog 非空；
3. 每个 specimen 的 console error、视口/格内溢出和危险注入；
4. `app.html` 壳加载与横向溢出；
5. settings 与 onboarding 活页 smoke；
6. disabled keyboard、dialog 内容转义等命令式专项。

该门禁只保护 web demo 自己。Flutter 当前门禁是 `make -C frontend verify`，后端
黑盒验收是 `make -C backend testend`。

## 变更纪律

- `core/manifest.js` 是 surface 装配清单；新增/删除 surface 时同步本页。
- `features/reference/catalog.js` 与 `catalog-stress.js` 是 specimen 清单；变更
  primitive 覆盖时同步 [`PATTERNS.md`](PATTERNS.md)。
- 规划项不进入本页。尚未实现的想法放 issue 或真正 active working 文档。
