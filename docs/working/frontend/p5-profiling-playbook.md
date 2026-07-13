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

# WRK-066 P5 — Live-Profiling Playbook（C 轨真机相位）

> 同轨 A/B/D 三轨已 100%，C 轨余 4 项（C-001/016/025/030）= **P5 性能相位**：感知层优化，当前行为**已正确**、只是非最优。每项在 headless 内无纯净安全子集（盲改冒 data-loss / gesture-break / stale-UI / brick 回归），故留到真机 profiler 定罪/证伪。
>
> **本文是操作手册**：你按每节跑一次真机、把「采集」栏的数据/现象贴回来，我对着真实 trace 逐项实现并关账（或据数据证伪、close）。**决策准则**已写明——jank ⇒ 实现「预备的修法」；smooth ⇒ 证伪关账。

## 0 · 通用：怎么建 profile 版

```bash
cd frontend
mise exec -- flutter run --profile -d macos          # 真 app + 真 sidecar,profile 模式(近 release 性能 + 可 profile)
```
- 运行后终端会打印一个 **DevTools URL**（`http://127.0.0.1:9xxx?uri=...`）→ 浏览器打开 → **Performance** 标签。
- Performance 面板：点 **Record** → 做动作 → **Stop** → 看 **Frame Time** 图。**Jank 判据**：UI 或 Raster 线程有帧 **>16.6ms**（60Hz 屏）/ **>8.3ms**（120Hz ProMotion）即掉帧。悬停红/黄帧看 UI-thread 耗时归属。
- `[startup]` 前缀的日志（C-030 用）直接打在运行终端里（`debugPrint`，profile 下可见、release 剥除）。

---

## C-030 · 冷启动计时 + keychain 无变砖

**关切**：后端 spawn 串在 `main()` 尾（prefs→window→launchAtLogin→runApp→gate→spawn→health），若 Go boot 是长杆，提前 spawn 与窗口初始化并行可省。**风险**：keychain/master-key 次序（ADR-0008）改错 = 旧装机变砖。

**已埋计时**（`backend_controller.dart`，本批加）：冷启时运行终端会打印一行
```
[startup] masterKey resolve=<N>ms
[startup] backend: spawn=<A>ms health-wait=<B>ms total=<C>ms
```

**跑法**：
1. `mise exec -- flutter run --profile -d macos`（现有装机 = 读现有 master key）。
2. 记下上面两行日志（重复启动 3 次取中位——首次可能含二进制冷缓存）。
3. **fresh-install 无变砖验证**（⚠️ 会清 dev 数据，先备份数据目录）：备份并删除数据目录（`~/Library/Application Support/Anselm/` 或你的 `ANSELM_DATA_DIR`）+ 删 keychain 里的 Anselm master-key 条目 → 再 `flutter run --profile`。应正常铸新钥 + 起来（**不能变砖**）。

**采集回贴**：① 现装机的 `masterKey resolve` / `spawn` / `health-wait` / `total` 三次中位；② fresh-install 是否正常起（是/否 + 现象）。

**决策**：`health-wait` 占 `total` 大头（如 >60%）且是冷启感知延迟主因 ⇒ **实现预备修法**＝把 `BackendController.start()` 的 spawn future 在 `main()` prefs 载入后**立即 kick-off**（不 await），window/launchAtLogin 期间并行 boot，gate 只 await 已在飞的 health；**keychain 次序原样保留**（spawn 内部先 resolve master key 再 Process.start，不动 ADR-0008 径）。回归验证：fresh + 现装机都干净起。若 `health-wait` 已很小（如 <150ms）⇒ 证伪关账（并行收益不抵 startup 协调复杂度，#6）。

---

## C-016 · 图节点拖拽

**关切**：`_updateNodeDrag` 每 pointer-move `setState` 重建整个画布。**风险**：隔离须么 reparent 拖拽节点（断在飞手势）、么 memoize 节点卡（须稳定 per-node 闭包）——手感须真机验。

