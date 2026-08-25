# SURF-112 stage/memory investigation

## Scope

验收记忆舞台的完整产品路径：读取非置顶记忆、展示 slug/来源/摘要/正文；AI 更新一条用户已置顶记忆；用户通过 REST pin/unpin；确认舞台不伪造 pin 控件，AI 写入不改变用户策展和作者归属。

## Static contract

- `MemoryStageBody` 是只读记忆笺：右上显示 slug，正文按 live tail / settled 全文展示，落定后显示运行结果条。
- 图钉是用户特权，舞台不渲染 pin/unpin 控件；pin/unpin 只能走记忆 REST 面。
- `write_memory` 只接受 `name/description/content`，写入 source=ai 且不携带 pinned；更新已有记忆时，服务层必须保留既有 `Pinned` 与 `Source`。
- pin/unpin 是 frame-only 用户回声，不应凭空新增 inbox 审计行；内容更新才产生带 `inbox=true` 的 durable notification。

## Real run

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-103249`
- workspace: `ws_0297769b02459438`
- recording: `screen.mov`, finalized `257.440000s`, `2696x1720`, 60fps
- disposable data: `/private/tmp/anselm-data-surf112-20260825-r1`
- seed memories: `release-rule` (pinned=true, source=user) and `handoff-note` (pinned=false, source=ai)

### Positive paths

1. 真实 App 发送“只读取 handoff-note、只调用一次、不要写入/置顶/删除”。LLM wire 中只出现一次 `read_memory({"name":"handoff-note"})`；UI 先出现“已回忆 handoff-note · 1 行”，打开活动后记忆笺显示 slug、标题/摘要、来源和完整正文。卡片没有 pin/unpin 操作，符合 REST-only 边界。
2. 真实 App 发送更新 `release-rule` 的用户目的。模型先只调用一次 `search_tools("write memory")` 激活懒工具，随后只调用一次 `write_memory`，没有 retry、重复 mutation、post-delete/fetch 或其它记忆操作；最终舞台显示 `release-rule`、原摘要和新正文。
3. REST readback 在 AI 更新后证明：`description="Release rule"` 保持不变，`content` 为新正文，`pinned=true` 仍在，`source="user"` 仍在。第二条 `handoff-note` 未被改动。
4. 对 `handoff-note` 依次调用 `POST /pin`、`POST /unpin`。两次均 200，最终 GET 为 `pinned=false`；notifications witness 只收到两个 `memory.updated` frame-only 信号，没有 `inbox` 字段或额外 durable inbox 行。

## Five-channel evidence

- **Frame/UI**: 录屏和抽帧：`evidence/frames/surf112-memory-read.png`、`evidence/frames/surf112-memory-write-170.png`；AX 树确认 slug、正文、来源和“已记忆”/“已回忆”活动，未发现 pin 控件。
- **Backend**: `backend.log` 全程无 WARN/ERROR/panic/FATAL；REST GET 读回上述 pinned/source/description 真相。
- **SSE**: `sse.jsonl` 的 messages durable seq `1..36` 单调连续，notifications seq `16..22` 单调；memory created/updated 信号与 REST 变更对应，pin/unpin 没有 inbox 标记。
- **Frontend**: `frontend.log` 无 `ERROR`、`Exception`、`Unhandled`、`FlutterError` 或 assertion marker；仅保留 macOS IMK 系统噪声。
- **LLM wire**: `llm.jsonl` 及 `llm-bodies/` 保留真实请求；读取路径一次 `read_memory`，更新路径一次 `search_tools` 加一次 `write_memory`，响应全部 200。

## Negative / boundary facts

- 本轮没有执行 `forget_memory` 或 DELETE，避免把不可逆破坏误当作普通清理；fixture 位于独立临时数据目录，收台后由台架回收。
- 记录中的 `AI` 胶囊表示该活动由 AI 工具产生，不是对 durable memory `source` 的重写；source 的权威判定来自 REST readback 和服务层保留规则。

## Product verdict

用户能从自然语言读取并确认记忆全文；AI 更新不会破坏用户的置顶策展或作者归属；图钉动作有明确的用户专属 REST 边界，舞台不提供误导性控制。五通道事实一致，视觉卡片信息密度和层次稳定。本轮五级判定可进入账本。
