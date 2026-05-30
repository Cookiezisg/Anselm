# 07 — 错误处理 / 重试 / 通知 / 死信

脑爆结论笔记(2026-05-27 起 / 2026-05-29 重大修正)。

---

## 核心规则

| 状态 | 行为 |
|---|---|
| 节点失败,**retry 次数内** | 只记录(写 messages / events),**不通知** |
| 节点失败,**retry 用尽** | **平台主动推 SSE 通知**——告诉用户哪个 workflow / 哪个节点失败 |
| **Trigger 节点** retry 用尽(特例) | **workflow 自动 inactive** + 通知(入口废了,workflow 客观失效) |
| 其他节点 retry 用尽 | flowrun 失败 + 通知,**workflow.active 不变** |

派生:
- **通知是 mechanism**(平台保证)— retry 用尽必通知,用户始终知道
- **retry 次数是 policy**(用户/AI 编排时拍)— 不填 = 0 次,失败立即通知
- **Trigger 失败让 workflow inactive 不是"替用户暂停",是诚实**——入口废了,active 是欺骗

---

## Mechanism vs Policy(修正后的分配)

| 维度 | 谁定 |
|---|---|
| retry 次数 / backoff | **Policy** — 用户/AI 在节点 config 拍 |
| retry 用尽后是否通知 | **Mechanism** — 平台强制通知 |
| 通知载体 | **Mechanism** — SSE notifications 流(已有) |
| 错误分类(transient vs business) | **Policy** — case 节点显式判断 |
| 通知聚合规则(连续 N 次只报 1 次) | **Policy** — AI 在 chat 帮聚合;平台保证推每次重要事件 |
| Workflow.active 自动变 inactive | **Mechanism**(仅 trigger 失败例外)— 入口失效平台必须诚实 |

---

## Trigger 节点的特例 — workflow 自动 inactive

入口失败是不同性质——workflow 客观上不能继续工作:

```
trigger 节点(例:cron / webhook / polling)失败
    ↓
平台按节点 retry 配置重试
    ↓ N 次后仍失败
    ↓
平台自动 deactivate workflow:
  workflow.active           = false
  workflow.attention_reason = "trigger_exhausted: <details>"
  workflow.last_action_by   = "system"        # 跟用户主动 deactivate 区分
  → 推 SSE notification:"workflow X 入口失效,需要人工干预"
    ↓
用户/AI 在 chat 看到 → 诊断 + 修 → 再 :activate
```

不影响:
- 其他节点(tool / agent)失败:只通知,workflow.active 不变
- Approval 节点超时拒绝(business 结果,不算节点失败)
- 用户主动 deactivate(`last_action_by = "user"`)

---

## 平台提供什么(机制层)

| 机制 | 干什么 |
|---|---|
| **消息持久化**(messages 表) | 所有消息永不丢,因果链可 trace |
| **失败计数 + retry 编排** | 按节点 config retry 重试,用尽后判定永久失败 |
| **死信 status** | 节点 failed 的 message 进 `messages.status='dead_letter'` |
| **通知 SSE** | retry 用尽 → 立即推 `notifications` 流 |
| **Trigger 失败 → workflow inactive** | 自动设 workflow.active=false + attention_reason + 推通知 |
| **复制 message 进 queue** | 给 case 回边 / retry / replay 用(同一机制) |
| **Cancel 机制** | `:cancel` flowrun 时杀消费 actor |
| **超时杀进程** | workflow / 节点超时时强杀(用户配的超时值) |
| **重放 API** | `POST /messages/{id}:replay` |

---

## 策略由 workflow 编排者拍

| 策略 | 怎么实现 |
|---|---|
| **失败重试次数 / backoff** | tool / agent / trigger 节点 config 填 `retry: {maxAttempts, backoff}`;不填 = 0 次,失败立即通知 |
| **错误分类** | 上游节点输出 error → **case 节点显式判断** + 路由 |
| **通知后做什么** | workflow 内部画(连一个 notify tool 节点 / 死信 / 等) |
| **超时** | 节点 / workflow config 填 `timeout`;不填 = 永不超时 |
| **死信处理** | 用户/AI 调 `:replay` 决定要不要重跑 |

---

## 死信

```
messages.status: pending | consumed | dead_letter
```

| 操作 | API |
|---|---|
| 查死信 | `GET /flowruns/{id}/dead_letters` |
| 重放 | `POST /messages/{id}:replay` |
| 清死信 | `DELETE /flowruns/{id}/dead_letters` |

---

## "再跑" 的统一抽象

所有"让某个节点再跑一次"在 message queue 模型下都是同一机制——**复制 message 进目标 queue**:

| 场景 | 触发方 |
|---|---|
| case 节点回边 | case dispatcher emit |
| 节点失败 retry(retry 次数内) | scheduler emit(retryAttempt +1) |
| 用户/AI replay 死信 | `:replay` API emit |

新消息 ctx 总有 `parentId` 指向源(因果链)。actor 永远只看到"一条 message",**无逻辑分支处理"重跑"**。

---

## AI 在错误处理中的角色

通知到达 chat 后,AI 主动诊断 + 帮修:

```
平台推 SSE 通知:"workflow X 的 tool 节点重试 3 次都失败 (handler crash, OOM)"
    ↓
AI 在 chat 主动起话题(订阅 notifications 流):
  "workflow X 的 Gmail handler 重试 3 次都 crash 了。
   看了下代码,cache 没限制大小导致 OOM。
   要我帮你改 + replay 失败的 message 吗?"
    ↓
用户 "好"
    ↓
AI 调 edit_handler → :accept → replay dead_letters
```

如果是 trigger 失败导致 workflow inactive:

```
平台推通知:"workflow X 入口 polling 失败 3 次,workflow 已 inactive"
    ↓
AI:"polling function 调 Gmail API 时 429,频率太高了。
   我看了下你设的 interval 是 5s,要不改成 60s 再 :activate?"
    ↓
用户 yes → AI edit polling function / 改 trigger interval → :activate
```

---

## 决策总览

```
1. retry 次数                   → tool / agent / trigger 节点 config(用户/AI 拍,不填=0)
2. retry 内失败                 → 只记录,不通知
3. retry 用尽                   → 平台强制通知 SSE
4. Trigger retry 用尽           → workflow 自动 inactive + needs_attention + 通知
5. 其他节点 retry 用尽           → 通知 + flowrun 失败,workflow.active 不变
6. 通知载体                     → SSE notifications 流(已有)
7. 错误分类                     → case 节点显式判断
8. 死信                         → messages 表 status='dead_letter'
9. 重放                         → :replay API,语义由用户/AI 决定
```
