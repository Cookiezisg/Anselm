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

**术后 A/B**（0716，同机同 profile 构建同探针，STRESS-400 真机打字）：

| 指标 | 术前 | 术后 |
|---|---|---|
| 打字 build（400 段，28 键/s） | 5–9ms/键，**每键 JANK** | **p95 3.0–3.1ms，max 3.4ms，零 JANK** |
| 打字 build（400 段，60 键/s 极限） | — | p95 3.1ms，max 3.5ms，零 JANK，满 120fps |
| GC 尖峰 | ConcurrentMark ~10ms | **消失**（探针无 >3.5ms 帧） |
| 打字 build（小文档） | ~1ms | p95 0.8ms（零回归） |

术后 ~3.1ms/键 = **平台地板**（恰等于 Phase 0 测得的 macOS 合线程 IME 派发 p95 3.07ms），
再往下要动 Flutter engine 线程模型、非本层可为。已知残留：**开文档首帧 ~70ms**（400 段
真实文本首次排版的一次性 hitch，与打字路径无关、术前同类成本已记录接受；根治要编辑器
布局懒化，超出本 ADR 范围）。

## 决策

**把 super_editor 0.3.0-dev.40 逐字拷入 `frontend/third_party/super_editor/`（lib/ + pubspec +
LICENSE），`pubspec.yaml` 以 `dependency_overrides` path 指向它，补丁面 = 四个文件**，
做节点级脏标记（当前形态见 `references/frontend/features/documents.md` 编辑器节）：

| 被补丁文件 | 补丁内容 |
|---|---|
| `layout_single_column/_presenter.dart` | 核心：`DocumentChangeLog` 事件归账（fail-safe：空/未知事件=全量脏）→ 脏半径扩张（4 条依赖边）→ 基底 vm 按节点缓存复用 → 五相**子集喂入+与缓存合并**（相输出增删 vm 即契约违约、落回全量）；相基类加节点级脏通道 `markDirtyNodes` + **`styleIsStructureDependent` 声明**（结构变更趟对声明相强制整相，治 C1）；**空 carry 长度守卫**（纯删除趟脏半径全死时落回全量，治 C2 幽灵 vm）；**趟中标脏 tripwire assert**（相 style() 若有 notifier 副作用其脏会被吞且增量不自愈——今日五相皆纯，assert 钉死）；`AnPresenterFlags`（增量总闸 + `debugVerifyAgainstFullRebuild` 自校验）+ `AnPresenterMetrics` 工作量计数器 |
| `layout_single_column/_styler_user_selection.dart` | 选区监听从 `markDirty`（整相）改为上报节点级脏（旧选区∪新选区的节点）；陈旧选区指向已删节点时 fallback 整相脏；`styleIsStructureDependent=true`（**C1**：「我在选区里吗」取决于节点序与存在性——裸删节点[如右键删表]翻别的节点的答案而选区值/监听不动，对抗复审探针实锤的静默渲错） |
| `layout_single_column/_styler_composing_region.dart` | 组字区监听同上（旧区∪新区）；**null↔非null 转换必须整相脏**——上游 `style()` 在有组字区时给**全文档**每个 text vm 盖 `showComposingRegionUnderline=true`（全局印章、非节点局部），差分 rig 抓出的真分歧。组字中逐键（非null→非null，CJK 热路径）保持节点级；`styleIsStructureDependent=true`（与选区同族的结构依赖） |
| `core/editor.dart` | **undo 毒径标记**（差分 fuzz 扩容后抓出的第二个真分歧）：`Editor.undo()` = `MutableDocument.reset()` 回快照 + 重放全史，事务结束发出的 changeLog 事件描述的是**重放过程**而非 undo 前后差——节点级归账被结构性欺骗。修法：`MutableDocument` 的 `_didReset` 事实带进 changeLog 本体（新哨兵事件 `DocumentWasResetChange` 前置入 log），presenter 的 unknown-event fail-safe 自动接住→全量重建；不看事件类型的消费者（全部核查过）不受影响 |

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
- **升级时要重放补丁**：布局管线三文件上游 dev.41–52 恒同 → 预期零冲突；`core/editor.dart`
  未验证跨版稳定（大文件、上游活跃），但其补丁=两个锚点极小的 hunk（独立哨兵类 + 单方法
  一处改），冲突也能秒重放。diff 对 pub 原件即是完整补丁清单（vendor 落库为独立提交，
  紧随其后的手术提交即补丁本体）。
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
   脚本步逐依赖边打（含定向 heading-gap 前驱翻转 + 表格整节点替换）+ 种子化随机 fuzz
   （16 类操作：打字/删段/块型/增删移/选区/组字/跨节点删/Enter 分段/划选加粗/undo·redo/
   码块·表格替换；失败打印种子+步数可逐字复现）；样式探针含表格逐 cell（表 vm 的 `==` 跳闭包）；
3. **fail-safe 层层兜底**：空/未知 change log → 全量脏（undo 的 `DocumentWasResetChange`
   哨兵即由此接住）；相在子集下增删 vm / 缓存缺节点 / 纯删除趟脏半径全死 → 本趟落回全量；
   陈旧选区/组字区 → 整相脏；结构变更趟 → 结构依赖相（选区/组字）整相；
4. **O(变更) 守卫测**（防回归棘轮）：200 段文档打一键 `baseVmCreates ≤ 8`、`phaseVmStyled ≤ 40`；
   光标移动 rebuild=0、restyle ≤ 4——回归重引入 O(文档)/键即报警；
5. **对抗复审战果**（双复审员，0716）：测试网复审=突变实验 3/3 击杀（4/4/32 测炸、零假绿）+
   表格双盲/heading-gap 定向步/16 类 fuzz 补强；算法复审=C1（裸删选区端点滞留高亮）/C2
   （删空文档幽灵 vm）两个探针实锤真分歧，修法入上表，rig 各有定向复现测且**突变验证过会咬**
   （移除修复→测试炸）。

## 增量前提立法（未来演化必读）

- **禁用 `BlockSelector.before()` / `atIndex(k)`**：脏半径四边全部向下传播+首末，覆盖不了
  「读后继」与「按绝对序号」的选择器。An 样式表现零使用；要用必须先给脏半径补对应边
  （成文于此，违者=静默渲错）。
- **事件忠实度是新地基**：上游全量模式下 command 漏报/错报事件会被后续任意重建捎带自愈；
  增量下漏报=永不修复（undo 毒径即此类）。新增/自定义 `EditCommand` 必须让 `DocumentChangeLog`
  精确描述其文档改动；不能精确描述的（快照式/批量式）必须发 `DocumentWasResetChange` 类哨兵。
- **相 style() 必须纯**（无 notifier 副作用）——趟中标脏会被吞且增量不自愈；tripwire assert 在守。
- **新相若读文档结构**（节点序/存在性/计数）必须 override `styleIsStructureDependent=true`。
