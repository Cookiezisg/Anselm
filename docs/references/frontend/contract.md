---
id: DOC-046
type: reference
status: active
owner: @weilin
created: 2026-06-26
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# 前端契约层——后端线缆的 Dart 投影

> `frontend/lib/core/contract/` 只做编解码，不是第二套业务模型。后端权威见 [`api.md`](../backend/api.md)、[`events.md`](../backend/events.md)、[`error-codes.md`](../backend/error-codes.md) 与各 domain reference。

## 1. 边界

- 后端 JSON 使用 camelCase；Dart 以 `freezed` + `json_serializable` 生成不可变 DTO。
- 后端字段变化必须在同一提交更新 Dart 源 DTO、生成物与 golden。
- `ApiClient` 统一处理 N1 `{data: ...}` 信封与标准错误；feature repository 不重复解包逻辑。
- DTO 只表达 wire 形状。状态折叠、文案、颜色、按钮可用性等属于 feature/core model。

## 2. 物理地图

| 路径 | 主要投影 |
|---|---|
| `api_error.dart` | `ApiException`、标准错误 envelope、前端确需分支的精选错误码 |
| `page.dart` | keyset `Page<T>`、带聚合的 `PageWithAggregate<T,A>` |
| `workspace.dart` | Workspace、ModelRef 与 workspace 设置轴 |
| `conversation.dart` | 对话 rail 行、模型覆盖、分叉血缘、驻地/分支/worktree 投影 |
| `attachment.dart` | 附件元数据与 preparation 状态 |
| `interaction.dart` | danger/ask/approval 人在环请求与 resolved 投影 |
| `notification.dart` | durable notification 行；Broadcast 不在此出现 |
| `messages/` | REST ChatMessage/ChatBlock、流式 block content、transcript window/anchor |
| `entities/` | Function、Handler、Agent、Workflow、Control、Approval、Trigger、Document、Skill、Relation、Scheduler/Flowrun |
| `api_key.dart`、`model_capability.dart` | provider credential 元数据与模型能力/knob |
| `mcp.dart`、`memory.dart`、`sandbox.dart` | Settings 资源面 |
| `limits.dart`、`network.dart`、`retention.dart` | schema/系统设置 |
| `todo.dart`、`touchpoint.dart` | Chat 右岛与任务投影 |

生成的 `*.freezed.dart` / `*.g.dart` 与源文件一起入库，但不可手改。

## 3. 信封与分页

- 标准成功响应经 N1 `{data: ...}`；同步 run/call/invoke 也不例外。
- 列表默认使用 N4 keyset：`data`、`nextCursor`、`hasMore`。
- 带统计的列表把 rows 与 aggregate 放在 data 对象内，使用 `PageWithAggregate`。
- `GET /flowruns` 另有与 cursor 互斥的 offset/total 模式；两种 envelope 不混解。
- `FlowrunComposite` 是明确登记的复合投影：flowrun、nodes、分页坐标，以及工具封顶形态可能携带的 node summary。
- transcript around window 的坐标与 `data` 并列，必须用专用 envelope 解码，不能经只取 `data` 的 helper。

## 4. 开放与封闭

只把协议明确封闭且有 unknown fallback 的集合做 Dart enum，例如 node kind、trigger source、firing status。以下保持开放 String：

- 错误码全集；
- notification type；
- lifecycle/runtime/config/status 字段；
- Chat block 的未来类型与 marker kind；
- provider、模型与 MCP 扩展词表。

UI 通过纯映射把开放值折叠为已知语义；未知值必须可降级显示或安全缺席，不能因客户端枚举过期而解码失败。

## 5. 消息、版本与实时

- REST `ChatMessage`/`ChatBlock` 与 SSE block content 是同一持久真相的两种读形态。
- `tool_call` close 代表参数完整；`tool_result` close 才代表 Execute 结束。
- `compaction` 与 `marker` 是持久行，不一定经 live block 流到达。
- retry/edit 追加新消息并以 `attrs.retryOf`/`supersededBy` 建版本链；旧消息仍可读取。
- `messages`、`entities`、`notifications` 三条 SSE 的帧形在 `core/sse`，不在每个 DTO 重复定义。
- `seq>0` 才能推进 durable 水位；`seq=0` 只用于 delta/tick/interaction 等瞬时投影。

## 6. 高风险投影

- `Conversation.modelOverride` 的 PATCH 是三态：缺键不改、对象设值、显式 null 清除；`workDir` 则用空字符串表示卸载。
- `WorkDirInfo` 是逐请求活投影；路径存在性、git branch、dirty、branches/worktrees 不能从 Conversation 行猜。
- `AttachmentPreparation` 只说明模型代理准备度，不是“附件是否允许发送”的门。
- workflow 历史图必须读 flowrun 钉住的 version id；当前 active version 不能替代。
- Trigger 无版本；`listening` 是 active workflow 引用造成的真实热 listener，`nextFireAt` 只在
  可解析 cron **正在监听且未暂停**时出现。冷态或 paused 的 trigger 不会产生未来事件，前端不得把
  数学上的 cron 刻度渲染成即将执行。
- Relation kind 与端点 kind 是开放产品图词表，前端不得假设只含 rail 七类。
- provider secret 只写不回；DTO 只能携带掩码元数据，不能把密钥留在普通 state。

## 7. 门禁

- contract golden 校验 `fromJson → toJson` 的 key/形状对齐。
- `make -C frontend verify` 运行 codegen、analyze 与全部契约/feature 测试。
- 文档漂移门禁只检查显式锚定且能与同名 Go struct 配对的 DTO；未锚定项仍需人工按本篇地图复核，不能把 warning 当全覆盖证明。
