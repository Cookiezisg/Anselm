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
| FRT-01 | 默认聊天 + 图片/视频附件 + 语音输入 | managed-read/default | Anselm 的实际输入路由、lease 与能力降级正确；语音输入另走 proof-bound ASR WebSocket | 请求形状 + 回合/附件真相；ASR `session.finished` | image / MP4 video / image+MP4 same-turn fusion / realtime ASR session 通过；默认 chat 不宣传 audio，但 WAV 附件在单独和“图片+不支持音频”同一回合中都真实走明确文本降级，图片仍走受管视觉路由，回合完成且附件字节不变 |
| FRT-02 | BYOK 视觉/音视频输入 | byok-read | 多模态输入是正式 BYOK 能力，不被生成边界误关 | 目录能力、wire part 或明确文本降级 | OpenAI image / Google Gemini image / Qwen MP4 video / Qwen WAV audio / Qwen image+MP4 same-turn fusion / 同会话 Qwen→OpenAI 模型切换后的 history media re-projection 真实通过；Qwen3 Omni image+WAV 真实探测确认上游只允许 text+单一其它模态，产品现在保留图片原生 wire、将音频明确降级为文本注记而不再把组合转成 400；OpenAI `gpt-audio` 目录滞后由 provider-owned capability bridge 覆盖，真实 WAV `input_audio` 产品路径及 audio+`run_function` continuation 已通过 |
| FRT-03 | BYOK 模型调用受管出图 | hybrid | 模型调度与受管生成正确接合，生成者不被重复喂像素导致重画 | tool/receipt、调用次数、产物与后续请求 | OpenAI→managed image 通过；真实 OpenAI continuation wire 已逐字节收到生成图片 |
| FRT-04 | workflow：生成者 → 下游观看者 | hybrid | 下游收到真实媒体而非“产物已生成”文本 | 录制请求包含原始媒体字节 | managed image→BYOK OpenAI / Google viewer、managed speech→BYOK Qwen audio viewer、managed video→BYOK Qwen qwen3.7-plus viewer 的 workflow exact-byte wire through；纯 managed 下游节点也完成且附件可回读；managed provider wire 仍待 gateway 侧 recorder |
| FRT-05 | MCP/function/handler 产物 → 下游模型 | byok-read / hybrid | 各产地均能成为 MediaRef；不退化为占位字符串 | 产物字节、MediaRef、下游请求 | MCP/function/handler producers and chat/workflow vision wire through；subagent managed generation→receipt state through；subagent provider failure is annotated, durable, and parent-continuable；同一 execution group 的双 subagent 并发结果各自挂回独立 tool_call、父回合可继续；reprobe on media/ref encoder changes |
| FRT-06 | 文档内图像 → 引用/问答 | managed-read/default / byok-read | 编辑器往返和 LLM 消费保真 | 文档、附件与请求三方一致 | managed image-reference 与 BYOK OpenAI exact-byte wire 均通过 |
| FRT-07 | 音色完整生命周期 | hybrid + managed-write | 预置语音→附件→危险审批→异步登记→克隆合成→库存→删除 | 生产 API Serve、inventory、网关句柄到上游 id 的映射、删除后状态 | 默认 Anselm API managed E2E 通过；网关句柄/default/WAV 修复已被真实链路覆盖 |
| FRT-08 | 朗读缓存与配额 | managed-write | 同文本同音色不二次调用；换输入才花费 | managed gateway quota delta + attachment cached；provider recorder 仅有 archived 直连证据 | managed sequential and concurrent same-key cache/quota through; provider-wire count remains a gateway-side evidence gap |
| FRT-09 | 生成工具诚实显隐 | managed-write | 出图/改图/动画/音色各自独立，不能因一个能力存在而全露出 | 工具表 + 具体 route/capability | managed image/speech/edit/video/animation live through; speech and async-video danger denial return completed refusal paths without a synthesis receipt or extra reservation; animation uses the dedicated `/videos/animations` route and caps oversized output before continuation |
| FRT-10 | 无 tool-call 模型 | byok-read | 可聊天但不作为 agent 可用模型；不被目录裁剪误删 | 模型选择器/API + agent 限制 + chat-only wire | Qwen-MT 真实通过；chat 去工具；产品 agent invoke 以 failed/0 steps 明确拒绝 |
| FRT-11 | provider 行为类 | byok-read | compat、Anthropic、Azure、Google、Vertex 的凭证/URL/编码边界正确 | 每类最小 probe + 错误分类 | DeepSeek v4 + Google Gemini 3 文本与原生 functionCall/functionResponse 续接真实通过；当前 Kimi 凭证在 `:test` 入口按约定返回 422 `API_KEY_TEST_FAILED` 并保留 `details.reason=HTTP 401`；Anthropic/Azure/Vertex 待抽样 |
| FRT-12 | 工具参数流 | byok-read / hybrid | 累积式与增量式 `arguments` 都能执行一次正确工具调用 | 两类 fixture + 真线缆样本 | locked; reprobe with parser changes |
| FRT-13 | 取消、重试与恢复中的媒体 | all applicable | 取消回合不留孤儿、重放不错误复用或重复消费；审批停泊与外部 firing 在崩溃后仍可恢复，网络重试不重复执行；触发源/工作流软删后引用关系必须可审计且只能显式修复或终止 | durable 状态、附件溯源、调用计数、inbox/审计关联、删除/重建/重绑定前后能力与 listener 投影 | handler/workflow cancel/retry/crash no-orphan + image preparation ready/failed/cancel/retry + boot budget eviction/regeneration + crash requeue + parked approval restart/decide + approval v1 pin survives entity edit→v2 short timeout + SIGKILL→Restart + inbox rendered/deadline remains pinned + webhook firing restart-before-drain + deactivate detaches listener, fences in-flight reports already past the listener snapshot, and keeps draining until accepted pending firing is consumed + pending structural shed also reconciles shed-only drain to inactive + same-body minute dedup + fsnotify event payload/filter/hot-swap + sensor false/true transition/handler invoke failure/MCP target/eager validation + fsnotify/sensor pause→SIGKILL→resume through；真实 webhook 双触发下 serial/skip/buffer_one/replace/allow_all 五种 overlap 策略的 firing disposition 与 flowrun 状态均通过；多入口 workflow 的 distinct trigger attach、重复 ref 去重、重复 activate 幂等与全量 detach 通过；多入口 stage 第一火全量撤防、并发 report 的 one-shot 原子消费通过；active workflow 的 trigger 软删→dangling capability→同名重建不隐式换绑→显式 edit rebind→deactivate 全量摘除通过；active workflow 软删→全量摘 listener→取消 parked run→保留审计/版本历史→同名重建无幽灵 listener 通过；deleted workflow 的历史可读但所有 action/iterate 入口拒绝，跨 workspace 不泄漏 workflow/trigger/run；queued firing 在删除后进入 shed 且不铸造幽灵 run；`:kill` 在取消在途 run 前 shed 剩余 pending firing，硬停后不复活新 run；trigger dangling active state survives restart and requires explicit rebind before relistening；accepted firing survives trigger deletion with deleted triggerId and honest origin omission when TriggerKind lookup is unavailable, including SIGKILL→Restart before scheduler drain；accepted firing whose source entry is removed by active workflow edit settles as shed instead of retrying forever；active edit→revert 在 pending firing 与 parked run 并存时恢复当前 listener、保持原 run version pin，且 SIGKILL→Restart 后第二 firing 只 drain 一次；approved managed video cancellation after gateway submission reaches local cancelled terminal without a video receipt or late attachment (provider job/spend intentionally remains gateway-side and may continue); reprobe on worker/recovery/trigger lifecycle changes |
| FRT-14 | provider 模型资格漂移 | byok-read | `/models` 可见不等于当前账号可生成；选择后 404 应可解释、不可重试且不污染回合 | `/models` 与最小 generate 对照 + 产品选择/失败状态 | Google `gemini-2.5-flash` 真实通过：可见、可保存选择，首发单次 404、error turn 无 assistant 文本；回合级 code 现保留为 `LLM_MODEL_NOT_FOUND`，失败横幅提供重选模型入口；同一会话切换 `gemini-3-flash-preview` 后恢复完成且仅多一次 generate；模型失效记忆/目录自动降级仍待后续 |
| FRT-15 | workflow 大图扇出与 AND-join | managed-write / hybrid | 多路 live 入边必须全部完成后才 join；节点按 `(node, iteration)` 只落一次，终值不丢；失败/崩溃后可从断点恢复且遵守 run 起跑时的版本 pin | HTTP flowrun、节点 durable rows、终点结果、replay/boot recovery 后的调用台账与 versionId | 12 节点/8 路扇出/两级 join、25 迭代深循环（含 REST 节点分页、function flowrunIteration）、真实 failed replay（已完成节点复用、驻留 handler 第二次成功、二次 replay 拒绝）、function v1→v2 编辑后的原 pin/fresh run 分界及 SIGKILL→boot recovery 的唯一节点/执行审计均通过；reprobe on scheduler/storage changes |

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
