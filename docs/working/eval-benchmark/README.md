---
id: WRK-094
type: working
status: active
owner: @weilin
created: 2026-10-18
reviewed: 2026-10-18
review-due: 2027-01-16
audience: [human, ai]
landed-into:
---

# WRK-094 · 建图与修复测量基准（evalbench）

> 目标：把"一句话建出能跑的 workflow""失败 run 被修成新版本"这两句产品结论变成**可复现的数字**。
> 没有数字之前，这两句只能是 demo；有了数字，README 与对外介绍都引用同一张表。
> 代码在 [`testend/evalbench/`](../../../testend/evalbench/)，比率定义只在
> [`score.go`](../../../testend/evalbench/score.go) 一处。

## 1. 四条车道与主数字

| 车道 | 主数字 | 判定方式 | 实现 |
|---|---|---|---|
| Build | Pass@1、Pass@3 | 回环 sink 收到的调用序列 + Library/MCP 台账 | `TestEvalbench_Build`（真模型） |
| Repair | 修复成功率、无回归率、误修复率 | 同上，故障由 sink 或 harness 注入 | `TestEvalbench_Repair`（真模型） |
| Durable | 崩溃恢复成功率、副作用重复次数 | 既有 scenarios 已证明，待计数 | `scenarios/contract_workflow_test.go` 中 `*Restart*` 系列、`media_recovery_test.go` |
| Guard | 强制确认召回率、绕过次数 | llmmock 脚本化自报 `danger=safe` 调用下限工具 | 目录在 [`dangers.json`](../../../testend/evalbench/dangers.json)，场景待补 |

Build 与 Repair 是本战役新增的测量；Durable 与 Guard 的行为已有黑盒覆盖，本战役只补"把通过次数变成
分子分母"的汇总。

## 2. 任务集（Build / Repair 共用）

[`tasks.json`](../../../testend/evalbench/tasks.json)：60 条，四档各 15 条。每条三件套：自然语言输入、
期望结构（节点类型计数 + trigger 类型）、可执行断言。

| 档 | 定义 | 断言面 |
|---|---|---|
| T1 | 单 trigger + 单 Function，无分支 | sink 收到 1 次指定 method/path/body |
| T2 | ≥3 节点，Control 分支、fan-in 或严格顺序 | 分支互斥（`absent`）、fan-in 汇总值、调用顺序（`ordered`） |
| T3 | Agent 节点 + 审批节点 + 有状态 Handler | 审批 yes → 送达；审批 no → `absent`；Handler 计数进 body |
| T4 | Webhook trigger、MCP 工具、多步外部副作用、Library 文档 | harness 投递 webhook、MCP 调用台账、文档存在 |

断言规则全部机器可判（`Judge`，有单测）：`calls` 精确次数 + body 子串；`absent` 零调用；`ordered`
同一 path 的 body 按序出现；`documents` 按名；`mcpCalls` 按工具/状态。模型的叙述永不进入裁决。

外部依赖只有一个：进程内 `httptest` 回环 sink（`sink.go`）。沙箱函数直连网络，无需代理；提示词里的
`{{SINK}}` 发送前替换为真实基址。

## 3. 指标定义

### Build

- **attempt**：attempt 1 = 模型首次建图 + 任务规定的首跑，零追问；之后每个 attempt 是 harness 一轮
  "修一下"追问——只回引观测到的失败文本，不含代码、不提示修法，不是人工编辑。
- **Pass@1** = attempt 1 通过的 run 数 / 总 run 数（60 × reps）。
- **Pass@3** = attempt ≤ 3 通过的 run 数 / 总 run 数。恒有 Pass@3 ≥ Pass@1。
- **分档 Pass@k**：同口径，分母为该档 15 × reps。
- **trigger 匹配**：trigger 域没有 `manual` 种类（手动跑是 workflow 自身能力），而图必须有一个 trigger
  节点，所以期望 `manual` 由图上任意 trigger 满足；其余种类须精确相等。只报告不门控。
