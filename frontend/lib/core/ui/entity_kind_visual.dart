import 'package:flutter/widgets.dart';

import '../../i18n/strings.g.dart';
import '../graph/relation_graph_config.dart';

/// THE single source for an entity KIND's visual identity, keyed by its backend wire string — the 11-kind
/// `EntityKind` vocabulary (relation/entitykind.go): the four Quadrinity (function/handler/agent/workflow),
/// the three support kinds (trigger/control/approval), and the four accessory kinds (skill/mcp/document/
/// conversation) that never reach the 7-value rail enum. It has two faces here — [entityKindColor] and
/// [entityKindWord] — with the glyph twin at `AnIcons.entityKindGlyph`. Consumed by the Entities Overview
/// relationship graph (WRK-072), the only surface that COLORS entity kinds (AnRefPill renders them
/// monochrome-outlined). 实体 kind 视觉单源(按后端线缆值),色 + 本地化词;字形孪生在 AnIcons.entityKindGlyph。
///
/// COLOUR (v2「涟漪焦点星图」, 用户 0719 拍板 · 报告在案): the graph gets a DEDICATED FOG palette that lives in
/// [RelationGraphConfig.fogColor] — deliberately DIVORCED from the AnTone/AnStatus alert colours the v1
/// graph borrowed (red/green/amber), which the user rejected as 「脏兮兮」. Kinds differ by HUE only at one
/// low-saturation lightness (core Quadrinity 有彩 / scheduler family 暖 / knowledge+equipment accessories 贴灰,
/// conversation shares the document grey); intensity is the orthogonal ripple axis the graph paints on top.
/// This function forwards to that single fog table so the node dot, the legend chip and the explore card all
/// read one source. `context` is retained for call-site stability (the fog palette is currently theme-
/// independent). 图色板独立于 AnTone,单源=config 的雾彩表;此函数只转发。
Color entityKindColor(BuildContext context, String wireKind) =>
    RelationGraphConfig.fogColor(wireKind);

/// The localized noun for an entity kind (a11y labels / relation sentences). Cases = the backend
/// EntityKind wire (`document` not `doc`, incl. control/approval) — the contract vocab, not the demo's
/// icon aliases; unknown → the raw string (open set, degrade gracefully). Single source shared by
/// [AnRelationGraph] and AnRefPill. kind 本地化词(a11y/关系句),线缆词表,未知原样降级。
String entityKindWord(BuildContext context, String wireKind) {
  final r = context.t.ref;
  return switch (wireKind.toLowerCase()) {
    'function' => r.function,
    'handler' => r.handler,
    'workflow' => r.workflow,
    'agent' => r.agent,
    'document' || 'doc' => r.document,
    'conversation' => r.conversation,
    'skill' => r.skill,
    'mcp' => r.mcp,
    'trigger' => r.trigger,
    'control' => r.control,
    'approval' => r.approval,
    _ => wireKind,
  };
}
