/// Theme-INVARIANT design tokens — geometry + time values that don't change between light and
/// dark (colors live in [AnColors], a ThemeExtension, so they can lerp). Three self-consistent
/// maths keep every surface dimensionally coherent: density = 4-grid, layout = 2:3:6 harmonic
/// columns, motion = a small fixed duration/easing set. NEVER inline a raw px/ms — read a token.
///
/// 主题无关 token:明暗不变的几何/时间值(会变的色在 [AnColors])。三套自洽数学(密度=4 网格 ·
/// 布局=2:3:6 谐波列 · 动效=固定时长/缓动)保证全局尺寸一致——绝不内联裸 px/ms。
library;

import 'package:flutter/widgets.dart';

/// Spacing scale (4-grid). Value-named to stay unambiguous at call sites.
/// 间距阶梯(4 网格)。值命名,调用处零歧义。
abstract final class AnSpace {
  static const double s0 = 0; // explicit zero (beats a magic 0 literal) 显式零
  static const double s2 = 2;
  static const double s4 = 4;
  static const double s6 = 6; // gap-tight: low-weight inline gap (icon↔label, dot↔label) 紧凑行内间距
  static const double s8 = 8; // inline gap + the shell's island padding/gap 行内间距 + 岛内距/间距
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s48 = 48;
  static const double s64 = 64;
}

/// SEMANTIC spacing tier (mirrors [AnRadius]) — the raw [AnSpace] scale names VALUES; these three
/// classes name ROLES over it, so the SAME relationship renders at ONE value everywhere. Widget code
/// reads these, never `AnSpace.sN` directly (which is reserved for these definitions). A retune of one
/// role changes one line product-wide. 语义间距层:按角色命名(非尺寸),同一种关系全产品一个值;组件读这层、
/// 不直接读 AnSpace.sN。
///
/// Gaps BETWEEN two sibling elements (no surface fill between them). 兄弟元素间的间距。
abstract final class AnGap {
  static const double inlineHair = AnSpace.s2; // flush to a 1px border/badge; label→hint micro-pair 贴边微对
  static const double inline = AnSpace.s6; // DEFAULT icon↔label inside a compact control (button/badge/dropdown/tab/chip) 紧凑控件内 icon↔label
  static const double inlineLoose = AnSpace.s8; // row lead↔label, control↔control in a toolbar 行首↔标签 / 工具条控件间
  static const double stackTight = AnSpace.s4; // bound vertical pair (label over its field); dense li↔li 绑定纵对 / 密集列表项
  static const double stack = AnSpace.s8; // item↔item in a menu/list group 菜单/列表项间
  static const double block = AnSpace.s12; // DEFAULT gap between stacked blocks/cards/turns (the house unit) 块/卡/回合间(主单位)
  static const double section = AnSpace.s24; // titled section ↔ titled section 有题段落间
  static const double region = AnSpace.s32; // major page region ↔ region (rare) 大区块间(罕用)
}

/// Padding INSIDE a surface — a density ladder; pick the rung by surface class. 表面内 padding(密度阶梯)。
abstract final class AnInset {
  static const double denseRowV = AnSpace.s4; // dense field/KV row vertical floor 密集行纵向下界
  static const EdgeInsets tight = EdgeInsets.symmetric(horizontal: AnSpace.s8, vertical: AnSpace.s4); // dense card / toast
  static const EdgeInsets snug = EdgeInsets.symmetric(horizontal: AnSpace.s12, vertical: AnSpace.s8); // callout / medium alert
  static const EdgeInsets card = EdgeInsets.symmetric(horizontal: AnSpace.s16, vertical: AnSpace.s12); // standard bordered card / dialog body
  static const EdgeInsets bubble = EdgeInsets.symmetric(horizontal: AnSpace.s16, vertical: AnSpace.s8 + AnSpace.s2); // chat user bubble around the 15/1.6 reading line (16h/10v — the s12/s8 machine inset reads pinched at 24px lines) 用户泡内距(15 阅读行盒配比)
  static const double island = AnSpace.s8; // island outer pad + inter-island gap (= AnSize.shellPad) 岛内距 + 岛间距
  static const double pageX = AnSpace.s24; // reading-column horizontal pad 阅读列水平内距
  static const double pageBottom = AnSpace.s48; // trailing scroll runway 尾部滚动余量
}

