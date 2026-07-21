import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../router/panel_registry.dart';
import '../ui/ui.dart';

// The tool-card navigation seam — one place that turns a {kind, id} into a tappable ref pill wired to
// the panel registry (WRK-056 #8). A pill navigates iff its kind has a real panel ([hasPanelFor]);
// otherwise it renders inert (never a dead link that lands on "?"). Shared by F08 exec credentials and
// F09 run-log provenance so the SAME nav rule lives once (原则 8:不两处手搓导航). 工具卡导航缝。

/// A ref pill that deep-links to its entity panel when navigable, else renders as a plain annotation.
/// 可导航→深链面板;否则纯标注。
/// Navigate to an entity's panel (registry-gated; a kind with no panel is a no-op). The ONE
/// go-closure — call sites stop re-rolling `panelLocationFor + context.go` (A-024). 唯一导航闭包。
void goToPanel(BuildContext context, String kind, String id) {
  final loc = panelLocationFor(kind, id);
  if (loc != null && context.mounted) context.go(loc);
}

Widget toolNavPill(
  BuildContext context, {
  required String kind,
  required String label,
  String? id,
}) {
  final can = id != null && id.isNotEmpty && hasPanelFor(kind);
  return AnRefPill(
    kind: kind,
    label: label,
    id: can ? id : null,
    onTap: can ? (target) => goToPanel(context, target.kind, target.id) : null,
  );
}

/// Navigate to a {kind, id}'s panel if one exists (a no-op otherwise). Used by tappable rows that aren't
/// pills (a RunLedger row). 跳到 {kind,id} 面板(无则 no-op);供非药丸的可点行用。
void toolNavTo(BuildContext context, String kind, String id) {
  final loc = panelLocationFor(kind, id);
  if (loc != null && context.mounted) context.go(loc);
}
