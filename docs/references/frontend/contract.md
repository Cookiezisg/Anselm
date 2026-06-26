---
id: DOC-046
type: reference
status: active
owner: @weilin
created: 2026-06-26
reviewed: 2026-06-26
review-due: 2026-09-26
audience: [human, ai]
---

# 前端契约层 —— 后端线缆的 Dart 投影（`core/contract/`）

> 契约层 = **后端契约的逐字镜像**，非独立设计。所有 DTO 是 `references/backend/{api,database,events,error-codes}.md` + `domains/` 的 1:1 投影；后端改字段 → **同提交**改这里的 Dart DTO + golden（文档纪律延伸到前端契约，见 [`CLAUDE.md`](../../../CLAUDE.md) 前端节）。
> 分层位置见 [`architecture.md`](architecture.md) §2；envelope/paging/错误码契约依据 [`api.md`](../backend/api.md)（N 系列）+ [`error-codes.md`](../backend/error-codes.md)。

## 1. 一句话

后端是事实源，前端零业务规则。契约层只做**编解码**：freezed 不可变值类型 + json_serializable（`explicit_to_json: true`，嵌套对象序列化为对象而非 `toString`）。**线缆 camelCase**（N3）、**无 rename map**（唯一例外：`default` 保留字 → `defaultValue`）。

## 2. 物理结构

```
core/contract/
  api_error.dart           # N1 信封 + ApiException + AnselmErr（前端分支用的精选码常量）
  page.dart                # N4 keyset 分页:Page<T>（data 列表）+ PageWithAggregate<T,A>（data 对象:列表 + 聚合 sidecar）
  workspace.dart           # Workspace(+ ModelRef) —— 唯一鉴权轴实体
  entities/                # Quadrinity 实体 DTO(Phase 4.1 STEP 0,~22 类型)
    values.dart            # 跨域共享值类型 + NodeKind 封闭枚举
    function.dart          # FunctionEntity/Version/Execution + FunctionRunResult(bare)
    handler.dart           # HandlerEntity/Version/Call
    agent.dart             # AgentEntity/Version/Execution + InvokeResult(bare) + MountHealth(Report)
    workflow.dart          # WorkflowEntity/Version + Flowrun/FlowrunNode/FlowrunComposite
    common.dart            # ExecutionAggregates + CapabilityReport(跨域)
```

## 3. 信封 + 分页 + 错误（`api_error` · `page`）

- **N1 信封**：成功 `{data:...}`；失败 `{error:{code,message,details}}`。`ApiException.fromEnvelope(body, status)` 解错误体 → 持 `code`/`message`/`details`/`httpStatus` + 状态谓词（`isConflict`/`isGone`/`isUnauthorized`/`isNotFound`/`isTransport`）。`AnselmErr` 只登记**前端实际分支用的**精选码常量（`unauthNoWorkspace`/`unauthBadToken`/`seqTooOld`/`unknown`/`transport`）——~261 错误码全集**保持开放**，不在前端枚举（见契约开放性铁律）。
- **N4 分页**：分页坐标（`nextCursor`/`hasMore`）**永在 envelope 顶层、绝不进 `data`**。`Page<T>.fromBody` 解 `data` 为列表；`PageWithAggregate<T,A>.fromBody` 解 `data` 为对象（`{<listKey>:[...], <aggregate>}`），用于日志页（列表 + ok/failed 聚合）。`isLastPage` = `nextCursor` 缺失 ∨ `hasMore` false（防御性兼容两者不一致）。

## 4. 实体 DTO（`entities/`，Quadrinity 投影）

### 4.1 共享值类型（`values.dart`）

`Field`（typed I/O，`type` 粗粒度开放 String，后端不强校）· `ToolRef`（agent 工具挂载 `fn_…`/`hd_….method`/`mcp:…`）· `MethodSpec`（handler 方法）· `InitArgSpec`（handler `__init__` 配置项，带 required/sensitive/`default`）· `NodePosition`/`RetryConfig`/`Edge`/`Node`/`Graph`（workflow 图）。

**`NodeKind` 封闭枚举**（`trigger`/`action`/`agent`/`control`/`approval` + `unknown` 兜底）—— 5 图节点 kind 是真封闭集（合 CLAUDE.md「仅 seal 真封闭集」），`Node.kind` 用 `@JsonKey(unknownEnumValue: NodeKind.unknown)`，后端若扩集前端不崩。

### 4.2 四实体（function/handler/agent/workflow）

每实体三件套：**Entity**（公共头 `id`/`name`/`description`/`tags`/`activeVersionId`/时间戳 + 嵌入 `activeVersion`，bare-entity 规则）· **Version**（append-only 版本体）· **Execution/Call/Flowrun**（日志行）。差异：

| 实体 | Version 特有 | 日志行 | 实体头特有 |
|---|---|---|---|
| Function | `code` + I/O Fields + env mirror | `FunctionExecution`（`logs` 仅单 GET） | — |
| Handler | imports/init/shutdown/`methods`/`initArgsSchema` + env mirror | `HandlerCall`（+ `method`/`instanceId`） | `configState`/`missingConfig`/`runtimeState`（计算态） |
| Agent | `prompt`/`skill`/`knowledge`/`tools`/I/O/`modelOverride`(复用 `ModelRef`) | `AgentExecution`（+ `modelId`/`apiKeyId`/`provider`/`transcript`，**无 logs**） | — |
| Workflow | `graph`(raw JSON,真相) + `graphParsed`(解析 `Graph`) | `Flowrun`/`FlowrunNode`（record-once 记忆化行） | `active`/`lifecycleState`/`concurrency`/`needsAttention` |

- **Bare 执行结果**（同步动词直返、**不裹信封**）：`FunctionRunResult`（`:run`）· `InvokeResult`（`:invoke`，带 token/step 计数）。
- **复合解码**（非标准 bare-entity）：`FlowrunComposite` = `{flowrun, nodes, nextCursor}`（GET /flowruns/{id}）。

### 4.3 跨域（`common.dart`）

`ExecutionAggregates`（日志页 ok/failed 计数，随 `PageWithAggregate` 同行）· `CapabilityReport`（结构可运行性：`problems` 阻塞执行 / `warnings` 仅告知）。

## 5. 契约开放性铁律（seal 谁、不 seal 谁）

**仅 seal 真封闭集**（NodeKind 5 + unknown）。协议级**保持开放 + 字符串兜底**：错误码（~261，前端只精选常量）· `lifecycleState`/`concurrency`/`configState`/`runtimeState`/`envStatus`/`status` 等状态串（开放 String，不枚举）。理由：后端是唯一事实源，前端枚举状态串 = 给自己埋未来不兼容；开放 String + UI 层 `status_state` 折叠语义即可。

## 6. 纪律

- 改后端 DTO 字段/端点 → **同提交**改对应 Dart DTO + `entities_test.dart` golden（fromJson↔toJson key-equal）。
- codegen 产物（`*.freezed.dart`/`*.g.dart`）**入库**（源等价、deterministic，fresh checkout 直接 analyze）；`build.yaml` 把 freezed/json scope 限到 `contract/**` + `features/**/data/**`，`explicit_to_json: true`。
- 门禁 `make fe-verify`：codegen + `flutter analyze` 净 + `flutter test` 绿（含契约 golden）。