**跑法**：
1. profile 版 → entities 海洋 → 打开一个**带图的 workflow** → 进编辑态 → **持续拖一个节点画圈 ~5s**。DevTools Performance 录制这段。
2. 记下图的**节点数**（realistic workflow 通常几~几十个）。

**采集回贴**：① 拖拽期 UI-thread 有无 >16ms 帧（Frame Time 图有无红/黄）；② 图节点数；③ 主观：拖拽跟手还是滞后/卡顿。

**决策**：拖拽掉帧（UI-thread pointer-move 帧 >16ms）⇒ **实现隔离**（预备：`_dragScene`→`ValueNotifier`；拖拽期把非拖拽节点卡按 id memoize[props 拖拽期冻结]，setState 重建时同实例短路、仅被拖节点 Positioned 更新；drag-end 清缓存），再真机复验手势不断、drop 落点对。全程 <16ms 平滑 ⇒ **证伪关账**（典型小图已够快、隔离只利大图 100+ 节点，workflow 罕见）。

---

## C-025 · 侧幕舞台流式期重建

**关切**：`_GenericStage` 的 `ValueListenableBuilder` 监听整会话 transcript，任一别块的 delta 都令所有展开舞台重建。**已缓释**：昂贵路径全记忆化（scene/arg/receipt/resultObj/graph = C-005/007/018/028/042，有测），残余=廉重建。**风险**：granular selector 须走 `BlockNode.revision`（原地可变、身份选择器漏更新），但嵌套 subagent 树的父块 revision 传播不确定（漏则嵌套树 stale）。

**跑法**：
1. profile 版 → chat → 发一条**触发长流式 + 多工具调用**的消息 → 在右岛**展开一个工具舞台** → 保持展开让回复流完。DevTools 录制流式全程。

**采集回贴**：① 流式期有无与舞台重建相关的 UI-thread 掉帧；② 同时展开多个舞台时是否更明显。

**决策**：流式掉帧且归因舞台重建 ⇒ **实现 revision 选择器**（舞台只在 `transcript.liveBlock(blockId)?.revision` 变时重建）+ **必配嵌套传播测**（构造带 subagent 子块的 tool 卡,断言子块变更令父块可见更新——若不传播则改用 subtree-max-revision 或保守回退 VLB）。流式平滑 ⇒ **证伪关账**（记忆化已够、granular 不值漏更新风险 #6）。

---

## C-001 · 编辑器整篇序列化 + IME

**关切**：`_onDocumentChanged` 每次改动 `markdownFromDocument(_document)` 整篇序列化;大文档 = 打字滞后。**风险**：debounce 须 flush-on-dispose（否则丢末次编辑）；IME 组合期 emission 行为须设备实测。

**跑法**：
1. **大文档**：新建/打开一篇大文档（粘 ~1 万字）→ 在**末尾快速连打**。DevTools 录制打字这段。
2. **IME**：切中文拼音 → 在编辑器里**组合一段中文**（长句连打）→ 观察组合是否卡 + 录制。

**采集回贴**：① 大文档快速打字有无掉帧/滞后（DevTools + 主观）；② 中文 IME 组合期是否卡顿/丢字；③（可选）能否观察到一次输入触发多条同步变更（组合期）。

**决策**：大文档打字滞后 ⇒ **实现 microtask-coalesce 序列化 + flush-on-dispose**（同帧多条变更并一次序列化,无时延无丢失窗;dispose 时若有 pending 同步 flush 一次）,并真机复验:**打字→立即关文档→重开→内容完整**（末次编辑不丢）+ 中文 IME 不回归。打字流畅 ⇒ **证伪关账**（序列化对现实文档够快）。

---

## 关账流程

每项数据回来后：**jank/确诊** → 我实现预备修法 + 真机复验 + widget/probe 测锁 + 关 C-0xx；**smooth/证伪** → 我按数据写证伪 note、close。四项走完 → C 轨 42/42，同轨四轨全绿 → P6 二轮普查 + 归档。