- **结构 Jaccard**：期望与实际节点类型多重集的 Σmin/Σmax，只报告不门控——形状不同但跑通仍算通过。
- **稳定任务**：每次重复都在 attempt ≤ 3 通过的任务集合，作为 Repair 车道的分母来源。
- **失败归因**：Pass@3 未通过的 run 按裁决文本归入 structure / code / wiring / mapping / other。

分母是 run 数而不是任务数：三次重复过一次只贡献 1/3。

### Repair

[`faults.json`](../../../testend/evalbench/faults.json) 五类：`http_502`、`timeout`（sink 瞬时故障，
首次调用后解除，重试即可修）；`schema_change`、`http_401`（header 门故障，请求携带指定 header 前持续
失败，只有改代码才算修）；`model_bad_output`（harness 把函数改成返回 list，引擎在节点拒绝）。

- **送达口径**：被故障应答的请求记入台账并标 `faulted`，但不计为送达；`calls` / `ordered` 只看送达，
  `absent` 看任何尝试。因此"失败一次后重试成功"恰好是一次送达。
- **注入有效**：故障真的让 run 失败或断言不过；否则该行作废（`failed=false`），不计入任何分母。
- **修复成功** = 图内函数出现新版本 **且** 重跑 completed 并通过断言 / 有效注入数。
- **无回归** = 修复后撤故障、清 sink 再起一次干净 run 仍通过 / 修复成功数。
- **误修复** = 出了新版本、重跑 completed、但断言失败 / 有效注入数。
- 修复追问最多 2 轮，只回引 run 的失败文本；`http_401` 额外给出 bearer token（目录声明用户本就知道）。

### Durable 与 Guard（计数口径）

- **崩溃注入**：节点完成写库后、下一节点开始前 `Kill9` 进程；恢复成功 = 重启后 run 到达 completed；
  副作用重复 = sink 实收调用数 − 期望调用数，目标 0。
- **Guard**：11 个带不可绕过 `dangerous` 下限的工具（`destructive_test.go`）× 3 种预授权条件（无 /
  `approve_always` / skill `allowed-tools`）= 33 例；每例脚本化模型自报 `danger=safe`，通过 = 出现
  HumanLoop interaction 且工具未执行。召回率目标 100%，绕过目标 0。

## 4. 执行协议

```bash
make -C backend evalbench                      # 全部 60 条 × 3 次，先 Build 再 Repair
EVALBENCH_TASKS=T1 make -C backend evalbench   # 只跑一档；或 EVALBENCH_TASKS=T1-03,T4-07
EVALBENCH_REPS=1 make -C backend evalbench     # 调试用单次
EVALS_PROVIDER=deepseek make -C backend evalbench   # 便宜模型对照（需 .env 里的 key）
make -C backend evalbench-score                # 折叠 results.jsonl → Markdown 表
```

- 模型固定、每任务 3 次（`EVALBENCH_REPS`），每个 (task, rep) 独立 workspace，模型看不到其它 run 的实体。
  每条车道只起一个 server：每个 server 都是一次新的受管 install，网关对 install 登记限流（429）。
- 建图对话里的自报危险门与 ask_user 由 harness 自动放行（与 golden 同策略）；workflow 审批节点按任务
  的 `approvalDecision` 立即裁决。
- 结果追加到 `testend/evalbench/out/results.jsonl`（gitignored）；`evalscore` 的 Markdown 表连同环境
  （模型、日期、commit）贴到本文件 §5，Repair 车道在存在结果文件时只取稳定任务。
- 受管路由默认模型与一个便宜模型各跑一遍，两组数一起报。

## 5. 结果

尚未运行。首次结果落在这里，格式即 `evalscore` 输出；写进 README 或对外介绍的数字必须能在此找到分子分母。

## 6. 已知边界

- Build 车道的"修一下"追问计入 attempt，不是人工编辑；因此 Pass@3 口径偏保守。
- T4 的 `eb_digest` 依赖 Agent 节点挂 document 工具；若模型不给 Agent 挂工具，归因为 structure。
- `timeout` 故障依赖沙箱对挂起请求的超时；若沙箱超时长于 `EVALBENCH_RUN_MS`，该注入会被判作废而非失败。
- Durable 与 Guard 的计数脚本尚未落地，本文件 §1 的"待补"即收口条件。
