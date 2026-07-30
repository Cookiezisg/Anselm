---
id: WRK-026-FRONTIER
type: working
status: active
owner: @weilin
created: 2026-07-29
reviewed: 2026-07-29
review-due: 2026-08-12
audience: [human, ai]
---

# Frontier · 高频动态覆盖与 reprobe 队列

> 这里记录下一批值得跑的真实路径，不是冻结的“覆盖率百分比”。完成后将结论移入 LOG 或 HISTORY；承重面变化后，历史绿格可以重新回到这里。

## 选择规则

优先级 = 高频度 × 用户损失 × 当前变化风险 × 证据缺口。每项至少注明：路由类别、执行面、媒体/资源流、后端真相和最小证据。173 家 provider 不是 173 条手工 lane；以协议/行为类抽样，验证目录解析与路由边界。

## 当前队列

| ID | 路径 | 路由 | 要证明的事实 | 最小证据 | 状态 |
|---|---|---|---|---|---|
| FRT-01 | 默认聊天 + 图片/视频/PDF 附件 + 语音输入 | managed-read/default | Anselm 的实际输入路由、lease 与能力降级正确；PDF 在 `nativeDocs=false` 时必须 sandbox 抽取（直投影与 `read_attachment` 工具路径）；附件先经 `list_attachments` 发现，再按类型进入读取/检查路径；大文本 `read_attachment` 与 `inspect_media` 都必须能暴露 query/index/page 参数并保持 bounded；大图 `inspect_media` 必须暴露 tiles/tileRows/tileCols 类型并返回紧凑 tile map；图片可经 `inspect_media` 嵌套视觉请求获得 bounded evidence；音视频 `inspect_media` 只返回诚实的本地元数据 capsule，不伪造转录/场景理解；语音输入另走 proof-bound ASR WebSocket | 请求形状 + 回合/附件真相；ASR `session.finished` | image / MP4 video / image+MP4 same-turn fusion / plain-text attachment direct projection / text+image same-turn direct fusion / text+video same-turn direct fusion / text+image+video three-way same-turn fusion / PDF+image same-turn fusion / text+unsupported-audio same-turn honest degrade / managed multiple-image same-turn fusion / attachment history multi-turn re-projection / deleted attachment → follow-up history honest degrade / `list_attachments` 双附件发现 / 136,890-char text `read_attachment` bounded query / 116,043-byte text `read_attachment` compact index（managed string-bool 首次校验失败后已兼容解码） / 157,248-byte text `read_attachment` 默认省略控制参数自动 compact index（复跑无校验警告） / 78,388-char text `read_attachment` offset=40800 limitChars=128 page（managed string-int 同样由兼容解码处理） / page-marked text `inspect_media` page=2 limitChars=128（managed string-int 首次校验失败后已兼容解码） / text `inspect_media` offset window + limitChars=96（managed string-int 由兼容解码处理） / 91,540-char text `inspect_media` bounded query / 512×512 image `inspect_media` 2×3 tile map / image `inspect_media` crop 0.25,0.25,0.5,0.5 + high detail / PDF sandbox extraction / PDF `read_attachment` tool continuation / image `inspect_media` nested vision / video+audio `inspect_media` metadata / video `inspect_media` 1000–2000ms range / audio `inspect_media` 1200–2600ms range / realtime ASR session 通过；默认 chat 不宣传 audio，但 WAV 附件在单独、“文字+不支持音频”、“图片+不支持音频”及“视频+不支持音频”同一回合中都真实走明确文本降级，支持的图片/视频分支仍完成且附件字节不变 |
| FRT-02 | BYOK 视觉/音视频/文档输入 | byok-read | 多模态输入是正式 BYOK 能力，不被生成边界误关 | 目录能力、wire part 或明确文本降级 | OpenAI image / OpenAI native PDF (`gpt-4.1-mini`) / OpenAI multiple-image same-turn / OpenAI image+不支持 audio 同轮降级 / OpenAI image+不支持 video 同轮降级 / Google Gemini image / Qwen MP4 video / Qwen WAV audio / Qwen image+MP4 same-turn fusion / 同会话 Qwen→OpenAI 模型切换后的 history media re-projection 真实通过；2026-07-30 当前 Qwen→OpenAI 模型切换两次真实复跑均保持第一轮双 native、第二轮 image native + video 明确降级及附件字节不变；Qwen3 Omni image+WAV 真实探测确认上游只允许 text+单一其它模态，产品现在保留图片原生 wire、将音频明确降级为文本注记而不再把组合转成 400；2026-07-30 当前 Qwen key 的 image+audio 组合两次真实复跑均保持同一 wire/字节边界；本轮 Qwen `qwen3.7-plus` 直接 image+MP4 fusion 两次复跑均观察到同一回合 `image_url`/`video_url` 与 exact-byte wire；本轮 OpenAI `gpt-audio` 音频+`run_function` 两次复跑均保持第二次请求的 `input_audio`、tools、函数结果与最终文本；OpenAI `gpt-audio` 目录滞后由 provider-owned capability bridge 覆盖，真实 WAV `input_audio` 产品路径及 audio+`run_function` continuation 已通过 |
| FRT-03 | BYOK 模型调用受管出图 | hybrid | 模型调度与受管生成正确接合，生成者不被重复喂像素导致重画 | tool/receipt、调用次数、产物与后续请求 | OpenAI→managed image 通过；真实 OpenAI continuation wire 已逐字节收到生成图片 |
| FRT-04 | workflow：生成者 → 下游观看者 / 用户附件 → workflow agent | hybrid / managed-read | 下游收到真实媒体而非“产物已生成”文本；用户上传的 MediaRef 也能从 trigger payload 穿过 CEL 接线进入 workflow agent | 录制请求包含原始媒体字节；flowrun trigger/node durable result、附件字节与模型回答 | managed image→BYOK OpenAI、managed speech→BYOK Qwen audio、managed video→BYOK Qwen qwen3.7-plus viewer 的 workflow exact-byte wire through；managed speech→managed viewer 同 run 完成并对默认 chat audio 做诚实降级；managed video→managed viewer 同 run 完成且真实 MP4 可回读；managed provider wire 仍待 gateway 侧 recorder；用户上传 PDF+image+MP4→manual trigger payload→managed workflow agent 两次真实复跑通过（PDF sandbox token + 三份 MediaRef 保留 + 552-byte PDF、98-byte PNG、2,969,360-byte MP4 源字节均不变）；用户上传 PDF+image→webhook body `start.body.*`→managed workflow agent 两次真实复跑通过（`origin=webhook`、PDF sandbox token、两份 MediaRef 保留及 552-byte PDF、98-byte PNG 源字节均不变）；用户在对话中经 `search_tools` 发现 `trigger_workflow`→携带 webhook-shaped PDF+image payload→managed workflow agent 两次真实复跑通过（`origin=chat`、`conversationId` 保留、PDF sandbox token、两份 MediaRef 保留及 560-byte PDF、98-byte PNG 源字节均不变）；Google native viewer producer 稳定完成，但约 1MB managed inlineData workflow 请求仍受 429 阻断，而独立 98-byte image probe 已恢复，暂保留为大媒体/request-shape 外部限流项；纯 managed 下游节点也完成且附件可回读 |
| FRT-05 | MCP/function/handler 产物 → 下游模型 | byok-read / hybrid | 各产地均能成为 MediaRef；不退化为占位字符串 | 产物字节、MediaRef、下游请求 | 当前受管 + BYOK workflow 的真实 function、resident-handler、stdio MCP producer→OpenAI vision viewer exact-byte wire 均 through；chat/workflow vision through；subagent managed generation→receipt state through；subagent text attachment→token roundtrip through；subagent image attachment→bounded `inspect_media` evidence/父回合续接/源字节守卫通过（真实模型若选择 Explore 则父层诚实 fallback，Explore 白名单边界保持不变）；subagent PDF attachment→`read_attachment` sandbox token roundtrip through（general-purpose 子代理真实调用、父层无偷调、原 PDF 字节不变）；subagent video/audio attachment→`inspect_media` bounded temporal metadata（kind/mode/range）通过，父层无偷调、原媒体字节不变且不伪造 transcript；subagent provider failure is annotated, durable, and parent-continuable；同一 execution group 的双 subagent 并发结果各自挂回独立 tool_call、父回合可继续；其余产地仍按 producer-specific reprobe；reprobe on media/ref encoder changes |
| FRT-06 | 文档内图像 → 引用/问答 | managed-read/default / byok-read | 编辑器往返和 LLM 消费保真 | 文档、附件与请求三方一致 | managed image-reference 与 BYOK OpenAI exact-byte wire 均通过 |
| FRT-07 | 音色完整生命周期 | hybrid + managed-write | 预置语音→附件→危险审批→异步登记→克隆合成→库存→删除 | 生产 API Serve、inventory、网关句柄到上游 id 的映射、删除后状态 | 默认 Anselm API managed E2E 通过；网关句柄/default/WAV 修复已被真实链路覆盖 |
| FRT-08 | 朗读缓存与配额 | managed-write | 同文本同音色不二次调用；换输入才花费 | managed gateway quota delta + attachment cached；provider recorder 仅有 archived 直连证据 | managed sequential and concurrent same-key cache/quota through; API Serve full-stack e2e also confirms its stream/non-stream settle and ledger guardrails; provider-wire count remains a deliberate gateway-side evidence gap because the deployed public surface never exposes raw upstream wire |
| FRT-09 | 生成工具诚实显隐 | managed-write | 出图/改图/动画/音色各自独立，不能因一个能力存在而全露出 | 工具表 + 具体 route/capability | managed image/speech/edit/video/animation live through; speech and async-video danger denial return completed refusal paths without a synthesis receipt or extra reservation; animation uses the dedicated `/videos/animations` route and caps oversized output before continuation |
| FRT-10 | 无 tool-call 模型 | byok-read | 可聊天但不作为 agent 可用模型；不被目录裁剪误删 | 模型选择器/API + agent 限制 + chat-only wire | Qwen-MT 真实通过；chat 去工具；产品 agent invoke 以 failed/0 steps 明确拒绝 |
| FRT-11 | provider 行为类 | byok-read | compat、Anthropic、Azure、Google、Vertex 的凭证/URL/编码边界正确 | 每类最小 probe + 错误分类 | DeepSeek v4 + Google Gemini 3 文本与原生 functionCall/functionResponse 续接真实通过；2026-07-30 当前 DeepSeek/Google key 文本 smoke 与 DeepSeek tool continuation 再次通过；当前 Kimi 凭证在 `:test` 入口按约定返回 422 `API_KEY_TEST_FAILED` 并保留 `details.reason=HTTP 401`；原生 Anthropic 本地黑盒已通过 `/v1/models` 探测、能力目录、`x-api-key`/版本头、`/v1/messages` block body、命名 SSE 与 usage 落盘；`custom + anthropic-compatible` 与 `custom + openai-compatible` 均已双跑：APIFormat 写回、各自探测/auth/chat wire 正确，custom 无目录时能力保持保守空面；Azure/Vertex 仍待真实凭证抽样；本轮 Google 原生 tool continuation 两次均被上游 429，产品稳定归类 `LLM_RATE_LIMITED`，未伪造 assistant 文本 |
| FRT-12 | 工具参数流 | byok-read / hybrid | 累积式与增量式 `arguments` 都能执行一次正确工具调用 | 两类 fixture + 真线缆样本 | locked; reprobe with parser changes |
| FRT-13 | 取消、重试与恢复中的媒体 | all applicable | 取消回合不留孤儿、重放不错误复用或重复消费；审批停泊与外部 firing 在崩溃后仍可恢复，网络重试不重复执行；触发源/工作流软删后引用关系必须可审计且只能显式修复或终止 | durable 状态、附件溯源、调用计数、inbox/审计关联、删除/重建/重绑定前后能力与 listener 投影 | handler/workflow cancel/retry/crash no-orphan + image preparation ready/failed/cancel/retry + boot budget eviction/regeneration + crash requeue + parked approval restart/decide + approval v1 pin survives entity edit→v2 short timeout + SIGKILL→Restart + inbox rendered/deadline remains pinned + webhook firing restart-before-drain + deactivate detaches listener, fences in-flight reports already past the listener snapshot, and keeps draining until accepted pending firing is consumed + pending structural shed also reconciles shed-only drain to inactive + same-body minute dedup + fsnotify event payload/filter/hot-swap + sensor false/true transition/handler invoke failure/MCP target/eager validation + fsnotify/sensor pause→SIGKILL→resume through；真实 webhook 双触发下 serial/skip/buffer_one/replace/allow_all 五种 overlap 策略的 firing disposition 与 flowrun 状态均通过；多入口 workflow 的 distinct trigger attach、重复 ref 去重、重复 activate 幂等与全量 detach 通过；多入口 stage 第一火全量撤防、并发 report 的 one-shot 原子消费通过；active workflow 的 trigger 软删→dangling capability→同名重建不隐式换绑→显式 edit rebind→deactivate 全量摘除通过；active workflow 软删→全量摘 listener→取消 parked run→保留审计/版本历史→同名重建无幽灵 listener 通过；deleted workflow 的历史可读但所有 action/iterate 入口拒绝，跨 workspace 不泄漏 workflow/trigger/run；queued firing 在删除后进入 shed 且不铸造幽灵 run；`:kill` 在取消在途 run 前 shed 剩余 pending firing，硬停后不复活新 run；trigger dangling active state survives restart and requires explicit rebind before relistening；accepted firing survives trigger deletion with deleted triggerId and honest origin omission when TriggerKind lookup is unavailable, including SIGKILL→Restart before scheduler drain；accepted firing whose source entry is removed by active workflow edit settles as shed instead of retrying forever；active edit→revert 在 pending firing 与 parked run 并存时恢复当前 listener、保持原 run version pin，且 SIGKILL→Restart 后第二 firing 只 drain 一次；approved managed video cancellation after gateway submission reaches local cancelled terminal without a video receipt or late attachment (provider job/spend intentionally remains gateway-side and may continue); reprobe on worker/recovery/trigger lifecycle changes |
| FRT-14 | provider 模型资格漂移 | byok-read | `/models` 可见不等于当前账号可生成；选择后 404 应可解释、不可重试且不污染回合 | `/models` 与最小 generate 对照 + 产品选择/失败状态 | Google `gemini-2.5-flash` 真实通过：可见、可保存选择，首发单次 404、error turn 无 assistant 文本；回合级 code 现保留为 `LLM_MODEL_NOT_FOUND`，失败横幅提供重选模型入口；同一会话切换 `gemini-3-flash-preview` 后恢复完成且仅多一次 generate；2026-07-30 当前 GEMINI key 两次真实复跑仍复现同一资格边界；本轮再验证用户不改选择连续发送两次时每回合各自只发一次上游请求、均诚实落 `LLM_MODEL_NOT_FOUND`、无 fallback/assistant 文本；模型失效记忆/目录自动降级仍待产品策略决定 |
| FRT-15 | workflow 大图扇出与 AND-join | managed-write / hybrid | 多路 live 入边必须全部完成后才 join；节点按 `(node, iteration)` 只落一次，终值不丢；失败/崩溃后可从断点恢复且遵守 run 起跑时的版本 pin | HTTP flowrun、节点 durable rows、终点结果、replay/boot recovery 后的调用台账与 versionId | 12 节点/8 路扇出/两级 join、25 迭代深循环（含 REST 节点分页、function flowrunIteration）、真实 failed replay（已完成节点复用、驻留 handler 第二次成功、二次 replay 拒绝）、function v1→v2 编辑后的原 pin/fresh run 分界及 SIGKILL→boot recovery 的唯一节点/执行审计均通过；reprobe on scheduler/storage changes |
| FRT-16 | 对话分叉与分支续接 | managed-read/default | 从已完成消息另开分支时，源线程 append-only 不变，新线程保留明确血缘且能继续走默认 Anselm 路由 | fork lineage、源/分支消息集合、分支 follow-up durable terminal | 2026-07-30 简单分叉两次通过；并行 subagent 树分叉两次通过：两 child 行与 marker 随最新分支复制、消息/块 ID 全新、`Attrs.parentBlockId` 锚到分支自己的父 block、源线程不变且分支 follow-up 无工具复活；前缀切点语义与一次真实锚泄漏已修正 |