/// Prose vertical rhythm — the reading column + markdown flow, tied to the body line box. Headings are
/// ASYMMETRIC (more space above than below — they belong to the content below). 阅读列/markdown 垂直节奏,
/// 与正文行盒挂钩;标题上下不对称(上留多、下贴内容)。
abstract final class AnFlow {
  static const double listItem = AnSpace.s4; // li ↔ li 列表项间
  static const double block = AnSpace.s12; // ONE markdown/prose block gap (para↔para/code/table/quote/list) 唯一块间距
  static const double headBody = AnSpace.s12; // section heading → its body (default) 段标题→正文
  static const double headBodyTight = AnSpace.s8; // faint-meta title → body 淡 meta 标题→正文
  static const double headBodyDense = AnSpace.s6; // quiet/collapsible header → body 静默/折叠头→正文
  static const double headingTop = AnSpace.s24; // h2 space-ABOVE (own the block below) h2 上方留白
  static const double subheadingTop = AnSpace.s16; // h3 space-above h3 上方留白
}

/// HANGING INDENT tier (批7 B 轨) — a wrapped/second line aligns under the text that follows a lead
/// marker, so the indent = marker slot + its inline gap. Named by MARKER so feature code never sums
/// tokens (grammar #4): a dot-led hang is [dot], an icon-led hang is [icon]. The row family's OWN
/// expandChild indent stays primitive-internal (iconSm-cell, AnLedgerRow).
/// 悬挂缩进档:换行/次行对齐到 lead 记号后的文字——缩进=记号槽+行内距。按记号命名,feature 层不再
/// token 算术;行族披露体缩进仍原语自持。
abstract final class AnIndent {
  static const double dot = AnSize.dot + AnGap.inline; // 13 — dot-led hang (thinking rail, emit rows) 点式悬挂
  static const double icon = AnSize.icon + AnGap.inline; // 22 — icon-led hang (tool-card bodies) 图标式悬挂
}

/// Corner radii (4-grid). Each tier maps to a surface class: tag→button→chip→card→island.
/// 圆角(4 网格)。每级对应一类表面。
abstract final class AnRadius {
  static const double tag = 4;
  static const double button = 8;
  static const double chip = 12;
  static const double card = 16;
  static const double island = 20;
  static const double pill = 999;
}

