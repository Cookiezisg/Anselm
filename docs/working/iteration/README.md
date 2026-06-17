---
id: WRK-026
type: working
status: active
owner: @weilin
created: 2026-06-18
reviewed: 2026-06-18
review-due: 2026-09-16
audience: [human, ai]
landed-into:
---

# Iteration Loop —— AI 操作手册（START HERE）

> **你是一个 AI?读完这个文件夹你就能立刻跑这个 loop。** 本文件 = 怎么跑 + 怎么判 + 铁律。
> [`TASKS.md`](TASKS.md) = 跑什么 + 预期 + **后端 ground-truth 查询**。[`LOG.md`](LOG.md) = 已发现什么（线性记录，别重复）。
> 仓库根：`/Users/SP14921/Documents/Personal/PersonalCodeBase/Foryx`。真模型 key 在仓库根 `.env`（`DEEPSEEK_API_KEY`，deepseek-v4-flash）。运行器：`testend/golden/selfiter_*_test.go`。

## 这个 loop 是什么

一条**延绵不断、线性的**迭代线，永远在转：

```
EXPLORE ──► CONFIRM ──► FIX ──► VERIFY ──► LOG ──┐
（找下一个问题）  （确认是真的）（动手修）（重跑同样的测）（记账）   │
  ▲                                                              │
  └──────────────────────────────────────────────────────────────┘
```

两个不可省的灵魂：
- **每个 test 是一段多轮对话**，不是一次问答——一个**目标驱动的 user-simulator** 带着上下文跟 agent 聊 N 轮、会追问会反驳；agent 也带着对话上下文。综合判整段轨迹。
- **判不只看 LLM 回复，要进后端 query**——回复说"已触发任务"不算数，得查 flowrun 节点真跑上没、跑对没。**后端状态才是 ground truth**（见 RUBRIC + TASKS 每条的 ground-truth 查询）。

## 架构：EXPLORE 并发 / EXPLOIT 串行

| 阶段 | 谁干 | 怎么干 |
|---|---|---|
| **EXPLORE**（找问题） | **多 agent 并发**（Workflow 扇出） | 每个 agent 选一个方向，跑多轮 probe + 后端查询，报候选问题（带证据） |
| **EXPLOIT**（处理问题） | **回到主 agent，串行** | CONFIRM → FIX → VERIFY → LOG，一个问题彻底解决再开下一个 |

**线性的是骨干**（问题→问题→问题，LOG 一条线长大）；**并发只在发现的爆发期**。两者不矛盾。

## 一圈 = 6 拍

### 拍 1 · EXPLORE（多 agent 并发，开拓不同方向）
解决完上一个问题后，扇出多个 agent，各探一个**没覆盖过**的方向（读 LOG 避重）：handler 常驻、workflow durable 崩溃恢复、search RAG、大工具面下的选择、跨对话 memory、edit 循环里的恢复……每个 agent 跑多轮 probe + 后端查询，报候选问题 + 证据。候选回到主 agent。

### 拍 2 · CONFIRM（主 agent，是真问题还是噪声?）
围绕候选问题**设计多个变体 probe**（不同措辞/不同实体），各跑 1-2 次。**"确认" = 跨变体一致复现**，不是出现一次就算。一次性 ≠ 系统性。

### 拍 3 · FIX（主 agent，直接动手修）
确认是真问题 → **直接改**。先定位到层：tool 描述 / tool 实现 `.go` / 引擎 / system prompt。改最小的那处。`make verify` 必绿；改文案触动契约 → 同提交改 `references/`。

### 拍 4 · VERIFY（主 agent，前后对比）
**重跑确认它的那些 probe**（拍 2 的变体 + 原始发现 probe），对比修前/修后 + 查后端状态。**改进必须可见**（失败调用没了 / 选对了 / 后端状态对了）。没改进 → 回拍 3 换修法，或记为"修法无效"。

