---
id: WRK-026-LOG
type: working
status: active
owner: @weilin
created: 2026-07-29
reviewed: 2026-07-29
review-due: 2026-10-27
audience: [human, ai]
---

# LOG · 已确认发现

> 只追加。每行必须是已确认的事实，并能指向复现、测试、提交或真相源；探索假设不记录在这里。

| 日期 | ID | 发现 / 影响 | 范围 | 证据与守卫 | 落点 |
|---|---|---|---|---|---|
| 2026-07-28 | EVO-001 | 产品边界改为“写留给受管，读交给目录”；BYOK 多模态输入为正式能力 | 聊天、模型能力、生成工具 | WRK-085（2026-07-29 landed）；能力与路由文档 | H11/H12 完成、结论已入 references |
| 2026-07-28 | EVO-002 | OpenAI-compatible 流式工具参数存在增量和累积两种 wire；拼接累积值会使工具调用全量失败 | compat provider / agent loop | `toolargs_test.go`；真实 DashScope 线缆 | compat 归一层 |
| 2026-07-28 | EVO-003 | 音色登记必须走生产网关，且上游异步就绪；mock 无法证明此契约 | managed voice lifecycle | `TestLiveVoice_EnrollSpeakDelete`，`EVALS_VOICE=1` | live acceptance |
| 2026-07-28 | EVO-004 | 真实多模态验收须同时保存上游请求与产物字节，不能采信模型自述 | chat/workflow/MCP/function/handler | `live_media_test.go`，`EVALS_MEDIA=1` | live acceptance |
| 2026-07-29 | EVO-005 | 受管语音真钱验收硬编码旧 qwen3-tts 音色 `Cherry`，使 qwen-audio-3.0 默认路径假红；默认音色必须由 API Serve 决定 | managed TTS acceptance | `TestLiveManaged_ImageAndSpeech`：旧值失败、空 voice 重跑验证 | 当前提交 |
| 2026-07-29 | EVO-006 | 新 workspace 在受管 key 落盘后先做网络能力刷新、后播种默认模型；用户首发消息可命中无默认的 `LLM_RESOLVE_ERROR` | freetier onboarding / 默认聊天 | `TestLiveManaged_DefaultChat` 复现；首发黑盒守卫 + `TestEnsure_SeedsDefaultsBeforeLiveCapabilityProbe` | 当前提交 |
| 2026-07-29 | EVO-007 | 静态多模态夹具把 CRC 损坏的字节称作“合法 PNG”；mock 从不解码而掩盖问题，真实受管视觉路由会被上游拒绝 | testend mock / 媒体回归 | `TestLiveManaged_DefaultChatWithImageAttachment` 先红；`TestMockPNGDecodes` 守 decoder-valid fixture；32×32 真图重跑通过 | 当前提交 |
| 2026-07-29 | EVO-008 | BYOK 视觉输入可在不借用受管 fallback 的情况下走完真实 key 创建、probe、目录能力、默认模型、附件与对话；它证明真实 provider 接受产品请求，不把模型文案误当像素语义证据 | BYOK read / OpenAI-compatible visual input | `EVALS_BYOK=1` + `OPENAI_API_KEY` 的 `TestLiveBYOK_OpenAIImageInput`；harness 默认关闭 gateway，附件字节与 durable turn 双侧断言 | 当前提交 |
| 2026-07-29 | EVO-009 | 混合路径可以让 BYOK 对话模型调度、但由 Anselm 受管路由出图；默认图像场景仍指向 managed key，receipt 标明 `anselm`，一次受限回合只铸一件真实图片 | hybrid / BYOK planner + managed writer | `EVALS_HYBRID=1 EVALS_MANAGED=1` + `OPENAI_API_KEY` 的 `TestLiveHybrid_OpenAIPlansManagedImage`；受管 route、tool receipt、一次调用和产物字节均断言 | 当前提交 |
| 2026-07-29 | EVO-010 | 默认受管 MP4 输入可走完上传、device-proof staging/lease、部署网关与 durable 对话；规范短片未越过网关发布的 3MiB 解码预算，附件字节保持不变 | managed read / video input | `EVALS_MANAGED=1` 的 `TestLiveManaged_DefaultChatWithVideoAttachment`；SHA 校验 fixture、能力投影、回合终态与附件逐字节回读 | 当前提交 |
| 2026-07-29 | EVO-011 | 文档 Markdown 中的 `anselm://media/<attachmentId>` 不会停留为 system prompt 的字面字符串：附图经文档扫描后可进入受管媒体消费路径并完成新对话 | managed read / document media reference | `EVALS_MANAGED=1` 的 `TestLiveManaged_DocumentImageReference`；文档挂载、新对话终态与附件逐字节回读 | 当前提交 |
| 2026-07-29 | EVO-012 | Qwen BYOK 的目录默认 endpoint 与 video 方言可实际接收 MP4：真实 key 的 probe、`qwen3.7-plus` 能力投影、默认模型和附件对话均不借用受管 fallback | BYOK read / Qwen video input | `EVALS_BYOK=1 QWEN_API_KEY=…` 的 `TestLiveBYOK_QwenVideoInput`；harness 默认关闭 gateway，MP4 终态与逐字节回读 | 当前提交 |
| 2026-07-29 | EVO-013 | function 与驻留 handler 的声明式二进制产物都能经共享 `mediaartifact` collector 落为一等附件；handler 连续调用各自拿到不同 receipt，来源与附件字节均保真，且不需 provider key | function / handler artifact producer | `TestFunction_ArtifactProduct`、`TestHandler_ArtifactPerCallProduct`：真实 HTTP、有效 PNG、连续运行/调用、receipt source、附件逐字节回读 | 当前提交 |
| 2026-07-29 | EVO-014 | MCP stdio server 的 image content 会经 `mcp_media` receipt 进入同一附件库，并在下一轮视觉对话请求中以原始 base64 `image_url` 送达；模型文案不是证据，抓包字节与附件回读一致才算通过 | MCP producer / chat media expansion | `TestMCP_ArtifactReachesVisionModel`：真实 Python JSON-RPC server、64×64 PNG、receipt、附件回读、llmmock 线缆 exact-byte 断言、chat 触发台账 | 当前提交 |
| 2026-07-29 | EVO-015 | workflow 可把 function 产物的 MediaRef 从上游 agent 节点的终答交给下游 agent；下游请求包含与附件库逐字节一致的原始 image part，且不需要受管生成或 provider key | workflow / agent-to-agent media | `TestWorkflowMedia_FunctionArtifactToVisionAgent`：真实 function sandbox、flowrun 节点结果、附件回读、第三个模型请求 exact-byte 断言 | 当前提交 |
| 2026-07-29 | EVO-016 | 驻留 handler 的二进制产物也能经 chat 的 lazy `call_handler` 进入视觉消费咽喉；第三次模型请求携带与附件库一致的 PNG，而不是 receipt/占位文本 | handler producer / chat media expansion | `TestHandler_ArtifactReachesVisionModel`：真实 handler sandbox、call_handler 工具、handler_artifact receipt、附件逐字节回读、llmmock 第三请求 exact-byte 断言 | 当前提交 |
| 2026-07-29 | EVO-017 | chat 在 handler 产物调用已发出进度但尚未完成时取消，回合与 handler 台账均落 `cancelled`，临时输出不会晚到上传，附件行数保持不变且不出现伪造 receipt | cancellation / handler media cleanup | `TestChatCancel_HandlerArtifactLeavesNoOrphan`：真实 chat→call_handler、SSE 进度边界、取消、durable 状态、SQLite attachment count、receipt negative assertion | 当前提交 |
| 2026-07-29 | EVO-018 | 对含 handler 产物的 assistant 回合做 regenerate 时，旧 assistant 版本被 supersede，handler 不会再次执行、附件不重复铸造；原始附件行与字节仍可读，符合只对现行版本装配 LLM 历史的 retry 语义 | retry / side-effecting media producer | `TestChatRetry_HandlerArtifactDoesNotReexecute`：真实首次 call_handler、重生成、handler calls=1、附件行数不变、原始内容回读 | 当前提交 |
| 2026-07-29 | EVO-019 | backend 在 handler 媒体调用进行中硬崩溃并重启后，boot sweep 会把 chat 回合对账为 `cancelled`，废弃调用没有晚到附件行 | crash recovery / handler media cleanup | `TestChatCrash_HandlerArtifactLeavesNoOrphan`：真实在途 call_handler、SSE 边界、Kill9→Restart、durable cancelled 状态、SQLite attachment count 不变 | 当前提交 |
| 2026-07-29 | EVO-020 | attachment 的 image preparation 是真实异步、可恢复的用户侧车：有效 PNG 从 queued/processing 到 ready 并暴露 proxy 尺寸；不可解码 image 仍先保留原件、再诚实进入 failed，可 cancel 为 cancelled、retry 后重新失败；非 image 明确为 not_required | attachment / media worker / preparation API | `TestAttachmentPreparation_ManagedImageLifecycle`：真实 HTTP upload→GET 轮询、派生元数据、坏图 failed→cancelled→retry、原件逐字节回读、text not_required | 当前提交 |
| 2026-07-29 | EVO-021 | media cache 超过机器级预算时不会静默丢原件：boot GC 清理派生 CAS、把 ready 行标成 `MEDIA_ARTIFACT_EVICTED` 且可 retry；同一 source/transform identity 可在重启后重新生成 | media cache / boot GC / resource hygiene | `TestAttachmentPreparation_MediaBudgetEvictsAndRegenerates`：真实 `/limits` 设 1MB、>1MB JPEG proxy、Restart、sidecar eviction/error、media CAS 文件清理、原件逐字节回读、retry ready | 当前提交 |
| 2026-07-29 | EVO-022 | `inspect_media` 对 audio/video 当前诚实地只返回本地 metadata capsule：保留 attachment id、kind、mime、size 与 start/end intent，明确写出不含 transcript；下一次模型请求只收到 JSON evidence，原始媒体字节不会泄漏 | attachment tool / temporal media read | `TestInspectMedia_AudioVideoMetadataCapsule`：真实 HTTP upload、lazy `search_tools`、两次 inspect_media、llmmock tool-message JSON 与 raw-byte negative assertion | 当前提交 |
| 2026-07-29 | EVO-023 | image `inspect_media` 走真实嵌套视觉调用：内部请求携带 `data:image/*` native part，主对话拿到的是带 attachment/尺寸/detail/answer 的 bounded JSON evidence，不把 provider 原始回答或图像字节直接回灌 | attachment tool / image inspection / nested LLM | `TestInspectMedia_ImageUsesVisionAndReturnsBoundedEvidence`：真实 HTTP upload、lazy discovery、内部 vision wire、外层 tool-message JSON 解析与字段守卫 | 当前提交 |
| 2026-07-29 | EVO-024 | workflow 中正在 provider 调用的 agent 可经 `POST /flowruns/{id}:cancel` 被打断：run 终止为 `cancelled`，不会留下假 `failed/running` 节点，随后同一 workflow 可接受并完成下一次 run | workflow / scheduler cancellation | `TestFlowrun_CancelInFlightAgent`：真实 agent workflow、异步 manual run、llmmock Stall、list 发现 running、HTTP cancel 202、终态节点负断言、后续 run completed | 当前提交 |
| 2026-07-29 | EVO-025 | API Serve 最新网关变更修正了 managed TTS 的句柄解析、默认音色与 WAV 字节/媒体部署注入边界；这些变化直接改变受管音色验收的真实前提，但尚未宣称 managed E2E 已重跑通过 | API Serve / managed voice / deploy media | API Serve commits `63f402f`, `2e308f3`, `b9c046d`; 在 `Anselm-API-Serve` 执行 `go test ./...` 全绿；managed voice/live read-aloud 下一次真实运行作为 FRT-07 reprobe | gateway audit |
| 2026-07-29 | EVO-026 | image preparation 在上传后硬崩溃可恢复：SIGKILL 留下 running derivative，下一次同 data dir boot 将其 requeue，worker 从不可变原件重新生成 ready proxy，原件字节不变 | attachment / media worker / crash recovery | `TestAttachmentPreparation_CrashRequeuesInterruptedWork`：真实 HTTP 上传、Kill9→Restart 日志 `media: requeued interrupted work`、ready 派生元数据与原件逐字节回读 | 当前提交 |
| 2026-07-29 | EVO-027 | 音色真钱验收不再要求已删除的本机 `DASHSCOPE_*` 凭据或 BYOK Qwen 对话 key：测试改为等待生产 API Serve 的 managed `anselm` 行与默认 dialogue，再由默认 Anselm API 驱动登记工具；真实音色购买尚未重跑 | managed voice acceptance / API boundary | `TestLiveVoice_EnrollSpeakDelete` 静态门控审计通过；无 `EVALS_VOICE=1` 时仅跳过，未宣称上游 enrollment/synthesis/delete 绿 | 当前提交 |
| 2026-07-29 | EVO-028 | 本轮跨实体黑盒回归在最新 backend 上全绿：并行真实 HTTP/SSE 场景、媒体准备/崩溃恢复、workflow/handler/MCP/function 产物链均通过；真钱 EVALS 仍按显式门控未触发 | full testend regression | `make -C backend testend` → `ok github.com/sunweilin/anselm/testend/scenarios 260.291s` | 当前提交 |
| 2026-07-29 | EVO-029 | 最新 API Serve 上默认 Anselm managed voice 全生命周期通过：受管 install/default 就绪后，预置朗读生成参考音频、`enroll_voice` 危险审批与异步登记、库存/上游句柄可见、克隆音色朗读产出不同音频，最后先删上游再删本地行并释放槽位 | managed voice / API Serve TTS / danger approval / inventory | `EVALS_VOICE=1 go test ./scenarios -run '^TestLiveVoice_EnrollSpeakDelete$' -count=1` → PASS 43.50s；未读取本机 provider secret，生产网关 HTTP 真实链路 | 当前提交 |
| 2026-07-29 | EVO-030 | 默认 Anselm managed 多模态读路径全链路通过：普通聊天、图片附件、MP4 附件、文档内 `anselm://media` 图片引用与免费档配额均在生产 API Serve 上完成；附件原件/回合终态/能力投影均成立，未走 BYOK fallback | managed read / image / video / document media / quota | `EVALS_MANAGED=1 go test ./scenarios -run '^TestLiveManaged_(DefaultChat|DefaultChatWithImageAttachment|DefaultChatWithVideoAttachment|DocumentImageReference|Quota)$' -count=1` → PASS 60.627s；无本机 provider key | 当前提交 |
| 2026-07-29 | EVO-031 | 默认 Anselm managed `generate_image` 写路径通过：默认 dialogue 模型恰调用一次工具，receipt 标出 `provider=anselm`，真实图片附件可解码且字节可回读；回合上限为两步，避免模型重画失控 | managed write / image generation | `EVALS_MANAGED=1 go test ./scenarios -run '^TestLiveManaged_GenerateImageArtifact$' -count=1` → PASS 28.11s；无本机 provider key | 当前提交 |
| 2026-07-29 | EVO-032 | 默认 Anselm managed `generate_speech` 写路径通过：默认 dialogue 模型恰调用一次工具，receipt 标出 `provider=anselm`，网关返回真实 RIFF/WAVE 音频附件并可回读；两步上限约束付费重试 | managed write / speech generation / API Serve TTS | `EVALS_MANAGED=1 go test ./scenarios -run '^TestLiveManaged_GenerateSpeechArtifact$' -count=1` → PASS 12.42s；无本机 provider key | 当前提交 |
| 2026-07-29 | EVO-033 | H11 边界审计确认：`live_media_test.go` 与 `live_media_guard_test.go` 仍绑定 `EVALS_MEDIA`、DashScope 录制代理和本机 provider secret，属于历史直连线缆；当前生成实际由 Router 派发到 `anselm`，`EVALS_VOICE` 已走生产 managed。旧文件保留作历史证据，不作为产品入口 | H11 routing boundary / live acceptance governance | `rg` 审计旧测试入口与 `Router.{Image,Speech,Video}Available` / dispatch；working CURRENT/README 与文件注释已明确分层 | 当前提交 |
| 2026-07-29 | EVO-034 | 默认 Anselm managed `generate_image` → `edit_image` 写路径通过：模型先铸一张图，再以 receipt 的 attachmentId 改图；两件均为有效、不同字节的图片，edit receipt 保留 `sourceAttachmentId` 且两次 provider 均为 `anselm`，回合最多四步 | managed write / image edit / MediaRef lineage | `EVALS_MANAGED=1 go test ./scenarios -run '^TestLiveManaged_EditImageArtifact$' -count=1` → PASS 78.28s；无本机 provider key | 当前提交 |
| 2026-07-29 | EVO-035 | 默认 Anselm managed `generate_video` 写路径通过：工具先停在危险审批，批准后经 API Serve 异步提交/轮询/下载，落下一件可解码 MP4；receipt 恰好一条且 provider 为 `anselm`，两步上限阻止重复付费调用 | managed write / video generation / danger approval / async gateway | `EVALS_MANAGED=1 go test ./scenarios -run '^TestLiveManaged_GenerateVideoArtifact$' -count=1` → PASS 166.71s；无本机 provider key | 当前提交 |

## 追加格式

`日期 | EVO-编号 | 一句事实与用户影响 | 共同层/执行面 | 最小可复现或测试 | commit / reference`

若某项被推翻，在原行之后新增一行说明推翻条件；不要回写历史事实。