/// Sizes — control heights, icon slots, the 2:3:6 layout columns, the window envelope, and the
/// window-controls reserve. 尺寸——控件高、图标槽、2:3:6 布局列、窗体外廓、窗控留位。
abstract final class AnSize {
  // Density anchors. 密度锚。
  static const double row = 32; // standard row height (the one) 标准行高(唯一)
  static const double control = 28;
  static const double controlSm = 24;
  static const double tab = 34; // AnTabs text-underline tab height — INTENTIONALLY 2px over row (half-u), a bespoke nav metric (demo --tab-h) 文字下划线 tab 高(有意比 row 高 2px、半 u)
  static const double icon = 16;
  static const double iconSm = 12;
  static const double iconLg = 20;
  static const double iconXs = 8; // sub-row trajectory glyph (subagent tail rows — below iconSm) 次级尾行字形(iconSm 之下)
  static const double dot = 7;
  static const double dotPulse = 5; // run-status breath expansion radius 呼吸外扩半径
  static const double dotSm = 5; // small dot tier (in-chip op ticker, cast pulse, channel dot) 小点档(芯片内/主角点/频道点)
  static const double swatch = 10; // colour swatch dot (workspace colour) 色板圆点(工作区色)
  static const double capsulePadY = 1; // inline baseline-capsule hair inset (v-pad + h-breathing margin) 行内药囊发丝距(竖内距+横呼吸边距)
  static const double hairline = 1;
  static const double gripLine = 2; // drag-handle hover divider (2× hairline) 拖柄悬停分隔线
  static const double ring = 1.5; // thin stroke tier (badge halo, canvas connect handle, mini-graph edge) 1.5 细描边档(强调环/接柄/mini 图边)
  static const double glyphStroke = 1.2; // drawn-glyph side (editor task checkbox — optically matches the icon face's stroke) 手绘字形描边(编辑器任务框,光学对齐图标字面)
  static const double caret = 1.5; // text caret width 文本光标宽
  // Text caret height is DERIVED, never fixed: fontSize + caretRise, so the cursor hugs whatever
  // style the field renders (13→16 exactly the old constant; 15→18; an H2-24 rename→27). A fixed
  // 16 left a stubby caret beside big glyphs. 光标高按有效样式推导(fontSize+caretRise),13→16 与旧
  // 常量一致;定值 16 在大字旁显得矮短。
  static const double caretRise = 3;
  static const double caretEndPad = 3; // end-of-line caret room (caret width + a hair) so the last glyph isn't clipped under the cursor (flutter#24612) 行尾光标留位(光标宽+一丝)

  // Primitive control metrics (the demo's PRIMITIVE METRICS group). 原语控件度量。
  static const double btnPadX = 14; // text-button horizontal optical pad 文本钮水平光学内距
  static const double btnPadXSm = 10; // small-button horizontal pad 小钮水平内距
  static const double badge = 22; // status/tag badge visual height 徽章视觉高度
  static const double badgePadX = 9; // badge horizontal pad 徽章水平内距
  static const double inputMin = 180; // single-line input min width 单行输入最小宽
  static const double inlineEditMin = 32; // in-place edit field min width — an empty seamless field has ~0 intrinsic width and would be un-clickable 就地编辑框最小宽(空 seamless 框固有宽≈0、否则不可点)
  static const double editBoxPadX = 8; // in-place edit FRAME horizontal pad (demo .v.editing padding-x=--sp-2): left bleeds over slack (text anchored), right is real growth 就地编辑框横向内距(左溢出、右真占位)
  static const double editBoxPadY = 4; // edit-frame vertical pad — layout-compensated to add NO row height (demo --grid, cancelled by negative margin) so the box bleeds over the fixed row's slack 编辑框纵向内距(布局补偿、不加行高,溢出到固定行余量)
  static const double stateIcon = 40; // AnState placeholder glyph — larger than iconLg(20), distinct from control icons 状态占位大字形
  static const double stateMaxWidth = 360; // AnState centered content column max width (short lines stay readable) 状态内容列最大宽
  static const double stepCurrent = 18; // AnStepper elongated current-dot width (done/upcoming use dot=7) 步进器当前点拉长宽
  static const double skeletonLine = 12; // AnSkeleton text-line bone height (≈ a body text line box) 骨架文本行骨高
  static const double tagRemoveHit = 18; // AnTags remove-× min hit target (avoids fat-finger mis-delete) 标签移除×命中区
  static const double block = 280; // inspector 2-col min track + badge max-width 检查器列 + 徽章最大宽
  static const double menuMinWidth = 200; // dropdown/menu min width (rich rows fit even off a compact trigger) 菜单最小宽(紧凑触发器也容得下富行)
  static const double menuMaxWidth = 360; // dropdown/menu popover max width 菜单浮层最大宽
  static const double menuMaxHeight = 320; // dropdown/menu popover max height (then scrolls) 菜单浮层最大高(超则滚)
  static const double toastMaxWidth = 360; // toast single-row max width (demo --island-w) — a SEPARATE token from menuMaxWidth/stateMaxWidth (same 360 value, distinct semantic axis: a retune of one must not drag the others) toast 单条最大宽(语义独立,勿与菜单/状态列共号)
  static const double tagFieldMaxWidth = 360; // inline tag add-field cap — its own axis (same 360, NOT the menu axis) 标签就地输入宽上限(独立轴,勿与菜单共号)
  static const double jsonViewport = 240; // tool-card JSON-tree window height (then scrolls) tool 卡 JSON 树视口高(超则滚)
  static const double codeViewport = 320; // live/settled bounded code viewport (transcript contexts) 代码有界视口(transcript 语境两脸同钳)
  static const double codeViewportSm = 160; // nested/secondary code viewport ≈8 code lines (handler rack spines stay scannable) 嵌套次级代码视口≈8 行(方法架书脊可扫读)
  static const double proseClamp = 144; // live prose tail bottom-pinned clamp ≈6 reading lines (WRK-066 族六) 活散文尾贴底钳高≈6 阅读行
  static const double proseViewport = 340; // settled prose/markdown window collapse height (ProseWindow / MemoryNoteCard, WRK-066 族一) 落定散文窗折叠高
  static const double proseStage = 220; // sidestage live prose tail fill height (document stage) 侧幕活散文尾填充高
  static const double proseStageFail = 260; // sidestage failed-hold prose rescue viewport 侧幕失败救援散文视口
  static const double inspectorMetaCol = 72; // right-island meta-row label column (Path/Size/Modified) 右岛元数据行标签列宽

