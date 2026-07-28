---
id: WRK-026-CURRENT
type: working
status: active
owner: @weilin
created: 2026-07-29
reviewed: 2026-07-29
review-due: 2026-08-12
audience: [human, ai]
---

# 当前战役 · 后端高频真实路径

## 目标

在当前后端上持续覆盖高频真实用户路径，优先验证“用户实际获得的体验”而非静态实现的自洽。每条路径都以真实状态、可复现线缆或明确的结构化证据收口，并把确认的缺陷沉淀为常规回归或真钱接受层。

## 当前不变量

1. **媒体是一种跨面值流。** `MediaRef` 可以来自上传、生成、MCP、function、handler、驻地文件或文档；它必须能被正确持久化、传给下游、按模型能力消费并在前端渲染。
2. **能力由实际路由决定。** 模型能力 = 目录声明 ∧ 当前方言可编码的 part；生成能力还必须存在受管路由。不可用时诚实缺席，输入不支持时保留可理解的降级信息。
3. **写入只走受管。** 图像、视频、语音、朗读、音色登记/删除等生成和身份资源不允许绕回 BYOK 直连方言。
4. **读取允许 BYOK。** 文本与图像/视频/音频输入都是 BYOK 的正式能力；目录预填可由用户覆盖，覆盖后的连接责任与错误解释必须清楚。
5. **混合路径是一等路径。** 一个 BYOK 模型可以调用由 Anselm 受管执行的生成工具；不能把两把 key 并存误判为配置异常。
6. **费用和资源必须可解释。** 受管配额、缓存是否命中、危险操作是否经过审批、音色库存是否释放，都以实际调用与持久化状态为准。BYOK 直连不存在产品内生成支出台账。
7. **端到端不索取 provider secret。** 默认与受管写入场景只配置 `ANSELM_GATEWAY_URL`（生产默认即 API Serve），由 device proof 开通 install 后调用网关。供应商 key、workspace endpoint、媒体 host 和上游资源 id 都属于 API Serve 运维边界。

## 本轮优先级

| 优先级 | 目标 | 完成证据 |
|---|---|---|
| P0 | 默认受管路径可用且能力诚实 | workspace 开通、`anselm-auto` 路由、工具显隐、额度/错误分类 |
| P0 | 混合生成路径 | BYOK 调度模型实际调用受管生成；产物、receipt、后续消费和费用一致 |
| P0 | 多模态跨执行面 | chat、workflow、agent/subagent、MCP/function/handler、文档间的真实字节或 MediaRef 证据 |
| P1 | BYOK 目录与协议类 | 模型选择、能力投影、工具模型限制、Azure/Vertex/compat 等行为类抽样 |
| P1 | 高风险资源链 | 音色登记→异步就绪→合成→库存→删除；视频与图像的成本人闸/取消/恢复 |
| P2 | 历史高频 lane reprobe | 旧绿格在当前网关、路由、消息投影和媒体架构下重新判定 |

## 运行前准入

- 使用当前源构建；不得复用无从确认版本的已运行后端。
- 明确本轮走的路由类别，以及是否会触发真实费用、危险操作或生产网关。
- 对会花费的操作设定最小目标和停止点；不要让模型在生成工具上无界重调。
- 需要真实上游的场景只使用对应 `EVALS_*` 门控；普通门禁不应偷偷花费。
- 现存要求本地 `DASHSCOPE_API_KEY` 或 `ANSELM_DASHSCOPE_BASE` 的 live scenario 是历史直连缝；在其重写前不得把它当作产品端到端的验证入口。
- 发现行为差异时先保留请求、响应摘要、状态和时间线，再判断是否是缺陷。

## 当前真相源

- 路由治理：[WRK-085 · BYOK 治理](../../archive/byok-governance/README.md)（已 landed，事实源见 `references/backend/foundation/stream-llm.md`）
- LLM、目录、方言与工具参数：[stream + llm](../../references/backend/foundation/stream-llm.md)
- 多模态收口：[WRK-082 历史战役](../../archive/multimodal-output/README.md)
- chat 能力工具与诚实缺席：[chat domain](../../references/backend/domains/chat.md)
- 附件到模型输入：[attachment domain](../../references/backend/domains/attachment.md)
- 受管开通与配额：[support services](../../references/backend/domains/support-services.md)

详细的可执行队列在 [`FRONTIER.md`](FRONTIER.md)。
