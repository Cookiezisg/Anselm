# Round 0013 — SSE 三流统一协议 domain（波次 0 · M0.4）

类型 / 目标：把三条 SSE 流从「各长各的异构事件协议」重构为「统一的流式树协议」的 domain 层。改名 + 语义升级 + 统一数据结构。设计蓝本 = `stream-protocol.md`。

考古发现（重构动机）：
- 三流数据结构异构：eventlog 5 强类型事件 / forge 4 强类型事件 / notifications 1 弱类型 `Event{type,id,data}`；但骨子里都是「对一棵渲染树的增量操作流（open→delta→child→close）」，notifications 是其退化（瞬时单点）。
- 三个 infra Bridge 95% 同构三抄（seq+环形buffer+扇出），只差元素类型/buffer 大小/notif 多 2 方法 → M0.5 收敛单一 Bus。
- pkg/* 是 producer 辅助层（非残留）；旧 `forge→eventlog` domain→domain 边 = 共享 Scope。

设计（与作者深度讨论后定稿）：
- **传输/语义正交分解**：三流共享信封 + 四动词（Frame），各流只定义 Node 词表。
- 信封：`Envelope{Seq; Event{Scope, ID, Frame}}`——**ID 升信封层**（节点身份 universal，四帧都有；与 `Open.ParentID`「挂哪」正交）；Event/Envelope 两层 = seq 所有权边界（producer 草稿 vs bus 成品）。
- Frame 四动词封闭联合 `Open/Delta/Close/Signal` + `Durable()` **可丢性分级**：delta=ephemeral（不入 buffer）/ open·close·非ephemeral signal=durable（入 buffer，`Close.Result` 带快照作重连真相）→ token 级 delta 永不撑爆 replay。
- Node 判别联合（`NodeType()` 线缆判别）：messages 7 词（message/text/reasoning/tool_call/tool_result/progress/compaction）· entities 4 词（forge/run/env_attempt/terminal）· notifications 3 词（entity_changed/flowrun_tick/flowrun_lifecycle）。
- Node 是 interface → 跨流复用免费、流包之间无 import（双输出免费的根由）。
- Bridge：`stream.Bridge`(Publish/Subscribe) 通用端口；三流 thin 接口供强类型 DI；notifications 额外 `List`（REST 快照，无 DB 落盘读内存 buffer）。

落地（4 包 12 源 + 6 测试）：
- `domain/stream`：event/scope/node/frame/bridge/validate.go（协议核心，纯 stdlib）。
- `domain/messages`·`domain/entities`·`domain/notifications`：各 nodes.go(词表) + bridge.go(thin 端口)。
- domain→domain 仅一条边：三流 → stream（指向协议核心）。entities **不** import messages（node 复用在 producer 层）。

测试：18 文件中 6 测试 — frame 可丢性分级（5 例）、ValidateEvent 通用不变量（合法 6 / 非法 6，errors.Is ErrInvalidEvent）、scope String+IsValidKind、三流 NodeType（顺带 `[]stream.Node` 编译期证 node 实现接口）。

验证：`gofmt -l` 空 / `go build ./...` / `go vet` / `go test`（4 包）全绿。

是否更干净：✅ 三流数据结构标准化统一；marshal/线缆形状（判别字段注入）留 M0.7 transport（形状已在 stream-protocol.md 定义，domain 保持纯净不碰序列化）。

覆盖状态：三流 domain 重建完成。infra bus（单一 Bus×3 实例 + frame 分级 buffer + scope）= M0.5；producer 辅助统一 `pkg/streamemit` + ~20 目录 emit 改造 + messages DB 落盘随 chat + 对外契约重写 → deps-todo（R0013 节）。

下一步：M0.5 `infra/stream`（单一 `Bus` 实现）+ `infra/chat`。
