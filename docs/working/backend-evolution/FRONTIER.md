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

同日复探 BYOK 文档/视频读侧当前配置：OpenAI `gpt-4.1-mini` 原生 PDF 与 Qwen `qwen3.7-plus` 视频连续两轮独立组合全绿（15.923s、15.675s）；PDF 仍经 native `file_data`/document wire，视频仍保留 `video_url` 与源附件字节，workspace 未安装 managed fallback，未形成 provider encoder 或文档/视频投影回归。

模型切换回归哨兵随后再次通过：同一会话先由 Qwen `qwen3.7-plus` 接收 image+video，再切到 OpenAI `gpt-4.1-mini`；第二轮只保留 image native，video 明确降级为 capability 注记，两个源附件仍逐字节回读。两次独立进程通过（12.75s、10.26s），未复现历史 semantic backfill 关闭竞态或 `database is closed`。

同日补做 OpenAI 图片历史与多图高频交互：`retry` 的无内容 regenerate 保留单一 user 行、追加 assistant 版本链，并让首轮与重试都携带 exact-byte `image_url`；编辑文字的 resend 同样重投影原图；同一回合两张图片各自保留附件并同时穿过原生线缆。首轮组合与独立多图补跑全绿（retry/edit 包 16.919s；multiple 7.687s），第二个三场景独立进程也全绿（包 48.955s；retry 37.54s、edit 7.56s、multiple 3.48s），未形成历史、附件或 part encoder 回归。

随后复探 OpenAI 异构附件边界：同一回合的 image+WAV 与 image+MP4 均保持 image 的 exact-byte `image_url`，不支持的音频/视频被写成明确 capability note，原始 PNG/WAV/MP4 均逐字节可回读；两个独立组合进程全绿（16.351s、9.644s）。原生 PDF 路径也在两个独立进程中完成，recorder 观察到 file part/inline file_data，PDF 原件保持 540 bytes（9.593s、5.300s），未形成降级、附件或文档编码缺陷。

同日补做 Qwen 方言三件套：`qwen3.7-plus` 单视频真实 BYOK 回合完成且 2,969,360-byte MP4 保持不变；同模型 image+video 同回合经 recorder 同时捕获 exact-byte `image_url`/`video_url`；`qwen3-omni-flash` image+WAV 遵守 `maxDistinctMediaKinds=1`，保留 image native、把 audio 变成明确约束注记而不发上游非法组合。两轮独立组合均通过（21.755s、16.582s），未形成 Qwen provider 方言或多模态降级缺陷。

同日复探 OpenAI 同回合多图：两个独立进程都把两份 98-byte PNG 送入真实视觉回合，durable history 完成且两份附件逐字节回读（6.62s、5.51s）；BYOK workspace 未安装 managed fallback，未形成多 part 编码或附件列表投影回归。

同日复探 OpenAI image 与不支持的音频/视频异构组合：两轮独立组合均通过（13.416s、10.074s）；PNG 继续走 native image，WAV/MP4 被写成明确能力降级而不是发非法组合，三份附件源字节仍可逐字节回读，未触发 provider 400、managed fallback 或历史媒体丢失。

同日补做 managed 读侧与多模态交叉独立进程：subagent 经 sandbox 读取 PDF、直接 `inspect_media` 图片、文本 bounded query、PDF+图片同回合，以及修复后的 PDF `read_attachment` oracle 共 5/5 通过（包总计 83.988s）；源附件均可回读，未出现 durable 读错、工具结果污染或多模态投影回归。

随后复探 OpenAI `gpt-audio` 的交叉边界：单音频回合的 WAV 以 exact-byte `input_audio` 到达 recorder；音频+`run_function` 首轮保留音频与 tools，sandbox 结果回灌后第二次 `/chat/completions` 完成，durable history 同时保留 tool call/result/最终文本。两轮独立组合全绿（15.334s、12.211s），未形成音频 encoder、agent loop 或工具续接回归。

Google 原生视觉也做了当前 key 的独立双跑：`gemini-3-flash-preview` 探针能力含 vision，PNG 经 Gemini contents/parts 完成 BYOK 回合，原始 98-byte 附件逐字节可回读；两次通过（7.085s、5.820s），未遇到 rate-limit，也未形成 Google native part 或 capability projection 缺陷。

本轮再次复探跨 provider 模型切换：Qwen `qwen3.7-plus` 首回合把 image+video 的 exact bytes 送入 recorder；切到 OpenAI `gpt-4.1-mini` 后，历史只保留 image native，video 变成明确 capability note 且不发送其字节，两个附件仍可逐字节回读。两次独立进程通过（12.527s、11.959s），未形成历史语义回填、能力门控或 provider 路由回归。

### FRT-03 最新证据

本轮复探 hybrid ownership 的两条最小闭环：OpenAI BYOK planner 只规划一次并把生成交给默认 Anselm managed image route；反向路径由 managed image producer 生成真实 PNG MediaRef，再由 OpenAI BYOK vision viewer 读取同一附件。两条路径各跑两个独立进程均通过（planner/viewer 组合包 62.764s、60.281s），附件端点可逐字节回读，没有重复生成、receipt 冒充媒体或 managed/BYOK ownership 串线。

随后把 viewer 方言扩展到 native Gemini 与 Qwen：managed image→Gemini inlineData 两次通过（56.34s、65.18s）；managed speech→Qwen audio viewer 两次通过（17.86s、18.55s）；managed async video→Qwen video viewer 两次通过（122.77s、119.56s，MP4 约 9.7MB/9.2MB）。每条路径都等待真实 MediaRef、回读原始附件并完成下游回合，未形成跨 provider 编码、异步等待或 ownership 回归。

### FRT-04 最新证据

2026-07-30 新增聊天可观测闭环：首轮对话经 `search_tools` 发现并调用 `trigger_workflow`，等待真实 run 完成后，下一轮再经 `search_tools` 发现 `get_flowrun`，读取同一 completed `flowrunId`；`origin=chat`、`conversationId`、函数节点 marker 与 assistant 最终回答均保留。两次真实 managed 复跑通过。

同日补充失败诊断闭环：首轮触发故意失败的 workflow，下一轮经 `search_tools` 发现 `search_flowruns` 找到 `status=failed` 的 run，再发现 `get_flowrun` 读取节点错误；`origin=chat`、错误 marker 与 assistant 的 failed/失败回答均保留。初次探索曾因模型偏离精确 `workflowId` 得到一次 `workflow not found`，增加实体读回与逐字 ID 约束后两次规范复跑通过，归类为模型参数遵循观察而非稳定后端缺陷。

同日补充人在环闭环：聊天触发的 webhook workflow 先在 `human` approval 节点 durable park，第二轮只经 `search_tools`→`get_flowrun` 读取 parked 状态，第三轮才经 `search_tools`→`decide_approval(yes)` 恢复并完成下游 publish；两次真实 managed 复跑均保留 `flowrunId`、审批决策、completed 状态与下游 marker。