### FRT-02 最新证据

本轮补做 Qwen 直接多模态融合，而不是只依赖模型切换场景的间接覆盖：BYOK key 经产品 API 探针和能力投影后选择 `qwen3.7-plus`，同一回合上传 98-byte PNG 与 2,969,360-byte MP4。recorder 两次独立进程都捕获了包含原始字节的 `image_url` 与 `video_url` native parts；回合完成，两个附件 HTTP 回读仍逐字节一致，未走 managed fallback 或文本占位。两次通过（12.93s、10.10s），未形成后端缺陷。

同轮复探 OpenAI `gpt-audio` 的音频+agent 交叉边界：两次独立进程都把 WAV 作为原生 `input_audio` 送入首发，完成一次 `run_function` 后将结果回灌第二次 `/chat/completions`；recorder 同时钉住音频原始 base64 与 `tools`，durable history 保留 tool call/result/最终文本，附件字节不变。两次通过（11.18s、9.32s），未复现此前的瞬时 provider stall。

模型切换回归哨兵随后再次通过：同一会话先由 Qwen `qwen3.7-plus` 接收 image+video，再切到 OpenAI `gpt-4.1-mini`；第二轮只保留 image native，video 明确降级为 capability 注记，两个源附件仍逐字节回读。两次独立进程通过（12.75s、10.26s），未复现历史 semantic backfill 关闭竞态或 `database is closed`。

