---
id: DOC-068
type: reference
status: active
owner: @weilin
created: 2026-07-31
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# Feature：Chat（对话海洋）—— 当前形态

> 本篇只描述 `frontend/lib/features/chat/` 的当前产品面。后端线缆见 [`conversation.md`](../../backend/domains/conversation.md)、[`chat.md`](../../backend/domains/chat.md)、[`messages.md`](../../backend/domains/messages.md) 与 [`attachment.md`](../../backend/domains/attachment.md)；右岛侧幕见 [`chat-sidestage.md`](chat-sidestage.md)。

## 1. 产品面

| 面 | 当前事实 |
|---|---|
| 左岛 rail | 新对话与搜索、置顶、按驻地分组、最近对话；服务端分页、搜索、驻地计数和批量归档/删除；行级重命名、置顶、归档、删除 |
| 中心 transcript | REST 水化 + `messages` SSE 增量合并；终态、在飞、乐观回声三层；老页向上加载不跳位；流式跟随可脱离和归队 |
| Composer | 文本、`@` 提及、文件选择/粘贴/拖放附件、模型选择；发送与停止；生成中 Enter 入队，队列可编辑、删除和取回 |
| 回合操作 | 复制整回合、分叉、重试换模型、编辑重发、同一逻辑回合的版本翻页；历史版本仍可读，不把 `superseded_by` 当软删 |
| 驻地 | 对话可挂工作目录；三态入口；在访达/终端打开、切换/退出驻地、切分支、新建分支、创建 worktree；脏区切分支直接拒绝 |
| 工具与人在环 | 工具卡按工具族渲染，默认收起；失败与交互门自动展开；坏参数也必须安全降级并显示后端错误，不能把 transcript widget 树打崩，也不能因此回显敏感参数；危险调用、提问与审批都走同一 interaction broker；`replay_flowrun` 被后端拒绝时明确显示“未执行重放”，不得沿用“已重放运行”；可空 query 的实体搜索才可切到“列”声道，`search_documents` 的 query 必填，畸形空参数必须仍显示“搜索失败”；`delete_document` 的 not-found completed 软失败必须显示失败动词与原始证据，不得显示“已删除”或“软删除,可恢复”；终局拒绝后的重复工具调用保留在线缆与 durable 证据，但不在 transcript 追加第二条“未执行”噪音卡 |
| 右岛 | 触点台账 + 流式侧幕；只在存在 Activity 时可揭示，详见 [`chat-sidestage.md`](chat-sidestage.md) |

## 2. 数据与状态边界

