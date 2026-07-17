---
id: WRK-070
type: working
status: active
owner: @weilin
created: 2026-07-17
reviewed: 2026-07-17
review-due: 2026-10-15
audience: [human, ai]
landed-into:
---

# 泄漏猎战役 0717 —— 进程/内存/磁盘/CPU 资源正确性(实测定罪)

> 起因(用户实机取证,非推断):Mac 发烫卡顿,Activity Monitor 实拍 **31 个 llama-server / 16G 内存吃掉 12.23G**;30/31 为孤儿(PPID=1),来自 22 个 testend 测试。加一个 anselm-server 自身成孤儿(PPID=1,跑 3h)。
> 本战役是 [`systems-correctness.md`](systems-correctness.md)(WRK-030,R1–R24)的**续篇 + 方法论审判**:R2 一个月前把同一个 bug 标 ✅ FIXED,一个月后同症状从 7 个涨到 31 个。本轮换方法论:**实测定罪,读码只用来解释实测到的现象。**

---

## 0. 方法论 —— 实测定罪(本战役的全部立身之本)

**没有真机前后计数的「发现」,不是发现。静态推断只能提出假设,不能定罪。**

### R2 复发的铁证(为什么必须换方法)

`systems-correctness.md` 的 **R2**(2026-06-19,起因写着「长 dev 会话漏 7 个 2GB llama-server」,与本轮症状一模一样)标着 ✅ FIXED。它当时的复核结论逐字写着 **"Verified against the code"** —— 对着代码验、不是对着机器验。结果:代码上三层防护(`search.Close()` + `reapStalePID` pidfile 回收 + 进程组机制)**看着都在,三层全失守**,纯读码判 SAFE。一个月后同一症状回来。

R2 的修法(下次 boot 按 pidfile 回收)**对真实用户成立**(数据目录稳定),但它自己的触发描述里白纸黑字写着 test runs / `kill -9` / crashes / IDE restart —— 而 **testend 每测一个全新临时数据目录,那条回收路径结构性够不到**。它修好了诊断书里排第二的场景,漏掉了排第一的。

> **方法论教训(一,继承 R22)**:把某物列为**威胁模型的一部分**,就等于把它排除出了**审查对象** —— 盲区不在被扫的代码里,在扫描面的定义里。
> **方法论教训(二,继承 R23)**:静态扫描对「状态相关成本」结构性失明 —— `cp -R $cache` 这行源码不含量级信息,它多贵取决于运行时状态。只有真机 + 特定状态才现形。
> **方法论教训(三,本轮新增)**:**ground-truth 真但 root-cause 常假**。多条 finding 的症状数字铁证如山,但第一版根因表述是错的(见域1 C2「无 ctx 无超时」实为「取消送到了但 waitDelay 兜底」)。对抗复审逐条要求「重跑 + 对照臂」才反转。

### 仪器也会撒谎(R2 教训在量尺上反复复发,本轮抓到 ≥13 次)

本战役最硬的自证:参与者带着「知道这个坑」的先验,仍在量测仪器上一次次踩同一失效模式 —— **仪器报告了自己没做成的事**:

| 仪器事故 | 失效 | 后果 |
|---|---|---|
| `cp-sampler.sh` `pgrep -fc` | macOS pgrep 无 `-c` 旗标 → 恒 0 | 977 样本捏造「全程无 llama-server」 |
| `dense_sampler v1` lstart 解析 | `split(None,3)` 遇 5-token lstart 抛错 continue | 进程表恒空 → 自信报「全机零 llama」 |
| leak 分析 `timeout` | macOS 无 `timeout` → 命令没跑 | `grep -c` 报 0 → 差点写「composer 干净」 |
| S1 脚本 200 POST 全 400 | 字段 `name` 非 `title` | 照打「200 docs created」→ DB=0 揭穿 |
| WAL 未 checkpoint | VACUUM 前不 checkpoint | 报「收回 0.00MB」→ 差点反转域4 #1 |
| zsh `no matches found` | glob 不匹配 → 整条 `rm` 未执行 | 下句照打「已删」→ 逐项复核揪出 |
| `setsid(1)` macOS 不存在 | ARM 什么都没干 | 报 0.00s → 差点反转域1 C2 |

> **对策(已固化进本轮全部量尺)**:任何仪器**先自证再取信** —— 植入正/负对照、`samples=0` 拒绝出数、解析数≠header 数拒绝出数、`listener_pid==自己` 才算数、建完 DB 必须有行否则拒绝出数。逐项复核而非信 echo。

---

## 1. 量尺 —— 怎么复现本轮所有量测

产物全在 `.leak-lab/`(已 `.gitignore:240`,零污染仓库)。**归因铁律**:机器上有并行 agent(Scheduler WRK-069 构建/测试 + R22 修复者),故**按身份归因(锚在自己 make/root pid 的窄子树 + `(pid,lstart)` 防 PID 复用),绝不用裸全局计数**。并行 agent 与本 agent 共用同一祖先 shell(Claude Code harness)⇒ 祖先链归因失效,只有窄子树是有效键。

| 量测面 | 工具(`.leak-lab/`) | 真值口径 |
|---|---|---|
| 进程/端口/fd 快照三拍 | `snap.sh` + `diff.sh --tag` | before / after / **settle(+9s,让 cp 相冤案自灭)** |
| 4Hz 密采样整棵子树 | `dense_sampler.py`(带自检)· `fe_sampler.py`(补 flutter 六形态) | 快照会漏短命子进程,故必采 |
| goroutine 逐栈归因 | `gor.py`(解析数≠header 拒绝出数) | pprof `/debug/pprof/goroutine?debug=1`(`ANSELM_DEV=1`) |
| CPU 空转真值 | `soak_sampler.py` | **累计 CPU 时间差 ÷ 墙钟**(不信 `ps %cpu` 的 decaying average) |
| Dart 侧泄漏 | `leak_tracker`(flutter_test 内建) | **只信确定性 `notDisposed`**,不信 `notGCed`(实验性,依赖 GC 时序) |
| C1 死锁 A/B | `txlab/main.go` | Transaction 函数体**逐字复制**自产品,只改 ctx 一个变量 |
| app 退出 harness | `quitlab/lib/main.dart` | `ProviderScope`+`ref.onDispose`+`stop()` **逐字复刻** runtime.dart |
| 崩溃孤儿复现 | `d1-crash.sh`(A 崩溃/B 下次 boot/C 优雅) | marker-in-argv 归因 |

---

## 2. 实测名单(按**烧机器程度**排,每条附站得住的数字)

> 排序口径 = 该缺陷在真机上实测/外推的资源消耗(CPU 热 + 内存 + 磁盘 + 累积无界性)。**T7 是唯一例外**:它不「烧」,它**砖化**——但它喂养 T2/T3 的孤儿(用户强杀重启),故收在名单里。

### T1 [HIGH·两侧] AnStatusDot 呼吸循环 → 整个 app 120fps 永久空转,烧 24.92% CPU 【✅ 已修 2026-07-17】