### FRT-04 最新证据

2026-07-30 新增聊天可观测闭环：首轮对话经 `search_tools` 发现并调用 `trigger_workflow`，等待真实 run 完成后，下一轮再经 `search_tools` 发现 `get_flowrun`，读取同一 completed `flowrunId`；`origin=chat`、`conversationId`、函数节点 marker 与 assistant 最终回答均保留。两次真实 managed 复跑通过。

同日补充失败诊断闭环：首轮触发故意失败的 workflow，下一轮经 `search_tools` 发现 `search_flowruns` 找到 `status=failed` 的 run，再发现 `get_flowrun` 读取节点错误；`origin=chat`、错误 marker 与 assistant 的 failed/失败回答均保留。初次探索曾因模型偏离精确 `workflowId` 得到一次 `workflow not found`，增加实体读回与逐字 ID 约束后两次规范复跑通过，归类为模型参数遵循观察而非稳定后端缺陷。

同日补充人在环闭环：聊天触发的 webhook workflow 先在 `human` approval 节点 durable park，第二轮只经 `search_tools`→`get_flowrun` 读取 parked 状态，第三轮才经 `search_tools`→`decide_approval(yes)` 恢复并完成下游 publish；两次真实 managed 复跑均保留 `flowrunId`、审批决策、completed 状态与下游 marker。

