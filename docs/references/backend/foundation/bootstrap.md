---
id: DOC-034
type: reference
status: active
owner: @weilin
created: 2026-06-11
reviewed: 2026-06-14
review-due: 2026-09-14
audience: [human, ai]
---

# bootstrap —— composition root

## 1. 定位 + 心智模型

**唯一**允许横跨所有 app/infra 包 import 的地方（无人 import 它 → 无依赖环；`cmd/server/main.go` 是薄壳）。`Build` 把 SQLite + 全部 store + infra 单例（加密/LLM factory/三条流 Bus）+ **28 个 app Service**（按依赖 Tier 构造）+ 跨服务适配器 + 工具集 + HTTP router 焊成一个 `*App`。

**关键装配模式**：
- **后注入破环**（SetRelationSyncer / SetInvokeDeps / SetExecutionPorts / SetLifecycleReconciler…）：构造序无环、能力后接。
- **toolsetHolder 破环**：subagent 读工具集要等 Subagent 工具追加、而那又要 subagent Service——holder 懒读破此环。
- **窄接口适配**（dispatch.go 四执行端口 / sensor.go invoker / runnerAdapter / RefResolver / KnowledgeProvider）：调度器与实体互不知具体类型。

## 2. 生命周期

- **settings**：`app/settings` 在装配前读 `<dataDir>/settings.json`（**三段** `limits`/`network`/`retention`；缺文件=纯默认、坏文件=boot 失败）——limits 装成 `limits.Current()` 活动源、PATCH /limits 持久化 + 热换；network 段 boot 与 PATCH 时应用代理 env；retention 段（工单⑬）由 retention 清理循环每趟现读、故 PATCH 天然热生效，PATCH 另经 `SetOnRetentionChanged` 钩子踢一趟即时清理。**persist 三段整体写**——修补任一段绝不丢其余两段。
- **日志**：zap 双 sink——stderr 控制台（dev 彩色 / 否则 JSON，级别 dev=DEBUG / 否则 INFO）+ `<dataDir>/logs/anselm.log` 轮转 JSON 文件（10MB×3、28 天、gzip；`infra/logger`）——桌面报障 = 发这一个文件。
- **Serve**：Boot → ListenAndServe → 信号 → **三步优雅关停**（① 先 cancel base 请求 ctx——三条常驻 SSE 永不 idle，不先断它们 http.Shutdown 会干等满 grace 窗 ② http.Shutdown 瞬间排空 ③ App.Shutdown 停后台、最后关 DB checkpoint WAL）。**关停预算格（T8，WRK-070）**：app 侧给后端 **8s** SIGTERM 宽限（前端 `backend_controller.dart` `shutdownGrace`），超过升级 SIGKILL = 有序关停全部作废（孤儿子进程 + 跳过 WAL checkpoint）——故 `shutdownGrace`（**6s**，罩 ctx 有界各步）与不认 ctx 的串行地板 `drainShutdownGrace`（**2s**）+ 2×`shell.WaitDelay`（**2s**，StopPool 与 chat.Shutdown 各等一个被取消 Bash 的管道地板）都必须嵌进 8s 之内；`shutdown_budget_test.go` golden 测试解析 app 侧常量、钉死全部不等式。
- **Boot**：sandbox bootstrap（失败=degraded）→ **双崩溃回收网**（sandbox `RestoreOrCleanupOnBoot` 杀 running_pid 清单残留 + shell `ReapStaleOnBoot` 杀 `<dataDir>/shellpids/<bsh_id>.pid` 清单记录的 run_in_background 孤儿**组**——`Manager.Stop()` 只在优雅 Shutdown 可达、内存注册表随崩溃一起死，pid 清单是崩溃半唯一的网（T3，WRK-070）；记录=spawn 时自己子进程的 pid（组长，`Setpgid`）、每条退出路径都删（整组死时的 noteExited / KillShell / Stop / boot 回收），boot 侧负 pgid 整组杀，Getpgid 确证「存活非组长」= pid 被无辜进程复用则放过）→ trigger.Start → search.Start（索引 worker + 逐 ws 对账自愈，绝不阻塞 boot）→ scheduler.Recover（跨 ws 重走 running run）→ **`forEachWorkspace`**（后台播种铁律，[引擎文档](scheduler-flowrun.md)#5；workspace 种子盖在**调用方 ctx** 上而非另起 Background——每个调用方都是后台循环、其 ctx **就是**关停信号，盖 Background 会把信号扔掉、让循环的关停等待与 `SweepRunRetention` 的批间 `ctx.Err()` 检查读一个永不可取消的 ctx。Boot 传的是 Background，故不受影响）逐 ws：handler/mcp 预热 + chat.SweepOrphans（崩溃孤儿回合对账）+ workflow.ReattachActive + **`trigger.SweepMisfires`**（工单⑨：把停机期间到期的 cron 刻度入账；**严格在 ReattachActive 之后**——sweep 读监听表才知道谁在监听，表空则静默什么都不记） + **freetier.EnsureForWorkspace**（回填内置免费档受管 key，幂等 best-effort）→ 启 **5s drain ticker**（逐 ws `DrainFirings`）+ **独立 5s timeout ticker**（逐 ws `CheckTimeouts`——F174 与 drain 解耦，满载的 Advance 池绝不饿死审批超时结算）+ **1min misfire ticker**（逐 ws `SweepMisfires`：笔记本睡一小时醒来、进程还活着的 misfire 与关机一模一样，没有重启，只有正在跑的 sweep 会发现） + **6h run 历史保留 ticker**（工单⑬：逐 ws `SweepRunRetention`，按 `retention` 段的线算 cutoff；线为 `0`=永久即碰都不碰 DB。boot **不内联跑**、而是预置一次 buffered kick 让循环自己的 goroutine 立刻跑——长积压后的首趟可清数千 run，内联会把开始服务拖慢那么久；`PATCH /retention` 经钩子同样踢这个 channel，非阻塞发送使并发的多次踢合并成一次；**一趟清理真删了行后调一次 `infra/db.ReclaimFreePages` 把腾出的页还给文件系统**——删行本身在磁盘上一字节不还，库跑在 `auto_vacuum=INCREMENTAL` + 越闸 `incremental_vacuum`，T4/WRK-070，机制见 [platform-pkgs.md](platform-pkgs.md#infradb)）。免费档 provisioner 同时经 **workspace.SetOnCreated** 钩子覆盖 boot 后新建的 ws（异步 best-effort，首启承载路径——全新 data dir 无 ws、Boot 循环不覆盖）。
- **Shutdown 逆序**：停 ticker（drain/timeout/misfire/**retention** 各自 stop 先全发、再逐个等 done——并发关停不串行啃 grace 预算；retention 循环**删行**，掉队者撞 db.Close 是这些等待所防危险中最锋利的一种，它批短且批间查 ctx，故在下个批边界返回）→ trigger → chat 队列 → search worker → mcp/handler 常驻进程 → sandbox 兜杀残留 handle → shell `Manager.Stop()` 收割 run_in_background 组并删 pid 清单记录（R1 优雅半；崩溃半=Boot 的 `ReapStaleOnBoot`）→ flush 日志 → 关 DB。每步 best-effort（一个卡死子系统不拖垮其余）。

## 3. 契约（引用）

守护测试 `background_ctx_test.go`（裸 ctx 必败/播种必通）。码 `UNTRIAGEABLE_EXECUTION`（aispawn triage 适配在此实现）。`Config{DataDir("" = 内存 DB 测试), Addr, Fingerprint, Dev}`；Fingerprint 空（服务正常路径）时 newEncryptor 解析真实机器指纹（`MachineFingerprint()`），平台拿不到才回退 `anselm-local:<dataDir>` 种子。
