import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/entities/document.dart';
import '../../../core/contract/entities/skill.dart';
import '../data/document_repository.dart';

/// The Documents ocean's server-state, over the [documentsRepositoryProvider] seam. The rail watches the
/// tree + skill lists; the center watches the selected node's full content. Selection is a plain provider
/// (routing is a later fold-in). 文档海洋的 server-state:rail 看树+skill 列表,中心看选中节点正文;选区走 provider。

/// The whole document tree as flat metadata (no content) — the rail assembles the hierarchy by parentId.
/// 整树扁平元数据(无 content),rail 组树。
final documentTreeProvider =
    FutureProvider<List<DocumentNode>>((ref) => ref.watch(documentsRepositoryProvider).getTree());

/// Every skill as light metadata (no body). 全部 skill(无 body)。
final skillListProvider =
    FutureProvider<List<Skill>>((ref) => ref.watch(documentsRepositoryProvider).listSkills());

/// A selected navigator node — a document (by `doc_` id) or a skill (by slug name). `isSkill` disambiguates
/// which collection [id] indexes. 选中的导航节点:document(doc_ id)或 skill(slug 名);isSkill 消歧。
typedef DocSelection = ({bool isSkill, String id});

/// The current selection (null = nothing open → the center shows its empty state). Routing is a later
/// fold-in; for now selection is provider-driven (like the ocean switcher). 当前选区(空=中心空态)。
class SelectedDocController extends Notifier<DocSelection?> {
  @override
  DocSelection? build() => null;

  void select(DocSelection sel) => state = sel;
  void clear() => state = null;
}

final selectedDocProvider =
    NotifierProvider<SelectedDocController, DocSelection?>(SelectedDocController.new);

/// The open document WITH content (fetched on select; autoDispose releases it on deselect). 打开的文档(带正文)。
final openDocumentProvider = FutureProvider.autoDispose
    .family<DocumentNode, String>((ref, id) => ref.watch(documentsRepositoryProvider).getDocument(id));

/// The open skill WITH body + frontmatter (fetched on select). 打开的 skill(带 body + frontmatter)。
final openSkillProvider = FutureProvider.autoDispose
    .family<Skill, String>((ref, name) => ref.watch(documentsRepositoryProvider).getSkill(name));