- **症状(A/B 因果实测)**:原样 HEAD 空转 215s → 烧 53.64s CPU → **AVG 24.92%**,33,833 帧全 120fps。只把那一行 `.repeat()` 钉死 → **0.0523%**,**降 476×**,235s 连 60 帧都凑不够。同屏控制(BEFORE/AFTER 同一屏 Scheduler Overview、4 个蓝点仍渲染)排除「AFTER 恰好落在无 run 页面」的假因。
- **根因**:`frontend/lib/core/ui/an_status_dot.dart:70` —— `status==AnStatus.run && !reduced` ⇒ `_c.repeat()` 永不停。仓里**已有** `core/perf/pulse_clock.dart`(共享单 Ticker + `idleAfter:6s` 自动静息),其文档逐字预言了 24.92%,而 AnStatusDot 正是它为之而建的类却自走 `.repeat()`。全仓 4 个自走 `.repeat()`(status_dot/skeleton/shimmer_text/graph_canvas)vs 仅 2 个 PulseClock 采纳者。
- **触发**:屏上有任何 `run` 态的东西可见(scheduler 有 run 在跑 / chat 生成中 = **产品正常态**)。1 个点就够 120fps。
- **累积**:非累积,是**稳态热**。一个跑 30min 的 workflow = 30min 25% CPU,哪怕用户没看。这是全战役**唯一用户能感觉到的空转热源**,直接对应用户报告的「发烫」。
- **修法(已落)**:①`AnStatusDot` run 面弃自持 `AnimationController.repeat()`,改骑共享 `PulseClock`——活 run 点仅在**到场 + 每次 rebuild 触达**(流帧重建所在行=心跳)时 `poke()`,呼吸跟随真实活动、app 安静 `idleAfter`(6s) 后钟停、点冻回 t=0 实心姿态(满足消费者契约:t=0 即静态实心点)。②`PulseClock` 的驱动器由 vsync `Ticker` 换成**低频周期 `Timer`**(`AnMotion.pulseCadence`=33ms≈30fps)——**这是根治**:Flutter 无官方帧率上限(flutter/flutter#159797),活 Ticker 逼引擎按屏幕刷新率产整帧;~2s 呼吸在 30fps 阶梯不可察,视觉观感不变。③**三重不呼吸门**:非 run / `reducedOrAssistive`(reduced 双闸,批7 立法)/ 离屏(`TickerMode.valuesOf(context).enabled`,补 vsync 控制器原本从 TickerMode 免费得到的离屏自停)一律静态、不订阅不 poke。**纠正 Phase 2/常见建议**:`RepaintBoundary`(仅活 run 面带,C-017)**早就在、没救** —— 重绘隔离 ≠ 帧调度;救下 476× 的是让钟**停**。
- **实测定罪(WRK-070 同款 A/B/C,累计 CPU 时间差÷墙钟,机器非绝对安静故绝对值偏高但三臂同机可比;profile 构建、4 个真 run 点、180s soak、15s warmup)**:
  - **BEFORE**(修前实现逐字复刻,自持 `.repeat()`)= **AVG 23.06%**,180s 烧 41.5s CPU,19,505 帧(≈108fps 稳态)——复现 24.92% 同量级。
  - **AFTER**(修后,到场后无新活动,超 idleAfter 钟停)= **AVG 0.0333%**,180s 仅 0.06s CPU,soak 窗内 frames 几乎不再增(184→187,6s 呼吸落在 warmup 内)——**降 ~692×**,达 WRK-070 预言的 0.05% 量级。
  - **ACTIVE**(修后 + 每秒一次整窗 `setState`=模拟 flowrun tick 心跳,持续呼吸的诚实**上界**)= **AVG 9.88%**,180s 烧 17.78s CPU,5467 帧=**稳态 30fps**(证节拍生效:非活 run 曾 108fps)。这是**悲观上界**——harness 每秒重建整个窗口比真实「单行随 tick 重建」重得多,且真实场景下这些 rebuild 本就因数据在流而发生、呼吸点的增量成本近零;而**发烫本体=稳态热**由 REST 态(AFTER 0.0333%)治愈,呼吸只是数据在流时的瞬态。30fps 为共享钟对最快消费者(`AnRadarSweep` 旋转弧,空间频率高于 alpha 呼吸)的安全下限。
- **净判决**:稳态热 **23.06% → 0.0333%(降 ~692×)**,直接消灭用户报告的「发烫」唯一前端空转热源;呼吸态 23.06% → 9.88%(30fps 封顶)、且真实增量远低于此。视觉观感不变(呼吸周期 1.8s、30fps 阶梯不可察)。
- **守卫(已落)**:①`test/core/perf/pulse_clock_test.dart` 加「1s@33ms 通知 25–35 次(≈30fps,非 vsync 60–120)」T1 节拍断言;②`test/core/ui/an_status_dot_pulse_test.dart` 五测锁死——静态点 `hasScheduledFrame==false`(引擎全睡)/ run 点超 idleAfter 归静息且零请求 / rebuild 触达顺延静息窗 / reduced 与离屏双闸不订阅不 poke。`fe-verify` 全绿(除上游正改的 scheduler 区 4 处预期红,与本改无关)。

### T2 [CRITICAL·两侧] app 正常退出**从不**杀 sidecar → 野生孤儿后端无界累积 —— **✅ 已修(0717,双保险)**

> **修法落地**(与下文「修法」栏的方案一致,仅前端半改走官方 Dart 路由而非 Swift):
> ①**干净退出半**:`main.dart` 挂 `AppLifecycleListener.onExitRequested` → `stopBackendOnExit`(⌘Q/关窗时 FlutterAppDelegate 把 `applicationShouldTerminate` 路由进框架,优雅 SIGTERM sidecar、等其退出、再放行 app 退出;绝不 cancel——stop() 自带 SIGTERM→8s→SIGKILL 升级,退出永远可靠)。
> ②**崩溃半**:后端 `cmd/server` **stdin 死人开关**(`ANSELM_PARENT_WATCH=1` 时读 stdin 至 EOF = 父死,汇入与 SIGTERM 同一 `NotifyContext` 取消 → 同一有序关停);launcher 恒设该 env 并终生握子进程 stdin——父亲以任何形态退出管道必 EOF。
> ③**配套**:sidecar 模式 `signal.Ignore(SIGPIPE)`——没有它死人开关等于没装:父死时 stderr 管道同断,有序关停自己写的第一条日志就会被 fd-2 SIGPIPE 半路杀掉(**实测抓获**:修①②后路 2 sidecar 死了但日志零关停行;加③后两行俱在)。
> **三路退出矩阵真机验收(新二进制,身份经编译/启动时间戳核对)**:⌘Q / `kill -TERM` GUI / `kill -9` GUI → 三路 sidecar 全数落幕,日志三次俱见 `"shutting down gracefully"` + `"sandbox shutdown: all handles killed"`(= kill-set 真跑),终局清点 GUI/server/llama = **0/0/0**。llama 环节为链式证明:kill-set 行 + 当日活标本(SIGTERM 优雅关停带走 1GB llama 子进程,leak-lab 7329→10496)。
> 单测:`cmd/server/main_test.go`(死人开关「沉默活管道绝不触发/EOF 必触发」)+ `backend_controller_test.dart`(spawn 恒带 `ANSELM_PARENT_WATCH=1`;`stopBackendOnExit` 先 SIGTERM 等退出再放行)。文档:CLAUDE.md 进程模型节重述 + `api.md` env 登记 + `frontend/architecture.md` process 行。

- **症状(实测)**:开工第一条 `ps` 撞见**基线 4 个 anselm-server,PPID=1,各占一端口,存活 5h+**(peer 正常开关 app 4 次的残留)。忠实 harness 三种退出方式 **3/3 全漏**:osascript quit(=Cmd-Q)/kill -TERM app → app 真死、onDispose ❌、stop() ❌、子进程无 SIGTERM、**PPID=1 孤儿存活**。先跑正对照(显式 `stop()` → 子进程收 `GOT_SIGTERM` → 死 ✅)证尺子有效。
- **爆炸半径(实测非推断)**:孤儿 sidecar 是**功能完好的后端** —— health=200、`POST /documents` rc=201 **真写进用户 DB**、能自拉 **451MB llama-server**。用户以为关掉的 app,其孤儿仍在写库 + 吃 451MB + 双后端抢同一 SQLite。
- **根因**:`frontend/macos/Runner/AppDelegate.swift:6` 只有 `applicationShouldTerminateAfterLastWindowClosed`,**无 `applicationShouldTerminate` 钩子**;`stop()` 全仓仅 2 个调用点(`runtime.dart:72` 的 `ref.onDispose` + `factory_reset.dart:24`),而 macOS AppKit 退出直接终止进程、Flutter **不拆 widget 树 ⇒ onDispose 永不触发**;后端 `main.go` 零 parent-death / stdin-EOF watch。
- **触发**:每一次正常关 app。**累积**:每次开关攒 ≥1 个满血后端(+ 潜在 451MB llama),**无界**。这是原始 12GB 事件的 product-side 同形。
- **修法**:`AppDelegate` 加 `applicationShouldTerminate` → 同步 `stop()`;**兜底**后端加 stdin-EOF/getppid watch(SIGKILL app 时前端补丁也救不了 —— 那才是真正需要 parent-death watch 的场景)。域1 C2 的 8s<10s 常量倒挂是它的下游,先修上游。
- **守卫**:harness 断言「osascript quit app → 子进程在 N 秒内死」(`quitlab` 现成)。

### T3 [HIGH·两侧] background bash 崩溃路径零回收网 → 永久孤儿、无界累积 —— **✅ 已修(0717,pidfile 清单 + boot 组杀)**

> **修法落地**(与下文「修法」栏一致——照 llama pidfile + sandbox boot 扫描先例接线,零发明):
> ①**持久清单**:`ProcessManager` 得 `pidDir`(装配传 `<dataDir>/shellpids/`),`Register` 时把**自己刚 spawn 的直接子进程** pid 落 `<bsh_id>.pid`(身份写入时百分百确定,绝非名字/扫描匹配);每条退出路径都删记录——自然退出且**整组死透**(`noteExited` 探组)/ KillShell / 优雅 Stop / boot 回收,pid 复用窗口收窄到「组活着时崩溃」= llama 同款被接受窗口。孙进程还撑着组时(sh -c 'daemon &')记录**必须留**——POSIX 保留有存活成员的 pgid,记录仍可证明是我们的。
> ②**boot 网**:`Boot` 在 sandbox `RestoreOrCleanupOnBoot` 之后调 `shellMgr.ReapStaleOnBoot`(build.go),扫清单逐条**负 pgid 整组 SIGKILL**(与 killSurvivor/killProcessTree 同构),记录无论生死一律删。
> ③**别杀错人**:唯一豁免闸=`Getpgid` **成功且 pgid≠pid**(确证存活非组长=pid 被无辜复用,我们的子进程恒为组长)→ 放过;其余(ESRCH=组长被收尸或 macOS 僵尸组长——**真进程探针实测** getpgid 拒僵尸而 signal 0 仍见其在,首版据此差点放跑整组)一律只信**组探针** `kill(-pid,0)`——组活=pgid 被 POSIX 保留=必是我们 spawn 的组。机器重启后 pid 洗牌的窗口与 llama/sandbox 先例同样接受(单用户本机,非组长即洗脱)。
> **崩溃路径真机验收(真二进制,非单测)**:staged 崩溃现场(A 形 `sleep 600` 组长 + B 形 `sh -c 'sleep 733&×3;wait'` 整组,5 进程 2 组 ALIVE)→ 真 `cmd/server` 二进制冷 boot → **5/5 全 DEAD**,日志两行 `shell boot scan: killed stale background process group`(bsh_replaya/b)+ `scanned:2 killed:2`,清单目录清空。台账原判「下次真 boot 跑完孤儿仍 ALIVE」→ 翻转为 DEAD。
> 单测(真进程真 kill,零 mock):`shell/reap_unix_test.go` 5 测——worker 组崩溃回收(经真 Bash 工具 bg spawn)/ 短命作业整组死即删记录 / daemon 形记录保留+无组长回收 / **僵尸组长回归**(钉死 getpgid-ESRCH 误判洞)/ **无辜非组长复用 pid 必须放过**;`bootstrap/reap_unix_test.go` 加 `TestBoot_ReapsBackgroundShellSurvivorsAcrossCrash`(双 Build 同 DataDir,app1 热丢弃模拟崩溃,app2 真 Boot 杀 survivor——现有 R1 测试只测优雅半,此测钉住崩溃半接线)。文档:`foundation/bootstrap.md` Boot/Shutdown 两行同步。**选型记档**:pidfile 而非 DB 行——bg 进程是机器域(shell 包无 workspace 概念,D2 无从适用)、shell 包契约明言无 store/DDL、bg bash 无既有 DB 实体可挂列(sandbox running_pid 是 env 表上的列),R2 修法原文已裁「非 env owner 用轻量 pid 清单更简」。

- **症状(实测 A/B/C)**:真 `Bash` 工具跑 `sleep 600` → SIGKILL 后端 → 存活 PPID=1;**下次真 boot 跑完孤儿仍 ALIVE**;优雅 `Manager.Stop()` → DEAD(R1 修法确实活)。带 worker 作业(`sleep 733 & ×3 & wait` = `npm run dev` 形)→ **1 次崩溃 = 4 存活 / 1 真孤儿**,整组幸存。
- **根因**:`backend/internal/app/tool/shell/manager.go:105` `procs map[string]*BgProcess` = **纯内存零持久化**(实测 `find -name '*.pid'` 空、DB 无 shell 表);boot 网 `restore.go:18` 只扫 `ListEnvsWithRunningPID`(sandbox env),background bash 从不写 env 行 ⇒ **网没有输入**。与 R2「网够不着」不同类 —— 什么目录都救不了它。全平台成立(shell 的 `proc_unix.go` 连 Linux 都不设 Pdeathsig)。
- **触发**:任何非优雅退出 + 有后台作业在跑(SIGKILL / panic / OOM / **app 8s 逾时升级**)。**累积**:每次崩溃 ≥1,永不回收,且 background bash 每作业独立 `bsh_` id、**无封顶**(对比 llama pidfile 单文件封顶 1)。
- **修法**:照 llama(pidfile)/sandbox(`running_pid`)先例把 bg pid 落持久清单,boot 时按负 pgid 收整组(`killSurvivor` 现成)。**不必发明,只需接线** —— 机制在 llama 与 sandbox 上都已建好。
- **守卫**:crash 路径单测 —— spawn bg → SIGKILL server → 新 boot → 断言 pid 已死(现有 `reap_unix_test.go` **只测优雅路径**)。

### T4 [HIGH·product] DB 棘轮:retention 删真实历史,磁盘一字节不还 —— **✅ 已修(0717,auto_vacuum=INCREMENTAL + 保留清理后回收;调研先行/真库实测/驱动坑当场抓获)**

> **修法落地**（与下文「修法」栏一致,但**先调研再动手**、每步真库实测定罪——原则 #8;新增 `infra/db/vacuum.go` + `vacuum_test.go`,接线 `openDB`/`sweepRetention`,零改 `pkg/orm/db.go`〔T7 领地,不冲突〕、`cmd/server`、`frontend/`）：
> **① 常态模式 = `auto_vacuum=INCREMENTAL`**（**非** `FULL`）：`FULL` 每次 commit 都回收 = 高频单写者 app 的常驻每写开销;`INCREMENTAL` 只在指针图记下腾空的页、显式索要时才回收——恰在保留清理后、离开请求路径。SQLite 官方推荐的「按计划回收」模式。
> **② 新库天生 INCREMENTAL**（`buildDSN` 把 `auto_vacuum` 排 DSN **最前**、在 `journal_mode(WAL)` 初始化文件头之前）——**实测定死顺序**：`auto_vacuum` 在 WAL 之前 → mode=2 ✓;在 WAL 之后（现有风格）→ mode=0 ✗;**显式 `Exec` 一律 mode=0 ✗**（DSN 的 WAL 已先初始化文件头、锁死 auto_vacuum）。glebarez 驱动按 DSN 顺序应用 `_pragma`,故唯一可靠姿势 = DSN 首位。
> **③ mode=0 库升级 = 用户主动 `Compact`**（**boot 自动迁移已删——用户 0717 拍板决策 (a)**：项目未发版、不存在「本次改动之前的安装」,那个 `openDB` 里自动 `VACUUM` mode=0 旧库的逻辑是给不存在的老用户写的兼容代码,违反 #7「零历史包袱」）。被删的「设 `INCREMENTAL` + 全量 `VACUUM` 回收」能力**不浪费,搬进用户主动点的 `Compact` 端点**（`infra/db.Compact`，`app/storage.Service` → `POST /storage:compact`）：用户点一次「压缩数据库」,他的库当场升级到 `INCREMENTAL` + 把死空间全还回去,而且是知情、主动（`VACUUM` 锁库几秒）、非开机偷跑——这同时给了用户当前那个 mode=0 dogfood 库一条出路。**为什么 `Compact` 用 `VACUUM` 而非 `incremental_vacuum`**：`VACUUM` 对**任何** mode 都回收（含 mode=0）且顺带升级 mode;`incremental_vacuum` 只在已是 `INCREMENTAL` 的库上工作。手动按钮=知情等待=`VACUUM` 合适;自动 retention 后=轻量=`incremental_vacuum`（`ReclaimFreePages` 不动）。实测（`vacuum_test.go`）:mode=0 库 `Compact` → mode=2、reclaim>0、跨重开持久、第二次幂等（reclaim 全部死空间但 migrated=false）、零丢行。失败（磁盘满、无 `VACUUM` 临时空间）返错给调用方 → `app/storage` 映射 `STORAGE_COMPACT_FAILED`、存储面板诚实上报（库不动、可重试）。
> **④ 稳态回收**（`ReclaimFreePages`,`sweepRetention` 在一趟清理**真删了行**后调**一次**,DB 全局非逐 ws）：`wal_checkpoint(TRUNCATE)`（删落 WAL、freelist/incremental_vacuum 作用于主文件,不 checkpoint 则回收到零 = 台账仪器事故 #5 亲证）→ **回收闸**（死空间 ≥25% 文件比例 **或** ≥128MiB 才回收——freelist 是**棘轮非泄漏**,稳态新 run 复用腾出的页,每 6h 都回收只空折腾;日常 churn 两闸皆不过、**收紧保留线**才过,正是催生本修复的场景）→ drain `incremental_vacuum` → 再 `wal_checkpoint(TRUNCATE)` 落盘。**逐页查 ctx**,关停在页边界可打断（同保留批循环,不让掉队者攥单连接过关停宽限）。
> **⑤ 头号陷阱当场抓获**（今晚失败模式的活标本）：`Exec` 跑 `PRAGMA incremental_vacuum`(任何参数形式)**只回收 1 页**——modernc/glebarez 驱动把它当单语句、不 drain 逐页结果行。**实测**:`Exec` 无论 no-arg/`(0)`/`(1000000)` 都只 freed 1 页;`Query`+遍历 `rows.Next()` → freed 全部 30069 页 = 123.2MB。若用 `Exec`,「修复」= 回收一页的空头支票、自洽而错。改用 `Query`+drain。
> **⑥ D1 裁定:不是物理删例外、无需新立法**——`VACUUM`/`incremental_vacuum` 都不删任何**逻辑行**,只把 `PurgeTerminalRunsBefore`(例外②,已立法)**已经腾空**的页还给 OS。纯空间回收 ≠ 物理删。文档:`database.md` flowrun 节 + `foundation/platform-pkgs.md`(infra/db 唯一事实源,三件=`ReclaimFreePages`/`Compact`/`Stat`)+ `scheduler-flowrun.md` §4.2 + `api.md`(两新端点)+ `error-codes.md`(`STORAGE_COMPACT_FAILED`)+ 前端 `contract.md`/`features/settings.md` 同步。
> **守卫**:`infra/db/vacuum_test.go` 真落盘库——`ReclaimFreePages` 主测〔全新库天生 mode=2 → 删 80% → `os.Stat` 断言**光删不缩**(棘轮/bug) → 回收后文件**真缩**且行完好〕+ 回收闸挡住日常 churn(删 5% → reclaim=0、文件不动)+ **`Compact`** mode=0 库升级〔→mode=2、reclaim>0、持久、幂等[第二次 migrated=false]、零丢行〕+ `Compact` 已 INCREMENTAL 库无闸仍缩 + **`Stat`** 报告死空间且压缩后回落;`app/storage/storage_test.go`(Service 映射线缆结构);前端 `s5_storage_limits_test.dart`(死空间足迹渲染 / 压缩忙态「压缩中…」+转圈 / 回收后重取缩小 / 失败诚实 toast)。
> **产品决策已拍板并实现(用户 0717,两决策合流成一波)**:**(a) 删掉 boot 自动迁移**(用户原话「看不懂。我们还没发版呢。」——项目未发版、不存在此改动前的安装,`EnsureIncrementalAutoVacuum` 是给不存在的老用户写的兼容代码、违反 #7,**已删**)+ **(b) 加「压缩数据库」按钮 + 死空间显示**(用户原话「做:压缩按钮 + 死空间显示」)。两件合流:被删的迁移能力搬进用户主动的 `Compact`(见 ③)。

- **症状(实测复核台账,数字站得住)**:台账 243.6MB@129,600 runs 我按比例缩量在真库复现——全新 mode=2 库装 15000 行×3KB = **61.7MB**,删 80% 行 + `wal_checkpoint(TRUNCATE)` 后文件 **61,665,280 → 61,665,280 逐字节不变**(棘轮证实);`ReclaimFreePages` → **12.3MB**,归还 **49.3MB**、3000 行完好。全量 `VACUUM` 成本实测 **405ms@257MB**(印证台账 0.59s@243MB 同量级)。台账核心数字**成立**。
- **根因**:`backend/internal/infra/db/db.go:54-57` 只设 WAL/busy_timeout/foreign_keys/synchronous,**无 auto_vacuum**(实测真实用户库 `PRAGMA auto_vacuum=0`);`grep -i vacuum backend/`(去测试)=**0 命中**,产品从不 VACUUM。
- **诚实边界**:这是**棘轮、非无界泄漏**(实测 freelist 会被复用,上界=历史最高水位)。**真正的用户可感后果**:`storage_panel` 把「Run history retention」摆在存储面板,90d→7d 想腾磁盘 **实测一个字节都不掉** —— 产品承诺与物理事实不符。
- **触发**:默认即触发(`DefaultRunRetentionDays=90`),任何跑过量 run 又被清的用户。
- **修法(最终形态)**:①新库天生 `auto_vacuum=INCREMENTAL`(DSN 首位)+ `sweepRetention` 删行后 `ReclaimFreePages`(越闸 `incremental_vacuum`,`Query`-drain);②**无 boot 自动迁移**(决策 a 删);③mode=0 库靠用户主动 `Compact`(全量 `VACUUM` 升级+回收全部死空间)+ `Stat` 诚实显示死空间(决策 b)。三件都在 `infra/db/vacuum.go`,经 `app/storage.Service` → `GET /storage-stat`·`POST /storage:compact` 上前端存储面板。
- **守卫**:见上「守卫」栏(后端 `vacuum_test.go`/`storage_test.go` + 前端 `s5_storage_limits_test.dart`)。
- **产品决策已拍板并实现**:见上「产品决策已拍板并实现」栏——(a) 删 boot 自动迁移 + (b) 加压缩按钮 + 死空间显示,两件合流成一波已落。

### T5 [MEDIUM·dev] frontend build/test 缓存无界累积 —— **✅ 已修(0717,frontend Makefile `clean` 目标 + 实清 15.6GB)**

> **实测复核(先量再修,数字站得住)**:台账定位**全对**——`du -sh` 实测 `frontend/build/test_cache` = **6.9GB / 99 个 `.cache.dill.track.dill`**,mtime 从 **2026-06-24 到 07-17 跨 23 天**(06-24 的 11 个文件今仍在,按日期计数逐日累积、旧的从不驱逐)⇒ ≈300MB/天。同源第二坨 `.dart_tool/flutter_build` = **5.9GB / 32 个内容寻址 hash 目录**(每个 300–500MB,同样累积)。前端两大可重建根:`build` = **9.6GB**(内含 test_cache 6.9G + 已构建的 `build/macos` app 2.5G + 散落 dill)、`.dart_tool` = **6.0GB** ⇒ 合计 **15.6GB**,本机本项目最大单项。
> **辨明(S22 删前先辨)**:`.dart_tool/{package_config.json,package_graph.json,version,native_assets.yaml}` = **pub get 生成的配置状态、非产物**(删了要重 `pub get`);`build/` = 纯产物可删;`.dart_tool/flutter_build`·`build/test_cache` = 纯缓存产物可删;`~/.pub-cache` = **下载的依赖包(正常缓存、非泄漏),绝不清**。
> **机制查清(原则 #8,先查官方再动手)**:`build/test_cache/build/<hash>.cache.dill.track.dill` = **flutter test 的内容寻址增量 kernel 编译缓存**(flutter/flutter#51235 引入,让重跑 test 免重编入口);**无 LRU / 无大小上限 / 无驱逐配置**——官方唯一清理入口就是 `flutter clean`(`flutter clean --help` 逐字自报「Delete the build/ and .dart_tool/ directories」,同时清两坨)。故**不手搓 `rm`**(那是抄它的实现),直接用官方命令。
> **修法落地**:①`frontend/Makefile` 加 `clean:` 目标 = `$(RUN) flutter clean`(不加台账原稿的 `rm -rf build .dart_tool`——那与 flutter clean 逐字重复、纯冗余),help + `.PHONY` 同步补 `clean`;②root `Makefile` 加 `fe-clean:` 委派(`$(MAKE) -C frontend clean`,与既有 `fe-verify` 委派对称、让前端清理从根可发现),help「清理」段补一行;③**修 root `.PHONY` 差集**——原缺 `fe-verify`(台账指认的 S22 缺项)**与** `fe-clean`,一并补入。**刻意不入 `fe-verify` 门禁**(清缓存会逼下轮全量冷重编、拖慢每次 pre-push;定位=「缓存涨了 `du -sh build .dart_tool` 手动跑一次」,写进 Makefile 注释)。**gitignore 无缺口**:`frontend/.gitignore` 已 ignore `/build/`·`.dart_tool/`·`.pub-cache/`·`/coverage/`,git 未追踪任何该路径下文件,无需补。
> **物理清理实测(dogfood 新目标)**:`cd frontend && make clean` → flutter clean 删 `build/`(2028ms)+`.dart_tool/`(497ms)+平台 ephemeral+`.flutter-plugins-dependencies`,**回收 15.6GB**(build 9.6G→0 + .dart_tool 6.0G→0,两目录清后不存在)。随后 `make setup`(pub get)+ `make fe-verify` 冷缓存全量重编 → 全绿(基线 4189)。

- **症状(实测)**:`frontend/build/test_cache` **6.9GB / 99 个 .dill**,mtime 跨 23 天(06-24 文件今仍在)⇒ **~300MB/天,旧的从不驱逐**;加 `.dart_tool/flutter_build` 5.9GB ⇒ 前端可重建根(build 9.6G + .dart_tool 6.0G)**15.6GB**,本机本项目最大单项。
- **根因**:flutter test 内容寻址缓存自身无 LRU/上限 + 我们**无清理入口**:`grep -c '^clean:' frontend/Makefile`=**0**;root `.PHONY` 差集缺项=`fe-verify`(S22:声明对不上物理事实)。
- **触发**:每次 `make fe-verify` 且代码有变(pre-push 门禁,每天多次)。dev-time only(`frontend/.gitignore:33 /build/` 已忽略)。

### T6 [MEDIUM·两侧] TextPainter 族泄漏:3 站漏、1 站做对 —— **✅ 已修(0717,收归 measureText 地基 + FlutterMemoryAllocations 守卫 + 突变验杀)**

> **站点复核(grep 定死,不信「3」这个数)**:`grep -rn "TextPainter(" frontend/lib/` = **恰 4 站**(third_party/super_editor 的 2 处 vendored 不动)。逐站验:`an_ocean_switcher.dart:138`(labelWidth,每动画帧×每 item 建、无 dispose)/ `an_composer.dart:270`(_countLines,每击键建、无 dispose)/ `an_version_diff.dart:333`(_gutterWidth,每 build 建、无 dispose)= **3 站漏**;`chat_thinking.dart:190`(_lineHeight,建后 `tp.dispose()`)= **1 站做对**。台账「3 漏 1 对」逐字属实。
> **修法落地(强化地基而非各站手搓 dispose——原则 #8)**:四站本是同一套 `new TextPainter → layout → 读指标 → (dispose)` 骨架,漏就漏在「dispose 是可忘的独立手动步」(台账自证根因=**不一致非无知**)。新增 `lib/core/ui/text_measure.dart` 的 `measureText<T>(InlineSpan, {read, textDirection, textScaler, maxLines, maxWidth})`——布局后把 painter 交 `read` 读指标、`finally` 里必 dispose(读回调抛异常也 dispose);默认值逐一对齐 TextPainter 原生构造/layout 默认(maxLines=null / textScaler=noScaling / maxWidth=∞ / textDirection=ltr),**路由既有站点零行为变化**(逐站核对每个显式参数保留:ocean 传 maxLines:1+textScaler、composer 传 maxWidth、version-diff 传 textScaler、chat 全默认)。**4 站(含原本做对的 chat_thinking)全部改走 measureText**,漏 dispose 从此结构上不可能;导出进 `core/ui/ui.dart` 桶供未来复用。视觉零变化(dispose 只动生命周期不动渲染)。
> **leak_tracker 验证(用其同源信号、确定性、无 GC 依赖)**:`leak_tracker_flutter_testing` 是**传递依赖**,直接 import 会踩 `flutter_lints` 的 `depend_on_referenced_packages`(analyze 不净)+ 动 `pubspec.lock`(与 T5 缓存战役撞车),故守卫改用 leak_tracker 自身消费的底层信号——`package:flutter/foundation.dart` 的 `FlutterMemoryAllocations`(直接依赖、零新包):`test/core/ui/text_measure_leak_test.dart` 监听 `ObjectCreated`/`ObjectDisposed`、只数 `object is TextPainter`,断言 created==disposed(=notDisposed==0)。**只信确定性 notDisposed、不碰 flaky notGCed**:①`measureText` 纯单测(无 widget 树 → 无框架 painter 噪声),正常路径+read 抛异常两路都 created==disposed==2;②三个漏站 widget 各:初始挂载后才挂账 → 逼 20 次纯 rebuild(框架 RenderParagraph painter 挂载时一次性建、rebuild 间复用不再派事件,故被隔离在计数窗外),量测站每 rebuild 建当帧毁 → created 恒等 disposed。`kFlutterMemoryAllocationsEnabled = …||kDebugMode` 在 `flutter test` 恒真;`created>0` 守卫防空过(仪器若关会红而非静默绿)。
> **突变验杀**:临时删 `measureText` 的 `painter.dispose()` 重跑 → 4 测全红,数字正如预测(ocean created **40**〔2 item×20 rebuild〕/version-diff **20**/composer **20**/helper **2**,disposed 全 **0**);恢复 dispose → 全绿。守卫真咬得住,非摆设。
> **文档**:本节整体重述为 ✅ + §4.1 守卫表 T6 行改为落地事实(FlutterMemoryAllocations 计数、`text_measure_leak_test.dart`、突变验杀过)。fe-verify 基线 4189 → 见下收尾。

- **症状(剂量-反应实测)**:全套 **541 个 TextPainter `notDisposed`**。AnComposer 0/5/40 击键 → 漏 0/5/40(1:1 线性,0 击键漏 0 因 `_countLines` 空文本早退);AnOceanSwitcher STATIC 2/4 项→2/4、**ANIMATED 4 项一次 240ms 滑动→104**(=4×26 build)。
- **根因**:三站无 `tp.dispose()` —— `an_composer.dart:270`(每击键)/ `an_ocean_switcher.dart:138`(常驻左岛,每动画帧×每 item)/ `an_version_diff.dart:333`(每 build);唯一 dispose 的 `chat_thinking.dart:190`**不在泄漏名单** ⇒ 团队知道正确写法,是**不一致非无知**。
- **诚实边界**:**MEDIUM 非 HIGH** —— build 后即不可达,GC 终会回收、原生 paragraph 由 finalizer 释放,**非无界**(与 Phase 2 前端 RSS 一路降 204.5→167.1MB 吻合,不拿它解释发烫)。危害真实:Dart 壳极小、原生 paragraph 大 ⇒ GC 感受不到压力 ⇒ 原生内存延迟释放。
- **修法**:读完 metrics `tp.dispose()`(try/finally),3 行零行为变化。

### T7 [CRITICAL·砖化非烧·机制实测/触发未证] orm.Transaction 无 defer 回滚 → Detached ctx 上 panic = 永久整库死锁 —— **✅ 已修(0717,一行 defer + 突变验杀)**

> **修法落地**(与下文「修法(一行)」一致):`orm/db.go` Transaction 在 BeginTx 成功后立即 `defer func() { _ = sqlTx.Rollback() }()`——Go 标准套路:panic 展开时 defer 照跑、回滚后 panic 原样上抛(不吞);错误路径回滚并入同一 defer;Commit 成功后 Rollback 返回 `sql.ErrTxDone`、丢弃即净(database/sql 语义,无 double-rollback 冲突)。**修在地基层 = 全部调用点自动受保护**:grep 全仓 `.Transaction(` = 21 个调用点(store×11 文件 + infra/search + infra/db 迁移/rebuild)全走 `*ormpkg.DB.Transaction` 这一个实现,orm 外零裸 `BeginTx`/`sql.Tx`。
> **守卫 + 实测证据**:`orm/tx_test.go` `TestTransaction_PanicRollsBackAndFreesConnection`——真 SQLite `SetMaxOpenConns(1)` 内存库(newTestDB 本身就是砖化臂)+ 不可取消 ctx(Background+ws 值 = reqctx.Detached 形状),fn 写一行后 panic:断言 ①panic 原值上抛(吞掉=红) ②带 2s deadline 的后续读返回 ErrNotFound(连接已释放**且**已回滚——deadline 把「砖化」变红灯而非挂死) ③同一连接新事务照常提交。**突变验杀**:临时删 defer 重跑 → 红灯 `context deadline exceeded`(正是 ARM_B 砖化签名);恢复 → 绿。
> **遗留(不在本刀内)**:扳机可达性(fn 真会 panic 吗)仍未证,§6#1 照旧;「给 reqctx.Detached 立法 WithCancel+挂关停链」是独立立法项——本刀已拆除其最重后果,但「别再新增裸 Detached 调用点」的叮嘱不变。文档:`foundation/orm.md` §4 DB 行同步 panic 语义。

- **症状(A/B 实测,Transaction 函数体逐字复制,只改 ctx)**:ARM_A(可取消 ctx)panic 被 recover → `awaitDone` 驻留 0、DB responsive;ARM_B(`Background` ctx)→ **awaitDone 永久驻留、DB `context deadline exceeded` = 整库死锁**。给真 `orm/db.go` 打上 `defer{recover→Rollback→repanic}` → ARM_B 立刻 `dbAlive=true`、rows=0、panic 仍上抛。
- **根因**:`backend/internal/pkg/orm/db.go:56-59` —— `fn` panic 时 Rollback/Commit **一个都不跑**。救不救得回全看 ctx:`database/sql` 的 `awaitDone` 靠 `<-tx.ctx.Done()` 自动回滚,`Background` 永不取消 → `<-nil` 永久阻塞;`SetMaxOpenConns(1)` 使这一条连接就是全部 ⇒ 此后每次 DB 操作永久阻塞,进程看着还活。
- **可达性(对抗复审反转「未证」为「引信已铺」)**:域2 自证「主聊天回合无罪」(runner.go WithTimeout+defer cancel,LIFO 先于 recover)**这一半成立**;但 `host.go:144` 的 `WriteFinalize` **自铸 `Detached(wsID)`**(设计上就要逃开 cancel)→ `FinalizeMessage` = `messages.go:118` 的 Transaction,整段跑在 recover 之下 ⇒ **投递路径每个 assistant 回合恰一次**。仍缺:`insertBlocks` 很防御,**fn 内真会 panic 未证**。诚实定级:**机制=CONFIRMED(A/B 数据),扳机=未证**——潜伏地雷 + 已铺好的引信。
- **为什么收在「烧机器」名单**:它不烧,它砖化 —— 但用户见 app 永久转圈 → 强杀重启 → 喂养 T2 孤儿。product-side 更致命(重启才活),dev-time 伪装成「testend 卡死/超时」。
- **修法(一行)**:`defer` 回滚 + 重抛(不吞 panic)。给 `reqctx.Detached` 立法:后台工作一律 `WithCancel(Detached(ws))` 并把 cancel 挂进关停链(`sensor.go:98` 现成范例)。**在此之前别再给 Detached 新增裸调用点**。
- **守卫**:①`goleak` 逮泄漏的 `awaitDone`(见 G0);②5 行单测 Transaction 里 panic + Background ctx + 随后 `QueryRow` 带 timeout,断言不超时。

### T8 [HIGH·两侧,放大器] waitDelay 10s > app grace 8s → 正常退出升级成 SIGKILL —— **✅ 已修(0717,分层预算 + 跨端 golden)**

> **修法落地**(选「后端预算 < app grace」端,app 侧 8s 不动):读关停链定**分层预算**——地板嵌进总预算、总预算嵌进 app 宽限:`shell.WaitDelay` 10s→**2s**(导出;链中唯一不认任何 ctx 的地板——被取消 Bash 的管道地板,StopPool 与 chat.Shutdown 的 wg.Wait 要**串行**各等满一个)· `bootstrap.drainShutdownGrace` 6s→**2s**(WaitPoolDrained 宽限=串行地板第一项;没赶上的节点记 failed 下次 boot 续,严格好于写一半被 SIGKILL)· `bootstrap.shutdownGrace` 10s→**6s**(总预算,罩 ctx 有界各步)。最坏串行地板 2+2+2=6s < 8s,余量 2s;三处常量注释逐字钉死「为什么是这个数:app 侧宽限 8s,超过=SIGKILL 升级=前功尽弃」。2s WaitDelay 的唯一代价=逃逸管道持有者 +2s 后才写的尾部输出从 tool result 丢掉。
> **守卫(§4.1 那条「今天它是反的,没有任何测试看着它」)**:`bootstrap/shutdown_budget_test.go` golden 测试——**解析前端源码** `backend_controller.dart` 的 `shutdownGrace = const Duration(seconds: 8)`(两仓常量第一次进同一条断言;dart 文件缺失/改形=红灯而非跳过,会跳过的守卫不是守卫),钉死四条不等式:`shutdownGrace ≤ appGrace−1s` / `WaitDelay < shutdownGrace` / `drainShutdownGrace < shutdownGrace` / `drainShutdownGrace+2×WaitDelay < appGrace`。
> **台账修法第二句(shellMgr.Stop 提前)裁定不做**:读码证 `Manager.Stop()` 无 closed 门——提前到 chat.Shutdown 之前会开「Stop 后活回合新 spawn 永不回收」的竞态窗(现位置在 chat 之后=无新回合=无新 spawn,是刻意安全序);预算压缩后它在 SIGKILL 前必然可达,常量对齐正是主刀(与下文「fix①才是主刀」判词一致)。T2 的 stdin 死人开关汇入同一条有序关停,同样受益。文档:`foundation/bootstrap.md` Serve 行补预算格 + `testend/overview.md`·`testend/harness/server.go` 的 10s 复述同步为 6s(20s 测试余量保持,排空卡死不论预算多少都是缺陷)。

- **症状(实测)**:`Bash.Execute` 在 ctx cancel 后 **3/3 = 10.00s** 才返回(孙进程 `os.setsid()` 逃出进程组、攥 stdout 管道);对照(组内进程)post-cancel **0.00s**。app 只等 **8s**(`backend_controller.dart:68/273`)然后 SIGKILL(:275,两个生产构造点都吃 8s 默认)。后端自报预算 10s。
- **根因修正(域1 C2「无 ctx 无超时」表述假)**:`chat.Shutdown()` **是**先 `close(s.stop)` 再逐个 `q.cancel()` 再 `wg.Wait()`,取消**送到了**;真根因是**送到也没用** —— 10s 地板 > 8s 宽限,与「谁取消」无关。⇒ 域1 fix②(给 wg.Wait 收 ctx)只是次要治标,**fix①常量对齐才是主刀**。
- **为什么是放大器**:它把 T2/T3 的孤儿从「意外」变成「正常退出的常规升级」—— 每次 Cmd-Q 都掷硬币,若有在途 Bash 孙进程守护化(标准做法)则 8s 到、SIGKILL,拖垮整个关停家族(llama 孤儿 442MB / MCP·handler 孤儿 / background bash 永久孤儿 / db 不干净关)。
- **修法**:两常量对齐(app grace > 后端 10s,或后端预算 < app grace);`shellMgr.Stop()`(纯内存 kill、不碰 DB)从关停链最后(build.go:697)提到不可跳过的早位。
- **守卫**:一条跨端常量断言 `frontend grace > backend waitDelay`——**今天它是反的(8<10),没有任何测试看着它**。

### 次级(结构缺口/守卫缺,非独立 burn)

- **T9 [MEDIUM] retention sweep 每批全表排序**:`retention.go:87-94` `julianday(completed_at)<?` 列上套函数 + `ORDER BY completed_at` 无索引 → `USE TEMP B-TREE`,单批 0.41s 冷 @129,600 行,433 批。**证伪了自己的「追不上→无界」假设**(`app/scheduler/retention.go:39-58` 是 `for{}` 清干净)。修:索引 `(workspace_id,status,completed_at)`(**坑**:julianday 两侧都过是故意的,防秒/纳秒精度错序,不能盲删)。
- **T10 [MEDIUM·结构缺口] 一次性 sandbox 进程崩溃无 boot 网**:`spawn.go` `Spawn` 只存内存 `oneShots`、从不 `SetEnvRunningPID`(仅 `SpawnLongLived:83` 写)⇒ boot 网 `restore.go:18` 结构性够不着。与 T3 同族但受 Timeout + 在途数封顶 ⇒ **不无界**,故 MEDIUM。「调用点缺席」= 读码可靠证明的那类。
- **G0 [守卫缺口] `goleak` 是幽灵依赖**:`grep goleak` = 0 用点,`go.mod` require 0 条(仅 zap 的 test 依赖被 go.sum 记哈希)。`make verify` 645 测**无一条**断言「测试结束无多余 goroutine」。它已在 go.sum(v1.3.0),引入零新第三方信任面,且恰好逮 T7 的 awaitDone。

---

## 3. 已证伪 / 洗脱的(同样是产出 —— 记下「查过、清白」省下次的功)

| 假设 | 判决 | 站得住的凭据 |
|---|---|---|
| 后端 ticker 是热源(drain/timeout/misfire/retention/keepalive/pool) | **无罪** | 每 tick 0.34–0.56ms;空转 AVG **0.014–0.026% CPU**;`sample` 7866 样本零落应用码 |
| 后端 goroutine 泄漏 | **无罪** | 空转/90 次 SSE 连断/40 次实体 churn/优雅关停:19→19、28→28 全平,逐栈归因无神秘 |
| `make verify` 漏子进程/端口/临时目录 | **无罪** | 4Hz 密采样 99 样本树内零 llama/dart 子进程;端口 1→1;`TMPDIR/go-build*` 自建自清 |
| `make fe-verify` 漏 flutter_tester | **无罪** | 278 生 278 死 0 漏出;峰值并发 4;dart analysis 一次性非常驻 |
| `make demo/gallery` 拉起后端 | **无罪** | 活着时抓到的 anselm/llama 命令行自证是 peer testend;`~/.anselm`=0.0MB |
| S1:backfill 的 Detached `prov.Embed` 拖垮关停超 8s | **洗脱** | 黑洞 Ollama 制造 60s 窗口,SIGTERM → 关停 **0.081s**;`grep wg.Wait app/search/` 无一等 embedWorker |
| S2:`handler/call.go:168` 裸 sleep 是第二个 R9 busy-retry | **出局** | 不在 `for{}` 里,单次 stderr 排空宽限;全库 `for{}` 均带 `<-ctx.Done()` |
| `stats.go` rows 未 Close → 单连接死锁 | **证伪(我的 grep 撒谎)** | rows 变量名 `base/recent/parked/streak` 各自 `defer Close()`,按变量名重审全库 0 处真漏 |
| Riverpod / SSE demux / AnTimePulse 泄漏 | **无查获** | keepAlive 仅 SSE+overlay 有立法;demux `onCancel` 移除;AnTimePulse listener 全成对、0.013% |
| blob store 孤儿累积 | **无罪(有治理)** | `build.go:346` boot 跑 `attachment.GC`,内容寻址去重,注释解释为何在 boot 非 delete |
| ScrollController 55 / FocusNode 3 / PulseClock 9 假阳性 | **拒报** | 无创建栈会误报:实为 super_editor AutoScrollController 1:1 配对 / 测试文件自造 / static 单例 |

**testend cp 放大(任务原①)在本战役窗口内被 peer 修完并提交**:`5cfd5b0d` 整树 `cp -R` 换 `clonefile(2)`(45min→**19m11s**)、`87badefa` TMPDIR scratch 收容(清 4.5G)。我的 4.37GB 泄漏取证正是其「before」。不重复它。

---

## 4. 守卫设计 —— 终局一条 `make leakcheck` 进 pre-push

**每条 confirmed 配一个能抓住它的守卫**(见 §2 各条末),核心是把「实测定罪」固化成不可回归的门禁。分两层:

### 4.1 单点守卫(随包,进各自门禁)

| 守卫 | 抓 | 落点 |
|---|---|---|
| `goleak.VerifyTestMain(m)` + 白名单 | T7 awaitDone + 未来任何 goroutine 漏 | 先只在 `bootstrap`+`scheduler` 两包开(别全库,否则被常驻 goroutine 白名单淹没) |
| Transaction panic + Background ctx 单测 | T7 | `orm/tx_test.go` ✅ 已落(0717,突变验杀过) |
| crash 路径子进程单测(spawn→SIGKILL→boot→断言死) | T3 + T10 | `shell/` + `sandbox/`(现有 reap_test **只测优雅**) |
| 跨端常量断言 `grace > waitDelay` | T8 | `bootstrap/shutdown_budget_test.go` ✅ 已落(0717,解析 dart 源、缺失即红) |
| `EXPLAIN QUERY PLAN` 断言无 `TEMP B-TREE` | T9 | `flowrun/retention_test.go` |
| 插行→删→断言 freelist/size 下降 | T4 | `infra/db/vacuum_test.go` ✅ 已落(0717,真落盘库 `os.Stat` 前后 + 回收闸 + `Compact` mode=0 升级 + `Stat` 死空间) + `app/storage/storage_test.go` + 前端 `s5_storage_limits_test.dart` |
| TextPainter created==disposed(`FlutterMemoryAllocations` 计数,leak_tracker 同源信号;确定性、无 GC) | T6 | ✅ 已落 `test/core/ui/text_measure_leak_test.dart`,进 `make fe-verify`(突变验杀过——删 dispose→4 测红) |
| 空转 N 秒断言 summary 帧 < 阈值 | T1 | perf 探针 |
| quitlab「quit app→子进程 N 秒内死」 | T2 | app 生命周期 harness |

### 4.2 `make leakcheck`(黑盒,跑完工作负载断言零增长)

**设计**(照 `testend/` 模式,独立 module、拉真二进制、纯量测):

1. **前拍**:真 boot 后端(自选空闲端口、断言 health=200+`listener_pid==自己`),记 `(进程数, 孤儿数, 端口数, RSS, goroutine total via pprof)` 基线,锚在自己的 root pid 子树。
2. **跑工作负载**:一组代表性动作 —— N 轮 SSE 连断 + N 次实体 CRUD(触发 embed 拉 llama) + spawn background bash + 一次崩溃恢复(SIGKILL→reboot)。
3. **关停 + settle(+10s)**:优雅 SIGTERM,等 cp/在途相自灭。
4. **后拍 + 断言零增长(身份级 diff,键=`(pid,lstart)`)**:`我的孤儿 Δ==0`、`我的端口 Δ==0`、`我的 llama/anselm-server 存活==0`、`goroutine total 回落到基线±白名单`、`freelist 复用(插行后 size 不涨)`。
5. **仪器自检门(硬约束)**:采样数<阈值 / 自身 pid 不在进程表 / 建的资源实测不存在 → **拒绝出数、红**(不许打印好看的空表)。
6. **不进 `make verify`**(分钟级、拉真二进制),与 `make testend` 同列 pre-push;`LEAKCHECK=1` 门控最重的崩溃恢复相。

> 这条守卫的立身之本 = **它自己先过仪器自检**。本战役 13 次仪器撒谎全是「报告了自己没做成的事」,`make leakcheck` 若不自证,就是又一个 `cp-sampler.sh`。

---

## 5. 与 R1–R24 的关系(方法论遗产:为什么上次没抓到)

| 本轮 | 与旧账关系 | 为什么上次没抓到 |
|---|---|---|
| T2 app 退出孤儿 | **漏网(新)** | R2 只看后端崩溃恢复,从没测「前端正常退出走不走 stop()」;`make app` 走 dev-attach 分支,`_spawn/_stop/_watchExit` **从不跑** ⇒ dev 流程结构性测不到 |
| T3 background bash 崩溃孤儿 | **R1 的未覆盖半** | R1 加了 `shellMgr.Stop()` 但**只在优雅 `App.Shutdown`(build.go:697)可达**;`manager.go:105` 纯内存 map、无 boot 网 ⇒ 与 R2 同一 R2-shape 盲区,crash 路径零测试 |
| T7 Transaction 死锁 | **新(读码盲区)** | 静态扫描看 `_ = sqlTx.Rollback()` 在 err 路径「有回滚」就放行,没问「panic 路径谁回滚」;只有 A/B 换 ctx 才现形 |
| T8 grace<waitDelay | **新(跨端常量)** | 两个常量在两个 repo(dart 8s / go 10s),没有任何单侧扫描会把它们放一起比 |
| T1 AnStatusDot | **Phase 2 热源的根因** | 前端从不在 systems-correctness 扫描面内(R1–R24 全是 `backend/`);`pulse_clock.dart` 注释逐字预言了它却没人接 |
| T4 DB 棘轮 | **新(product 磁盘)** | R10–R12 专扫 disk-io 只在 `backend/` 挖 I/O 放大,没问「删行后文件缩不缩」这个运行时状态 |
| T9/T10 | **R10–R12 / R1 同族缺口** | 同「调用点缺席」类,读码可证但没被列入扫描面 |

**抽查 R1/R3/R14(标 ✅ FIXED,是否别的也像 R2「修了没覆盖 dev/test 路径」)**:

- **R1(shell ProcessManager.Stop 可达性)= 有问题,同 R2-shape**。实测 + 读码:`shellMgr.Stop()`(build.go:697)只在优雅 `App.Shutdown` 可达;`manager.go:105 procs` 纯内存零持久化 ⇒ **优雅路径修对了,崩溃路径完全没网**(= T3)。R1 标 FIXED 只覆盖了优雅半。
- **R3(drainLoop ctx)= 真修了、覆盖完整** ✅。`build.go:489-497` ticker `defer t.Stop()` + `case <-ctx.Done()`;misfire/retention 各自 `context.WithCancel` + Stop/Done(正确的 detached-with-cancel 范式,同 sensor.go:98)。无隐患。
- **R14(search.Close 有界)= 真有界、但理由与注释不同** ✅。`service.go:163 Close(ctx)` 只 `close(embedQuit)` + provider Close;域2 黑洞实验证 **没有任何东西 wait 在途 Embed**,故 Close 不管 Embed 多慢都 0.081s 返回。注释称「bounded by shutdown ctx」易被误读为「ctx 兜住 Embed」,实为「根本不等 Embed」—— 结论对,措辞该收紧。

---

## 6. Open questions

1. **T7 扳机可达性未证**:机制 A/B 铁证,但 `insertBlocks`/store 层 fn **真会 panic 吗**未证(需 fuzz,超本轮预算)。在证明前它是「已铺引信的潜伏地雷」,不是「无路可达」。
2. **T2 SIGKILL app 路径**:前端 `applicationShouldTerminate` 补丁救不了 `kill -9 app`(那才真正需要后端 parent-death watch)。两条路都要修,优先级?
3. **发烫本体未测**:无 sudo ⇒ `powermetrics`/温度拿不到,24.92% CPU 是可信因果链但能耗/温度本身没测。
4. **冷缓存未测**:所有量测都是热 go-build/dart 缓存;冷编译首轮内存峰值必远高,「发烫」若指冷编译则本战役没覆盖。
5. **只测了 Scheduler Overview 一屏**(机器级 prefs 决定落哪个海洋);chat/entities/documents 空转帧数未测,但 T1 机制通用(任何 run 点)。
6. **testend 30m 预算**:peer clonefile 修后安静机跑 19m11s(余量 36%),但本战役全程机器不安静,「安静机干净全套」仍缺一次权威测。
7. **量尺缺陷**:`diff.sh` 无 `--tag` 时把所有新增 ours 记成本工作负载账,有并行 agent 时系统性冤枉;macOS GUI app(`*.app/Contents/MacOS/`)天然 PPID=1 应单列「GUI/launchd」不计孤儿(否则每次真机截图验收留假孤儿污染孤儿计数)。已记账,建议进 `.leak-lab/README`。
