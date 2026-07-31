---
id: WRK-026-CURRENT
type: working
status: active
owner: @weilin
created: 2026-07-29
reviewed: 2026-07-31
review-due: 2026-08-14
audience: [human, ai]
landed-into:
---

# 当前边界

## 目标

持续覆盖后端维度的真实高频体验，优先寻找“产品承诺与实际状态不一致”的路径。
每个稳定缺陷必须进入共享实现修复和确定性回归；外部或模型波动保留证据，但不污染
产品代码。

## 当前不变量

1. MediaRef 是跨 Chat、Agent、Subagent、Workflow、Document 与工具产物的统一值。
2. 能力由目录声明、当前 adapter 可编码 part 和实际路由共同决定。
3. 原生媒体还受单回合 parts、bytes、distinct-kind 组合额度约束。
4. 图像、语音、视频和音色等写入能力只走 managed route。
5. BYOK 读取与 hybrid 调度是正式产品路径，不是诊断后门。
6. 默认路径只依赖已部署 Anselm API 与 device proof，不依赖本地 provider secret。
7. 费用、缓存、审批和资源释放以真实调用及持久状态裁决。
8. Durable 恢复必须复用已完成节点，不能重复外部副作用。

精确当前契约以 backend reference 为准；本页只决定 iteration 的活动边界。

## 当前优先面

| 优先级 | 面 | 验证重点 |
|---|---|---|
| P0 | 默认受管对话 | 首次开通、能力诚实、错误与 quota 可解释 |
| P0 | 多模态跨执行面 | 原件/receipt/下游 wire/历史重建一致 |
| P0 | Durable 用户控制面 | cancel、approval、replay、restart、delete/rebind |
| P0 | Hybrid 生成 | BYOK planner 与 managed writer 不串权、不重复生成 |
| P1 | BYOK 行为类 | provider adapter、目录资格、组合媒体与错误分类 |
| P1 | 高风险资源 | danger、异步提交、缓存/计费、取消与最终清理 |
| P2 | 承重面变化后的 reprobe | 只抽取受影响代表 lane，不机械重跑全部历史 |

尚未闭合的具体路径只在 [`FRONTIER.md`](FRONTIER.md) 维护。

## 运行准入

- 从当前源新建隔离 workspace，不复用版本不明的长期进程。
- 先声明 `managed-read`、`byok-read`、`managed-write` 或 `hybrid`。
- 真实上游只通过显式 `EVALS_*` 开关启用；普通 verify 不花费。
- BYOK key 只从本地未跟踪环境读取，不写命令输出、文档、fixture 或提交。
- Managed 场景使用生产默认或显式 `ANSELM_GATEWAY_URL`，不注入网关内部 secret。
- 费用型路径预先设置最小样本、最大调用次数和停止点。
- 记录 request/response 摘要时先脱敏，并同时保留 durable state 和时间线。

## 权威入口

- 系统与后端：[`backend overview`](../../references/backend/overview.md)
- LLM 与模型能力：[`stream-llm`](../../references/backend/foundation/stream-llm.md)
- 多模态输入：[`attachment`](../../references/backend/domains/attachment.md)
- Chat 与工具能力：[`chat`](../../references/backend/domains/chat.md)
- Durable execution：[`scheduler-flowrun`](../../references/backend/foundation/scheduler-flowrun.md)
- Managed/API Serve 边界：[`managed-gateway`](../../references/backend/managed-gateway.md)