同日补充失败 run 的聊天 replay 闭环：首轮经 `search_tools`→`trigger_workflow` 启动带稳定前缀与常驻 flaky handler 的 workflow，handler 首次失败后 durable 记录 `origin=chat` 的 failed run；第二轮只经 `search_tools`→`get_flowrun` 读取 failed 节点，第三轮经 `search_tools`→`replay_flowrun` 恢复同一 `flowrunId`。replay 复用已完成的 stable 节点、只重跑失败 handler，随后 finish 节点完成；function execution 与 handler call ledger 均证明稳定前缀/finish 各一次、handler 恰一次 failed + 一次 ok。两次真实 managed 复跑通过（53.730s、50.552s）。首轮断言曾错误假设列表按时间正序，实际公开列表默认最新在前；改为校验 append-only 状态计数后通过，未形成后端缺陷。

同日补做 workflow producer→viewer 的真实 managed 产物链：image producer→managed viewer 与 speech producer→managed viewer 各自只生成一次真实 MediaRef，下游节点在同一 flowrun 中消费并完成；PNG（约 1.07–1.12MB）与 WAV（80,684 bytes）均可从附件端点回读，音频仍按默认模型能力诚实降级。两次独立组合均通过（首轮 101.747s、复跑 81.150s），未出现 receipt 文本冒充媒体、重复生成或附件丢失。

随后复探异步 video producer→managed viewer：两次独立真实 managed flowrun 均完成，下游拿到 producer 的同一 MP4 MediaRef，源视频可回读（7.18–10.94MB），无重复生成、孤儿 receipt 或 viewer 只读到文本。两轮通过（132.522s、119.756s），确认长尾异步等待和同 run 线缆仍闭合。

同日复核 gateway-side 观测边界：`Anselm-API-Serve` 的 tagged full-stack e2e 在真实 `router → middleware → SQLite → upstream` 装配上通过，覆盖 install/chat/quota、Qwen 多模态、tool loop、stream/non-stream settle、额度/预算、拒绝 rollback、异步图像/语音/视频、混合模态与 debug 计费。部署公网面只返回规范化 completion、quota 和 liveness；`/metrics`、`/readyz`、pprof、expvar 均由独立 loopback admin listener 提供，原始 provider body/header/key 按设计不出端。因此 FRT-04 的用户可见媒体/flowrun/附件证据已闭合，但“部署公网可录制原始 provider wire”不能在不改变 API Serve 安全边界的前提下补齐，不能把该缺口伪装成已覆盖。

同日复跑 workflow 用户附件融合的 manual-trigger 入口：上传 PDF+PNG+MP4 后，payload 经 trigger → CEL → managed agent 完整穿线，flowrun completed；agent 从 PDF sandbox 提取唯一 token，同时保留三份 MediaRef，源字节分别为 552、98、2,969,360 bytes。两个独立 backend 进程通过（63.203s、62.185s），未形成 workflow 或多模态产品缺陷。

同日补做 chat 入口的同形 payload：managed 对话经 `search_tools` 发现 `trigger_workflow`，把 PDF+image 的 webhook-shaped body 交给 workflow agent；两次独立复跑均保留 `origin=chat`、`conversationId`、flowrun completed、PDF token 与两份 MediaRef（560-byte PDF、98-byte PNG），证明从 chat 工具进入不会绕过或削弱 workflow 的多模态接线。

同日补做外部 webhook 入口：真实 `POST /api/v1/webhooks/{triggerId}/{path}` 接收 PDF+image body，flowrun 以 `origin=webhook`、正确 `triggerId` 完成，agent 经 `start.body.*` 读取 PDF token 并保留 555-byte PDF 与 98-byte PNG。两个独立 backend 进程通过（31.469s、24.281s），manual/chat/webhook 三入口均未形成产品缺陷。

同日复跑 producer→viewer 的异步资源方向：managed workflow 先经 `generate_video` 提交并轮询真实 gateway job，再把视频 MediaRef 交给下游 managed viewer；两次独立复跑均 flowrun completed，最终 MP4 可回读（11,165,527 bytes、10,657,043 bytes），viewer 读取的是实际产物而非 receipt-only 占位。单次耗时约两分钟，符合异步视频任务的真实延迟，未形成产品缺陷。

同日补做 speech producer→managed viewer：workflow 生成真实 WAV 后交给下游默认 managed agent；两次独立复跑均 flowrun completed，WAV（80,684 bytes）可回读，viewer 对 chat audio 维持诚实降级而未伪造转录或 native audio 能力，未形成产品缺陷。

同日补做 image producer→managed viewer：workflow 上游只调用一次 `generate_image` 生成真实 PNG MediaRef，下游 managed agent 消费同一产物后 flowrun completed；两次独立进程均能从 attachment content 端点回读完整 PNG（1,115,024 bytes、1,096,630 bytes），viewer 不是只看到 receipt 文本，未发生重复生成或媒体丢失，未形成产品缺陷。

同日复探聊天入口的 workflow 生命周期组合：默认 managed chat 先发现并调用 `trigger_workflow`，随后分别通过 `get_flowrun` 读取 completed run、通过 `search_flowruns(status=failed)` 加 `get_flowrun` 诊断 durable 节点错误、再调用 `replay_flowrun` 恢复同一失败 run。三条路径在两个独立进程中全部通过（包总计 134.638s、126.102s）；`origin=chat`、`conversationId`、节点错误、已完成节点不重跑与 function/handler execution ledger 均闭合，未形成后端缺陷。

### FRT-07 最新证据

本轮先把语音输入与音色全生命周期放在同一 managed 组中复探：realtime ASR 独立通过（10.01s），但首个 `EnrollSpeakDelete` 进程在等待 60s 内没有得到 `enroll_voice` danger interaction，测试在审批断言前退出，未提交登记任务，不能把该红灯误判成库存、异步状态或删除语义缺陷。随后将生命周期场景隔离并以两个独立进程复跑，均完整通过危险审批→异步登记→克隆音色合成→删除，耗时 44.75s、54.67s；voice inventory/上游句柄和最终本地清理均闭合。当前结论是受管模型/网关时序可靠性哨兵，保留首轮 60s stall 证据，未改生产代码。

随后单独复探 realtime ASR：proof-bound WebSocket 接受 100ms PCM、完成 finish，并从部署网关收到 `session.finished`（1.69s）；未把静音帧误当成转写语义，传输与会话生命周期闭合。

### FRT-08 最新证据

同日复探 managed 朗读成本闸：顺序路径第一次合成、同文本同音色命中同一缓存、换文本生成新 WAV；并发路径在同 workspace 同 key 下同时发起两次相同请求，两个响应共享同一附件且 quota 只增加一次。两条场景在两个独立进程均通过（顺序 10.11s/9.93s，并发 5.81s/5.25s），未复现重复付费竞态；provider wire 计数仍受 API Serve 公网不暴露 raw wire 的设计边界约束。

同日再次对 managed 朗读做真实双跑：顺序缓存与并发 dedup 两条都通过（组合 18.784s、16.756s），quota 变化、共享附件和换文本新产物均符合预期；没有重复消费或缓存穿透。

