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

## 追加格式

`日期 | EVO-编号 | 一句事实与用户影响 | 共同层/执行面 | 最小可复现或测试 | commit / reference`

若某项被推翻，在原行之后新增一行说明推翻条件；不要回写历史事实。