### 拍 5 · LOG（追加，线性记账）
[`LOG.md`](LOG.md) 追一条：证据→定位→修法→前后对比→状态。该 probe 进**永久回归集**（以后每圈重跑守它）。

### 拍 6 · LOOP
回拍 1，开拓新方向，直到下一个问题。**永不停。**

## 怎么跑一个 probe（命令）
```bash
bash -c 'set -a; . /Users/SP14921/Documents/Personal/PersonalCodeBase/Foryx/.env; set +a; \
  cd /Users/SP14921/Documents/Personal/PersonalCodeBase/Foryx/testend && \
  EVALS=1 mise exec -- go test -count=1 -timeout 25m -run <TestName> -v ./golden/...'
```
轨迹落 `/tmp/anselm_selfiter/<tag>.*.json`：`.messages.json`（核心轨迹：tool_call 名+args / tool_result / reasoning / text）· `.systemprompt.json`（agent 真看到的 system prompt，工具描述住这）· `.functions.json`/`.handlers.json`（实体终态）· `.usage.json`（token）。**后端 ground-truth 查询**：probe 里直接 `wc.GET(...)` 查 flowrun 节点 / 执行记录 / 版本 / trigger firing，落盘供判官核对。

## RUBRIC —— 把轨迹判成判词

六维度各 1-5，**每分必引证据**（block seq / tool_call 内容 / **后端查询结果**）：

| 维度 | 问 | 怎么判 |
|---|---|---|
| 工具选择 | 每个子目标选对工具没? | LLM 判（你） |
| 参数正确 | args 字段名/形状/值对没? | LLM 判 |
| 顺序 | 序列合理没? | LLM 判 |
| 恢复 | 撞错了下一步自纠没? | LLM 判（**容忍 double-check，收敛即满分**） |
| 效率 | 多余调用/回合?token 合理? | LLM 判 + usage |
| **系统终态（端到端真相）** | **后端真做成没?** 实体建了/run 出对值/版本前进/**flowrun 真跑上跑对**/trigger 真 fire | **code 判**（query 后端，最硬，不可省） |

**混合判官**：确定性事实（终态/版本/run 结果/崩溃恢复/firing）用 **code query 后端**；模糊质量用 **LLM 判**。能 code 判的绝不用 LLM 判。

## 铁律
1. **判官 ≠ 被测 agent。** 你判轨迹，别把判词喂回去污染被测。
2. **防自欺靠机制不靠人盯**：confirm-跨变体复现（拍 2）+ before/after-同测对比（拍 4）+ **后端 ground-truth**（拍 4）三件都是客观的，抗 AI 自我合理化。人是**LOG 这条线的审计者**，不是每步的闸。
3. **绝不改预期/断言来刷绿。** 预期错了就改预期并在 LOG 说明，不为通过而改。
4. **无回归 case 的修复 = 没修完**（拍 5 进永久集）。
5. `make verify` 必绿；改文案触动契约 → 同提交改 `references/`（CLAUDE.md 同步触发表）。

## 文件
- `README.md`（本文件）· [`TASKS.md`](TASKS.md)（任务+预期+后端查询）· [`LOG.md`](LOG.md)（线性账本）。
- 运行器：`testend/golden/selfiter_probe_test.go`（任务）+ `selfiter_confirm_*_test.go`（变体确认）。

## 还要建的（让 loop 真自动转）
- **多轮 user-simulator**：现在 probe 是单轮。建一个目标驱动的模拟用户（LLM 带 persona+目标，读 agent 回复生成下一轮），把 probe 升成 N 轮对话。
- **固化判官**：把"判官"变成一个 `judge` 调用（喂轨迹+后端查询+预期 → 结构化判词），不靠人手判（golden 层今天零 LLM 判官）。
- **explore 扇出**：把拍 1 做成 Workflow（多 agent 各探一方向）。固化后落 `references/`。
