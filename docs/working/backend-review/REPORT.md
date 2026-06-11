---
id: WRK-004
type: working
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-06-12
review-due: 2026-09-11
expires: 2026-09-11
landed-into: ""
audience: [human, ai]
---

# REPORT —— 全后端系统级 Code Review 终报（一轮 2026-06-11 · 二轮 2026-06-12）

## 结论

**一轮**（2026-06-11，五维 R1-R5）：修复 12 条（🔴×4 + 🟡×5 + 裁决实现 ×3）、产品决策 3 条已裁决并实现、亲验驳回误报 6 条、wontfix 带理由 7 条。方法：并发热点全部亲审 + 2 个 subagent 面扫后逐条亲验（见 [findings.md](findings.md)）。

**二轮**（2026-06-12，发版门禁）：**全仓库 624/624 文件（87,628 行 Go + 配置）逐行亲读、零 agent 代审**，产品正确性为第一维度。新修 8 条：CR-13🔴（Bash 孙进程持管道挂死→进程组杀+WaitDelay）、CR-14🔴（tool_result 无界→ 256KiB 三层封顶）、CR-18🔴（webhook 被 RequireWorkspace 拦→外部回调全 401）、CR-15🟡（Glob 噪音目录）、CR-16🟡（4 个 List 绕过 ParsePage 钳制）、CR-17🟡（agent 版本列表无分页）、CR-19🟡（pin 闭包没传到派发口——fn/ag 跑 active 版本而非冻结版本，违反 durable 语义承诺）、CR-20🟡（MachineFingerprint 死代码——落盘加密种子可猜，拷库即解）。W3（orm+22 store）、W5（loop/stream/llm/contextmgr）、W6（sandbox 双层+六实体 app）、W8（domain+pkg）为零缺陷波次。覆盖与逐波明细见 [round2-findings.md](round2-findings.md) + [round2-coverage.md](round2-coverage.md)。

两轮后 `make verify` + 并发包 `go test -race` 双绿。**发版判定：除 PD-4（WebFetch 第三方代理隐私）待裁决与 CORS Wails origin 待补两项外，后端达到可发版质量。**

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

## 产品裁决（已全部实现，2026-06-11）

1. **PD-1 → A 级联销毁 ✅**：workspace.Delete 经 Reaper 端口杀全部自动化 + 停 per-ws 常驻进程 + 删文件树 + 删行（CR-10）。
2. **PD-2 → 允许+自动解档 ✅**：Send 见 archived 即解档，软失败不挡消息（CR-11）。
3. **PD-3 → B 完整修复 ✅**：5 实体 create/edit 版本写各为单事务（store 复合方法 ×2、10 调用点、接口同步）（CR-12）。

## 审查覆盖与方法说明

- R1 亲审：chat 队列 / humanloop broker / handler·mcp 池 / scheduler inflight / stream bus / agentstate / cron·sensor listener / shell manager / loop progress / entitystream / catalog / autotitle——全部并发原语站点。
- R2 亲审产品边界：删对话/删实体在途、归档 Send、ws 删除、附件无效 id（软降级 ✓）、subagent 经 fork-skill 递归（Spawn ctx 闸防住 ✓）、审批并发（P3 已验 first-wins）。
- R3/R4 subagent 面扫 17 条 → 亲验后 2 真（1 修 1 留档）、6 误报驳回、9 wontfix 带理由——**误报率 >1/3，印证"subagent 报告必须逐条亲验"纪律**。
- 可维护性维度：TODO/FIXME 残留 0；docswriter 刚收口的 27 篇文档已覆盖注释/命名一致性；本轮行为变化已同步 6 篇文档（chat/conversation/messages/bootstrap/mcp/handler）。

## 遗留（已登记非本轮）

forgeSink ×2 同构（下沉受依赖环约束，落 envfix 侧再做）；broker.allowed 只增（量级 KB/月）；docswriter 留档的观测议题（agent tokens 持久化等）。
