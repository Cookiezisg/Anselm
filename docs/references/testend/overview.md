---
id: DOC-038
type: reference
status: active
owner: @weilin
created: 2026-06-12
reviewed: 2026-07-17
review-due: 2026-10-17
audience: [human, ai]
---

# testend —— 全功能黑盒验收套件

> 与 `backend/` 平级的独立 Go module。**零 backend import**：编译并拉起真实 `cmd/server` 二进制，只走纯 HTTP/SSE——验的就是用户与前端实际拿到的东西；场景在这里碰到的别扭本身就是前端开发者体验 finding。

## 入口

- `make testend` —— 全功能黑盒验收（scenarios/，llmmock 驱动 LLM 面，零 token，分钟级；**不进 `make verify`**）。
- `make evals` —— 金标 LLM 旅程（golden/，真模型；`EVALS=1` 门控 + `EVALS_BASE_URL/EVALS_MODEL/EVALS_KEY`；烧钱手动跑）。

## 布局

| 目录 | 职责 |
|---|---|
| `harness/` | 座架：`server.go`（编译+拉起真二进制、临时 dataDir、空闲端口、等 health、**退出收容**——见下节；sandbox 运行时经 `~/.anselm-testend-cache` 预置——首跑下载、后跑搭车）· `proc_unix.go`（收容原语：进程组 / SIGTERM / 组存活探针；testend 实际只跑 unix，故无 windows 孪生）· `client.go`（N1 envelope 解包、workspace 头、`OK`/`Fail(状态,码)` 断言、`Eventually` 异步涟漪轮询）· `llmmock.go`（OpenAI 兼容假模型：剧本化回应驱动 chat/agent/utility 全链零 token；**请求抓包即 promptdump**——线缆上的请求体就是模型真实看到的全部）· `sse.go`（三流订阅与事件断言） |
| `scenarios/` | 验收场景 = 普通 go test：每个测试函数是 PLAN 的一个「feature × 情况」单元，函数名即台账行；`-run` 过滤单域 |
| `golden/` | 真模型金标旅程（12 条端到端，机器可验收终态） |

## 进程收容（harness 硬契约）

> 场景拉起的是**真** sidecar，它自己还派生子进程——最要紧的是搜索的常驻 `llama-server` embedder（任何实体/对话入索引即起、常驻、占端口）。收容它是 **harness 的责任、不是后端的**：后端的孤儿回收器是「下次在**同一** dataDir 上 boot」的安全网，而 testend 给每个测试一个全新临时 dataDir、再无 boot 回访 → 那层安全网对 testend 结构性失效。

`Start`/`Restart` 起的每个进程都进**独立进程组**（`Setpgid`，对标 `infra/sandbox/proc_darwin.go`——复述而非 import），`t.Cleanup` 三层收容：

| 层 | 动作 | 为什么 |
|---|---|---|
| ① 优雅 | `SIGTERM` → 等至多 `gracefulStop`(20s) | **唯一**能跑起后端有序关停的方式，而只有那条链会杀 embedder（尾部的 `search.Close`）。`os.Process.Kill` 是**不可捕获的 SIGKILL**，用它 = 整条链一步不走。20s = 后端 `shutdownGrace`(10s，全程共享一个截止) + 不认 ctx 的尾步（池/chat waitgroup、WAL checkpoint）余量 |
| ② 兜底 | `kill(-pgid, SIGKILL)` 收整棵子树 | 兜住①够不着的：`Kill9`、卡死的排空、panic。embedder 由裸 `exec.Command` 起、不自设组 → 继承 server 组 → 一个负 pid 信号即收。**macOS 无 `Pdeathsig`**（父死子必孤），此层是 darwin 上唯一防线 |
| ③ 自检 | 轮询进程组至空；超 `groupReapWait`(10s) 仍有成员 → `t.Errorf` + 列幸存者命令行 | 泄漏必须**红**。旧实现全绿着漏出 31 个 llama-server（用户实机取证，12.23G/16G）——**测试绿不是收容的证据，空进程组才是**。每个测试自带此检，不设单独 leak 测试 |

- **`Kill9` 保持 SIGKILL、不得软化**：它模拟的正是「崩溃恢复」里的崩溃；软成 SIGTERM 会让优雅链把恢复半场要断言的残骸（非终态消息行、未收尸子进程、未 checkpoint 的 WAL）先删掉 = 什么都没测。它刻意孤儿掉的子进程由②收。
- **Ctrl-C**：①把 backend 移出了测试二进制的进程组，故 harness 自装 `SIGINT/SIGTERM` 处理器、退出前清扫所有活组（否则 `Setpgid` 会拿「正常退出泄漏」换来「Ctrl-C 泄漏」）。**不可约减的未覆盖**：`go test -timeout` 超时（进程内 panic、无信号可捕）与测试二进制自身被 SIGKILL——无 `Pdeathsig`，不在运行的 harness 察觉不了父死。
- **缓存只装运行时、不装状态**：`saveRuntimeCache` 回存前剥 `*.pid`。后端把 embedder pid 存在 `runtimes/llamasrv/embedder.pid`，而缓存会预置进**每个**未来测试的 dataDir 且每 kind 只拷一次——搭车的 pidfile 会让后端回收器永远指向操作系统此后回收给**别人**的那个号码。
- **预置靠 clone、不靠拷贝**：`Start` 用 `clonefile(2)` 把整棵缓存树**写时复制**进 dataDir（`clone_darwin.go`，一次 syscall ~90ms），非 Darwin / 非克隆文件系统回落 `cp -R`（`clone_other.go`）。**不是微优化**：缓存懒填充、随真跑长到 645MB，而 `Start` **每个用例跑一次**（实测每轮 **221** 次）——逐字节拷贝 = 每轮 ~139GB、~7.3s/用例 ≈ 26min，曾独吞 30m 预算的 86%（[R23](../../working/iteration/systems-correctness.md)）。COW 使隔离**完全等价**：往克隆里写永远碰不到源（已按套件级 checksum 复验）。**回落必打日志**：静默回落 = 套件悄悄变回 30m 超时。

## 纪律

- 黑盒铁律：禁止 import backend 任何包——线缆事实（header 名、payload 形状）从 api.md 复述，对不上即 doc/产品 finding。
- 场景对 `Eventually` 的依赖即产品的异步语义（索引/通知涟漪）；超时值是体验断言的一部分。
- 验收程序（acceptance-review）结束后本套件转为常驻回归：改 prompt/工具/契约后跑 `make testend`，改提示词工程后跑 `make evals`。
