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
> [`TASKS.md`](TASKS.md) = 跑什么 + 什么算好。[`LOG.md`](LOG.md) = 已经发现了什么（别重复）。
> 仓库根：`/Users/SP14921/Documents/Personal/PersonalCodeBase/Foryx`。真模型 key 在仓库根 `.env`（`DEEPSEEK_API_KEY`，deepseek-v4-flash）。运行器：`testend/golden/selfiter_probe_test.go`。

## 这个 loop 是什么（一句话）

让**真 agent 在真模型上跑真任务** → 抓**整条轨迹** → **你（AI）当判官**按预期判「工具用得对不对 + 整套工程转得对不对」 → 把 finding 记进 LOG + 提**修复 PR（人 review）** → 任务变**永久回归 case**。

**已证明能跑**（2026-06-18，deepseek-v4-flash，见 LOG.md）：第一圈就挖出一个真 finding，而现有 golden 测试对它瞎。

## 一圈 loop = 5 步

### 步 1 · 选/加任务
从 [`TASKS.md`](TASKS.md) 挑一条；要加新任务 = 在 `testend/golden/selfiter_probe_test.go` 写个 `TestSelfIter_<名>`（照现有两个的样子）+ 在 TASKS.md 登记预期。选任务原则：**端到端压全栈**，别测孤立工具 ping。

### 步 2 · 跑（真 agent × 真模型）
```bash
bash -c 'set -a; . /Users/SP14921/Documents/Personal/PersonalCodeBase/Foryx/.env; set +a; \
  cd /Users/SP14921/Documents/Personal/PersonalCodeBase/Foryx/testend && \
  EVALS=1 mise exec -- go test -count=1 -timeout 25m -run TestSelfIter -v ./golden/...'
```
`EVALS=1` 是真模型门控（不设则 skip、零 token）。`-run TestSelfIter` 跑全部 probe；换成单个 test 名跑一条。耗时：每任务约 20-60s（真模型多步工具循环）。

### 步 3 · 读轨迹
落在 `/tmp/anselm_selfiter/<tag>.*.json`（`<tag>` = probe 里传的标签）：

| 文件 | 是什么 |
|---|---|
| `<tag>.messages.json` | **核心**：每个 `tool_call`（`attrs.tool`=工具名，`content`=args）、`tool_result`（`content` + `error`）、reasoning、最终 text。判官读这个。 |
| `<tag>.systemprompt.json` | agent 真看到的 system prompt——**工具描述住这**，定位 description finding 必看。 |
| `<tag>.functions.json` / `.handlers.json` | 实体终态（建了什么、版本号）。 |
| `<tag>.usage.json` | token 账单（inputTokens/outputTokens）。 |

### 步 4 · 判（你 = 判官，按下面 RUBRIC）
对每个任务逐维度给分 + 定位 finding。**容忍恢复**：模型犯错 → 下一步自己改对 → 判恢复满分、整体 PASS。只看**收没收敛**，不因绕一步扣死（埋雷任务正是要看这个）。

### 步 5 · 记 + 提案
- 任何 finding 追加进 [`LOG.md`](LOG.md)（模板在那，append-only）。
- 可行动的 → 提一个**修复 PR**，**定位到层**（tool 描述 / tool 实现 `.go` / 引擎 / system prompt）。**人 review，绝不自动 merge。**
- 任务进永久回归集（以后重跑它守住不回退）。

## RUBRIC —— 怎么把轨迹判成判词

六维度，各 1-5，**每分必引轨迹证据**（block seq / tool_call 内容）：

| 维度 | 问什么 | 怎么判 |
|---|---|---|
| 工具选择 | 每个子目标选对工具没？ | LLM 判（你） |
| 参数正确 | args 字段名/形状/值对没？（看 tool_call 的 `content`） | LLM 判 |
| 顺序 | 序列合理没？（该 search 再 get、该 create 再 run） | LLM 判 |
| 恢复 | 撞错了能下一步自纠没？ | LLM 判（**容忍 double-check，收敛即满分**） |
| 效率 | 有多余调用/回合没？token 账单合理没？ | LLM 判 + usage.json |
| 系统终态 | 引擎真做成没？（实体建了/跑出对值/版本前进/崩溃恢复） | **code 判**（确定性事实，比 LLM 硬） |

**混合判官原则**：确定性事实（终态/版本/run 结果/崩溃恢复）用 **code 断言**；模糊质量（选得好不好、恢复漂不漂亮）用 **LLM 判**（你）。能 code 判的绝不用 LLM 判。

**finding 长什么样**：不是「分低」，是 **「第 N 步做了 X，该做 Y，因为 Z；坏在 <哪一层>；建议 <怎么改>」**。**定位到层**是关键——它决定提案改哪个文件。

## 铁律（读到这就别破）

1. **你是判官 + 提案者，不是自动合并者。** 每个修复 PR 由人 review。
2. **绝不改任务的预期/断言来让一次跑「通过」。** 预期写错了就改预期并在 LOG 说明，但不能为刷绿改它。
3. **无 case 的修复 = 没修完。** 每个真 finding → 一条永久任务（回归守它）。
4. **判官 ≠ 被测。** 你判的是 agent 的轨迹；你不是那个被测 agent，别把判词喂回去污染被测跑。
5. **安全地板**：改任何 `.go` 后 `make verify` 必绿（gofmt+vet+build+单测+doc gate）；改文案触动契约 → 同提交改 `references/`（CLAUDE.md 同步触发表）。

## 文件
- `README.md`（本文件）—— 怎么跑 + 怎么判 + 铁律。
- [`TASKS.md`](TASKS.md) —— 任务 + 预期注册表。
- [`LOG.md`](LOG.md) —— finding 账本（append-only）。
- 运行器：`testend/golden/selfiter_probe_test.go`（捕获层：跑真 agent + 落轨迹）。

## 把 loop 自动化的方向（按需做，非必须）
- **固化判官**：把「步 4」变成一个 `judge` 调用（喂 `messages.json` + 预期 → 结构化判词），让 loop 不靠人手判。这是 golden 层今天缺的那块（全仓零 LLM 判官）。
- **铺任务集**：把任务铺到压全栈（workflow+durable 崩溃恢复、handler、trigger、search…），覆盖「整套工程转不转」。
- **落地**：固化后这层从 `testend` 升级、把方法落 `references/`（working 90 天上限，见 GOVERNANCE §9）。
