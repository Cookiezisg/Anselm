---
id: WRK-026-FRONTIER
type: working
status: active
owner: @weilin
created: 2026-07-29
reviewed: 2026-07-31
review-due: 2026-08-14
audience: [human, ai]
landed-into:
---

# Frontier

本页只保存尚未闭合或因承重面变化而需要重探的路径。已完成证据进入
[`LOG.md`](LOG.md)，不会继续堆在状态栏里。

## 选择规则

优先级按以下因素共同决定：

```text
用户频率 × 失败损失 × 近期变化风险 × 证据缺口
```

每个 frontier 必须写清路由、执行面、后端真相与停止条件。Provider 以协议/行为类抽样，
不把目录规模变成逐家手工清单。

## 活动队列

### FRT-A · Managed 子代理的模型遵循与终态可靠性

- 路由：managed-read/default
- 路径：失败 Function、取消、并行 child、父回合续接、fork/retry
- 缺口：真实模型偶发重复派发、非法 `subagent_type` 修复循环或在 settle 窗口内不收口；
  隔离复跑通常通过，尚无稳定持久化缺陷。
- 要裁决：模型/提示词波动、超时 oracle，还是 queue/terminal/finalize 的确定性问题。
- 最小证据：父/子 Message 与 Block 树、`parentBlockId`、Execution 数、cancel timeline、
  follow-up 是否复活旧工具。
- 停止：先用确定性 fixture 证明后端不变量；只有同一持久状态缺陷跨独立进程稳定复现才修代码。

### FRT-B · Provider 资格与协议行为抽样

- 路由：byok-read
- 路径：Azure OpenAI、Vertex AI，以及 Google image-input 的 rate-window 后复探。
- 缺口：Azure/Vertex 尚无当前真实 credential 样本；Google image-input 最近被 provider 429
  阻断，不能从其它 Gemini 能力推断 native image wire。
- 最小证据：产品 key test、目录/能力、一次最小 generate、真实 wire 与稳定错误分类。
- 停止：凭证或 provider window 不可用时记录 external block，不循环消耗。

### FRT-C · 失效模型的产品策略

- 路由：byok-read
- 已知事实：目录可见但账号不可用的模型会单次失败为 `LLM_MODEL_NOT_FOUND`，不自动 fallback；
  用户显式切换后可恢复。
- 待裁决：是否自动标记资格失效、何时重新 probe、UI 如何提示；这是产品策略，不由 iteration
  擅自实现。
- 所需证据：同一账号的 list/generate 对照、失败频率、用户恢复路径与候选 UX。
- 停止：没有产品决定时只保持现有诚实失败，不改自动降级。

### FRT-D · Managed provider wire 的端到端可观测性

- 路由：managed-read / managed-write / hybrid
- 已知事实：本地 receipt、Attachment 字节、quota 与下游 BYOK recorder 已闭合；公开部署面
  不暴露原始上游 provider wire。主仓编译 base 的 `/healthz` 当前为 200，但同级
  API Serve `main` 明确自述尚未上线，故 health 不能证明仓库 HEAD 与线上 deployment 同版。
- 缺口：需要证明“网关转发给 provider 的字节/调用次数”时，证据必须在 API Serve 的受控
  integration/recorder 中产生，不能从主仓外推；每次候选上线还需确认部署 SHA/版本与
  主仓 managed contract 的兼容性。
- 最小证据：部署记录或不可伪造的版本标识 + API Serve 自身脱敏 recorder /
  integration fixture，与本地主键/lease 对齐。
- 停止：不得为取证把 provider secret 或公开调试端点拉进主仓。

### FRT-E · 跨产地 MediaRef 变更哨兵

- 路由：all applicable
- 路径：MCP、Function、Handler、managed generator、用户上传、Document URI →
  Chat/Workflow/Agent/Subagent 下游。
- 当前状态：代表路径已有真实证据；只有 producer adapter、MediaRef parser、Attachment
  provenance、content-part renderer 或 provider encoder 变化时进入 reprobe。
- 最小证据：唯一 receipt、`originToolCallId`、源附件 exact bytes、下游 wire、无重复生成。
- 停止：未命中承重变化时不为“刷覆盖”重复跑真钱矩阵。

## 承重变化触发器

| 组 | 变化 | 必须抽取的代表路径 |
|---|---|---|
| R-A | model client、catalog、provider adapter、tool parser | 默认 chat、一次 tool continuation、一个资格错误 |
| R-B | Agent/Subagent host、Toolset、Messages、context recovery | child 成功/失败/取消、父续接、fork |
| R-C | Scheduler、Flowrun store、Trigger、Approval | fanout/join、park/decide、replay、restart |
| R-D | Attachment、MediaRef、Media worker、part encoder | 上传 + 工具产物 + workflow 下游 |
| R-E | Gateway、quota、danger、resource store | deny-no-spend、approve/cancel、cache dedup、delete |

## 永不作为覆盖

- 模型声称“看见/听见”而没有 wire 或字节证据；
- 用 mock 推断真实 provider 计费、异步 job 或公网 lease；
- 逐家重跑全部 provider；
- 把历史 BYOK 直连生成缝当产品路径；
- 为测试默认 managed 路径而索取 API Serve provider secret；
- 把结构化 skip、429 或偶发模型选择直接记成产品通过；
- 在没有稳定复现时为了让 live test 变绿而修改生产语义。
