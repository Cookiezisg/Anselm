---
id: DOC-011
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# Function

## 1. 定位

Function 是用户构建的无状态 Python callable。每次调用在隔离进程中执行，进程
结束后不保留内存状态。需要跨调用共享状态时使用 Handler。

```text
Function row
→ immutable Version(code + schema + deps + env mirror)
→ isolated Run
→ terminal Execution audit
```

## 2. 实体与版本

主行只保存身份、标签和 `active_version_id`；代码、inputs、outputs、依赖、
Python 版本与 env 状态都在不可变 Version 上。

- Edit 将 ops 应用于 active draft，写 `max(version)+1` 并切 active pointer；
- Revert 只移动 pointer，不复制或重排版本；
- 每个版本有独立 `fnenv_` env，owner key 为 `functionID_envID`；
- Version 镜像 `pending|syncing|ready|failed`、错误与同步时间；
- 版本保留上限触发 trim 时，active version 不删，被裁版本的 env 最佳努力回收。

活实体名称由数据库 partial unique 约束；软删后名称可复用。Name 是代码实体
使用的受限 slug，不是自由展示文本；实际 Python 入口仍由首个顶层 `def` 决定。

## 3. 构建

Function 的唯一变更词汇是 ops：

```text
set_meta
set_code
set_inputs
set_outputs
set_dependencies
set_python_version
```

LLM 工具、HTTP `:edit` 与直接 create 最终都进入 `ApplyOps`。每个 op 后做增量
校验，完成后做终校验。工具输入可经过 JSON repair；非法 op 与非法最终代码
仍分别大声失败。

代码校验是轻量词法边界：必须存在顶层 `def`，首个顶层函数是入口；禁止导入
Handler SDK，以保持无状态/有状态执行边界。

Env 物化由 envfix 负责，状态与尝试过程写回 Version 并流到 entities build
终端。依赖修复不能通过减少声明包数量来制造假 ready。构建允许 env failed，
调用时则必须 ready。空 ops 表示重建 active env，不铸新版本。

## 4. 运行

所有入口汇入 `RunFunction`：

1. 解析指定 version，未指定则取 active；
2. 非 ready env 按需物化；
3. nil input 归一为 `{}`；
4. 在全局 Function wall-clock 内运行隔离进程；
5. env 被外部 GC 后，按版本快照重建并重试一次；
6. 在 detached workspace context 写终态 Execution。

调用来源为 `chat|agent|workflow|manual`。Conversation、message、tool-call、
flowrun、node 与 iteration 溯源从 request context 写入执行行。状态为
`ok|failed|cancelled|timeout`；超时向调用方返回 `FUNCTION_RUN_TIMEOUT`，
与审计记录保持同义。

Driver 在运行期间把用户 `print()` 导向 stderr，真实 stdout 只承载 JSON
结果。stderr 同时进入 Chat tool progress、Entities run terminal 与有界日志；
单条 Get 返回 logs，列表不复制大日志。

## 5. 媒体产物

每次运行获得一个空临时目录，同时作为 cwd 和 `$ANSELM_OUT`，结束后删除。
代码在返回值中显式声明：

```json
{"chart": {"$media": "chart.png"}}
```

采集器在原位置替换为 MediaRef receipt，保留 `chart` 这一业务字段，不扫描目录
猜测产物。路径必须位于输出目录；单件大小、单次引用数与 MIME 类型均受统一
限制。拒绝某个产物只写运行日志，声明原样保留，不推翻其余正确计算结果。

Function 与 Handler 共用 `app/mediaartifact`；attachment uploader 未装配时，
声明原样通过。

## 6. 删除与投影

Delete 软删主行、清 relation，并最佳努力销毁该 Function 的 env 和代码目录。主行与动作**不可恢复**；
`delete_function` 具有不可绕过的静态 `dangerous` 下限，即使模型自报 `safe` 也必须先经过 HumanLoop
用户批准，且不能被 skill 或 `approve_always` 预授权绕过。
Version 与 Execution 的耐久边界见 [`database.md`](../database.md)。

Function 通过以下投影进入产品：

- Catalog：name + description；
- Mention：description + active code；
- Relation：构建/编辑来源与调用触碰；
- Agent mount：`fn_<id>` 合成为以当前 Function 名命名的绑定工具；
- Workflow action、Chat、HTTP 与 Sensor 都调用同一 `RunFunction`。

## 7. 契约

精确端点见 [`api.md`](../api.md)，表见
[`database.md`](../database.md)，错误见
[`error-codes.md`](../error-codes.md)，事件见
[`events.md`](../events.md)。ID：`fn_`、`fnv_`、`fne_`；env：`fnenv_`。

LLM 工具覆盖搜索、读取、构建、revert、删除、运行和 Execution 查询。
`update_function_meta` 只改主行，不铸版本或重建 env。
