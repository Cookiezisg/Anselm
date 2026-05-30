# 05 — Approval 节点

脑爆结论笔记(2026-05-27)。

依赖纲领:[`00-overview.md`](./00-overview.md) 的 message queue 模型。

---

## 产品语义:yes/no + 携带上下文

approval 节点的本质:**消息到达 → 渲染一段说明给用户 → 等用户决策(批准 / 拒绝) → emit 不同端口的下游消息**。

核心简化:
- **决策只 yes/no 二元**(不做开放输入 / 不做选择题 / 不做条件 approve)
- 复杂的人机交互(收集参数 / 选择 / 迭代)推回 chat 层处理
- 跟"chat 老板 / workflow 员工"分工一致——workflow 是参数已齐自动跑,approval 只是"流程中段的二元卡点"

---

## config 字段

```yaml
type: approval
config:
  prompt: |                                    # 必填,markdown,可插值
    AI 准备发送邮件:
    - 收件人:{{ payload.to }}
    - 主题:**{{ payload.subject }}**
    - 正文:
      {{ payload.body }}
    
    是否批准发送?
  
  timeout: 30d                                 # AI 编排时拍;不填 = 永不超时
  timeoutBehavior: reject                      # AI 编排时拍(reject / approve / fail);填了 timeout 必填此项
  allowReason: true                            # AI 编排时拍(true / false)
```

| 字段 | 必/选 | 说明 |
|---|---|---|
| `prompt` | **必填** | markdown 模板,支持 `{{ payload.* }}` / `{{ ctx.* }}` 插值——让用户看清在批啥 |
| `timeout` | 可选 | duration;**平台无默认**;不填 = approval 永不超时(挂到用户操作) |
| `timeoutBehavior` | 条件必填 | 填了 timeout 必填此项;`reject` / `approve` / `fail` |
| `allowReason` | 必填 | `true` / `false`;**平台无默认**,AI 编排时根据业务拍 |

**`prompt` 必填** — 没说明,用户看到孤零零的按钮根本不知道在批啥,无意义。

模板插值跟 agent prompt / tool args **完全同一套机制**——心智一致,无新概念。

---

## 输出端口

| 端口 | 触发条件 |
|---|---|
| `yes` | 用户点批准 |
| `no` | 用户点拒绝 / 超时(若 `timeoutBehavior: reject`) |

下游可分别连不同节点。或者只连一个端口,另一端口默认结束 flowrun。

approval 节点**不改 payload** — 上游传啥下游收啥,纯路由 + 等待。

---

## 消息流

```
上游 emit message{ payload, ctx }
         ↓
[approval inbox queue]
         ↓
平台 consume 消息(但 lock 在 queue,visibility hidden,不向下 emit)
         ↓
渲染 prompt 模板 → 持久化为"待审批项"
         ↓
推通知(in-app SSE + 桌面通知)
         ↓
用户操作 / 超时:
   ├─ 批准 → emit message 到 yes 端口下游(payload 透传)
   ├─ 拒绝 → emit message 到 no 端口下游(payload 透传)
   └─ 超时 → 按 timeoutBehavior 处理
```

**核心**:挂起期间消息**留在 queue**,`consumed_at IS NULL`(类似 SQS visibility timeout)。状态完全在消息流里,actor 无隐藏状态。

进程重启 / 长部署 actor 重启,**approval 状态自动保持**——靠 message queue 持久化(详 [`00-overview.md`](./00-overview.md))。

---

## reason 字段 — 纯审计,不进数据流

用户操作 approval 时可选填一段 reason 文本:

- 写入 **flowrun 历史**(audit trail)
- **不进**下游消息的 payload
- 下游节点拿不到 reason

理由:reason 进数据流会让用户期待"AI 看 reason 改下次",workflow 变成迭代容器——这不是 workflow 的职责(那是 chat 的事)。reason 只是审计 / debug / 历史回顾的附属信息。

---

## UI 形态

approval inbox / 通知点开 / flowrun 详情页展示同一份内容:

```
┌─────────────────────────────────────┐
│ 待审批 · workflow "邮件助手"          │
├─────────────────────────────────────┤
│  [渲染后的 markdown 内容]            │
│   AI 准备发送邮件:                   │
│   - 收件人:user@example.com          │
│   - 主题:**Q3 预算报告**             │
│   - 正文:...                         │
│                                     │
│   是否批准发送?                      │
├─────────────────────────────────────┤
│  备注(可选):                        │
│  [文本框]                            │
│                                     │
│        [拒绝]      [批准]            │
└─────────────────────────────────────┘
```

触达通道:
- ✅ Forgify in-app notifications(SSE,已有)
- ✅ 桌面系统通知(macOS Notification Center / Windows Toast)— Wails 桌面 app 应启用
- ✅ 专门的 Approvals Inbox 页面(所有待审批一处看)
- ✅ flowrun 详情页里直接 approve(上下文丰富)
- ❌ 邮件 / 短信(单用户桌面不需要)

---

## 跟其他节点的关系

| 跟谁 | 关系 |
|---|---|
| **case 节点** | approval 也有命名分支(`yes` / `no`),但**固定两个**,不像 case 多路 + 动态。本质 approval 是 case 的"二元 + 异步等待"特例 |
| **agent 节点** | prompt 字段同一套模板插值机制 |
| **trigger 节点** | 跟长部署 / 短部署都兼容——approval 持久化在 message queue,不依赖 actor 实例 |
| **tool 节点** | 不是 tool(tool 是同步调能力,approval 是异步等用户) |

---

## 跟纲领的对齐

- 员工思维 ✓ — approval 节点接到消息 + 渲染 + 等响应 + emit,不改变流程结构
- message queue 模型 ✓ — 状态完全在消息流,无 actor 隐藏状态
- 用户心智简化 ✓ — 二元决策 + 可选备注,UI 极简
- 把复杂人机交互推回 chat ✓ — 收集参数 / 选择题 / 迭代等场景由 chat 处理

---

## 5 节点全集完成

workflow-revamp 5 个保留节点全部落档:

| 节点 | doc | 一句话 |
|---|---|---|
| trigger | [01](./01-triggers.md) | workflow 入口,emit 首条消息(5 种 kind 统一 event 契约) |
| agent | [02](./02-agent-node.md) | LLM 节点,4 类挂载 + outputSchema |
| tool | [03](./03-tool-node.md) | 调用 forge callable(function/handler/mcp) |
| case | [04](./04-case-node.md) | 多路 switch + 回边 loop |
| approval | [05](./05-approval-node.md) | 二元决策 + markdown prompt + 异步等待 |