本轮再次独立复探朗读与语音入口：顺序缓存、并发相同 key 去重和 realtime ASR 共 3/3 通过（包 18.649s；cache 10.19s、concurrent 5.97s、ASR 1.69s）；quota delta、共享附件与 `session.finished` 均闭合，未出现重复消费或资源孤儿。

同日补做 managed quota 设置面 fresh smoke：两个独立新 workspace 都读到自洽的 live `limit/used/remaining`、`available=true` 与 RFC3339 `resetAt`（5.158s、3.667s），没有触发模型或生成消费；配额投影当前没有回归。

### FRT-09 最新证据

同日复探 managed 高风险消费闸：`generate_speech` 与异步 `generate_video` 均先出现 danger interaction，客户端明确拒绝后回合完成；两轮独立进程均未进入合成、未铸造 provider receipt、未增加 generation reservation/quota。两轮整组通过（28.254s、27.967s；第二轮视频拒绝 11.64s），确认拒绝路径不会因上游窗口或重复点击而产生隐形消费，未形成产品缺陷。

同日再探批准后取消边界：视频任务在批准并提交后由客户端 `:cancel`，本地回合落 cancelled，历史与附件查询均不出现迟到视频或孤儿 receipt；底层 `generate_video` 的取消 WARN 是任务进程被杀后的可解释噪声。首轮在审批前 60s 未出现 interaction，随后两次隔离复跑完整通过（15.89s、31.58s），将红灯归类为 managed/provider 瞬态而非稳定产品回归。

同日复探直接 managed 生成低成本路径：`generate_image` 与 `generate_speech` 各自只执行一次，receipt 均标注受管 provider，PNG/WAV 真实附件可逐字节回读，回合完成且没有重复工具调用。两轮独立组合均通过（包 42.248s、44.673s；首轮 image 31.46s、speech 10.01s；复跑 speech 9.31s），未形成生成路由或成本闸回归。

同日复探编辑与动画专用写路径：`generate_image → edit_image` 两条 receipt 各恰一条，编辑 receipt 的 `sourceAttachmentId` 指向生成 sibling 且两份图片字节不同；文字-only `animate_image` 经过 danger approval 后走独立异步动画路由，source lineage 保留、单一真实 MP4 可回读。两轮独立组合均通过（包 207.653s、211.655s；动画分别 9,644,957 与 18,423,870 bytes），未形成编辑血缘、审批或异步产物孤儿。

本轮成本/人闸组合首个 managed 进程中，`generate_video` 拒绝、朗读顺序缓存、并发去重与 quota 均通过；`generate_speech` 首次未在 60s 内出现 danger interaction。将语音拒绝场景隔离后得到一绿一红（20.04s、64.62s）：绿色路径确认拒绝不铸造 receipt/不扣 quota，红灯仍停在 interaction 出现前，没有提交上游合成或状态断言。结合既有音色/视频审批复探，当前保留为 managed 模型/网关时序哨兵，不改成本或审批后端。

同日继续复探 denial continuation：语音成本闸再次在 60s 内缺失 danger interaction；视频两次均出现 danger interaction，deny 请求均返回 204，但正式断言各在 180s 内看不到回合终态。一个临时黑盒诊断进程在相同拒绝路径中捕获了完整 durable 序列 `tool_call → tool_result(The user denied...) → reasoning/text`，约 21.45s completed，且没有 generation receipt、附件或提交证据；因此把两类红灯保留为 managed 模型/上游流式续接时序哨兵，下一步应优先取得 gateway/stream request-level 观测再决定是否修产品层，不改成本闸或 broker。

紧接着做批准后的语音生成对照：`generate_speech` 连续两个独立 managed 进程各只调用一次，真实 WAV 可回读、receipt 标注 `provider=anselm` 且回合 completed（13.56s、10.70s）。这证明生成 route、artifact store 与 receipt ledger 没有随 denial 复探发生共享层回归；当前待查仍局限在 danger deny 后的 managed stream continuation 时序。

### FRT-01 最新证据

同日复跑默认 managed 三模态同回合 sentinel：同一用户消息同时携带 text、PNG 与 MP4，真实 Anselm API Serve 路由完成后，durable turn 保持 completed，三个附件仍可逐字节回读（80-byte fixture、98-byte PNG、2,969,360-byte MP4），未退化为占位文本、拆成错误的多回合或错误切换到 BYOK。两个独立 backend 进程通过（53.209s、48.321s）；关停阶段偶见的本地 search embedder `context canceled` 仍是已知 shutdown 噪声，未形成产品缺陷。

同日再复探支持/不支持模态交叉：默认 managed 同一回合携带 PNG 与 WAV，能力面继续只宣称 vision、不宣称 chat audio；两次独立进程均完成，PNG（98 bytes）与 WAV（96,044 bytes）原样回读，音频以诚实降级留在产品边界，没有把整回合变成 gateway 400 或伪造 native audio。关停阶段的 embedder `context canceled` 仍为已知噪声。

随后复探 managed 附件历史生命周期：一条路径在第二轮省略 `attachmentIds` 仍通过历史 re-projection 继续使用首轮图片，另一条路径删除首轮图片后 content 端点正确 404，后续对话仍 completed 且没有把已删媒体冒充为可读内容。两轮独立组合均通过（包 21.646s、16.020s），源 PNG 保持字节一致，未形成附件归属、lease、删除或历史装配缺陷。

同日补做附件生命周期哨兵：同回合两张独立图片均可回读；首轮消费图片后删除附件，后续回合面对 404 仍把历史媒体明确降级为 missing attachment 而完成；另一条会话在首轮带图后省略 `attachmentIds` 继续追问，历史媒体重新投影后仍完成且源字节不变。三条场景在两个独立 managed 进程中均通过（包总计 30.287s、29.376s），没有 400、孤儿媒体或跨回合丢失；关停阶段偶见 search embedder `context canceled` 仍归类为已知 shutdown 噪声。

同日再做附件删除/历史重投影两条最小组合的独立进程复探：删除后的历史回合继续诚实产出 missing-attachment 注记，省略 `attachmentIds` 的后续回合仍从历史投影得到原图语义，源字节守卫均通过。两轮组合均全绿（18.790s、19.490s），未形成生命周期回归。

同日复探 `inspect_media` 的参数下沉：图片 crop+high detail、视频 `startMs=1000/endMs=2000`、音频 `startMs=1200/endMs=2600` 均能返回带范围/模式/usage 的 bounded metadata capsule，PNG/MP4/WAV 源字节均未变。首轮三项组合通过（56.66s/16.15s/16.71s，包 90.245s）；第二个组合在音频项出现一次可区分的模型拒答——lazy 目录卡只暴露了必填参数，模型误以为 `startMs/endMs` 不在 schema。将时间窗能力前移到 `inspect_media` 目录卡首行并加离线断言后，音频时间窗两次独立真实复跑通过（30.93s、17.25s），确认是发现面提示缺口而非执行层不支持。