同日补充失败 run 的聊天 replay 闭环：首轮经 `search_tools`→`trigger_workflow` 启动带稳定前缀与常驻 flaky handler 的 workflow，handler 首次失败后 durable 记录 `origin=chat` 的 failed run；第二轮只经 `search_tools`→`get_flowrun` 读取 failed 节点，第三轮经 `search_tools`→`replay_flowrun` 恢复同一 `flowrunId`。replay 复用已完成的 stable 节点、只重跑失败 handler，随后 finish 节点完成；function execution 与 handler call ledger 均证明稳定前缀/finish 各一次、handler 恰一次 failed + 一次 ok。两次真实 managed 复跑通过（53.730s、50.552s）。首轮断言曾错误假设列表按时间正序，实际公开列表默认最新在前；改为校验 append-only 状态计数后通过，未形成后端缺陷。

同日复核 gateway-side 观测边界：`Anselm-API-Serve` 的 tagged full-stack e2e 在真实 `router → middleware → SQLite → upstream` 装配上通过，覆盖 install/chat/quota、Qwen 多模态、tool loop、stream/non-stream settle、额度/预算、拒绝 rollback、异步图像/语音/视频、混合模态与 debug 计费。部署公网面只返回规范化 completion、quota 和 liveness；`/metrics`、`/readyz`、pprof、expvar 均由独立 loopback admin listener 提供，原始 provider body/header/key 按设计不出端。因此 FRT-04 的用户可见媒体/flowrun/附件证据已闭合，但“部署公网可录制原始 provider wire”不能在不改变 API Serve 安全边界的前提下补齐，不能把该缺口伪装成已覆盖。