  // Sent-attachment surfaces (chat user bubble). 已发送附件面(用户泡)。
  static const double attachCard = 248; // file card fixed width (fits name + TYPE·SIZE meta) 文件卡定宽
  static const double attachBodyH = 35; // card body height (28 icon tile vs name+meta lines maxed) — the resolving skeleton pins to it so the card can't shift on resolve 卡体高(骨架同高、解析落地不位移)
  static const double thumbTile = 96; // multi-image square tile 多图方瓦片
  static const double thumbMaxW = 280; // single-image bound (= block) 单图宽上限
  static const double thumbMaxH = 240; // single-image height cap (10 reading lines, keeps the column calm) 单图高上限(10 阅读行)

  // Code-surface line-number gutter FLOOR (G5). The demo's --trail=20px holds only ~2 digits at the
  // mono code size; widgets compute the gutter dynamically (digit count × mono advance + pad) and
  // clamp to >= this floor (≥4 digits, so files into the thousands don't blur). 行号槽下界(动态计宽夹到此).
  static const double trail = 36;

  // Embedded graph-preview frame height (demo --h-graph-preview) — AnGraphCanvas[framed] on entity
  // pages. 实体页内嵌编排图框定高。
  static const double graphPreview = 380;

  // Run-cockpit metrics (demo --run-list-w / --lane-w) — the AnRunBoard run-list column + the
  // AnNodeGantt label lane. 驾驶舱度量:run 列表列宽 + 甘特标签列宽。
  static const double runListW = 208;
  static const double ganttLaneW = 132;

  // Editor-inspector field metrics — the field→CEL input-map key column + the small numeric field
  // (retry max-attempts). 检查器字段度量:输入映射 key 列 + 小数字输入框(retry 次数)。
  static const double inspectorKeyCol = 96;
  static const double inspectorNumField = 72;

  // Settings form metrics (批7 B 轨定档 — absorbs the panels' scattered literals). 设置表单度量档。
  static const double formMaxWidth = 480; // field-stack form reading column (network/keys/ws/sandbox/mcp) 字段栈表单列
  static const double formMaxWidthWide = 640; // long-text / paste editing surface (memory editor, JSON import) 长文编辑面
  static const double ctlSlot = 240; // standard control slot (2-seg segmented, dropdowns) 标准控件槽
  static const double ctlSlotLg = 320; // wide control slot (3+-seg segmented, model dropdowns) 宽控件槽
  static const double ctlSlotXl = 380; // extra-wide slot (long-label 3-seg: «streamable-http») 特宽槽(长标签三段)
  static const double numField = 140; // standalone numeric input (limits values) 独立数字输入
  static const double tabPane = 480; // settings tab-pane fixed height (mcp/sandbox aligned, 批7 拍板) tab 面板定高
  static const double followSlop = 32; // ≈one row from the bottom still counts as pinned-to-tail 贴底判定容差(≈一行)
  static const double opticalNudge = 1; // 1px optical baseline nudge (icon-beside-text rows) 光学微调(图标旁基线)

