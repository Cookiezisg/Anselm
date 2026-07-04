import '../../../core/contract/entities/document.dart';
import '../../../core/contract/entities/skill.dart';
import '../../../core/model/sidebar_model.dart';
import '../../../core/ui/icons.dart';

/// The i18n labels the (widget-free) rail projection needs — injected so the pure builder can be unit-tested
/// without a BuildContext. rail 投影所需的 i18n 文案(注入,使纯投影可脱 context 单测)。
class DocRailLabels {
  const DocRailLabels({
    required this.documents,
    required this.skills,
    required this.untitled,
    required this.newLabel,
    required this.filter,
  });

  final String documents;
  final String skills;
  final String untitled; // fallback label for an unnamed document
  final String newLabel;
  final String filter;
}

/// A skill row's id is namespaced (`skill:<name>`) so it never collides with a `doc_` id in the flat
/// [SidebarModel] id-space, and the consumer can disambiguate a selection by the prefix. skill 行 id 加前缀。
const String kSkillRowPrefix = 'skill:';

/// PURE projection: the flat document tree + the flat skill list → one [SidebarModel] with two sections
/// (Documents = the recursive page tree assembled by parentId + position; Skills = a flat slug list). The
/// documents section is a genuine tree ([SidebarRow.children]); a node with children renders a fold
/// chevron, so no folder/file discriminator is needed (every node is a page). Widget/context-free so the
/// mapping is unit-tested without pumping UI. 纯投影:文档树 + skill 列 → 双段 SidebarModel(文档树 + skill 扁平)。
SidebarModel buildDocumentsRailModel(List<DocumentNode> tree, List<Skill> skills, DocRailLabels labels) {
  // Group by parent + order by position, so the tree assembles in one pass. 按 parentId 分组 + position 排序。
  final byParent = <String?, List<DocumentNode>>{};
  for (final d in tree) {
    (byParent[d.parentId] ??= []).add(d);
  }
  for (final list in byParent.values) {
    list.sort((a, b) => a.position.compareTo(b.position));
  }

  SidebarRow toRow(DocumentNode d) => SidebarRow(
        id: d.id,
        label: d.name.isEmpty ? labels.untitled : d.name,
        icon: AnIcons.doc,
        children: [for (final child in byParent[d.id] ?? const <DocumentNode>[]) toRow(child)],
      );

  final docRows = [for (final root in byParent[null] ?? const <DocumentNode>[]) toRow(root)];
  final skillRows = [
    for (final s in skills)
      SidebarRow(id: '$kSkillRowPrefix${s.name}', label: s.name, icon: AnIcons.skill),
  ];

  return SidebarModel(
    newLabel: labels.newLabel,
    filterPlaceholder: labels.filter,
    groups: [
      SidebarGroup(types: [
        SidebarType(label: labels.documents, icon: AnIcons.doc, rows: docRows),
        SidebarType(label: labels.skills, icon: AnIcons.skill, rows: skillRows),
      ]),
    ],
  );
}

/// Resolve a rail row id back to a [DocSelection]-shaped tuple (a skill if it carries the namespace
/// prefix, else a document). 把 rail 行 id 解回选区(带前缀=skill,否则 document)。
({bool isSkill, String id}) docSelectionForRowId(String rowId) => rowId.startsWith(kSkillRowPrefix)
    ? (isSkill: true, id: rowId.substring(kSkillRowPrefix.length))
    : (isSkill: false, id: rowId);