同日补做大文本读取三件套：对 136,890/116,043/157,248-byte 级别的文本附件，managed 模型分别真实完成 `read_attachment` 的 query、显式 compact index 与省略控制参数的 auto-index；每条返回均保持 bounded，query/index 没有把正文整段泄漏到回合，源附件仍可逐字节回读。两轮独立进程三项全通过（首轮包 42.727s，Query/Index/AutoIndex 为 13.86s/7.88s/20.36s；复跑包 30.145s，Index/AutoIndex 为 7.52s/9.45s，Query 亦通过），没有再出现参数类型校验警告或隐式全文投影。

同日复探文本 `inspect_media` 的两个 bounded 形状时，首轮真实暴露了同一 lazy 目录卡缺口：`read_attachment` page 通过，但模型把 `inspect_media` 误读为只有 `attachmentId/question`，拒绝 page/limitChars，且 offset-window 只能走默认 12,000 字符窗口并找不到位于目标 offset 的 token。执行层 schema 本来已声明这些可选字段；将 `page/offset/limitChars` 与时间窗一起前置到首行后，两个场景连续两轮独立进程完成（首轮 20.59s/17.60s，包 38.479s；复跑包 38.252s），均返回 bounded 证据且源文本不变，确认是发现面提示问题而非 extractor/分页实现缺陷。

同日把直接 `inspect_media` 的图像、音视频证据补成完整组合：图片普通视觉、crop+high detail、2×3 tiles，以及视频普通/`1000–2000ms`、音频普通/`1200–2600ms` 七条路径均在真实 managed 回合完成；参数出现在 tool result 的 bounded evidence/capsule 中，音视频保持 metadata-only 合同，所有 PNG/MP4/WAV 源附件逐字节不变。两次独立进程组合均通过（135.017s、113.666s），未形成媒体检查或参数下沉缺陷。

本轮再做默认入口附件高频组合：单图、文本+图、多图、删除附件后的历史降级、保留附件的跨回合重投影，以及文档内图片引用，首轮与第二个独立进程均 6/6 通过（包 38.941s、48.030s）。PNG/文本源件均可回读，删除只产生诚实的 missing-attachment 注记，历史重投影没有跨回合丢图或占位 receipt；关停阶段的本地 search embed `context canceled` 仍是已知噪声。

随后复探默认 managed 的音视频能力矩阵：纯 WAV、image+WAV、MP4、MP4+WAV、image+MP4、text+MP4、text+WAV、text+image+MP4 八条入口首轮与第二个独立进程均 8/8 通过（包 251.428s、257.708s）。支持的 image/video 分支保持 native/字节保真，不支持的 audio 只形成明确降级注记，三模态同回合不拆回合、不产生 400 或伪造音频理解；源 MP4（2,969,360 bytes）与 WAV（96,044 bytes）均可回读。

本轮再做 managed 音视频与时序边界第二独立组合：视频+不支持音频、文字+图片+视频三路融合、视频/音频时间窗 `inspect_media` 共 4/4 通过（包 119.233s）；PNG、MP4、WAV 源字节均可回读，时间窗结果保持 bounded metadata，未出现 provider 400、错误转录或能力投影退化。

紧接着复探 `inspect_media` 工具面十条路径：图片普通/crop/high-detail/tiles、视频普通与时间窗、音频 metadata 与时间窗、文本 query/page/window，两次独立进程均 10/10 通过（163.419s、189.649s）。工具结果保持 bounded，音视频只返回 metadata capsule；首轮文本 query/page 出现过模型漏填必填 `question` 的校验警告但随后自我修正，复跑无警告，未形成后端执行或参数下沉缺陷。

本轮再做附件/文档读取长尾组合：`list_attachments`、纯文本、PDF、PDF+图片、PDF 工具读取，以及大文本 query/index/auto-index/page 共九条路径中七条首轮通过（129.417s）。PDF 工具路径实际先用 `attachmentId` 触发 `id is required`，随后用正确的 `id` 成功抽取 token；原断言漏看 block 的 `tool` 属性，已在 `4e33cd6a` 修正并由真实 managed 复跑通过（22.94s）。默认大文本 auto-index 在组合中一次触发 `MAX_STEPS_REACHED`，隔离后两次均通过（15.42s、27.17s），因此仍归类为模型参数纠错/步预算窗口信号；query/index/page 与源字节保真均成立。

同组第二个独立组合的七条稳定路径再次 7/7 通过（包 76.492s）：附件发现、纯文本、PDF、PDF+图片与大文本 query/index/page 均完成，PDF/PNG/文本源件逐字节保持；多条测试仍可见模型先传错 `id` 字段后自行修正的校验警告，但没有持久化或读取结果回归。

### FRT-05 最新证据

同日补充真实并行子代理树闭环：父聊天只派两个独立 `general-purpose` 子代理，两个子任务各自经 `search_tools`→`run_function` 执行不同 function；两个 child message 都以不同 `parentBlockId` 锚回父级 `Subagent` tool_call，父回合同时收到两个 marker 且没有直接调用 `run_function`。两个 function execution 各恰一条 `status=ok`、`triggeredBy=agent` 记录，并绑定同一 conversation 与 child message。探索阶段一次上游 502、两次测试 oracle 校准（模型先纠正缺失 `subagent_type`；执行台账结果字段为 `output` 而非 `result`）均未形成产品缺陷；校准后两次真实 managed 复跑通过（93.71s、76.33s）。关停阶段的本地 search embedder `context canceled` 仍归类为 shutdown 噪声。

同日补上真实嵌套失败证据：父聊天只派一个 `general-purpose` 子代理，子代理经 `search_tools` 发现 `run_function` 并调用一个必然抛错的 function；失败 execution 记录 `status=failed`、`triggeredBy=agent`、同一 `conversationId/messageId`，错误 marker 同时留在子消息树与父 `Subagent` tool result，父回合仍以 completed 结束且没有越权的父级 function 调用。两次真实 managed 复跑通过（49.94s、55.356s），补足 FRT-05 原先仅 mock 的失败续接证据，未形成后端缺陷。

同日补上真实嵌套取消证据：父聊天派出 `general-purpose` 子代理，子代理进入一个 60 秒 function 后，客户端按真实 `:cancel` 动作中止父回合；取消接口返回 204，父消息与带 `SubagentID` 的子消息均落 `cancelled`，function execution 恰一条、`status=cancelled`、`triggeredBy=agent` 且绑定 child `messageId`，同一对话的 follow-up 完成且没有复活旧 tool call。修订后的真实 managed 复跑通过两次（55.39s、53.93s）。初次探索曾等待 REST `/messages` 出现子代理的 streaming tool block，128.65s 后超时；期间历史端点只返回父侧短投影，直到子回合自然终态才批量出现嵌套 blocks。改用与 UI/SSE 等价的定时取消，再从 durable history/ledger 验证终态，证明这是 REST 历史投影的批处理边界而非取消后端缺陷。取消时 `run_function` 的底层进程组被杀并留下 `spawn process failed` WARN，但 durable/wire 语义正确；该日志目前归为可解释的取消噪声，不计稳定产品 bug。