  // Chat scene-strip (toc) popover — its own axis beside menuMaxWidth. 场次条浮层(独立轴)。
  static const double tocPaneMaxHeight = 560;
  static const double tocPaneWidth = 340;

  // In-card embedded graph stage height (workflow tool cards / stages — smaller than the entity
  // page's graphPreview). 卡内嵌图台高(小于实体页 graphPreview)。
  static const double graphStage = 200;

  // Editor toolbar link-input width. 编辑器划选条 URL 输入宽。
  static const double linkField = 280;

  // Inline count heat-bar FULL width (grep count rows — the bar scales inside this bound). NOT AnMeter
  // (a full-width 6px quota meter with warn/danger thresholds — a different role than a trailing-slot
  // relative-heat sliver). 行尾计数热力条满宽(条在此界内按占比缩放);非 AnMeter(整行配额表,角色不同)。
  static const double heatBar = 40;

  // Three-island layout columns. The LEFT island is elastic (draggable, 240–400, default 320);
  // the RIGHT island is fixed; the ocean is the flex remainder whose content column is elastic
  // 480–720 (`oceanMin`..`content`). 三岛列:左岛弹性(可拖 240–400,默认 320);右岛固定;
  // 海洋取余量、内容列弹性 480–720。
  static const double sidebar = 320; // left island default 左岛默认
  static const double sidebarMin = 240; // left island min (drag) 左岛最小
  static const double sidebarMax = 400; // left island max (drag) 左岛最大
  static const double rightIsland = 320; // right island default 右岛默认
  static const double rightIslandMin = 280; // right island min (drag) 右岛最小
  static const double rightIslandMax = 640; // right island max (drag; ocean floor still wins) 右岛最大(海洋保底优先)
  static const double content = 720; // 6u · ocean content column MAX (centers when wider) 内容列最大(更宽则居中)
  static const double oceanMin = 480; // ocean content column MIN (elastic 480–720) 内容列最小(弹性 480–720)
  static const double islandHead = 44; // floating header height 浮动头高

  // The macOS title-bar band the OS vertically CENTERS the traffic lights in (≈ titlebar/2 = 26 from the
  // window top). The shell's top controls (collapse / breadcrumb / panel toggle) align their CENTER to 26
  // so they sit on the lights' line. = macos_ui's ToolBar _kToolbarHeight. NOTE (real-run verified, research
  // wf w2ah4v0ll): macos_window_utils' getTitlebarHeight() returns the FULL title+toolbar band (~66) which
  // OVER-shoots — the lights center in this 52 title-bar portion (26), not the full band (33), so we use the
  // verified constant, not the runtime query. 红绿灯居中带(灯心≈26);顶控对齐到 titlebar/2;getTitlebarHeight 返全带 66 会偏低,故用此验证常量。
  static const double titlebar = 52;

  // Shell envelope: 8px padding around the islands + 8px gaps between them.
  // 壳外廓:岛四周 8px 内距 + 岛间 8px 间距。
  static const double shellPad = AnSpace.s8;
  static const double shellGap = AnSpace.s8;

