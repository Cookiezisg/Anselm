---
id: WRK-066-P5
type: working
status: active
owner: "@weilin"
created: 2026-07-13
reviewed: 2026-07-13
review-due: 2026-10-01
audience: [human, ai]
---

# WRK-066 P5 — 性能相位记录（C 轨 42/42 全落定）

> **C 轨全部落定**（C-001/016/025/030 本相位收官,其余随 P4 顺手清 + 记忆化批已落）。本文从「操作手册」改写为**实况记录**:方法学枢转 + 逐项结果。

## 方法学枢转（关键)

原设想真机 `flutter drive --profile` + `traceAction` 采 raster 帧时间。**实测发现自动上下文虽是 Aqua 会话、`screencapture` 通,但启动的 app 窗口不 foreground → `tester.pump` 卡 vsync、渲不出真帧**(`pumpWidget` 成、首个 `pump` 挂)。故 integration_test/flutter_driver 真机帧路径**移除**。

**顿悟**:这 4 项的关切**全是 Dart 侧构建/序列化成本**(整画布重建 / 舞台重建 / 每键序列化 / 冷启动串行),**不是 GPU raster**。故改 **headless `flutter test` + 真 `Stopwatch` / build-count 探针**——正是 C-023 用法,自动上下文可跑、可测量定罪/证伪。raster-inclusive 真机帧非这些条目的关切,故不需要。

## 逐项结果

### C-001 · 编辑器整篇序列化 — **证伪 + 顺手修真 bug**
- `test/perf/c001_serialize_perf_test.dart` 计时 `markdownFromDocument`:**279KB/1550 节点巨文档(远超现实)序列化中位 1.68ms debug ≈ 0.56ms release**,远在 16ms 帧预算内→每键序列化非打字延迟源。证伪。lazy-serialize 契约改不值 blast radius。
- **同区顺手修真 data-loss bug**:自动保存 Debouncer 无 flush-on-dispose→600ms 防抖窗口内切文档丢末次编辑。`Debouncer.flush()` + document_ocean 两 dispose 走 flush + `_onChanged` 挂载时捕获 repo(Riverpod 卸载期 ref 已释放)。debouncer flush 单测 + documents dispose 数据不丢测。

### C-025 · 侧幕舞台每 delta 重建 — **land-now**
- 立 `ValueListenableSelector<T,S>` 原语(选择性重建:仅 selector 切片变才重建;didUpdateWidget 重算基线防陈旧漏建)。`_GenericStage` 按 `liveBlock(blockId).revision` 门控。
- 命门=`revision` 子树最大值(reducer `_bump` 上抛全祖先,实测锁 test:嵌套/孙块变更均抬父 revision)→父块选择器绝不漏嵌套 subagent 更新。selector 双测 + subtree-max 测 + 382 chat UI 测绿。

### C-016 · 图节点拖拽整画布重建 — **land-now(实测 0 卡重建)**
- `_dragScene`→`ValueNotifier`,每节点 Positioned 包进从首 build 就在的 `ValueListenableBuilder`,`_NodeCard` 作稳定 `child`。pointer-move 只 `_dragScenePos.value+=delta`(无 setState)→只重跑轻量 Positioned、不重建 N 张卡、不断手势(VLB 首 build 就在无 reparent)。
- `GraphCanvasProbe` 实测:10 次 move **卡重建=0**(旧 setState-per-move=4×10=40),拖拽仍正确提交。

### C-030 · 冷启动后端串行 spawn — **land-mechanism(产线残余)**
- 幂等 `start()`(`_startCall` 并发/重复并入在飞启动、不双 spawn,崩溃重入 Retry)+ main 提前 kick spawn 与 initWindow/首帧并行 boot。keychain 次序字节不变(ADR-0008 无新变砖面)。幂等 concurrent-join/crash-re-enter 双测 + 16 startup-gate 测绿。
- `backend_controller` 埋 `[startup]` 计时(`masterKey resolve` / `spawn` / `health-wait` / `total`,release 剥除)。
- **唯一真机产线残余**:计时收益 + 全新装机无变砖须真机**产线 spawn 路径**验(dev 走 `ANSELM_BACKEND_URL` attach 不 spawn,故 dev 无法跑到 spawn/keychain);机制已落 + 测,埋点就绪。

## 主面场景套件 · 常驻 build-side 预算门禁

§4-C 的「主面场景套件预算测试常驻 fe-verify」以 **build-side 断言**落地(build-count / build-cost / rebuild-scope 上界——关切在 Dart 侧构建成本,非 GPU raster;自动上下文渲不了真窗,见「方法学枢转」)。逐主面映射:

| 主面 | 预算断言 | 常驻测 |
|---|---|---|
| 长对话流式 | 200 delta 只重建 live 叶(页/settled 行 0)+ 开回合内落定 text 块零重解析 | `chat_transcript_test`(BuildSpy / C-023) |
| transcript 滚动 | center-sliver prepend 零位移 + 上滚读者不被流式推 | `chat_transcript_test` |
| 海洋切换 | 懒 IndexedStack:未访零成本、重选零重挂(保 State) | `an_lazy_indexed_stack_test`(C-009) |
| 编辑器打字 | 整篇序列化 279KB 巨文档 <2ms debug(≈0.6ms release) | `c001_serialize_perf_test`(C-001) |
| 图渲染/拖拽 | 拖拽 10 move 0 卡重建 + workflow ops 图记忆化 | `an_graph_canvas_edit_test`(C-016)/`workflow_ops_graph_memo_test` |
| 右岛手风琴/舞台 | 选择性重建:仅本块 revision 变才重建 | `value_listenable_selector_test`(C-025) |
| 冷启动 | 幂等 start 并发不双 spawn + 后端提前并行 | `backend_controller_test`(C-030) |
| 其它嫌疑人电池 | ReDoS 线性 / tick 有界 / receipt·resultObj·arg·highlight 记忆化 / unread 等值 | `test/features/chat/perf/*`(P4,8 电池) |

**残余(真机产线)**:上表是 build-side 上界防回归;**raster-inclusive 真机帧时间**须真机产线跑(自动上下文窗口不 foreground、渲不了真帧),与 C-030 产线冷启计时同属真机残余——非核心关切(这些主面的瓶颈均在 build 侧,已测),而是「若要 raster 侧最后一钉」的可选项。