同日复跑 workflow 用户附件融合的 manual-trigger 入口：上传 PDF+PNG+MP4 后，payload 经 trigger → CEL → managed agent 完整穿线，flowrun completed；agent 从 PDF sandbox 提取唯一 token，同时保留三份 MediaRef，源字节分别为 552、98、2,969,360 bytes。两个独立 backend 进程通过（63.203s、62.185s），未形成 workflow 或多模态产品缺陷。

同日补做 chat 入口的同形 payload：managed 对话经 `search_tools` 发现 `trigger_workflow`，把 PDF+image 的 webhook-shaped body 交给 workflow agent；两次独立复跑均保留 `origin=chat`、`conversationId`、flowrun completed、PDF token 与两份 MediaRef（560-byte PDF、98-byte PNG），证明从 chat 工具进入不会绕过或削弱 workflow 的多模态接线。

同日补做外部 webhook 入口：真实 `POST /api/v1/webhooks/{triggerId}/{path}` 接收 PDF+image body，flowrun 以 `origin=webhook`、正确 `triggerId` 完成，agent 经 `start.body.*` 读取 PDF token 并保留 555-byte PDF 与 98-byte PNG。两个独立 backend 进程通过（31.469s、24.281s），manual/chat/webhook 三入口均未形成产品缺陷。

同日复跑 producer→viewer 的异步资源方向：managed workflow 先经 `generate_video` 提交并轮询真实 gateway job，再把视频 MediaRef 交给下游 managed viewer；两次独立复跑均 flowrun completed，最终 MP4 可回读（11,165,527 bytes、10,657,043 bytes），viewer 读取的是实际产物而非 receipt-only 占位。单次耗时约两分钟，符合异步视频任务的真实延迟，未形成产品缺陷。

同日补做 speech producer→managed viewer：workflow 生成真实 WAV 后交给下游默认 managed agent；两次独立复跑均 flowrun completed，WAV（80,684 bytes）可回读，viewer 对 chat audio 维持诚实降级而未伪造转录或 native audio 能力，未形成产品缺陷。

同日补做 image producer→managed viewer：workflow 上游只调用一次 `generate_image` 生成真实 PNG MediaRef，下游 managed agent 消费同一产物后 flowrun completed；两次独立进程均能从 attachment content 端点回读完整 PNG（1,115,024 bytes、1,096,630 bytes），viewer 不是只看到 receipt 文本，未发生重复生成或媒体丢失，未形成产品缺陷。

### FRT-08 最新证据

同日复探 managed 朗读成本闸：顺序路径第一次合成、同文本同音色命中同一缓存、换文本生成新 WAV；并发路径在同 workspace 同 key 下同时发起两次相同请求，两个响应共享同一附件且 quota 只增加一次。两条场景在两个独立进程均通过（顺序 10.11s/9.93s，并发 5.81s/5.25s），未复现重复付费竞态；provider wire 计数仍受 API Serve 公网不暴露 raw wire 的设计边界约束。

### FRT-01 最新证据

同日复跑默认 managed 三模态同回合 sentinel：同一用户消息同时携带 text、PNG 与 MP4，真实 Anselm API Serve 路由完成后，durable turn 保持 completed，三个附件仍可逐字节回读（80-byte fixture、98-byte PNG、2,969,360-byte MP4），未退化为占位文本、拆成错误的多回合或错误切换到 BYOK。两个独立 backend 进程通过（53.209s、48.321s）；关停阶段偶见的本地 search embedder `context canceled` 仍是已知 shutdown 噪声，未形成产品缺陷。

