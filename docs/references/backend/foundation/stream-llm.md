---
id: DOC-032
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-07-31
review-due: 2026-10-29
audience: [human, ai]
---

# stream + llm——实时总线与模型端口

## 1. Stream

`domain/stream` 定义与消息内容解耦的实时协议：

- `Frame`：open / delta / close / signal；
- `Scope{Kind, ID}`：实体锚点；
- durable 帧分配 `seq>0` 并进入 replay ring；
- ephemeral delta/tick 使用 `seq=0`，订阅者拥塞时可丢，不阻塞生产者；
- close 携带完整快照，支持重放客户端收口。

`infra/stream.Bus` 只实例化三次：messages、entities、notifications。每个 workspace 独立维护序号和 replay ring。续传优先读 `Last-Event-ID`，再读 `fromSeq`；游标早于 ring 返回 `SEQ_TOO_OLD` 410，消费方重取 REST 真相。

## 2. LLM 端口

`llm.Client` 把所有模型适配为同一 `Stream(ctx, Request)` 事件序列：文本/推理 delta、工具调用参数、结束原因与 token usage。Factory 负责 provider、credential、base URL 与方言选择；`app/modelclient` 是 chat 之外解析 scenario/override/key/client 的唯一编排链。

关键纪律：

- 业务层不分支 provider wire；
- tool call、reasoning 与多模态 part 在 adapter 归一；
- sanitizer 修复被取消历史中的孤儿 tool-call/tool-result 配对；
- provider 错误先分类再进入统一 `LLM_*` 错误，不透传可能带 secret 的原始 header/body；
- client cancel、请求拒绝、限流与 provider 故障保持不同语义；
- 模型是否能聊天、能用工具、能读某模态是不同能力位。

## 3. Provider 目录与能力

`modelcatalog.json` 是 models.dev 的 vendored 裁剪快照；运行时可刷新到 data dir，失败保留上次可用版本。目录提供 provider/model 身份、上下文/输出限制、模态与 reasoning options；方言代码只负责这些能力怎样编码到 wire。

- OpenAI-compatible 长尾共用 `compatProvider`，真实差异通过 spec/part encoder/knob spelling 注入。
- Anthropic、Google、Azure、Vertex 等非同形认证或 wire 使用专用适配。
- Ollama/custom/mock/anselm 是本地或产品自有入口，不由 models.dev 决定存在性。
- 目录声明有能力但 adapter 无对应 part/knob 拼法时，投影必须收窄，不能过度承诺。
- chat-only 模型可用于普通对话，但 Agent 解析必须拒绝 tools=false 的模型。

完整 provider 数量和模型数量是快照数据，不在文档硬编码；以当前 `modelcatalog.json` 与 `/providers`、`/model-capabilities` 投影为准。

## 4. Managed Anselm

`anselm` 是内置受管 provider，公开逻辑模型 `anselm-auto`。主仓用 OpenAI-compatible chat wire 与 device-proof transport 接已部署网关；上游 provider 选择、密钥、费率和成本账本不属于本仓。

- base 默认指向生产 Anselm API；`ANSELM_GATEWAY_URL` 仅用于显式覆盖。
- managed api-key 行保存公开 install id，不保存网关 provider secret。
- `/models` 的 `anselm_capabilities` 是当前 route budget/模态可用性的权威投影。
- quota、install、media staging、ASR 与生成请求复用同一 device-proof 身份。
- 详细责任边界见 [`managed-gateway.md`](../managed-gateway.md)。

## 5. 生成边界

`generate_image`、`edit_image`、`animate_image`、`generate_speech`、`generate_video` 与 `enroll_voice` 是逐请求注入的 capability tools，只在受管 route 对相应谓词可用时存在。

`edit_image` 始终先把源附件经受管 `/v1/images/edits` 送出并生成 sibling；对明确可判定为颜色替换的窄指令，桌面端随后只旋转源图匹配颜色的像素并保留其余像素，回执以 `editMode=precision_color_swap` 记录该事实。夜景、风格、对象增删等宽编辑继续使用上游生成式结果，不能伪装成像素级保真。

`animate_image` 走受管 `/v1/videos/animations`。桌面端必须发送 `prompt`、`seconds` 和首帧 `image` data URL；不得把桌面端的 `aspect`/`resolution` 继续带到该请求的上游形状，因为 API Serve 只在边界解析它们以校验词表，转发时会整体丢弃，视频继承首帧几何。文生视频 `/v1/videos/generations` 才发送这两个几何字段。

`animate_image` 只在成功的受管 `/models` 探测明确返回 `anselm_capabilities.video_generation.available=true` **并且** `image_to_video=true` 时注入。前者单独只证明文生视频可用，不能推断图生视频；缺字段、探测失败或 JSON 损坏均 fail-closed，工具必须诚实缺席，不能让用户得到一段重新构图的视频后再声称它使用了原图首帧。

BYOK 负责文本与受支持多模态输入读取，不提供本仓维护的生成方言。没有 managed route 时工具整族诚实缺席，而不是展示一个必然失败的按钮/工具。

所有生成结果收敛为本地 attachment + `MediaRef`；是否回喂当前模型由模型输入能力和媒体 envelope 决定，不由产地决定。

## 6. 验证

- Bus/replay/410：`backend/internal/infra/stream/`
- provider/compat/parts/knobs：`backend/internal/infra/llm/`
- model 解析：`backend/internal/app/modelclient/`
- managed device proof：`backend/internal/infra/deviceproof/`
- 默认产品与 BYOK 对照：`testend/scenarios/` 的 managed、BYOK、hybrid 与 multimodal 场景