同日补上失败 subagent 树的真实分叉：child 的 function 真实落一条 `failed + triggeredBy=agent` execution，错误 marker 与 completed child row 随 latest fork 携带，消息级 `parentBlockId` 重定基到分支自己的 `Subagent` tool_call；分支 follow-up 不复活失败工具、ledger 仍只有一条 execution，源历史不变。首轮探索只暴露了测试按最新在前历史过早校验 parent anchor 的 oracle 顺序问题，改为先收集全部 block 再验证后，两次真实 managed 复跑通过（62.26s、36.45s），未形成 backend 缺陷。

同日补上取消 subagent 树的真实分叉：父/child 通过真实 `:cancel` 都落 `cancelled` 后，latest fork 保留 child 的 terminal 状态与重定基后的 `parentBlockId`；底层 function ledger 仍恰一条 `cancelled + triggeredBy=agent`，分支 follow-up 不复活在途工具。两次真实 managed 复跑通过（54.58s、54.88s），关停时偶见 search embedder `context canceled`，归类为 shutdown 噪声。

同日补充并行子代理的跨回合上下文续接：首轮两个 child 均完成后，第二轮用户追问只要求复述两个 marker；父回合在不调用任何工具的情况下逐字恢复两份结果，历史仍保留恰两个 completed child、原 `parentBlockId` 锚点和两条唯一 `agent/ok` function execution。两次真实 managed 复跑通过（74.62s、59.65s），未形成后端缺陷。

同日补做单子代理附件消费三件套：文字附件由 child 读取并回传唯一 token，PDF 由 child 经 sandbox `read_attachment` 抽取 token，图片由 child 通过 `inspect_media` 产生 bounded evidence；父层均不偷调、源附件保持字节不变。首轮组合中文字/PDF 通过（32.11s/31.37s），图片链连续两次快速收到 managed `LLM_PROVIDER_ERROR (502)`，随后隔离重跑在长尾约 105.077s 完整通过；直接父层 `inspect_media` 对照也通过（20.394s），故当前把 502 归类为 subagent→nested-vision 的上游瞬态/长尾，不宣称稳定 backend 缺陷。第二个独立组合进程三条均通过（包 124.774s），FRT-05 仍保留该红绿分叉供后续 gateway/模型变更时复探。

同日复探子代理 managed image writer 时，低步预算下出现新的真实可靠性信号：三次独立进程中两次以 `MAX_STEPS_REACHED` 终止（17.901s、60.827s），共同伴随模型先传非法 `subagent_type` 的 schema warning；一次通过（52.834s）并确实只有一条 `generate_image` receipt、真实 PNG 可回读。红灯均发生在 durable image/receipt 断言之前，未观察到附件孤儿或重复生成，因此暂归为「模型参数纠错消耗父层 maxSteps=3」的 managed/tool-schema recovery 边界，而非已证实的存储或媒体后端缺陷；该红绿频率保留为后续提示词/预算/模型升级的回归哨兵。

同日复探子代理音视频时序边界：两个独立 managed 进程中，general-purpose child 均真实调用 `inspect_media`，视频回传 `kind=video/mode=metadata/startMs=1000/endMs=2000`，音频回传对应 `kind=audio/mode=metadata/startMs=1200/endMs=2600`；父层没有偷调，父回合完成，MP4/WAV 源字节均原样回读，未伪造 transcript。两轮组合均通过（包 130.455s、136.764s），未形成产品缺陷。

随后做子代理附件读取的对照复探：同一真实 managed 进程内，`general-purpose` child 分别读取 text 与 PDF，前者回传唯一 token，后者经 sandbox `read_attachment` 回传唯一 token；父层没有直接调用附件工具，两个源附件都逐字节保持不变，父回合均完成。组合包通过（115.530s；PDF 子场景 31.34s），说明前述 image writer 的两红一绿更像媒体写入路径叠加低 `maxSteps` 与模型 schema recovery 的可靠性边界，而不是通用 subagent/attachment read 缺陷。

本轮把同一 workflow producer→viewer 交叉面扩展到三种非 agent 产物：managed function、resident handler 与 stdio MCP 各自生成 MediaRef，再由 OpenAI BYOK vision viewer 接收并验证原始字节。三条路径首轮和第二个独立组合均通过（包 49.855s、48.202s；各单项约 13–20s），没有把产物降成 receipt 文本，也没有跨 workflow 或跨 provider 丢失附件；FRT-03/FRT-05 的 producer 共同层未形成回归。

本轮把并行子代理四项状态机组合拆成独立复测：聚合运行包在 248.957s 结束为 FAIL，其中 `SubagentCancelTerminal` 仍通过，取消 204、父子消息/函数 execution 均落 `cancelled`；`ParallelSubagentTrees` 独立通过（69.80s），两个 child、两个不同 `parentBlockId`、两个 marker 与各自唯一 function execution 均闭合。`SubagentFunctionFailureContinues` 连续两个独立进程均红，但红法不同：一次子代理拒绝调用预期失败函数，另一次没有产生 child execution；父回合都能 completed，却未满足测试要求的“确实执行一次失败函数并把 marker 带回”。`ParallelSubagentContextContinues` 一次独立进程通过（64.57s），另一次在模型先拒绝/重试后生成 4 个 durable child（两个重试 child + 两个最终成功 child）而非测试期望的 2 个，两个 marker 与函数执行本身均正确。当前证据指向 managed 模型的工具可用性判断、提示注入/安全拒绝与重试遵循波动，不是 backend 的孤儿、重复执行或锚点丢失；保留为 FRT-05 可靠性哨兵，不改生产代码，后续在模型/提示词/步预算变更时复探。

最新同一组合独立复跑重新全绿：`SubagentFunctionFailureContinues` 确实产生 `failed + triggeredBy=agent` execution，错误 marker 经 child message 与父 `Subagent` tool result 续接，父回合 completed；`ParallelSubagentContextContinues` 的两个 child 均完成，下一轮无工具 follow-up 逐字恢复两个 marker，历史锚点与各自 function execution 均闭合。该包 110.627s 全部通过，推翻不了前述红绿波动的事实，但进一步支持其为 managed 模型工具遵循/重试时序哨兵，而非已确认的 backend 状态机缺陷；继续保留低频复探，不改生产代码。

### FRT-06 最新证据

同日对文档内图片引用做双侧独立复探：managed 默认入口与 OpenAI BYOK 入口都从文档正文的图片引用解析到同一附件 MediaRef，模型回合完成，附件 content 端点回读的 98-byte PNG 与文档/消息投影一致；BYOK 路径保持 OpenAI 选择，不发生 managed fallback。managed 两次通过（5.974s、7.793s），BYOK 两次通过（4.796s、4.795s），未形成文档引用、附件归属或多模态编码缺陷。

### FRT-10 最新证据