同日再复探支持/不支持模态交叉：默认 managed 同一回合携带 PNG 与 WAV，能力面继续只宣称 vision、不宣称 chat audio；两次独立进程均完成，PNG（98 bytes）与 WAV（96,044 bytes）原样回读，音频以诚实降级留在产品边界，没有把整回合变成 gateway 400 或伪造 native audio。关停阶段的 embedder `context canceled` 仍为已知噪声。

同日补做附件生命周期哨兵：同回合两张独立图片均可回读；首轮消费图片后删除附件，后续回合面对 404 仍把历史媒体明确降级为 missing attachment 而完成；另一条会话在首轮带图后省略 `attachmentIds` 继续追问，历史媒体重新投影后仍完成且源字节不变。三条场景在两个独立 managed 进程中均通过（包总计 30.287s、29.376s），没有 400、孤儿媒体或跨回合丢失；关停阶段偶见 search embedder `context canceled` 仍归类为已知 shutdown 噪声。

### FRT-05 最新证据

同日补充真实并行子代理树闭环：父聊天只派两个独立 `general-purpose` 子代理，两个子任务各自经 `search_tools`→`run_function` 执行不同 function；两个 child message 都以不同 `parentBlockId` 锚回父级 `Subagent` tool_call，父回合同时收到两个 marker 且没有直接调用 `run_function`。两个 function execution 各恰一条 `status=ok`、`triggeredBy=agent` 记录，并绑定同一 conversation 与 child message。探索阶段一次上游 502、两次测试 oracle 校准（模型先纠正缺失 `subagent_type`；执行台账结果字段为 `output` 而非 `result`）均未形成产品缺陷；校准后两次真实 managed 复跑通过（93.71s、76.33s）。关停阶段的本地 search embedder `context canceled` 仍归类为 shutdown 噪声。

同日补上真实嵌套失败证据：父聊天只派一个 `general-purpose` 子代理，子代理经 `search_tools` 发现 `run_function` 并调用一个必然抛错的 function；失败 execution 记录 `status=failed`、`triggeredBy=agent`、同一 `conversationId/messageId`，错误 marker 同时留在子消息树与父 `Subagent` tool result，父回合仍以 completed 结束且没有越权的父级 function 调用。两次真实 managed 复跑通过（49.94s、55.356s），补足 FRT-05 原先仅 mock 的失败续接证据，未形成后端缺陷。

同日补上真实嵌套取消证据：父聊天派出 `general-purpose` 子代理，子代理进入一个 60 秒 function 后，客户端按真实 `:cancel` 动作中止父回合；取消接口返回 204，父消息与带 `SubagentID` 的子消息均落 `cancelled`，function execution 恰一条、`status=cancelled`、`triggeredBy=agent` 且绑定 child `messageId`，同一对话的 follow-up 完成且没有复活旧 tool call。修订后的真实 managed 复跑通过两次（55.39s、53.93s）。初次探索曾等待 REST `/messages` 出现子代理的 streaming tool block，128.65s 后超时；期间历史端点只返回父侧短投影，直到子回合自然终态才批量出现嵌套 blocks。改用与 UI/SSE 等价的定时取消，再从 durable history/ledger 验证终态，证明这是 REST 历史投影的批处理边界而非取消后端缺陷。取消时 `run_function` 的底层进程组被杀并留下 `spawn process failed` WARN，但 durable/wire 语义正确；该日志目前归为可解释的取消噪声，不计稳定产品 bug。

同日补上失败 subagent 树的真实分叉：child 的 function 真实落一条 `failed + triggeredBy=agent` execution，错误 marker 与 completed child row 随 latest fork 携带，消息级 `parentBlockId` 重定基到分支自己的 `Subagent` tool_call；分支 follow-up 不复活失败工具、ledger 仍只有一条 execution，源历史不变。首轮探索只暴露了测试按最新在前历史过早校验 parent anchor 的 oracle 顺序问题，改为先收集全部 block 再验证后，两次真实 managed 复跑通过（62.26s、36.45s），未形成 backend 缺陷。

同日补上取消 subagent 树的真实分叉：父/child 通过真实 `:cancel` 都落 `cancelled` 后，latest fork 保留 child 的 terminal 状态与重定基后的 `parentBlockId`；底层 function ledger 仍恰一条 `cancelled + triggeredBy=agent`，分支 follow-up 不复活在途工具。两次真实 managed 复跑通过（54.58s、54.88s），关停时偶见 search embedder `context canceled`，归类为 shutdown 噪声。

同日补充并行子代理的跨回合上下文续接：首轮两个 child 均完成后，第二轮用户追问只要求复述两个 marker；父回合在不调用任何工具的情况下逐字恢复两份结果，历史仍保留恰两个 completed child、原 `parentBlockId` 锚点和两条唯一 `agent/ok` function execution。两次真实 managed 复跑通过（74.62s、59.65s），未形成后端缺陷。

