import 'package:flutter/widgets.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';

/// THE single source for an entity KIND's visual identity, keyed by its backend wire string — the 11-kind
/// `EntityKind` vocabulary (relation/entitykind.go): the four Quadrinity (function/handler/agent/workflow),
/// the three support kinds (trigger/control/approval), and the four accessory kinds (skill/mcp/document/
/// conversation) that never reach the 7-value rail enum. It has two faces here — [entityKindColor] and
/// [entityKindWord] — with the glyph twin at `AnIcons.entityKindGlyph`. Introduced for the Entities
/// Overview relationship graph (WRK-072), which is the first surface to COLOR entity kinds (AnRefPill
/// renders them monochrome-outlined). 实体 kind 视觉单源(按后端线缆值),色 + 本地化词;字形孪生在
/// AnIcons.entityKindGlyph。为总览关系图引入——首个给实体 kind 上色的面。
///
/// COLOUR (拍板 · 报告在案): reuses design tokens ONLY — no new colour literals (原语 #8 / 收敛律:feature 不
/// 私铸色表). The rule is "Quadrinity pop, supporting cast recedes": the four stars wear the four vivid brand
/// hues (function=accent blue / handler=ok green / agent=teal / workflow=violet); the 配件 wear the alert
/// family (trigger=amber / approval=red) or steel (control); the accessory file-like kinds recede to muted
/// grey (skill/mcp/document) with conversation faintest (pure provenance). This ALIGNS agent=teal &
/// approval=danger with the existing `nodeKindColor` (workflow-graph) source and deliberately DEVIATES on
/// trigger (violet→amber) and control (warn→steel) so the four Quadrinity can claim the four vivid hues —
/// the palette carries only ~6 distinct hues, fewer than 11 kinds, so icon+label are the primary
/// disambiguators and colour is the coarse family grouping (categorical-colour best practice).
Color entityKindColor(BuildContext context, String wireKind) {
  final c = context.colors;
  final gc = context.graphColors;
  return switch (wireKind.toLowerCase()) {
    'function' => c.accent,
    'handler' => c.ok,
    'agent' => gc.teal,
    'workflow' => gc.violet,
    'trigger' => c.warn,
    'approval' => c.danger,
    'control' => c.inkMuted,
    'skill' || 'mcp' || 'document' || 'doc' => c.inkMuted,
    'conversation' => c.inkFaint,
    _ => c.inkFaint,
  };
}

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
