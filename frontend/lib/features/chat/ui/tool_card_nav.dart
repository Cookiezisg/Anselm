import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/panel_registry.dart';
import '../../../core/ui/ui.dart';

// The tool-card navigation seam — one place that turns a {kind, id} into a tappable ref pill wired to
// the panel registry (WRK-056 #8). A pill navigates iff its kind has a real panel ([hasPanelFor]);
// otherwise it renders inert (never a dead link that lands on "?"). Shared by F08 exec credentials and
// F09 run-log provenance so the SAME nav rule lives once (原则 8:不两处手搓导航). 工具卡导航缝。

/// A ref pill that deep-links to its entity panel when navigable, else renders as a plain annotation.
/// 可导航→深链面板;否则纯标注。
Widget toolNavPill(BuildContext context, {required String kind, required String label, String? id}) {
  final can = id != null && id.isNotEmpty && hasPanelFor(kind);
  return AnRefPill(
    kind: kind,
    label: label,
    id: can ? id : null,
    onTap: can
        ? (target) {
            final loc = panelLocationFor(target.kind, target.id);
            if (loc != null && context.mounted) context.go(loc);
          }
        : null,
  );
}