同日复探 Qwen chat-only 模型的 agent 资格闸：API key 探测与能力投影允许该模型作为对话模型，但把它显式设置到 agent 后，真实 `:invoke` 在 0 steps 直接落 `failed`，错误说明为 `cannot run as an agent`，未产生 tool call、function execution、模型回退或消费。两次独立 BYOK 进程通过（3.656s、3.050s），未形成目录裁剪或路由边界缺陷。

### FRT-11 最新证据

本轮先做 DeepSeek 兼容线缆的真实双跑：`deepseek-v4-flash` 在产品 API 内完成 `run_function`，函数结果回灌后第二次 chat/completions 采样完成；durable history 同时保留 tool call、tool result 和最终 `144`，recorder 观察到至少两次请求且请求携带 `tools`、`tool_calls` 与结果载荷。两次独立进程通过（12.52s、9.52s），未形成产品缺陷；关停阶段的 embedder `context canceled` 仍是已知 shutdown 噪声。

随后换到 Gemini 原生 `functionCall/functionResponse` + `thoughtSignature` 线缆。两次独立进程都在首轮 generate 收到上游 429，产品把回合落为结构化 `LLM_RATE_LIMITED` 并停止，没有重试成 404、没有生成 assistant 文本，也没有进入错误的 parser 断言；这记录为当前 Google provider rate window，而不是后端工具参数缺陷。FRT-12 的累积/增量本地 fixture 仍全绿，真实 parser 组合在 provider 窗口恢复或 parser 承重变更时再复探。

本轮补做原生 Anthropic 黑盒闭环：本地 Anthropic-shaped upstream 先由真实 backend 以 `GET /v1/models` + `x-api-key` + `anthropic-version: 2023-06-01` 探测，随后同一 key 的能力面保留 `claude-opus-4-8`、image/PDF 与 `thinking`/`effort` 原生旋钮；对话调用严格落到 `/v1/messages`，请求是 block-form `messages` + `stream:true`，没有 Bearer/OpenAI 兼容退路；命名 SSE 的 `message_start`、text delta、`message_delta(end_turn)` 产生的文本、stop reason 与 input/output usage 全部落入 durable turn。两次独立 backend 进程通过（6.47s、4.30s），未形成产品缺陷；测试隔离 free-tier install 失败与 shutdown embedder `context canceled` 仍为已知噪声。Azure/Vertex 仍需真实凭证才能补证，当前不伪造其结果。

紧接着补上 `custom + anthropic-compatible` 的产品入口：同一类本地端点通过 custom key 的闭合 `apiFormat` 白名单进入，`:test` 仍敲 `/v1/models`，model capability 只呈现 live model id、不凭空声称 image/PDF/旋钮，实际对话却通过 `lookupProvider` 切到原生 `/v1/messages`，同样使用 `x-api-key`、Anthropic 版本头、block-form body 与命名 SSE。两次独立 backend 进程通过（6.42s、4.07s），未形成产品缺陷；这证明「未知 custom 能力保守」与「用户明确选择 Anthropic 方言后 wire 正确」可以同时成立。

随后补齐对称的 `custom + openai-compatible` 入口：`:test` 使用 OpenAI 风格 `GET /models` + Bearer，聊天使用 `/chat/completions` + Bearer、`stream_options.include_usage` 与 data-only SSE；同一产品 API 把 wire 上的 `finish_reason=stop` 规范化为 durable history 的 `stopReason=end_turn`，token usage 与回答均落盘，且没有误走 `/v1/messages`/`x-api-key`。两次独立 backend 进程通过（5.31s、3.30s）；第一次 focused 红灯只是测试 oracle 错把 provider wire 的 `stop` 当成 durable 合同，修正为 `end_turn` 后未形成产品缺陷。

随后做当前 DeepSeek BYOK continuation 的稳定性对照：首轮三场景批次通过；第二轮在 `maxSteps=4` 下真实出现 `MAX_STEPS_REACHED`，回合保留诚实 partial 语义而不是伪造最终答案。该场景随后两个独立默认预算进程均通过（13.202s、14.912s），再以临时 `maxSteps=8` 控制实验通过（14.548s），且实验参数已恢复、未进入工作树。四次抽样合并为三绿一红，证据指向模型偶尔消耗额外工具/schema recovery 步数，而非共享 loop 的终态、tool-call/tool-result 投影或 DeepSeek wire 稳定损坏；低预算组合继续保留为 provider/模型升级时的可靠性哨兵。

同日复核 Kimi 凭证边界：当前 `KIMI_API_KEY` 两次独立 `:test` 都收到上游 401，产品稳定返回 422 `API_KEY_TEST_FAILED`，`details.reason` 保留 `HTTP 401` 且没有把失败误报为 model-not-found 或 generic transport；当前凭证仍不可用，未宣称 Kimi chat 绿。

随后 Google 原生工具续接的 provider 窗口恢复：`gemini-3-flash-preview` 两个独立 backend 进程均真实完成 `functionCall → functionResponse → 最终回答`，上游请求继续携带原生 `thoughtSignature`，durable history 保留工具调用、结果与最终文本，没有再出现 429、错误重试或 parser 误报（12.816s、11.452s）。此前的 429 仍作为历史 rate-window 证据保留，当前不再阻断该 lane。

### FRT-13 最新证据

同日补上真实 managed 原地重试闭环：首轮默认 chat 完成后调用 `:retry`（无 content 的 regenerate 分支），旧 assistant 行保留，新 assistant 行通过 `supersededBy`/`attrs.retryOf` 组成线性版本链，历史仍只有一条 user 行；随后在最新版本上继续发送 follow-up，回合再次 completed。两次真实 managed 复跑通过（总计 11.951s、12.262s）。首轮优雅关停阶段出现一次 search embed `context canceled` WARN，第二轮未复现，归类为测试服务 shutdown 噪声而非产品缺陷。

本轮再做普通 fork 与原地 retry 的最小高频组合，两次独立 managed 进程均通过（包 19.203s、24.079s）：fork 保持源线程 append-only 并可在分支继续，retry 保留旧 assistant、追加版本指针后继续对话；未见跨线程消息、旧工具复活或版本链断裂。

同日补上 retry 与 fork 的交互证据：先在真实 managed chat 生成 assistant，再走无 content `:retry` 形成两版本链，随后走空 body 的 latest `:fork`。分支耐久历史保留 user + 两个 assistant 版本，但 `supersededBy`/`attrs.retryOf` 均重定基到分支自己的新 message ID；分支 follow-up 只使用当前版本并完成，源历史仍保持 3 行。两次真实复跑通过（28.37s、20.98s），未形成后端缺陷。

同日补上显式旧版本切点：在 retry 链上以旧 assistant 的 message id 调 `:fork`，分支只复制 user + 旧 assistant；被切掉的新版本不留下悬空 `supersededBy` 或 `attrs.retryOf`，旧回答在分支内重新成为 current，分支 follow-up 完成且源仍保留三行历史。两次真实 managed 复跑通过（13.70s、12.32s），未形成后端缺陷。

