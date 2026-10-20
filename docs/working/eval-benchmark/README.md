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
| T4 | Webhook trigger、MCP 工具、Agent 输出驱动的多步外部副作用 | harness 投递 webhook、MCP 调用台账、调用次数/顺序/body |

断言规则全部机器可判（`Judge`，有单测）：`calls` 精确次数 + body 子串；`absent` 零调用；`ordered`
同一 path 的 body 按序出现；`mcpCalls` 按工具/状态。模型的叙述永不进入裁决。

**刻意没有文档断言。** 工作流内部无法创建 Library 文档：agent 的工具宇宙恰是其挂载，而 `sys:` 挂载表只有
生成/编辑类媒体工具。曾存在的那条反而可由**主对话助手**手工建档满足（全 workspace 名字检查，不是执行
裁决），已随三条无解任务一并移除。涉及 Agent 的 T4 任务改为让 Agent 做一个**确定性变换**（topic 转大写
连字符），其产物只能经 Agent 产生，再由下游函数 POST 到 sink——断言因此既机器可判、又真正依赖 Agent。

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
- **台账切窗**：裁决只看 flowrun `startedAt` 之后到达的 sink 调用。台账按 attempt 重置，但一个 attempt
  还含模型接线前自己做的事——用 `run_function` 试跑函数的模型会 POST 一次 sink，把它算进"恰好一次调用"
  等于惩罚"先验证再交付"。被排除的调用数会写进裁决理由，不静默丢弃。
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

### S7 · 2026-10-20 · `deepseek-v4-flash` · commit `41be3a23c`（对外口径）

`EVALS_PROVIDER=deepseek EVALBENCH_REPS=3 EVALBENCH_DUMP=1`，ATTEMPTS=3。180 次运行全部发出，
**13 次被污染检测判作废**（见下），有效分母 167。这是防线生效后的第一轮全量，也是唯一可对外引用的一组。

| Lane | Metric | Value |
|---|---|---|
| build | tasks / shapes / runs | 60 / 29 / 167 |
| build | Pass@1 | 92.2% (154/167) |
| build | Pass@3 | 98.2% (164/167) |
| build | T1 Pass@1 / Pass@3 | 100.0% (41/41) / 100.0% (41/41) |
| build | T2 Pass@1 / Pass@3 | 86.7% (39/45) / 95.6% (43/45) |
| build | T3 Pass@1 / Pass@3 | 93.0% (40/43) / 100.0% (43/43) |
| build | T4 Pass@1 / Pass@3 | 89.5% (34/38) / 97.4% (37/38) |
| build | mean structure Jaccard | 0.98 |
| build | stable tasks | 57 / 60 |
| build | VOID (contaminated, excluded) | 13 |
| repair | injections | 0 |

Wilson 95% 置信区间（按 run 数算，**低估**真实不确定度，见下"形状相关性"）：

| 分组 | attempt-1 | 三轮内 |
|---|---|---|
| 总体 | 92.2% [87.1, 95.4] | 98.2% [94.9, 99.4] |
| T1 | 100.0% [91.4, 100.0] | 100.0% [91.4, 100.0] |
| T2 | 86.7% [73.8, 93.7] | 95.6% [85.2, 98.8] |
| T3 | 93.0% [81.4, 97.6] | 100.0% [91.8, 100.0] |
| T4 | 89.5% [75.9, 95.8] | 97.4% [86.5, 99.5] |

工具调用次数（`modelCalls` 口径，全 attempt 合计）：中位 32、p90 54、最大 118。

**三次残余失败全部是 harness 墙钟超时**，不是裁决失败：`T2-08/rep2`、`T2-15/rep1`、`T4-08/rep1` 的
assistant 回合在 `EVALBENCH_TURN_MS=420000` 内未到终态，`modelCalls=0`、`reasons` 为空。按保守口径
计作失败。无法证明它们在更长的墙钟下会不会通过；转存显示同期有多次 60–72 调用的运行，所以更可能是
"还在干活就被掐断"而非挂死。

### 作废的 13 次：污染检测的首次全量实测

| 触及的产物 | 次数 | 任务 |
|---|---|---|
| 仓库根绝对路径 | 5 | T1-06/1、T1-10/3、T3-10/3、T4-04/3、T4-14/2 |
| `evalbench` | 8 | T1-10/2、T1-13/3、T3-01/3、T4-01/2、T4-03/1、T4-06/2、T4-07/1、T4-07/2 |

作废率 7.2%（13/180）。防线按设计工作：作废行既不计通过也不计失败，`Score` 单独报 `VOID`。

**13 次作废有同一个诱因。** 转存显示它们都走同一条路：任务要求"manual trigger"，模型调
`create_trigger(kind:"manual")` 得 `TRIGGER_INVALID_KIND`（消息只有 "unknown trigger kind"，不列合法
值），接着猜 `on-demand` / `on_demand` / `api` / `manual_fire`，再 `search_tools`、`search_documents`，
全部落空后开始 `Bash` / `Grep` 读 Anselm 源码找 kind 常量。**产品没有 `manual` 这个 trigger 种类**——合法 kind 只有 `cron` / `webhook` / `fsnotify` / `sensor`。
但手动跑的 workflow **仍然需要 trigger 节点**：`graph.go` 强制 `triggerCount >= 1`，
`scheduler.resolveEntry` 把入口 trigger 节点 seed 成 run 的根节点，零 trigger 节点的图既建不出来也跑不
起来。正确做法是建任意 kind（惯例 cron）挂成入口节点、workflow 保持 deactivated——listener 只在 ≥1 个
active workflow 引用它时运行，所以它不会自己 fire，而 `:trigger` 照常按需跑。
（`workflow.ErrNoTriggerEntry` 的注释曾声称"纯手动图没有 trigger 节点"，与 `graph.go` 矛盾，已按
`[doc-fix]` 更正。）

