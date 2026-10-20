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
- **首轮留存**：`reasons` 只保留最后一个 attempt 的裁决，所以 `firstReasons` 与 `firstTools` 额外留存
  attempt 1 的裁决文本与工具调用名序列。Anselm 的工具是进程内执行、不经 HTTP，服务端访问日志里看不到
  模型调了什么；`firstTools` 是首轮失败唯一可归因的记录。
- **作废（void）**：工具调用参数触及基准产物（`tasks.json`、`evalbench`、`eval-benchmark`、仓库根绝对
  路径）的运行记 `contaminated`，**从一切分子分母中剔除**，在表里单独报 `VOID` 一行。既不计通过（可能
  读了答案），也不计失败（从未被公平尝试）。标记在一次运行内粘滞：读过之后其后一切不可归因。
- **`modelCalls` 的口径**：数的是该 (task, rep) 全部 attempt 的 **tool_call 块总数**，不是 LLM 往返
  次数——一个 assistant 回合可并发多个工具调用。字段名是历史遗留，读数时按"工具调用次数"理解。

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
EVALBENCH_DUMP=1 ... make -C backend evalbench # 失败 attempt 转存整段建图对话，供归因
make -C backend evalbench-score                # 折叠 results.jsonl → Markdown 表
```

- 模型固定、每任务 3 次（`EVALBENCH_REPS`），每个 (task, rep) 独立 workspace，模型看不到其它 run 的实体。
  每条车道只起一个 server：每个 server 都是一次新的受管 install，网关对 install 登记限流（429）。
- 建图对话里的自报危险门与 ask_user 由 harness 自动放行（与 golden 同策略）；workflow 审批节点按任务
  的 `approvalDecision` 立即裁决。
- 每个 (task, rep) 的建图对话挂一个**空临时目录**作驻地（`PATCH /conversations/{id}` 的 `workDir`），
  使 Bash 从空目录起步。未挂等于「整台机器」，实际是 server 在本仓库内的 cwd——离任务定义只有一个 `ls`。
  这是收窄默认值而非禁闭：提示词仍告知模型可读任意绝对路径，故污染同时按运行检测并作废。
- `EVALBENCH_DUMP` 非空时，每个未通过的 attempt 把整段建图对话（含 tool_call 参数与 tool_result 正文）
  转存为 `out/dumps/<task>-rep<N>-attempt<M>.json`（gitignored）。行里的 `firstTools` 只有调用名序列，
  诊断真正要看的参数与工具报错在这里。
- 结果追加到 `testend/evalbench/out/results.jsonl`（gitignored）；`evalscore` 的 Markdown 表连同环境
  （模型、日期、commit）贴到本文件 §5，Repair 车道在存在结果文件时只取稳定任务。
- 受管路由默认模型与一个便宜模型各跑一遍，两组数一起报。

## 5. 结果

### S3 · 2026-10-20 · `deepseek-v4-flash` · commit `493a9ed9d`

`EVALS_PROVIDER=deepseek EVALBENCH_REPS=3`，ATTEMPTS=3。计划 180 次运行，实得 **179**：
`T1-01/rep3` 在 BYOK key probe 阶段遇 `api.deepseek.com` 连接超时（`API_KEY_TEST_FAILED`），
模型未被调用，按缺测处理而非失败。

| Lane | Metric | Value |
|---|---|---|
| build | tasks / runs | 60 / 179 |
| build | Pass@1 | 84.9% (152/179) |
| build | Pass@3 | 98.3% (176/179) |
| build | T1 Pass@1 / Pass@3 | 90.9% (40/44) / 100.0% (44/44) |
| build | T2 Pass@1 / Pass@3 | 91.1% (41/45) / 100.0% (45/45) |
| build | T3 Pass@1 / Pass@3 | 82.2% (37/45) / 100.0% (45/45) |
| build | T4 Pass@1 / Pass@3 | 75.6% (34/45) / 93.3% (42/45) |
| build | mean structure Jaccard | 0.99 |
| build | stable tasks | 58 / 60 |

自修复分布：27 次首轮失败中 19 次在 attempt 2 通过、5 次在 attempt 3 通过、3 次耗尽预算。

**结论集中在一个任务形状。** 按归一化提示词聚类，60 条任务只有 31 个不同形状；三次永久失败全部落在
`T4-13..T4-15`（同一形状的三份拷贝）。该形状 **Pass@1 = 0/9**、三轮内 6/9、中位 154 次工具调用；
其余 30 个形状三轮内全部 100%。剔除该形状后 T4 Pass@1 = 94.4% (34/36)，T4 中最复杂的 webhook 形状
（`T4-01..T4-05`）为 15/15。因此"T4 档偏弱"的正确表述是"`eb_digest` 形状有缺陷"，不是"多步副作用难"。

Repair 车道尚未运行（`injections=0`）。

### 三条无效任务与复算

转存（`EVALBENCH_DUMP=1`）证实 `T4-13..T4-15` **题目无解**，非产品缺陷：

- Agent 的工具宇宙恰是其挂载，合法 ToolRef 只有 `fn_` / `hd_…method` / `mcp:server/tool` / `sys:<name>`；
  `create_agent` 的 schema 只列前三种。而 `sys:` 注册表由 `generate.GenerateTools()` 填充，内容是
  `generate_image`、`generate_speech`、`generate_video`、`edit_image`、`animate_image`、`enroll_voice`
  ——**不含任何 document 工具**。因此"给 Agent 挂 document 工具"在当前产品里无法表达。
- 该形状 6/9 的"三轮内通过"同样不可信：`documents` 断言走 `docNames`，查的是**整个 workspace** 有无
  同名文档，不校验它由 flowrun 产生；而主对话助手自己持有 `create_document`。断言可被"助手在聊天里
  手工建档"满足，不是执行式的。

剔除这三条（9 次运行）后的复算，口径与上表相同：

| Metric | Value |
|---|---|
| tasks / shapes / runs | 57 / 29 / 170 |
| Pass@1 | 89.4% (152/170) |
| Pass@3 | 100.0% (170/170) |
| T1 / T2 / T3 / T4 Pass@1 | 90.9% (40/44) / 91.1% (41/45) / 82.2% (37/45) / 94.4% (34/36) |

对外引用以**这一组**为准，并须同时说明剔除了三条无效任务及其理由。

### 隔离性缺陷（未修）

同一份转存显示模型通过 `Bash` / `Grep` 读了 `testend/evalbench/tasks.json`（拿到 `expect` 与
`assert` 全文）与本文件 §5。这不是越权：`workDirSection` 明确告知模型"可用绝对路径读机器上任何地方"，
文件系统读取是产品的设计意图，无开关可关。后果是 evalbench **不是密闭基准**——任何一次通过都不能排除
读过答案。S3 的 170 次运行据此只能作内部回归信号，不能作对外数字。

防线已落地（空临时驻地 + 按运行的污染检测与作废，见 §3「作废」与 §4），但 **S3 是在防线之前跑的**，
其行没有 `contaminated` 字段，无法追溯判定。对外数字须等防线生效后重跑一轮取得。

### 对外引用口径

§3 的 `Pass@3` 是**历史命名**，量的是"≤3 个 attempt 内通过"，即 Chen et al. 2023 式的
execution-feedback self-repair（顺序修复、每轮回引失败），**不是** Chen et al. 2021 的 pass@k
（k 次独立采样取并）。对外写作必须用后者的术语区分，不可直接写 "pass@3"。

同理，分母的独立性有限：60 条任务 31 个形状（T2 仅 3 个形状各 5 份拷贝），拷贝之间高度相关，
按 179 次运行算二项置信区间会低估真实不确定度。对外引用须按**形状数**而非任务数陈述规模。

## 6. 已知边界

- Build 车道的"修一下"追问计入 attempt，不是人工编辑；因此 Pass@3 口径偏保守。
- T4 的 `eb_digest` 依赖 Agent 节点挂 document 工具；若模型不给 Agent 挂工具，归因为 structure。
- `timeout` 故障依赖沙箱对挂起请求的超时；若沙箱超时长于 `EVALBENCH_RUN_MS`，该注入会被判作废而非失败。
- Durable 与 Guard 的计数脚本尚未落地，本文件 §1 的"待补"即收口条件。
- **密闭性靠检测而非隔离**：模型持有 `Bash` / `Grep` / `Read`，且 `workDirSection` 明确告知它可读机器
  上任意绝对路径——这是产品的设计意图，没有开关。因此基准无法真正密闭。现行防线是收窄 + 检测：建图对话
  挂空临时驻地（Bash 不再从仓库起步），且任何触及基准产物的工具调用令该次运行作废。残余风险是模型用
  未被 needle 命中的路径拼接读到仓库；needle 清单是唯一的真相面，扩任务集或移动文件时必须同步。
- **`documents` 断言非执行式**：`docNames` 查整个 workspace，主对话助手自己能建档，断言可被绕过。
  需要把文档存在性绑定到 flowrun 产物，或改由只有工作流能触达的 sink 代替。
- **任务多样性不足**：60 条任务按归一化提示词只有 31 个不同形状，T2 的 15 条仅 3 个形状。拷贝提高
  重复测量的稳定性，但不增加独立信息；分档比率的有效样本量远小于 15 × reps。扩充前，分档数字只能
  作内部回归信号，不能作对外规模陈述。
