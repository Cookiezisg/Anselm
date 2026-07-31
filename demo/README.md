# Anselm Web Demo

`demo/` 是不连接后端的静态 Web Components 原型与视觉回归资产。它保存 Flutter
重建之前形成的交互样本、组件压力样本和 Playwright 矩阵，但**不是当前产品、
前端架构或后端契约的事实源**。

当前产品事实从以下入口读取：

- Flutter 产品与路由：[`docs/references/frontend/overview.md`](../docs/references/frontend/overview.md)
- 设计系统：[`docs/references/frontend/design-system.md`](../docs/references/frontend/design-system.md)
- 后端 HTTP / DTO：[`docs/references/backend/api.md`](../docs/references/backend/api.md)

## 当前用途

| 入口 | 用途 |
|---|---|
| `app.html` | 用固定 mock 数据浏览三岛壳和历史产品原型 |
| `reference.html` | 浏览 `core/primitives/` 的 specimen 与压力态 |
| `features/onboarding/onboarding.html` | 独立 onboarding 原型 |
| `make -C demo verify` | 运行源码 lint、reference 矩阵、app/settings/onboarding smoke 与安全专项 |

demo 不发真实 HTTP，不消费真实 SSE，也不证明 Flutter 已实现同名交互。需要验证当前
桌面产品时，使用 `make -C frontend gallery`、`make -C frontend demo` 或
`make -C frontend app`。

## 物理结构

```text
demo/
├── app.html                     # 静态产品原型入口
├── reference.html               # 组件 specimen 入口
├── core/
│   ├── tokens.css               # web demo token
│   ├── base.js                  # Web Component 基类
│   ├── primitives/              # 50 个历史原语 / 复合件
│   ├── config/                  # demo 枚举与状态映射
│   ├── schema/                  # demo 声明式实体投影
│   ├── manifest.js              # 原型 surface 注册
│   └── app.js, shell.js, ...    # 静态装配与三岛壳
├── features/                    # mock surface 与 reference catalog
└── tools/                       # serve、lint、Playwright matrix
```

`core/manifest.js` 当前登记 chat、entities、scheduler、documents、settings、
notifications、onboarding 与 graph-editor。这里的 `documents` 是旧原型命名；
当前 Flutter 产品面叫 Library。

## 使用

```bash
make -C demo setup
make -C demo serve
make -C demo verify
make -C demo clean
```

依赖由根目录 `mise.toml` 与 `demo/package-lock.json` 锁定。`verify` 会自起隔离
HTTP server，并使用与 lockfile 匹配的 Chromium。

## 修改边界

- 修 demo 自身回归或保留原型证据时，可直接修改本目录并同步本页。
- 产品事实、Flutter 组件契约与路由变化，不要求机械同步这套历史 Web 实现。
- 不从 demo 的 mock、旧 provider 名、阶段标记或像素值反推当前产品能力。
- 新增 demo primitive 时同步 [`PATTERNS.md`](PATTERNS.md)；改变 demo surface
  覆盖时同步 [`CAPABILITY.md`](CAPABILITY.md)。
