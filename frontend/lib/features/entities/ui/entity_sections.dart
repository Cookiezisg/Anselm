import 'package:flutter/material.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/ui/ui.dart';
import '../model/entity.dart';
import '../model/kind_schema.dart';

/// Renders a kind's detail from [kindSchema] + the entity's data bag, composing the UI kit
/// (AnSection/AnInfoCard/AnKvRow/AnCodeBlock/AnJsonTree + a compact rows list). One renderer
/// for all 9 kinds — adding a kind needs only a schema + data, no widget code.
/// 由 [kindSchema] + 实体数据袋渲染详情,组合 UI 套件。一个渲染器吃 9 种实体——加 kind 只需 schema+数据。
class EntitySections extends StatelessWidget {
  const EntitySections({super.key, required this.kind, required this.data});

  final EntityKind kind;
  final Map<String, Object?> data;

  @override
  Widget build(BuildContext context) {
    final sections = kindSchema[kind] ?? const <SectionSchema>[];
    final children = <Widget>[];
    for (final s in sections) {
      final body = s.grid ? _grid(context, s.fields) : _fields(context, s.fields);
      if (body == null) continue;
      if (children.isNotEmpty) children.add(const SizedBox(height: AnSpace.s24));
      children.add(AnSection(title: s.label, child: body));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }

  // A non-grid section: stack its field widgets (skipping empties).
  Widget? _fields(BuildContext context, List<SchemaField> fields) {
    final widgets = <Widget>[];
    for (final f in fields) {
      final w = _field(context, f);
      if (w == null) continue;
      if (widgets.isNotEmpty) widgets.add(const SizedBox(height: AnSpace.s12));
      widgets.add(w);
    }
    if (widgets.isEmpty) return null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: widgets);
  }

  // A grid section: 2-up cards (collapse to 1 column when narrow).
  Widget? _grid(BuildContext context, List<SchemaField> cards) {
    final built = [for (final c in cards) _card(context, c)].whereType<Widget>().toList();
    if (built.isEmpty) return null;
    return LayoutBuilder(
      builder: (context, cons) {
        if (cons.maxWidth < 520 || built.length == 1) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < built.length; i++) ...[
                if (i > 0) const SizedBox(height: AnSpace.s16),
                built[i],
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < built.length; i++) ...[
              if (i > 0) const SizedBox(width: AnSpace.s16),
              Expanded(child: built[i]),
            ],
          ],
        );
      },
    );
  }

  Widget? _card(BuildContext context, SchemaField card) {
    final children = <Widget>[];
    for (final sub in card.fields) {
      final w = _field(context, sub);
      if (w != null) children.add(w);
    }
    if (children.isEmpty) return null;
    return AnInfoCard(title: card.title ?? '', children: children);
  }

  Widget? _field(BuildContext context, SchemaField f) {
    final c = context.colors;
    final v = f.key != null ? data[f.key] : null;
    switch (f.type) {
      case FieldType.text:
        if (v is! String || v.isEmpty) return null;
        return Text(v, style: AnText.body.copyWith(color: c.ink));
      case FieldType.kv:
        if (v is! Map || v.isEmpty) return null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final e in v.entries) AnKvRow(label: '${e.key}', value: '${e.value}'),
          ],
        );
      case FieldType.code:
        if (v is! String || v.isEmpty) return null;
        return AnCodeBlock(v);
      case FieldType.json:
        if (v == null) return null;
        return AnJsonTree(v);
      case FieldType.rows:
        if (v is! List || v.isEmpty) return null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final r in v.cast<RowItem>()) _RowLine(r)],
        );
      case FieldType.card:
        return _card(context, f);
      case FieldType.graph:
        return const AnCallout(
          'Graph editor lands with the workflow feature.',
          tone: AnCalloutTone.neutral,
        );
    }
  }
}

/// A compact passive list line for the `rows` field: optional status dot + label + meta.
class _RowLine extends StatelessWidget {
  const _RowLine(this.item);
  final RowItem item;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AnSpace.s4),
      child: Row(
        children: [
          if (item.status != null) ...[
            AnStatusDot(item.status!),
            const SizedBox(width: AnSpace.s8),
          ],
          Expanded(
            child: Text(item.label,
                overflow: TextOverflow.ellipsis, style: AnText.body.copyWith(color: c.ink)),
          ),
          if (item.meta != null)
            Text(item.meta!, style: AnText.meta.copyWith(color: c.inkMuted)),
        ],
      ),
    );
  }
}
