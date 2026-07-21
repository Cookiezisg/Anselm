import 'package:flutter/widgets.dart';

import '../../../../core/contract/entities/relation.dart';
import '../../../../core/ui/ui.dart';
import '../../../../i18n/strings.g.dart';

/// Shared relation-graph sentence builders — the i18n the [AnRelationGraph] primitive takes as callbacks
/// (it stays i18n-light; the feature words the sentences). Used by both the Overview observing preview and
/// the full-page explore state. 关系图句子构造:原语取回调、feature 造句;总览预览与探索页共用。

/// The per-node a11y sentence: "{name}，{kind}，被 {n} 个实体引用" (coordinates baked in — desktop a11y §2).
String relationNodeLabel(BuildContext context, EntityNode n, int inDegree) =>
    context.t.a11y.relationNode(
      name: n.name.isEmpty ? n.id : n.name,
      kind: entityKindWord(context, n.kind),
      count: '$inDegree',
    );

/// The relation VERB word (equip/link/create/edit) — localized. 关系动词本地化词。
String relationVerbWord(BuildContext context, String verb) {
  final v = context.t.entities.graph.verb;
  return switch (verb) {
    'equip' => v.equip,
    'link' => v.link,
    'create' => v.create,
    'edit' => v.edit,
    _ => verb,
  };
}

/// The per-edge relation sentence (hover tooltip + a11y): "{fromName} {verb} {toName}". 边关系句。
String relationEdgeLabel(BuildContext context, EntityRelation e) {
  final from = e.fromName.isEmpty ? e.fromId : e.fromName;
  final to = e.toName.isEmpty ? e.toId : e.toName;
  return '$from ${relationVerbWord(context, e.kind)} $to';
}
