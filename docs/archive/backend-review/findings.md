---
id: WRK-002
type: working
status: archived
owner: @weilin
created: 2026-06-11
reviewed: 2026-06-12
review-due: 2026-09-11
expires: 2026-09-11
landed-into: "docs/archive/backend-review/REPORT.md"
audience: [human, ai]
---

# findings —— Code Review 发现登记

> 一条 `CR-N`：维度 · 严重度（🔴 致命 / 🟡 应修 / 🟢 小 / 📋 产品决策）· 描述 · **验证过程** · 处置（已修 / 留档 / wontfix+理由）。

## R1 并发与竞态（亲审全部热点）

- **CR-1 🔴 已修** chat 队列自毁丢 task：runQueue 的 `Delete→final-drain` 与 enqueue 的 `Load→send` 交错，task 可落进无人再读的 channel → 回合永久 streaming。修：拆卸（标 dead+注销+终抽干）与投递（查 dead 再 send）统一在 q.mu 下原子化。验证：-race ×2 绿。
- **CR-2 🔴 已修** chat.Shutdown 卡 5 分钟：裸 wg.Wait 而 runQueue 无 stop 信号，只能等满 idle timer（注释还称"idle 已退出"）。修：stop channel + Shutdown 先 cancel 全部在跑回合；注释重述。
- **CR-3 🔴 已修** 硬崩溃 streaming 孤儿无对账：kill -9 后 pending/streaming 行永久转圈（flowrun 有 Recover、messages 没有）。修：`SweepNonTerminal` + boot `forEachWorkspace` 接线。
- **CR-4 🟡 已修** humanloop broker Resolve 锁外 send TOCTOU：可对已中止 run 报"已送达"（HTTP 200 但决定丢失）。修：锁内非阻塞投递（Request 的注销同锁，窗口闭合）。
- **CR-5 🟡 已修** handler Get 并发双 spawn：chat 并行工具批打同 handler → 两次秒级 spawn 一个被扔。修：per-handler 单飞。
- **CR-6 🟡 已修** mcp 并发连接泄漏：双击 Reconnect / 撞 Boot → 注册覆盖、输家 client+进程僵尸。修：注册时换出旧值并关闭（后写者赢=重置语义）。
- **🟢 wontfix**：broker.allowed 白名单只增不清（单用户内存量级 ~KB/月）；autotitle 在 Shutdown 期间无 cancel（utility 调用秒级+自带超时）；scheduler inflight 同 run 覆盖（record-once+guarded terminal 已防住正确性）。

## R2 产品正确性对照

- **CR-8 🔴 已修** 删对话不停在途生成：继续烧 LLM、对已删线程推流。修：conversation 加 `GenerationCanceler` 可选端口（后注入破环，与 RelationSyncer 同模式），Delete 先 Cancel。
- **CR-9 🟡 已修** Send 不验对话存在：发往已删/未知对话先落孤儿 user 回合、processTask 里才失败。修：Send 头部存在性闸（404 早退）。
- **📋 留档**：PD-1 workspace 删除零清理（自动化还在跑！）；PD-2 归档对话可 Send；PD-3 Edit 两步写事务性。
- **驳回嫌疑**：subagent 经 activate_skill(fork) 绕递归——Spawn 入口有 ctx SubagentID 闸（defense in depth），fork 也走 Spawn ✓；附件 id 无效——ToContentParts skip+warn 软降级 ✓。

## R3 错误路径面扫（subagent 报 12 条，亲验后）

- **真问题已留档**：Edit 两步写（→PD-3，三实体同源）。
- **误报驳回**：walk.go "nil map panic"（Go 读 nil map 安全——代码注释自己写着，subagent 没读）；computeReady nil deref（同性质）。
- **wontfix（惯例/自愈）**：relation diffSync 部分失败（声明终态语义下次全量自愈）；writeAtomic 临时文件清理吞错（best-effort 惯例）；orm rollback 吞错（业界惯例：失败仅在连接死/已提交）；autotitle/ensureEnv 的 best-effort 丢错（注释已声明）。

## R4 架构一致性面扫（subagent 报 5 条，亲验后）

- **CR-7 🟡 已修** toJSON ×10 副本（9 同构+1 error 版）：下沉 `toolapp.ToJSON`（带 %v fallback），10 包全改、删本地副本。
- **🟢 留档** buildSink ×2 同构（function/handler）：真实重复（仅注释措辞差异），但下沉 toolapp 会引 toolapp→loop 依赖环——若修需落 envfix 侧。低收益，暂留。
- **误报驳回**：llm StreamEvent.Signature（anthropic 产/loop 消费，活代码）；WorkflowReader 同名两接口（不同包各自声明窄端口 = Go DIP 惯例）。
- TODO/FIXME 残留：0（subagent 与我 grep 双确认）。

## R6 裁决实现批（用户裁决 2026-06-11：PD-1 A / PD-2 允许+自动解档 / PD-3 B）

- **CR-10 ✅ 已修（PD-1 A）** workspace 级联销毁：Reaper 端口后注入；reaper = wf.Kill 全量（摘监听+杀在途 run+inactive——对 inactive 幂等、连手动 run 收割）+ handler/mcp per-ws 停（新增 StopWorkspaceInstances / DisconnectWorkspace——Shutdown 是全局的不能用）+ 删 ws 文件树 + 删行。关键正确性：reaper 用 Detached(目标 wsID)——DELETE 请求可来自另一 workspace。
- **CR-11 ✅ 已修（PD-2）** Send 自动解档：conversationapp.Unarchive（薄包 Update）+ chat 端口扩展 + Send 接线（软失败 warn 不挡消息）。
- **CR-12 ✅ 已修（PD-3 B）** 版本写事务化：5 实体 store 复合事务方法 ×2（orm Transaction 扁平嵌套）、app 10 调用点、domain 接口。create 不再可能留无版本实体行；edit 不再可能留孤儿版本+旧指针。