### FRT-11 最新证据

本轮先做 DeepSeek 兼容线缆的真实双跑：`deepseek-v4-flash` 在产品 API 内完成 `run_function`，函数结果回灌后第二次 chat/completions 采样完成；durable history 同时保留 tool call、tool result 和最终 `144`，recorder 观察到至少两次请求且请求携带 `tools`、`tool_calls` 与结果载荷。两次独立进程通过（12.52s、9.52s），未形成产品缺陷；关停阶段的 embedder `context canceled` 仍是已知 shutdown 噪声。

随后换到 Gemini 原生 `functionCall/functionResponse` + `thoughtSignature` 线缆。两次独立进程都在首轮 generate 收到上游 429，产品把回合落为结构化 `LLM_RATE_LIMITED` 并停止，没有重试成 404、没有生成 assistant 文本，也没有进入错误的 parser 断言；这记录为当前 Google provider rate window，而不是后端工具参数缺陷。FRT-12 的累积/增量本地 fixture 仍全绿，真实 parser 组合在 provider 窗口恢复或 parser 承重变更时再复探。

本轮补做原生 Anthropic 黑盒闭环：本地 Anthropic-shaped upstream 先由真实 backend 以 `GET /v1/models` + `x-api-key` + `anthropic-version: 2023-06-01` 探测，随后同一 key 的能力面保留 `claude-opus-4-8`、image/PDF 与 `thinking`/`effort` 原生旋钮；对话调用严格落到 `/v1/messages`，请求是 block-form `messages` + `stream:true`，没有 Bearer/OpenAI 兼容退路；命名 SSE 的 `message_start`、text delta、`message_delta(end_turn)` 产生的文本、stop reason 与 input/output usage 全部落入 durable turn。两次独立 backend 进程通过（6.47s、4.30s），未形成产品缺陷；测试隔离 free-tier install 失败与 shutdown embedder `context canceled` 仍为已知噪声。Azure/Vertex 仍需真实凭证才能补证，当前不伪造其结果。

紧接着补上 `custom + anthropic-compatible` 的产品入口：同一类本地端点通过 custom key 的闭合 `apiFormat` 白名单进入，`:test` 仍敲 `/v1/models`，model capability 只呈现 live model id、不凭空声称 image/PDF/旋钮，实际对话却通过 `lookupProvider` 切到原生 `/v1/messages`，同样使用 `x-api-key`、Anthropic 版本头、block-form body 与命名 SSE。两次独立 backend 进程通过（6.42s、4.07s），未形成产品缺陷；这证明「未知 custom 能力保守」与「用户明确选择 Anthropic 方言后 wire 正确」可以同时成立。

随后补齐对称的 `custom + openai-compatible` 入口：`:test` 使用 OpenAI 风格 `GET /models` + Bearer，聊天使用 `/chat/completions` + Bearer、`stream_options.include_usage` 与 data-only SSE；同一产品 API 把 wire 上的 `finish_reason=stop` 规范化为 durable history 的 `stopReason=end_turn`，token usage 与回答均落盘，且没有误走 `/v1/messages`/`x-api-key`。两次独立 backend 进程通过（5.31s、3.30s）；第一次 focused 红灯只是测试 oracle 错把 provider wire 的 `stop` 当成 durable 合同，修正为 `end_turn` 后未形成产品缺陷。

### FRT-13 最新证据

同日补上真实 managed 原地重试闭环：首轮默认 chat 完成后调用 `:retry`（无 content 的 regenerate 分支），旧 assistant 行保留，新 assistant 行通过 `supersededBy`/`attrs.retryOf` 组成线性版本链，历史仍只有一条 user 行；随后在最新版本上继续发送 follow-up，回合再次 completed。两次真实 managed 复跑通过（总计 11.951s、12.262s）。首轮优雅关停阶段出现一次 search embed `context canceled` WARN，第二轮未复现，归类为测试服务 shutdown 噪声而非产品缺陷。

同日补上 retry 与 fork 的交互证据：先在真实 managed chat 生成 assistant，再走无 content `:retry` 形成两版本链，随后走空 body 的 latest `:fork`。分支耐久历史保留 user + 两个 assistant 版本，但 `supersededBy`/`attrs.retryOf` 均重定基到分支自己的新 message ID；分支 follow-up 只使用当前版本并完成，源历史仍保持 3 行。两次真实复跑通过（28.37s、20.98s），未形成后端缺陷。

同日补上显式旧版本切点：在 retry 链上以旧 assistant 的 message id 调 `:fork`，分支只复制 user + 旧 assistant；被切掉的新版本不留下悬空 `supersededBy` 或 `attrs.retryOf`，旧回答在分支内重新成为 current，分支 follow-up 完成且源仍保留三行历史。两次真实 managed 复跑通过（13.70s、12.32s），未形成后端缺陷。

### FRT-15 最新证据

