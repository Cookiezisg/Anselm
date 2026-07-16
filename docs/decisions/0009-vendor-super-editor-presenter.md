---
id: DOC-056
type: decision
status: active
owner: @weilin
created: 2026-07-16
reviewed: 2026-07-16
review-due: 2099-12-31
audience: [human, ai]
---

# 0009 — vendor super_editor，给布局管线做节点级增量

## 背景

文档编辑器基座 super_editor **钉死 0.3.0-dev.40**（dev.41+ 引用本 Flutter 3.41.9 没有的
`TextInputConnection.updateStyle`，不能升）。其布局 presenter（`SingleColumnLayoutPresenter`，
`src/default_editor/layout_single_column/_presenter.dart`）在**任何**文档变更上无条件
`_earliestDirtyPhase = 0`（传入的 `DocumentChangeLog` 被整个丢弃）→ 全文档每个 node 重建
view model + 五个 styling phase 全文档重跑 + 每相全量 copy。

**测量定罪**（0716，真机 profile + VM timeline，两信源交叉验证）：

- 400 段文档打字 **5–9ms/键**（120Hz 预算 8.3ms，每键 JANK），成本 O(文档) 线性恶化；
- 每键产生 ~2500 个临时对象（420 次 createViewModel + 420×5 次 copy）→ **GC ConcurrentMark
  尖峰 ~10ms**；
- 微基准证实 presenter 纯 CPU 仅 ~0.9ms/400 段——它的主要伤害途径是**垃圾压力**，
  次要是 IME 派发路径内的同步工作（DispatchPlatformMessage p95 3.07ms）；
- 60–100 段典型文档尚可（尖峰 8.8ms 偶发）；滚动无辜（p95 2.6ms，满 120fps）。

## 决策

**把 super_editor 0.3.0-dev.40 逐字拷入 `frontend/third_party/super_editor/`（lib/ + pubspec +
LICENSE），`pubspec.yaml` 以 `dependency_overrides` path 指向它，补丁面 = 布局管线三个文件**，
做节点级脏标记（当前形态见 `references/frontend/features/documents.md` 编辑器节）：

| 被补丁文件 | 补丁内容 |
|---|---|
| `layout_single_column/_presenter.dart` | 核心：`DocumentChangeLog` 事件归账（fail-safe：空/未知事件=全量脏）→ 脏半径扩张（4 条依赖边）→ 基底 vm 按节点缓存复用 → 五相**子集喂入+与缓存合并**（相输出增删 vm 即契约违约、落回全量）；相基类加节点级脏通道 `markDirtyNodes`；`AnPresenterFlags`（增量总闸 + `debugVerifyAgainstFullRebuild` 自校验）+ `AnPresenterMetrics` 工作量计数器 |
| `layout_single_column/_styler_user_selection.dart` | 选区监听从 `markDirty`（整相）改为上报节点级脏（旧选区∪新选区的节点）；陈旧选区指向已删节点时 fallback 整相脏 |
| `layout_single_column/_styler_composing_region.dart` | 组字区监听同上（旧区∪新区）；**null↔非null 转换必须整相脏**——上游 `style()` 在有组字区时给**全文档**每个 text vm 盖 `showComposingRegionUnderline=true`（全局印章、非节点局部），差分 rig 抓出的真分歧。组字中逐键（非null→非null，CJK 热路径）保持节点级 |

**为什么选区/组字两相必须一起补**：这两相每键都脏（光标动/IME 组字动），presenter 若不知道
它们各自影响哪些节点，每键仍要整相 O(文档) copy——只补 presenter 治不了按键成本。

## 为什么只能 vendor（备选全部排除）

| 备选 | 为什么不行 |
|---|---|
| 参数/配置 | presenter 在 `super_editor.dart:620` **硬构造**，无注入缝 |
| 升级上游 | dev.41–52 `_presenter.dart` **md5 恒同**（12 版 7 个月未动）；上游无节点级脏标记的 issue/PR/路线 |
| 自建类放本仓 | SuperEditor 内部 new 的是它自己的类，自建类永远不被使用 |
| 给上游提 PR | 钉死 dev.40 拿不到；且上游节奏不可依赖 |

## 已知跨节点依赖边（脏半径的物理依据，四条）

1. **后继看前驱**：`.after()` 样式选择器 / 标题上距（前块也是标题则收紧）/ 引用延续（前块是引用）
   → 变更节点的**现后继**入脏集；
2. **删除/移动的旧位现任**：旧位置上的现节点换了前驱 → 按上趟序快照找旧位后继入脏集；
3. **有序列表序号**：ordinal 数上方连续列表项 → 沿每个脏节点**向下扫连续列表段**入脏集；
4. **首末与计数**：`.first()`/`.last()` 选择器 + 单节点 hint（读 nodeCount）→ 结构变更时新旧首末入脏集。

## 代价与缓解

- **仓库 +3.2MB 源码**：只拷 `lib/`（16MB 包中 13MB 是 example/test/goldens，不拷）。
- **升级时要重放补丁**：三个被改文件上游 dev.41–52 恒同 → 预期零冲突；diff 对 pub 原件
  即是完整补丁清单（vendor 落库为独立提交，紧随其后的手术提交即补丁本体）。
- **fork 漂移**：除上表三文件外**逐字同 pub**，禁止顺手改其它文件——需要改的走既有
  vendor-单文件先例（`an_editor_text_component.dart` 式门面复制），不动 third_party。
- **lint 豁免**：`third_party/**` 不受本项目 lint 约束（`analysis_options.yaml` exclude），
  编译器仍全量类型检查。

## 正确性护栏（bug free 的实体）

1. **自校验开关**：`AnPresenterFlags.debugVerifyDefault`——增量算完在 assert 里按上游方式
   全量重算逐字段比对（含 textStyleBuilder 的 style-probe——vm 的 `==` 刻意跳过闭包，陈旧
   样式表闭包能过 `==` 但真机渲错）；`test/flutter_test_config.dart` 全局开启 → **全部既有
   编辑器测试自动变差分测试**；release 剥 assert 零成本；
2. **差分 rig**（`test/core/editor/an_presenter_differential_test.dart`）：同文档同 composer
   双 presenter（全量 oracle vs 增量，管线各自独立实例——共享会把单槽 dirtyCallback 静默改挂），
   脚本步逐依赖边打 + 种子化随机 fuzz（失败打印种子+步数可逐字复现）；
3. **fail-safe 层层兜底**：空/未知 change log（`MutableDocument.reset()`）→ 全量脏；相在子集
   下增删 vm / 缓存缺节点 → 本趟落回全量；陈旧选区/组字区 → 整相脏；
4. **O(变更) 守卫测**（防回归棘轮）：200 段文档打一键 `baseVmCreates ≤ 8`、`phaseVmStyled ≤ 40`；
   光标移动 rebuild=0、restyle ≤ 4——回归重引入 O(文档)/键即报警。
