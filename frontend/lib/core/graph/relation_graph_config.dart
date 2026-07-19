import 'dart:math' as math;
import 'dart:ui' show Color;

import 'force_layout.dart';

/// THE single tuning surface for the Entities-Overview relationship graph (v2 「涟漪焦点星图」, 用户 0719
/// 拍板). Every number the visual read depends on lives HERE, one per line, commented — the palette hexes,
/// the node-radius band, the four force coefficients, the ripple decay table, the label thresholds, and the
/// fit margins. Rendering ([an_relation_graph.dart]) and layout ([force_layout.dart]) read these; NEITHER
/// carries a literal. 用户明言后续要反复微调大小/颜色 → 调参 = 改这一个文件的一行，渲染/布局零魔法数。
///
/// WHY a config file and not scattered consts (原则 #8 · 收敛律): the v1 graph wore the AnTone alert palette
/// (red/green/amber 提示色) and grew force + radius literals inside the widget — the user rejected it as
/// 「脏兮兮」 and 「挤成一团」, and every re-tune meant hunting numbers across three files. One file, one edit.
///
/// 关系图 v2 唯一调参面:雾彩色板 hex / 节点半径档 / 四力系数 / 涟漪衰减表 / 标签显隐阈值 / fit 边距,全部在此、
/// 逐项注释。渲染件与布局引擎只读这里,自身零字面量。
abstract final class RelationGraphConfig {
  // ── ① 雾彩色板 (kind 管色相 · 等明度低饱和 · 与 AnTone/AnStatus 提示色体系完全独立) ──────────────────
  //
  // Design intent (用户 0719 拍板): kinds differ by HUE only; all sit at roughly one lightness and a low
  // saturation so no dot ever screams. The core Quadrinity (wf/ag/fn/hd) carry real colour; the scheduler
  // family (trigger/control/approval) runs warm; the knowledge/equipment accessories (mcp/skill/memory/
  // document) sink toward grey — 外圈叶子安静、骨干有彩. conversation shares the document grey (pure
  // provenance). Intensity (near→far from focus) is the ORTHOGONAL ripple axis below, NOT baked into these.
  //
  // 意图:kind 只分色相、同明度低饱和;核心族有彩、调度族暖、知识装备族贴灰、对话同 document 灰。强度轴是下面
  // 正交的涟漪不透明度,不在这张表里。这些是「起点色」——用户要调随手改 hex。
  static const Color _workflow = Color(0xFF7B9BE8); // 雾蓝  core orchestrator
  static const Color _agent = Color(0xFFA88BE0); // 雾紫  core reasoner
  static const Color _function = Color(0xFF5FB3BC); // 雾青  core pure-fn
  static const Color _handler = Color(0xFF7FB694); // 雾绿  core side-effect
  static const Color _trigger = Color(0xFFD6A661); // 雾琥珀 scheduler
  static const Color _control = Color(0xFFD492A6); // 雾玫瑰 scheduler branch
  static const Color _approval = Color(0xFFDE9B7E); // 雾珊瑚 scheduler gate
  static const Color _mcp = Color(0xFF8CA3BC); // 钢蓝灰 equipment
  static const Color _skill = Color(0xFFB5A48F); // 暖褐灰 equipment
  static const Color _memory = Color(0xFFA79BB8); // 灰紫  knowledge
  static const Color _document = Color(0xFF9AA3AD); // 中灰  knowledge (+ conversation, unknown fallback)

  /// The fog hue for an entity KIND (backend wire string, lower-cased). Single source shared by the node
  /// dot, the legend chip and the explore right-island card; unknown / conversation → the document grey
  /// (open set, degrade quietly). kind→雾色,图内一切上色的唯一入口;未知/对话回落 document 灰。
  static Color fogColor(String wireKind) => switch (wireKind.toLowerCase()) {
        'workflow' => _workflow,
        'agent' => _agent,
        'function' => _function,
        'handler' => _handler,
        'trigger' => _trigger,
        'control' => _control,
        'approval' => _approval,
        'mcp' => _mcp,
        'skill' => _skill,
        'memory' => _memory,
        'document' || 'doc' => _document,
        'conversation' => _document,
        _ => _document,
      };

  // ── ④ 节点大小 (按入度钳窄幅 — 病根之一是 v1 区间太宽出「巨点」) ────────────────────────────────────
  static const double nodeMinRadius = 4.0; // in-degree 0 leaf 叶子最小
  static const double nodeMaxRadius = 7.0; // saturated hub 枢纽封顶 (窄幅,不再有巨点)
  static const int degreeCap = 6; // in-degree at which radius saturates 入度到此半径饱和

  /// The canvas-coloured halo stroke around every dot (Obsidian/Gephi 标准做法): a ~1.5px ring in the
  /// BACKGROUND colour LIFTS the node off the edge layer so a line passing near a dot doesn't visually
  /// stick to it. 节点画布色描边:~1.5px 背景色环把节点从边线层抬出来,边掠过不粘连。
  static const double nodeStroke = 1.5;