- `ChatRepository` 是唯一数据缝；`LiveChatRepository` 接 HTTP/SSE，`FixtureChatRepository` 驱动 demo 与测试，两者保持同一契约形状。普通发送成功后若首条 user SSE 回声因新线程订阅竞态丢失，transcript 用 REST 头做窄对账，不让耐久 user 行与 optimistic bubble 同时可见；若 durable 回声在 REST 水化期间进入 prelude，且同一 block 已落在 `settled`，跨层 idempotency 会跳过它，不把同一回合再折进 `live`；失败气泡的 retry 保持同一气泡，仍由 SSE/重同步收口。
- 侧幕失败丝带按动作语义分流：`create_*` 只说明未创建实体，`edit_*` 才说明上一版仍是真相，执行类工具（例如 `invoke_agent`、`run_function`、`call_handler`）只说明运行失败并指向下方错误；执行失败不得复用草稿/版本文案。`edit_approval` 失败时，侧幕与中心工具卡都必须明确上一版仍有效，禁止把未保存 payload 渲染成带批准/拒绝按钮的审批预览。
- 对话列表、当前选区、transcript、草稿、附件准备、队列、interaction、驻地与侧幕分别持有最小状态；跨面只经 provider 或路由意图，不让 widget 互相持有。
- **DB 行是真相、流只为实时**：`seq>0` 的 durable 帧可推进水位；`seq=0` 的 delta/tick/interaction 只改瞬时态。410 后重取 REST，再从新水位续流。
- 流式正文与活尾的视觉树可以逐帧替换，但 macOS AX 只暴露一个稳定的外层语义节点；流式期间不把半成品 markdown 子节点交给读屏，落定后恢复完整的 markdown/链接语义，避免语义桥收到已移除的 child id。所有基于 `OverlayPortal` 的锚定菜单也必须在触发器所在树上常驻一个 `container + explicitChildNodes` 语义边界；开合只增删浮层子树，不得让瞬时菜单节点成为 AX 根。
- transcript 以服务端行保留全部版本；LLM 装配和压缩读过滤被替代版本，前端读形态不过滤，故版本翻页与模型上下文都成立。
- 附件上传、生成、MCP/function/handler 产物最终都以 attachment / `MediaRef` 投影进入同一媒体卡族；渲染按附件行 `mime`，不按 URL 或 receipt 自称猜类型。
- `list_attachments` 的 settled 目录行展示 filename、kind、MIME、大小和本地化的 `createdAt` 上传时点；附件没有详情 panel 时保持惰性，不渲染死链接。
- 用户消息附带的附件精确 ID 只进入模型专用的 `<uploaded_attachments_for_tools>` 目录，不进入可见 user bubble；模型因此可以直接用正确的 `read_attachment.id` 或 `inspect_media.attachmentId`，不会先把 `att_...` schema 示例当成真实文件而制造失败卡。
- `get_model_config` 的 settled tool card 是配置事实的 durable projection：展示每个默认角色及安全的 key display name、key 的 provider/masked/status、端点、模型的 context/output/media 能力和 native options；不展示 `apiKeyId`、密文或依赖模型 prose 才能理解的 raw map。
- `list_mcp_marketplace` 使用共享目录卡：行内保留 full registry name、description、runtime 和 required-env 数量；大目录明确显示 `first N of M`，点击后进入有界 JSON tree，不静默丢弃未显示的 server。模型正文可以补充每个 env 的精确名称与 required/optional 说明，但卡片的目录事实不依赖它。
- MCP 生命周期卡的安装/重连失败也可能是 loop 浮出的纯文本（例如 `required environment variables missing (missing=[ENTRA_CLIENT_ID])`），不能沿用成功语气：必须红色回执、自动展开，并保留具体缺失变量；失败帧的纯文本由底盘错误区唯一承载，族体不重复渲染；卸载成功的普通文本回执不误判为失败。结构化状态以后端 `ready` 为正常、`degraded` 为可调用警告，旧 `connected` 仅作兼容别名；不能把 `ready` 投影成 `disconnected`，也不能把 `degraded` 当成失败。`uninstall_mcp_server` 是受危险闸保护的持久化删除：最终卡片必须能区分拒绝、失败和成功，不能在一次失败后静默追加第二次模型重试。

## 3. 路由与生命周期

- Chat 无选中时显示 landing；`/chat/:id` 是线程路由。首次发送才创建对话，并在发首条消息前写入 landing 选择的模型。
- 对话切换不重挂 `AppShell`；当前线程的列表、transcript 与侧幕各自按 id 换代，workspace 热切换先离开旧深链再翻鉴权轴。
- 发送失败保留草稿；停止只取消当前在飞回合，不清后续队列；后台完成后 rail、标题、未读与侧幕以 durable 信号重取真相。
- sidecar 或 SSE 重连不能恢复 ephemeral interaction，因此重连后必须补拉 pending interactions。

## 4. 关键不变量

1. 用户消息、工具参数、模型输出的复制取自完整 model，不取自懒列表当前选区。
2. 分叉复制的是选定水位之前的自洽前缀；summary 越界时不得带入新分支。
3. retry/edit 只追加新版本并建立指针；旧行永远可读。
4. 驻地是 AI 的聚焦点，不是读取牢笼；越界写仍必须经过强制人闸。
5. 工具结果只把本次调用自己铸造的附件回喂模型；用户主动附加的附件走未收窄入口。
6. 生成工具是否存在由当前受管路由决定；BYOK 负责文本与多模态读取，不承载生成方言。

## 5. 验证入口

- feature 测试：`frontend/test/features/chat/`
- 流式与契约公共测试：`frontend/test/core/messages/`、`frontend/test/core/sse/`
- 产品黑盒：`testend/scenarios/` 中 conversation/chat/attachment/interaction 与多模态场景
- 人眼验收：`make -C frontend demo` 或 `make -C frontend app`