  // Window minimum — in LOGICAL POINTS. Sized to GUARANTEE the ocean keeps its minimum content
  // column (`oceanMin` = 480) even with the left island dragged to its MAX (worst case):
  // pad + sidebarMax(400) + gap + oceanMin(480) + gap + rightIslandMin(280) + pad = 1192. Min HEIGHT
  // = golden-ratio complement. Comfortably fits a 1512pt laptop with margin.
  // 窗口最小(逻辑点):保证即便左岛拖到最大(worst case)、海洋仍有最小内容列 480 =
  // 8+400+8+480+8+320+8 = 1232。高=黄金比例补。1512 屏上留有余量。
  static const double goldenRatio = 1.618;
  static const double windowMinWidth =
      shellPad + sidebarMax + shellGap + oceanMin + shellGap + rightIslandMin + shellPad; // 1192
  static const double windowMinHeight = windowMinWidth / goldenRatio; // ≈ 761
  static const double windowInitialWidth = 1280; // comfortable default, margin on a 1512pt screen 舒适默认、留余量
  static const double windowInitialHeight = windowInitialWidth / goldenRatio; // ≈ 791

  // The left-island chrome bar reserves this horizontal room for the macOS traffic lights, which
  // the OS draws/centers in the (taller) title bar — see window_setup (addToolbar). The lights'
  // VERTICAL position is OS-managed (click-safe); we never reposition the native buttons.
  // 左岛 chrome 条给红绿灯留此横向位;灯由 OS 在(加高的)标题栏绘制居中(见 window_setup 的 addToolbar),
  // 纵向位置 OS 托管、点击安全;绝不手动挪原生按钮。
  static const double windowControlsInset = 72;
}

/// Content caps — how many CHARACTERS a machine window materializes per frame/page (grammar #5:
/// display caps are tiers, not scattered literals). The full text stays in memory; caps bound what
/// LAYOUT sees. 内容封顶档——机器窗单帧/单页物化的字符上限(文法 #5:封顶走档,不散置裸数)。全文仍在
/// 内存,封顶只约束进 layout 的量。
abstract final class AnCap {
  static const int window = 6000; // machine-window materialization cap (live tails, term scrollback pages) 机器窗物化上限
  static const int proseFoldChars = 480; // prose window collapse gate: chars (WITH proseFoldLines) 散文窗折叠阈:字符
  static const int proseFoldLines = 10; // prose window collapse gate: newlines 散文窗折叠阈:行
  static const int noteFoldChars = 900; // memory-note collapse gate (short notes render whole) 记忆笺折叠阈
  static const int receiptTail = 4000; // collapsed tool-row receipt/result tail budget (chat_tool_card raw peek) 收起行回执/结果尾预算
  static const int stderrTail = 8192; // dossier log drawer's MCP server-stderr sibling-window budget 卷宗日志抽屉 stderr 同胞窗预算
  static const int logHead = 2000; // log drawer double-ended cap: head half (tail is the diagnostic end) 日志双端截断:头半
  static const int logTail = 4000; // log drawer double-ended cap: tail half (last yields/stderr/dying output) 日志双端截断:尾半
}

/// Opacity tokens — the few semantic alpha values used as whole-widget dimmers. 整件透明度语义值。
abstract final class AnOpacity {
  static const double disabled = 0.4; // dimmed disabled controls 禁用控件变暗
  static const double shadow = 0.12; // floating-pill soft shadow ink 浮丸柔影墨
  static const double dragDim = 0.35; // the row being drag-reordered (source ghost) 拖拽重排源行变暗
  static const double stratum = 0.4; // a faded prior/inactive layer (R-5 sidestage stratum) 淡化的旧/静置层
  static const double sending = 0.55; // an optimistic in-flight turn (visible but tentative) 乐观在途回合
  static const double veil = 0.85; // full-surface veil that must still hint at content beneath (drop overlay) 全面纱(微透底)
}