同日复探会话生命周期组合：普通 conversation fork、最新 assistant retry 后继续对话、旧版本 retry→fork 后继续对话三条路径在两个独立 managed 进程中全部通过（包总计 34.598s、27.400s）。源会话保持 append-only，retry 的 `retryOf`/`supersededBy` 与 fork 后的分支指针均落在新分支，旧版本切点没有悬空指针，分支 follow-up 完成且没有复活旧工具调用；未形成后端缺陷。

本轮再做聊天侧 workflow 状态机交叉复探：`search_tools → trigger_workflow → get_flowrun` 可观测读取、失败 run 的 `search_flowruns → get_flowrun` 诊断、human approval durable park→`decide_approval`→下游 publish，以及失败后的 `replay_flowrun` 都在首个独立组合中完成（包 180.391s）。第二个组合出现一次单场景红灯，但其余三项通过；将疑似失败的 `ChatFlowrunFailureDiagnosis` 隔离后连续两次通过（42.362s、58.943s），没有稳定错误、孤儿 run 或错误恢复缺陷，因此只保留为 managed 模型/工具序列波动哨兵，不改生产代码。

### FRT-14 最新证据

同日复探 Google 目录资格漂移：`gemini-2.5-flash` 仍在当前 `/models` 投影，但同一显式选择连续发送两次时，每回合只发一次上游请求并分别落 `LLM_MODEL_NOT_FOUND`，没有 assistant 文本、managed fallback 或无界重试；两次独立进程通过（6.282s、4.212s）。自动失效/降级仍保留为待产品决策的策略缺口。

本轮再次对该重复失败边界做两次独立复跑：同一显式模型连续两轮各自只产生一次非重试 generate，两个 error turn 都是 `LLM_MODEL_NOT_FOUND`，没有 assistant 文本或受管回退；两次包级通过（5.157s、3.934s）。证据继续支持“错误分类与重试上限已闭合”，而不是替产品决定自动失效/降级策略。

同日补做资格错误后的显式恢复：旧 Gemini 模型首发只调用一次并落 `LLM_MODEL_NOT_FOUND`，用户随后明确切换到 `gemini-3-flash-preview`，同一 conversation 恢复 completed 且总上游调用恰两次；两次独立复跑通过（6.959s、6.412s），没有错误回合污染后续历史。

本轮所有 live 探针与文档变更后执行一次全量后端黑盒回归：`testend/scenarios` 用时 328.040s 全绿，未引入新的稳定产品缺陷；该门禁只证明当前已落地行为没有被本轮工作回归，不替代各 provider/managed 场景的独立真线缆证据。

### FRT-15 最新证据

同日补上真实 managed workspace 的大图扇出/AND-join 闭环：一个 manual flowrun 展开 8 条 action 分支，两个四输入 join 在所有上游完成后各执行一次，finish 汇总 12 条 durable node rows；function ledger 同时证明 8 次 branch、2 次 join、1 次 finish 均绑定同一 `flowrunId`、`flowrunNodeId` 唯一且成功。两次真实复跑通过（总计 9.109s、9.867s），未形成后端缺陷；关停阶段 search embedder `context canceled` 仍归类为服务 shutdown 噪声。

同日再补用户入口组合：默认 managed chat 先经 `search_tools` 发现 `trigger_workflow`，再以 webhook-shaped payload 启动 4 路 fanout/双 join workflow；`origin=chat`、`conversationId`、8 条 durable node rows 及 branch execution ledger 均闭合。前两次探索分别受 managed gateway 响应头 timeout 与上游 502 阻断，未进入 workflow 断言；随后两次规范复跑通过（总计 30.092s、29.445s），因此红灯归类为外部 provider 窗口而非产品缺陷。

同日复探 workflow 并发核心与聊天入口组合：manual flowrun 的 8 branch/双四输入 join，以及 chat→`search_tools`→`trigger_workflow` 的 4 branch/双 join 均在两轮独立 managed 进程中通过（包总计 26.704s、26.876s）。所有 branch/join/finish execution 绑定同一 `flowrunId` 且各执行一次，chat 路径的 `origin=chat`、`conversationId` 与 durable node rows 保持闭合，未形成后端缺陷。

同日复探 workflow 内用户多模态融合三入口：manual trigger、真实 webhook 与 chat→`trigger_workflow` 均把 PDF+PNG+MP4 MediaRef 送入 managed agent；PDF 继续由 sandbox 抽取 token，PNG/MP4 走原生媒体分支，flowrun origin/`conversationId` 与三份源附件字节均保持可审计。两轮独立进程全绿（包总计 131.513s、177.032s），未形成入口间的媒体映射或 lazy-tool 回归。

### FRT-16 最新证据

同日补上真实对话分叉闭环：先完成一轮默认 managed chat，再从该 assistant 消息调用 `:fork`；源会话仍保持原 2 条 append-only 消息，新会话复制同一前缀但不复用源 assistant ID，返回的 `forkedFromConversationId`、`forkedFromMessageId` 与 `(fork)` 标题后缀均正确。随后在新分支继续发送 follow-up，仍经默认 Anselm 路由完成；源会话消息数保持不变。两次真实 managed 复跑通过（总计 13.209s、12.768s），未形成后端缺陷。

同一轮的普通 fork/retry 复探再次确认会话血缘没有被近期媒体与工具路径改变：两轮组合均通过，源历史、分支 follow-up 与 retry 版本链保持前述约束，未形成新的生命周期缺陷。

同日再补并行 subagent 树的真实分叉闭环：源对话先由两个 `general-purpose` child 各自发现 `run_function`、执行不同 function 并留下两个 marker；空 body 的最新分叉路径复制完整耐久树，child message 与 block 均铸造新 ID，两个 `Attrs.parentBlockId` 都重定基到分支自己的父 `Subagent` tool_call，源线程保持原集合；分支 follow-up 不调用工具却能恢复两个 marker。探索时显式切在 parent message 的首次断言误把“前缀不含后续 child”当成缺陷，改用 rail 的 latest fork 语义后，真实运行确认了一个后端缺陷：分叉复制了 child 行，却把消息 Attrs 中的 `parentBlockId` 留成源 block ID；`Fork` 现与 `Block.ParentBlockID`、`retryOf` 一起重映射该消息级 E3 锚，并由真实 store 单测锁住。修复后两次独立 managed 复跑通过（67.90s、72.20s）；中间模型未稳定产出双 child 的红灯未进入分叉断言，归类为 managed 波动而非产品缺陷。

同日补上版本链分叉交互：这条路径与上面的并行 subagent 树分叉互补，证明 `Fork` 的同一份预铸 message remap 表同时覆盖 `retryOf`/`supersededBy` 与消息级 E3 锚；真实 retry→latest fork→branch continuation 两次通过（28.37s、20.98s），源分支均未出现跨线程指针。

同日复探 managed 视频提交后取消：批准后确实进入异步 `generate_video`，随后 `:cancel` 返回 204；父回合、durable history、附件与 receipt 均保持 cancelled/无孤儿，后续不会被迟到的上游结果复活。当前窗口首轮 60s 未等到审批 interaction，隔离后两次通过（15.89s、31.58s），与既有取消证据一致。

