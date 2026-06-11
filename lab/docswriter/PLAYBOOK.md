# docswriter PLAYBOOK —— 每篇文档四步循环

> 一轮 = 一个模块（或一组紧密相关的小模块）。严格四步，不跳。每轮记 `target/rounds/NNNN/round.md`，更新 `STATE.md` / `ROUNDS.md`。

## ① 读码（代码是真相）

读这个模块的**全部**代码，建立完整事实：
- `domain/<m>/`：实体 struct、Repository 接口、领域错误、规则、ID 前缀。
- `app/<m>/`：Service 方法、生命周期、跨域端口、关键流程。
- `infra/store/<m>/`：表 schema、索引、CHECK/UNIQUE。
- `transport/httpapi/handlers/<m>.go`：端点、动词、请求/响应形状。
- `app/tool/<m>/`（若有）：LLM 工具。

抓出该模块的：**端点集 · 表集 · 错误码集 · 事件集 · ID 前缀 · 心智模型 · 关键取舍 · relation 边**。

## ② 写 module 文档（`domains/<m>.md`，骨架 + Why）

按 `skeleton.md` 7 节写。海拔 = **设计/为什么**：
- 定位、心智模型、物理模型（设计取舍，schema 引 database.md）、生命周期/行为、关键设计决策、契约（**引用** 4 索引、不重列）、跨域集成。
- **只写 Why、不写 What**；高密度、表格优先；零历史。

## ③ 同步 4 索引（单一枚举）

把该模块的枚举写进对应索引（**每条只此一处**）：
- 端点 → `api.md`（method/path → handler / 一句语义）。
- 表 + 列 + 索引 + ID 前缀 → `database.md`。
- 错误码 → `error-codes.md`（Go sentinel → wire code → HTTP → 场景）。
- 事件 → `events.md`（若该模块是 SSE producer）。

索引条目**对码逐字**（端点 = 真实路由；码 = 真实 sentinel）。

## ④ 验证（parity + 门禁）

- `make docs` 绿（frontmatter / 链接 / INDEX≤50）。
- **parity 抽查**：本模块的端点/表/码，逐条回代码核对——枚举无缺、无多、无错。
- module 文档的「契约」节引用的索引锚点都存在。
- 提交：**同一提交**含 module 文档 + 索引增量 + round.md。commit message 记本轮模块 + parity 结论。

## 跨模块依赖

写某模块时若它的契约依赖另一个还没写的模块（如 workflow 引用 trigger/control/approval），**先占位引用**（写「见 trigger.md」），到那个模块轮次补实。`order.md` 的波次序已尽量让依赖先行。