  /// Visual dot radius for a node of [inDegree] — a narrow [nodeMinRadius]→[nodeMaxRadius] band. 视觉点半径。
  static double nodeRadius(int inDegree) {
    final t = (inDegree.clamp(0, degreeCap)) / degreeCap;
    return nodeMinRadius + (nodeMaxRadius - nodeMinRadius) * t;
  }

  // ── ⑤ 标签盒保护 (碰撞力的第一道避让 — collision 半径把标签宽算进去,字不打架) ──────────────────────
  //
  // Kept MODEST on purpose: a collision radius that swallows the whole label half-width fights the spring
  // (it forces connected nodes apart past [ForceParams.idealLength] → long edges crossing empty space).
  // Far labels are hidden by the density cull below, so collision only needs to keep DOTS + the few visible
  // (focus/one-hop) labels apart. 刻意压小:碰撞半径若吞下整个标签半宽会跟弹簧打架(把相连点撑过理想边长→
  // 长边横穿空白);远处标签靠下面的密度裁隐藏,碰撞只需让点+少数可见(焦点/一跳)标签不打架。
  static const double labelCharWidth = 3.4; // est. px per glyph at meta(12) 每字估宽
  static const double labelMaxProtect = 24.0; // cap so a long name doesn't blow the field apart 保护上限
  static const double collisionPadding = 5.0; // breathing gap beyond the two radii 碰撞额外间隙

  /// The COLLISION radius the layout uses for a node — its visual dot radius grown to cover the (capped)
  /// label box so adjacent labels don't overlap. Fed to [ForceNode.radius]; the engine stays label-agnostic.
  /// 碰撞半径=视觉半径撑到盖住标签盒(半宽封顶),喂给引擎;引擎只认半径、不认字。
  static double collisionRadius(double visualRadius, String name) {
    final labelHalf = math.min(name.length * labelCharWidth * 0.5, labelMaxProtect);
    return math.max(visualRadius, labelHalf) + collisionPadding;
  }

  // ── ② 涟漪焦点衰减表 (色彩强度轴 · 与色相正交) ──────────────────────────────────────────────────────
  //
  // From the focus node, opacity falls off by GRAPH DISTANCE (hop count) — the hue never changes, only the
  // veil lifts. COMPRESSED (用户 0719 真机: the old 0.18 far tier vanished on-screen and jarred against the
  // solid near edges): the last tier stays ~0.32 so the 外圈 reads as「隐约有彩」, not gone. Index = hop;
  // past the last clamps to it. 焦点向外只降不透明度、不动色相;末档压到 ~0.32,远处隐约有彩而非消失。
  static const List<double> nodeOpacityByHop = [1.00, 0.80, 0.55, 0.32];

  /// Node fog opacity at graph distance [hop] from the current focus. 节点按跳数的不透明度。
  static double nodeOpacity(int hop) =>
      nodeOpacityByHop[hop.clamp(0, nodeOpacityByHop.length - 1)];

  // Edge veil by the NEARER endpoint's hop. ALL edges wear the FOCUS node's fog hue (never ink/black — 用户
  // 0719 真机「黑腿」禁令: contrast comes from LAYERING, not from darkening); the focus's own edges read
  // MEDIUM (~0.55), each ring fainter, unrelated edges a faint fog texture. 边全用焦点节点雾彩色相(全域禁
  // ink/黑,对比靠层次不靠加黑);焦点邻接边中等 ~0.55、逐跳更淡、无关边淡雾纹理。
  static const List<double> edgeOpacityByHop = [0.55, 0.40, 0.28, 0.16];

  /// Edge stroke opacity given the nearer endpoint's [hop]. 边不透明度(取较近端点跳数)。
  static double edgeOpacity(int hop) =>
      edgeOpacityByHop[hop.clamp(0, edgeOpacityByHop.length - 1)];

  static const double edgeWidth = 1.0; // resting stroke 静止边宽
  static const double edgeWidthFocus = 1.5; // focus-incident edge 焦点邻接边
  static const double edgeWidthHover = 2.0; // the one edge under the cursor 光标下那条
  static const double edgeHoverAlpha = 0.95; // hovered edge = focus fog at this alpha (NOT ink) 光标下=焦点雾彩此透明度

  // ── 焦点节点强化 (稍大一号 + 柔光环) ─────────────────────────────────────────────────────────────────
  static const double focusRadiusBonus = 2.0; // the focus dot grows by this many px 焦点点加大
  static const double focusGlowBlur = 12.0; // soft halo blur radius 柔光模糊
  static const double focusGlowSpread = 2.0; // soft halo spread 柔光外扩
  static const double focusGlowAlpha = 0.45; // halo = fog colour at this alpha 柔光=雾色此透明度
  static const double oneHopGlowAlpha = 0.22; // a gentler halo on the immediate ring 一跳更弱柔光