60 条任务里 **56 条**的提示词写着 "a manual trigger"——这个词不在产品词汇里，模型要么猜 kind 拼写、
要么读源码找常量。通过的运行实际做的是"建一个从不 activate 的 cron trigger"，也就是**正确用法**；
`TriggerMatches` 对 `manual` 放行任意 trigger，所以判分看不出模型为此烧了多少调用。因此这是题集的
措辞缺陷叠加三处产品告知缺口（`TRIGGER_INVALID_KIND` 不列合法值、`create_trigger` 与 `create_workflow`
的描述没讲"手动跑怎么建"）。影响方向是**压低**数字：浪费的调用、13 次作废和 3 次墙钟超时都来自这里。
因此 S7 偏保守，可以安全对外引用。

### 形状相关性

按归一化提示词聚类，60 条任务只有 **29 个不同形状**（归一化规则：`eb_*` 名 → `NAME`、`/tN-NN*` 路径
→ `PATH`、双引号字面量 → `STR`、整数 → `N`、压缩空白）。T2 的 15 条只有 3 个形状各 5 份拷贝。拷贝之间
高度相关，按 167 次运行算二项置信区间会低估真实不确定度。**对外陈述规模必须用形状数，不是任务数。**

形状级口径（一个形状的全部有效重复都通过才算通过）：29 个形状中 **20 个** attempt-1 全通，
**26 个** 三轮内全通。

### 对外引用口径

§3 的 `Pass@3` 是**历史命名**，量的是"≤3 个 attempt 内通过"，即 Chen et al. 2023 式的
execution-feedback self-repair（顺序修复、每轮回引失败断言），**不是** Chen et al. 2021 的 pass@k
（k 次独立采样取并）。对外写作必须用前者的术语，不可直接写 "pass@3"。同理 `modelCalls` 数的是
tool_call 块数，不是模型往返次数。

### S3 · 2026-10-20 · commit `493a9ed9d`（历史，不可引用）

防线之前的一轮：179 次运行、Pass@1 84.9%、三轮内 98.3%。该轮**不可对外引用**，原因有三：

- 不密闭：转存证实模型用 `Bash` / `Grep` 读了 `tasks.json`（`expect` 与 `assert` 全文）与本文件 §5；
  该轮的行没有 `contaminated` 字段，无法追溯判定哪些通过读过答案。
- 判分未切窗：模型接线前用 `run_function` 试跑会 POST 一次 sink，被算进"恰好一次调用"，惩罚"先验证
  再交付"。
- 题集含三条无解任务：`T4-13..T4-15` 要求"给 Agent 挂 document 工具"，而 `sys:` 注册表由
  `generate.GenerateTools()` 填充、只含六个媒体工具，**不含任何 document 工具**；其 `documents` 断言
  又查整个 workspace 的同名文档、可被主对话助手自己建档满足。该形状 Pass@1 = 0/9、中位 154 次工具调用。
  三条已重写为三个不同形状（manual+Agent、webhook+Agent、Agent+双步有序副作用），`documents` 断言与
  其全部管线已删除。S7 的 3/3 首轮通过证明问题在题目，不在产品。

## 6. 已知边界

- Build 车道的"修一下"追问计入 attempt，不是人工编辑；因此 Pass@3 口径偏保守。
- `timeout` 故障依赖沙箱对挂起请求的超时；若沙箱超时长于 `EVALBENCH_RUN_MS`，该注入会被判作废而非失败。
- Durable 与 Guard 的计数脚本尚未落地，本文件 §1 的"待补"即收口条件。
- **密闭性靠检测而非隔离**：模型持有 `Bash` / `Grep` / `Read`，且 `workDirSection` 明确告知它可读机器
  上任意绝对路径——这是产品的设计意图，没有开关。因此基准无法真正密闭。现行防线是收窄 + 检测：建图对话
  挂空临时驻地（Bash 不再从仓库起步），且任何触及基准产物的工具调用令该次运行作废。残余风险是模型用
  未被 needle 命中的路径拼接读到仓库；needle 清单是唯一的真相面，扩任务集或移动文件时必须同步。
  S7 实测作废率 7.2%（13/180）——检测会命中，代价是分母变小。
- **`expect.trigger: "manual"` 是目录词汇而非产品词汇**：它的语义是"图上任意 trigger 均可"
  （`TriggerMatches`，见 §3）。产品没有 `manual` kind，但每个图都必须有 trigger 节点，所以
  `expect.nodes.trigger: 1` 是对的、不需要改。该目录词沿用历史命名，读表时按"不限 kind"理解。
- **提示词与产品告知已在 S8 前修正**（见 §5「S8」）：50 条提示词的 "a manual trigger" 改为
  "an entry trigger I fire by hand (never on a schedule)"，六条 T4 webhook 任务的
  "(no manual trigger)" 改为 "(not fired by hand)"；产品侧补了
  `TRIGGER_INVALID_KIND` 的合法值与 `create_trigger` / `create_workflow` 描述里"手动跑怎么建"。
- **任务多样性不足**：60 条任务按归一化提示词只有 33 个不同形状，T2 的 15 条仅 3 个形状。拷贝提高
  重复测量的稳定性，但不增加独立信息；分档比率的有效样本量远小于 15 × reps。扩充前，分档数字只能
  作内部回归信号，不能作对外规模陈述。