同日补上真实 managed workspace 的大图扇出/AND-join 闭环：一个 manual flowrun 展开 8 条 action 分支，两个四输入 join 在所有上游完成后各执行一次，finish 汇总 12 条 durable node rows；function ledger 同时证明 8 次 branch、2 次 join、1 次 finish 均绑定同一 `flowrunId`、`flowrunNodeId` 唯一且成功。两次真实复跑通过（总计 9.109s、9.867s），未形成后端缺陷；关停阶段 search embedder `context canceled` 仍归类为服务 shutdown 噪声。

同日再补用户入口组合：默认 managed chat 先经 `search_tools` 发现 `trigger_workflow`，再以 webhook-shaped payload 启动 4 路 fanout/双 join workflow；`origin=chat`、`conversationId`、8 条 durable node rows 及 branch execution ledger 均闭合。前两次探索分别受 managed gateway 响应头 timeout 与上游 502 阻断，未进入 workflow 断言；随后两次规范复跑通过（总计 30.092s、29.445s），因此红灯归类为外部 provider 窗口而非产品缺陷。

### FRT-16 最新证据

同日补上真实对话分叉闭环：先完成一轮默认 managed chat，再从该 assistant 消息调用 `:fork`；源会话仍保持原 2 条 append-only 消息，新会话复制同一前缀但不复用源 assistant ID，返回的 `forkedFromConversationId`、`forkedFromMessageId` 与 `(fork)` 标题后缀均正确。随后在新分支继续发送 follow-up，仍经默认 Anselm 路由完成；源会话消息数保持不变。两次真实 managed 复跑通过（总计 13.209s、12.768s），未形成后端缺陷。

同日再补并行 subagent 树的真实分叉闭环：源对话先由两个 `general-purpose` child 各自发现 `run_function`、执行不同 function 并留下两个 marker；空 body 的最新分叉路径复制完整耐久树，child message 与 block 均铸造新 ID，两个 `Attrs.parentBlockId` 都重定基到分支自己的父 `Subagent` tool_call，源线程保持原集合；分支 follow-up 不调用工具却能恢复两个 marker。探索时显式切在 parent message 的首次断言误把“前缀不含后续 child”当成缺陷，改用 rail 的 latest fork 语义后，真实运行确认了一个后端缺陷：分叉复制了 child 行，却把消息 Attrs 中的 `parentBlockId` 留成源 block ID；`Fork` 现与 `Block.ParentBlockID`、`retryOf` 一起重映射该消息级 E3 锚，并由真实 store 单测锁住。修复后两次独立 managed 复跑通过（67.90s、72.20s）；中间模型未稳定产出双 child 的红灯未进入分叉断言，归类为 managed 波动而非产品缺陷。

同日补上版本链分叉交互：这条路径与上面的并行 subagent 树分叉互补，证明 `Fork` 的同一份预铸 message remap 表同时覆盖 `retryOf`/`supersededBy` 与消息级 E3 锚；真实 retry→latest fork→branch continuation 两次通过（28.37s、20.98s），源分支均未出现跨线程指针。

同日补上失败树分叉交互：失败 child 的 durable error 证据与 E3 锚和成功 child 使用同一套 fork remap 语义；这条路径两次通过（62.26s、36.45s），补足了 FRT-05 “failure is durable” 与 FRT-16 “fork is self-contained” 的交集。

同日补上取消树分叉交互：取消 child 与失败 child 一样是可读的 durable terminal history，而不是被 fork 丢弃的 transient；两次通过（54.58s、54.88s），补足 FRT-13 取消恢复与 FRT-16 分支自洽的交集。

## 历史高频 reprobe 组

这些不是“已覆盖所以跳过”。当任一承重面改变时，按组抽取代表路径重测：

| 组 | 代表路径 | 触发 reprobe 的承重变化 |
|---|---|---|
| R-A | 对话、模型选择、工具调用、错误恢复 | modelclient、catalog、provider 方言、loop、消息投影 |
| R-B | agent/subagent、动态工具、持久化 trace | toolset、agent runner、SSE、上下文压缩 |
| R-C | workflow、触发、暂停/审批、replay | durable engine、节点协议、并发、flowrun 存储 |
| R-D | 附件、文档、MCP/function/handler 产物 | MediaRef、attachment、renderer、part encoder |
| R-E | 配额、缓存、危险操作与资源清理 | gateway、managed key、quota、approval、resource store |

## 不做的伪覆盖

- 不逐家手工验证全部 provider；目录规模下这会制造过期清单而不是保证。
- 不以模型自然语言自述证明它“看见了”媒体；需要线缆或字节证据。
- 不用 mock 证明真实供应商的异步状态、URL 可达性、计费或流式分片约定。
- 不把已删除的 BYOK 直连生成路径作为正常能力回归。
- 不要求本地测试者持有或注入 API Serve 的 provider secret；那会把运维边界错误地拉回产品端。