  // ── ③ 布局力系数 (四力 + 碰撞) ───────────────────────────────────────────────────────────────────────
  //
  // Handed to [ForceLayout] as ONE tuned [ForceParams]. BASELINE aligned to the d3-force community defaults
  // (link.strength = 1/min(deg), velocityDecay 0.4, alphaDecay 1−0.001^(1/300)) then tightened for OUR node
  // sizes (用户 0719 真机「中心一坨 + 长腿横穿」: connected nodes must actually CLUSTER — short rest length +
  // firm low-degree springs pull leaves in; repulsion just spaces, it doesn't fling). 基线对齐 d3-force
  // 社区默认再按我们的节点尺寸收紧:相连点真正成团(短边长+低度对硬弹簧把叶子拉近,斥力只撑开不甩飞)。
  static const ForceParams forceParams = ForceParams(
    idealLength: 58, //         spring rest length — SHORT so connected nodes cluster 弹簧静止长(短,相连成团)
    repulsion: 5200, //         charge strength — spaces the graph, must NOT out-fling the spring 斥力(撑开,不甩过弹簧)
    springStrength: 0.16, //    base Hooke constant — FIRM (d3 link.strength spirit) 弹簧基强度(硬)
    hubStretch: 0.28, //        edge rest-length grows with the higher endpoint degree hub 边随高度端放长
    centering: 0.02, //         WEAK x/y pull to a component anchor — anti-drift only 弱定位(只防漂移)
    collisionStrength: 0.85, // fraction of overlap corrected per pass (0..1) 碰撞每遍纠正比例
    collisionIterations: 3, //  relaxation passes per tick (d3 collide 做法) 碰撞松弛遍数
    velocityDecay: 0.40, //     per-tick velocity damping (d3 default) 速度阻尼
    alphaDecay: 0.0228, //      cooling: settles in ~300 ticks (d3 default) 冷却率
    alphaMin: 0.001, //         below this the sim is settled → Ticker stops 静止阈
    reheatAlpha: 0.55, //       a drag/data change re-warms to this 拖拽/换数据重加热到
    minDist: 1.0, //            distance floor so repulsion can't explode at overlap 距离下限
    initialSpacing: 40, //      phyllotaxis seed radius factor (per component) 初铺半径系数(分量内)
    componentGap: 60, //        gap packed between connected components 连通分量打包间隙
    isolateGap: 32, //          horizontal gap between zero-degree isolates in their band 孤点带内水平间距
    isolateTopGap: 52, //       gap from the main cloud down to the isolate band 主云到孤点带的落差
    componentIterations: 340, //fixed per-component settle iterations (determinism) 分量固定迭代数
  );

  // ── fit / zoom / label chrome (视口 · 缩放 · 标签显隐门) ──────────────────────────────────────────────
  static const double sceneMargin = 72; // scene padding around the node cloud (fit headroom) 云周边距
  static const double minScale = 0.25; // InteractiveViewer hard floor 缩放硬下限
  static const double maxScale = 2.5; // InteractiveViewer hard ceiling 缩放硬上限
  static const double fitMinScale = 0.3; // fit() won't shrink a huge graph below this fit 最小
  static const double fitMaxScale = 1.1; // …nor blow a SPARSE graph up past this (用户: 别放太大) fit 最大
  static const double wheelScaleFactor = 666.6667; // trackpad/wheel zoom sensitivity 滚轮灵敏度
  static const double labelScaleThreshold = 0.5; // below this zoom → dots only (drop all labels) 此缩放下只留点

  // Label density cull (⑤ 第二道 — 用户 0719 真机「字压节点」): at the DEFAULT fit view only the focus + its
  // one-hop ring keep labels (the structure that matters); the outer rings are dots until the user zooms
  // PAST [labelDetailScale] (set ABOVE [fitMaxScale] so a sparse graph — which fits near 1.0 — doesn't dump
  // every label at once → the validate-schema/handbook pile-up). Standard graph-tool behaviour (Obsidian).
  // Ordering 焦点 > 一跳 > 其余. 默认 fit 只显焦点+一跳标签(外圈是点),放大过 labelDetailScale(高于 fitMaxScale,
  // 故稀疏图 fit 时不倾倒全部标签)才现外圈——业界标准(Obsidian)。
  static const int labelAlwaysWithinHop = 1; // hops ≤ this always label 此跳内恒显标签
  static const double labelDetailScale = 1.28; // zoom past this → outer rings also label 放大过此外圈也显
  static const int labelCullMinNodes = 12; // below this many nodes the graph is sparse → show ALL labels 稀疏图全显

  /// Whether a node at graph distance [hop] shows its label, given the visible [nodeCount] and current
  /// [scale] (after the hard [labelScaleThreshold] dot-only gate, checked by the caller). The cull only bites
  /// when the graph is actually DENSE ([nodeCount] ≥ [labelCullMinNodes], brief ⑤「过密时」); a sparse graph
  /// shows everything. 标签是否显示:仅当图确实密(节点数≥阈值)才裁,稀疏图全显。
  static bool labelVisible({required int hop, required double scale, required int nodeCount}) =>
      nodeCount < labelCullMinNodes || hop <= labelAlwaysWithinHop || scale >= labelDetailScale;
}