/// Motion — durations + easing. fast = hover, mid = reveals, slow = island slides; breath is
/// the run-status pulse. 动效:fast 悬停 / mid 揭示 / slow 岛屿滑动;breath 运行呼吸。
abstract final class AnMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration mid = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 340);
  static const Duration breath = Duration(milliseconds: 1800);

  // Delay before a loading skeleton/indicator is shown — a sub-threshold async (the common case for a
  // local sidecar) resolves first, so the indicator never flashes (appear-then-instantly-vanish).
  // 加载骨架/指示器显示前的延迟:亚阈值异步(本地 sidecar 常态)先返回,指示器不闪烁。
  static const Duration loaderDelay = Duration(milliseconds: 160);

  // Dwell-to-act delay — hovering a drop target this long triggers its secondary action (a collapsed
  // sidebar group expands under the dragged row). 悬停驻留触发时长(拖拽悬停展开折叠组)。
  static const Duration dwell = Duration(milliseconds: 600);

  // AnTypewriter cadences. 打字机节奏。
  static const Duration typePerChar = Duration(milliseconds: 55); // per-grapheme reveal 每字素揭示
  static const Duration deletePerChar = Duration(milliseconds: 28); // delete (faster than typing) 删除(快于打字)
  static const Duration typeHold = Duration(milliseconds: 1400); // pause at a full phrase 满句停顿
  static const Duration typeGap = Duration(milliseconds: 400); // blank gap before the next phrase 换句空隙

  // Debounce tiers (批7 B 轨) — RESPONSE classes, not animation lengths: inline typeahead must feel
  // attached to the keystroke; list filtering may lag a beat; autosave waits for the pause.
  // 防抖档——响应级而非动画时长:行内预输入要贴手,列表过滤可缓半拍,自动存等停顿。
  static const Duration typeahead = Duration(milliseconds: 150); // @-mention / inline completion 行内预输入
  static const Duration searchDebounce = Duration(milliseconds: 250); // rail search filtering rail 搜索过滤
  static const Duration autosave = Duration(milliseconds: 600); // document/frontmatter autosave 文档自动存

  // Long one-shot / loop tiers (批7). 长一次性/循环档。
  static const Duration wash = Duration(milliseconds: 2200); // deep-jump highlight wash (W6 编舞值) 深跳洗亮
  static const Duration stagger = Duration(milliseconds: 30); // list cascade per-row offset 级联逐行错峰
  static const Duration revealCap = Duration(milliseconds: 3000); // content-scaled reveal HARD CAP 内容揭示总长封顶
  static const Duration travel = Duration(milliseconds: 1100); // live-edge comet circuit (≠breath) 活边彗星巡回
  static const Duration toast = Duration(seconds: 4); // UI-feedback toast (user present) 操作反馈 toast
  static const Duration toastLong = Duration(seconds: 8); // event-notification toast (user may be away) 事件通知 toast
  static const Duration elapsedReveal = Duration(seconds: 3); // running tool card starts showing its ticking elapsed 运行卡读秒登场阈

  static const Cubic easeOut = Cubic(0.16, 1, 0.3, 1);
  static const Cubic spring = Cubic(0.2, 0.9, 0.25, 1);
}

/// Accessibility-driven motion gate — the single source every animated An* widget reads in build()
/// to decide whether to run. Uses the ASPECT accessors so a widget rebuilds only when the flag
/// flips, never on unrelated MediaQuery changes (NEVER read raw `MediaQuery.of(c).disableAnimations`
/// — over-rebuilds — and never per-platform detection). [reduced] gates FUNCTIONAL one-shot reveals;
/// [reducedOrAssistive] gates DECORATIVE loops (shimmer / caret blink / typewriter / breath pulse) —
/// continuous motion under an active screen reader is noise that competes with announcements.
///
/// 无障碍动效门控——每个动画 An* 件 build() 里读它决定要不要动。用 aspect 访问器(只在标志翻转时 rebuild)。
/// reduced 门控功能性一次性揭示;reducedOrAssistive 门控装饰循环(屏幕阅读器活跃时持续动效是噪声)。
abstract final class AnMotionPref {
  static bool reduced(BuildContext context) => MediaQuery.disableAnimationsOf(context);
  static bool reducedOrAssistive(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context);
}
