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

> AI：读完这个文件夹你就能跑这个 loop。本文件 = 怎么跑 + 怎么判 + 铁律。
> [`TASKS.md`](TASKS.md) = 跑什么（索引表）。[`LOG.md`](LOG.md) = 已发现什么（索引表，别重复挖）。
> 仓库根 `/Users/SP14921/Documents/Personal/PersonalCodeBase/Foryx`；真模型 key 在根 `.env`（`DEEPSEEK_API_KEY`，deepseek-v4-flash）；运行器 `testend/golden/selfiter_*_test.go`。

## 一句话

让真 agent 在真模型上跑真任务 → 抓整条轨迹 → 你（Claude）当判官判「工具用得对不对 + 整套工程转得对不对」 → **有就都修** → 重跑同测看前后 → 记一行 → commit。一条延绵不断、线性的迭代线。

**两个灵魂：**
- **① 多轮对话，不是一问一答。** **你（Claude）亲自扮演用户**，带一个目标跟 agent 聊 **6-9 轮**——它做错你纠正、它问你答、它绕了你引导，综合判整段。（当前标准目标驱动用户即可，暂不做多人设。）
- **② 判要进后端 query。** 回复说"已触发"不算，查 flowrun 真跑上没——后端状态才是 ground truth。

## 架构：EXPLORE 并发 / EXPLOIT 串行
- **EXPLORE**（找问题）= 多 agent 并发，各探一个没覆盖的方向（每个 agent 也亲自演用户跑多轮）。
- **EXPLOIT**（CONFIRM→GENERALIZE→FIX→VERIFY→LOG→COMMIT）= 回主 agent，串行，一个问题彻底解决（含同类一起解决）再开下一个。
- 线性的是骨干（LOG 一行一行长大）；并发只在发现的爆发期。

## 循环 = 8 拍

| 拍 | 名 | 干什么 |
|---|---|---|
| 1 | **REVIEW** | 起手先读本 README，刷新操作模型（防漂移、加深印象）。 |
| 2 | **EXPLORE** | 多 agent 并发各探一新方向（先读 LOG 避重）；跑**多轮对话** probe + 后端查询，报候选。 |
| 3 | **CONFIRM** | 多变体各跑 1-2 次，**跨变体一致复现才算真**，出现一次不算。 |
| 4 | **GENERALIZE** ★ | **修任何东西前的第一反射**：独有还是**范问题**（不止这里）？读共享层 / 同类工具确认范围。 |
| 5 | **FIX** | 直接修，**有就都修**（不设"值不值得"闸）。范 → 批量 + 修地基一处；独有 → 只修这处。定位到层。 |
| 6 | **VERIFY** | 重跑确认它的那些测 + 后端 ground-truth，前后对比。**能转成零 token 结构断言的就转**（回归守得便宜）。改进必须可见，否则回拍 5。 |
| 7 | **LOG** | 在 [`LOG.md`](LOG.md) 表里追一行（索引，不写 essay）。 |
| 8 | **COMMIT** | **一个 fix = 一个 commit**：fix + 回归 test + LOG 行同提交，专用分支。 |

回拍 1，开拓新方向，**永不停，直到 API 报告没额度**（见「停止信号」）。

## 跑 probe —— 两种形态
- **多轮探索 / 评估（主形态，你演用户）**：拉起配置好的 server（helper `selfiter_serve`，待建：server + ws + deepseek 默认模型 + conv），然后**你逐轮驱动**：POST 你的用户消息 → 轮询 assistant 回合到终态 → 读 agent 干了啥（messages：tool_call 名+args / 结果 / text）→ 你作为标准目标驱动用户写**下一句**→ 重复 6-9 轮 → 判整段 + 查后端。每轮自动放行 danger 门。
- **单轮回归（守已找到的，Go test）**：`testend/golden/selfiter_*_test.go`，零交互可后台跑。**多轮找到的问题，把你当时各轮的用户消息脚本化进一个 Go test**（用户侧固定、agent 侧真模型）做回归。命令：
  ```bash
  bash -c 'set -a; . /Users/SP14921/Documents/Personal/PersonalCodeBase/Foryx/.env; set +a; cd /Users/SP14921/Documents/Personal/PersonalCodeBase/Foryx/testend && EVALS=1 mise exec -- go test -count=1 -timeout 25m -run <Test> -v ./golden/...'
  ```
  轨迹落 `/tmp/anselm_selfiter/<tag>.*.json`。

## RUBRIC（判官，判整段对话非单轮）
六维度各 1-5，**每分必引证据**（轮次/block seq / tool_call 内容 / 后端查询结果）：工具选择 · 参数 · 顺序 · **恢复**（容忍 double-check，**跨轮收敛即满分**）· 效率（含 token）· **系统终态**（query 后端，确定性事实，最硬）。
混合判官：确定性事实用 code 判；模糊质量用 LLM 判。**finding** = 「第 N 轮/步做了 X，该 Y，因为 Z；坏在<哪层>；建议<怎么改>」——定位到层才知道改哪个文件。

## 铁律
1. **GENERALIZE 先于单修**（拍 4）：修任何东西前先问"范问题吗"、读共享层。修一类别一个个磨。
2. **有问题就都修**（不设值不值得闸）。
3. **防自欺靠机制**：CONFIRM 跨变体 + VERIFY 前后 + 后端 ground-truth，三者皆客观。判官 ≠ 被测。
4. **绝不改预期/断言刷绿**；预期错了改预期并在 LOG 注明。
5. **无回归 test 的修 = 没修完**（拍 8 进永久集；能零 token 结构断言就优先用它）。
6. `make verify` 必绿；改文案触动契约 → 同提交改 `references/`（+ Co-Authored-By 尾注）。
7. **commit 在专用分支**（不动 `main`）；消息 `fix(loop): F<n> <一句话> [范围]`。

## 停止信号
**唯一停止信号 = deepseek API 报额度/余额耗尽**（model 调用持续因无额度失败）。此时**不撂挑子**：把当前卡在一半的修做到**干净态**（`make verify` 绿 + 该 commit 的 commit 掉），再收工等下一步。**绝不留半坏状态。**

## 文档规范（强制 —— 这些表会无限增长）
LOG / TASKS 是**索引表非 essay**：一条 = 一行，每格一短语；详情进 commit/test，不进表。违反（写成段落、重复别处已有事实）= 文档腐烂，立刻压回一行。

## 文件 / 已知 gap
文件：`README.md` · [`TASKS.md`](TASKS.md) · [`LOG.md`](LOG.md) · 运行器 `selfiter_*_test.go` + **待建 `selfiter_serve`**（多轮 bring-up）。
已知 gap：判官是裸的你 + 单模型（自评偏差，靠后端 ground-truth + 前后对比兜）；EXPLORE 无"已探方向"地图（可能反复挖浅）；回归套真模型成本（尽量转零 token 结构断言）。
