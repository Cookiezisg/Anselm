---
id: WRK-004
type: working
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-06-11
review-due: 2026-09-11
expires: 2026-09-11
landed-into: ""
audience: [human, ai]
---

# REPORT —— 全后端系统级 Code Review 终报（2026-06-11）

## 结论

五维审查完成（R1-R5）。**修复 9 条（🔴×4 + 🟡×5）、留档产品决策 3 条（PD-1/2/3）、亲验驳回误报 6 条、wontfix 带理由 7 条**。`make verify` + **全量 `go test -race`** 双绿。方法：并发热点全部亲审 + 2 个 subagent 面扫后逐条亲验（含验证过程登记，见 [findings.md](findings.md)）。

## 修复一览（按维度）

**工程正确性（并发/竞态/泄漏）——R1**
| # | 问题 | 修法 |
|---|---|---|
| CR-1 🔴 | chat 队列自毁与投递交错 → task 滞留死 channel、回合永久 streaming | 拆卸与投递同锁原子化（dead 标志） |
| CR-2 🔴 | Shutdown 裸 wg.Wait → 关 app 卡到 5 分钟 idle timer | stop channel + 先 cancel 在跑回合 |
| CR-3 🔴 | 硬崩溃 streaming 孤儿永久转圈（无 boot 对账） | SweepNonTerminal + forEachWorkspace 接线 |
| CR-4 🟡 | broker Resolve 锁外 send TOCTOU（对已中止 run 报已送达） | 锁内非阻塞投递 |
| CR-5 🟡 | handler 并发首调双 spawn（秒级开销 ×2、一个被扔） | per-handler 单飞 |
| CR-6 🟡 | mcp 并发连接注册覆盖 → 输家 client+进程僵尸 | 注册换出旧值并关闭 |

**产品正确性——R2**
| # | 问题 | 修法 |
|---|---|---|
| CR-8 🔴 | 删对话不停在途生成（烧 LLM、对已删线程推流） | GenerationCanceler 端口（后注入），Delete 先 Cancel |
| CR-9 🟡 | Send 不验对话存在 → 孤儿 user 回合落库后才失败 | Send 头部存在性闸（404 早退） |

**架构一致性——R4**
| # | 问题 | 修法 |
|---|---|---|
| CR-7 🟡 | toJSON ×10 包级副本 | 下沉 `toolapp.ToJSON`，10 包统一 |

## 等你裁决（[DECISIONS-PENDING.md](DECISIONS-PENDING.md)）

1. **PD-1 workspace 删除零清理**——删了 ws 行但自动化还在跑、数据全留。推荐 A（级联销毁）。
2. **PD-2 归档对话可 Send**——纯产品语义二选一。
3. **PD-3 Edit 两步写事务性**——我倾向 wontfix（反校验剧场），候选 B 是 store 复合事务方法。

## 审查覆盖与方法说明

- R1 亲审：chat 队列 / humanloop broker / handler·mcp 池 / scheduler inflight / stream bus / agentstate / cron·sensor listener / shell manager / loop progress / entitystream / catalog / autotitle——全部并发原语站点。
- R2 亲审产品边界：删对话/删实体在途、归档 Send、ws 删除、附件无效 id（软降级 ✓）、subagent 经 fork-skill 递归（Spawn ctx 闸防住 ✓）、审批并发（P3 已验 first-wins）。
- R3/R4 subagent 面扫 17 条 → 亲验后 2 真（1 修 1 留档）、6 误报驳回、9 wontfix 带理由——**误报率 >1/3，印证"subagent 报告必须逐条亲验"纪律**。
- 可维护性维度：TODO/FIXME 残留 0；docswriter 刚收口的 27 篇文档已覆盖注释/命名一致性；本轮行为变化已同步 6 篇文档（chat/conversation/messages/bootstrap/mcp/handler）。

## 遗留（已登记非本轮）

forgeSink ×2 同构（下沉受依赖环约束，落 envfix 侧再做）；broker.allowed 只增（量级 KB/月）；docswriter 留档的观测议题（agent tokens 持久化等）。