同日补上失败树分叉交互：失败 child 的 durable error 证据与 E3 锚和成功 child 使用同一套 fork remap 语义；这条路径两次通过（62.26s、36.45s），补足了 FRT-05 “failure is durable” 与 FRT-16 “fork is self-contained” 的交集。

同日补上取消树分叉交互：取消 child 与失败 child 一样是可读的 durable terminal history，而不是被 fork 丢弃的 transient；两次通过（54.58s、54.88s），补足 FRT-13 取消恢复与 FRT-16 分支自洽的交集。

同日再做成功/失败/取消三类子代理树的 fork 聚合复探：失败与取消路径继续通过；并行路径一次由托管模型重复派发到 4 个 child，两个 marker、4 个父锚点和父回合完成态都存在，但严格“恰好两个 child”断言未满足。独立复跑在 104.552s 通过，未见 fork 消息/block 铸造、`parentBlockId` 重映射、终态或 function ledger 缺陷，因此保留为 managed 重复派发波动哨兵，不改生产代码。

同日复探 BYOK 读取协议的产品入口：DeepSeek OpenAI-compatible 与 Google Gemini 原生文本 smoke 连续两个独立进程均通过，key probe、model-capabilities、显式 default model、真实 conversation turn 与 assistant 文本保持闭合；managed gateway 在 BYOK-only workspace 中未介入，未形成 provider 方言或路由回归。

同日继续沿 DeepSeek 兼容层下钻 tool continuation：两次独立进程都保住 assistant `tool_call`、sandbox function 的 `144` 结果和第二次 assistant sampling；录制请求同时含 `tools`、`tool_calls` 与工具结果，未发现重复执行、managed fallback 或兼容序列回归。

同日复探 Qwen `qwen3.7-plus` 的双原生媒体入口：image+video 同回合融合连续两次通过，能力投影、录制 wire 的 exact-byte `image_url`/`video_url`、附件回读与无上游 400 均闭合，未形成 renderer 或组合契约回归。

同日补测 Qwen Omni 的组合限制：image+audio 连续两次通过，`maxDistinctMediaKinds=1` 能力契约被 renderer 遵守，图片保留原生 wire、音频明确降级而不是把供应商 400 暴露给用户；附件字节与回合终态稳定。

同日补上 OpenAI `gpt-audio` 的音频+agent 交叉面：原生 `input_audio` 的 exact bytes、tools、sandbox function 与第二次采样连续两轮闭合，未出现媒体丢失、工具结果截断或重复执行。

同日复探 Google Gemini 原生工具线缆：`functionCall`、`functionResponse`、`thoughtSignature` 与第二次 streaming `generateContent` 连续两次闭合，未出现 429、错误回合污染或工具结果丢失。

同日复核 Kimi/Moonshot 凭证错误边界：当前 key 连续两次由 `:test` 稳定落 422 `API_KEY_TEST_FAILED`，结构化保留 `HTTP 401` 原因，没有被误报成模型不存在、网络错误或可用能力。

同日切到 sibling `Anselm-API-Serve` 做一次完整契约门禁：vet、trimpath build、race 测试、integration-tag 真 HTTP+SQLite e2e、golangci-lint 与 docs lint 全绿；其工作树保持 clean，主仓本轮 managed/BYOK 证据与 gateway 公共合同未出现漂移。

同日对 Google Gemini 原生 image-input 做两次真实探针，均触达当前 provider 429；产品稳定归类 `LLM_RATE_LIMITED` 并停止，没有错误回合 assistant 文本、managed fallback 或媒体编码误报。视觉 wire 证据暂留待 provider rate window 恢复后再取，不能把这两次限流当成视觉能力通过。

同日对 Google Gemini 原生 image-input 做第二轮当前窗口复探，两个独立进程仍均收到 provider 429，并由产品结构化归类 `LLM_RATE_LIMITED` 后 skip（5.17s、3.10s）；OpenAI/Qwen 视觉与 Google 原生工具续接仍各自有真实通过证据，但 Google image-input 的 native wire 继续保留为 provider rate-window 缺口，不改 parser 或能力投影。

同日补一条 OpenAI `gpt-4.1-mini` 真实 image-input 对照：连续两次完成，能力投影、回合终态与附件源字节均闭合；这给 FRT-02 保留了当前可用 provider 的视觉用户路径证据，不把 Google 的限流窗口扩大解释成共享后端故障。

同日复探 OpenAI 多模态历史生命周期：image retry 与 edit/resend 连续两轮均保留 native image wire、原附件字节和正确 assistant 版本关系，未重复 user 消息或退化成 text-only retry。

同日复探 managed 会话血缘三件套：普通 fork、retry→fork 与旧版本 retry→fork 连续两轮保持 source append-only、版本指针与分支 continuation 自洽，未复活旧工具或产生跨线程消息。

同日复探聊天入口 workflow 状态机四件套：observability、失败诊断、human approval park→decide 与 replay 连续两轮全绿，durable flowrun/node、interaction、下游恢复与错误分类均闭合，未形成孤儿 run 或错误回合污染。

同日复探 workflow fanout/双 join：manual 8 分支和 chat→`trigger_workflow` 4 分支连续两轮全绿，所有 branch/join execution 绑定同一 `flowrunId` 且各执行一次，chat 路径 `origin=chat`、`conversationId` 与 durable node rows 均闭合。

同日补做聊天多模态 workflow 入口：`search_tools → trigger_workflow` 携带 PDF+PNG+MP4 MediaRef 连续两次完成，PDF 仍由 sandbox 抽取 token，PNG/MP4 与三份源字节、`origin=chat`、`conversationId` 和 flowrun 节点行保持闭合，未出现入口专属媒体映射回归。

同日补做非聊天触发源对照：manual trigger 与 webhook body 的用户附件融合连续两轮全绿，PDF token、`origin`/`triggerId`、flowrun 状态、CEL 接线及 PDF+PNG(+MP4) 源字节均保持闭合，未发现 chat 之外的 MediaRef 丢失。

同日以完整 `make -C backend testend` 收口本轮工作：`testend/scenarios` 342.216s 全绿，未见本轮 live 场景或测试 oracle 变更造成黑盒回归；该门禁继续只作为当前落地行为的基线，不替代各 provider/managed 的独立真实证据。

同日再做会话生命周期组合的独立复探：普通 fork、retry continuation 与旧版本 retry→fork continuation 仍保持同一组 durable lineage 约束，两轮均全绿；两次运行均未观察到源历史改写、跨线程 message/block 指针或旧 tool execution 复活。

同日复探聊天侧人在环 workflow：第一回合让 `trigger_workflow` 在 `human` approval 节点 durable park，第二回合只读 parked 状态，第三回合调用 `decide_approval(yes)` 继续下游 publish action。两次独立 managed 进程通过（53.682s、47.580s），decision、marker、`flowrunId`、`origin=chat` 与下游 execution ledger 均闭合，未形成审批恢复缺陷。

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
