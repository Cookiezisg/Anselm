import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/entities/document.dart';
import '../../../core/overlay/an_overlay.dart';
import '../../../core/ui/an_button.dart';
import '../../../core/ui/an_menu.dart';
import '../../../core/ui/an_rail_states.dart';
import '../../../core/ui/an_sidebar_list.dart';
import '../../../core/ui/an_toast.dart';
import '../../../core/ui/icons.dart';
import '../../../i18n/strings.g.dart';
import '../data/document_repository.dart';
import '../state/document_state.dart';
import 'document_rail_model.dart';

/// The left-island Documents navigator — one [AnSidebarList] over two sections (the recursive document
/// page tree + the flat skill list), now with CRUD: a New row creates a root page (then inline-renames it),
/// and each row hovers a ⋯ menu — pages get Rename / Duplicate / Delete, skills get Delete (skills have no
/// rename: `name` is the slug/identity). Writes go straight through the repository seam and the two plain
/// FutureProviders are `invalidate`d to refetch (no optimistic notifier). Deleting the open selection clears
/// it. Filtering stays client-side inside AnSidebarList.
///
/// 左岛文档导航:一个 AnSidebarList 双段(文档页树 + skill 扁平列)+ CRUD:New 建根页(随即就地改名),每行
/// hover ⋯ 菜单——页=改名/复制/删除,skill=删除(skill 无改名:name 即 slug 身份)。写过 repository 缝,两个
/// 普通 FutureProvider invalidate 重取(无乐观 notifier);删掉选中即清选区。过滤仍走 AnSidebarList 客户端。
class DocumentRail extends ConsumerStatefulWidget {
  const DocumentRail({super.key});

  @override
  ConsumerState<DocumentRail> createState() => _DocumentRailState();
}

class _DocumentRailState extends ConsumerState<DocumentRail> {
  String? _editingId; // which row is mid inline-rename (transient view state). 哪行在就地改名中。

  DocumentsRepository get _repo => ref.read(documentsRepositoryProvider);

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final treeAsync = ref.watch(documentTreeProvider);
    final skillsAsync = ref.watch(skillListProvider);
    final selected = ref.watch(selectedDocProvider);

    final tree = treeAsync.value ?? const <DocumentNode>[];
    final skills = skillsAsync.value ?? const [];
    final anyData = treeAsync.hasValue || skillsAsync.hasValue;

    return AnRailStates(
      // Aggregate over both lists: loading = neither resolved; error = both failed with nothing; empty =
      // loaded but zero documents AND zero skills. 两列表聚合:载=均未解 / 错=均败且无 / 空=载完全零。
      loading: !anyData && (treeAsync.isLoading || skillsAsync.isLoading),
      error: !anyData && treeAsync.hasError && skillsAsync.hasError,
      empty: anyData && tree.isEmpty && skills.isEmpty,
      strings: AnRailStrings(
        errorTitle: t.documents.errorTitle,
        errorHint: t.documents.errorHint,
        retry: t.documents.retry,
        emptyTitle: t.documents.emptyTitle,
        emptyHint: t.documents.emptyHint,
      ),
      onRetry: () {
        ref.invalidate(documentTreeProvider);
        ref.invalidate(skillListProvider);
      },
      builder: () => AnSidebarList(
        model: buildDocumentsRailModel(
          tree,
          skills,
          DocRailLabels(
            documents: t.documents.documents,
            skills: t.documents.skills,
            untitled: t.documents.untitled,
            newLabel: t.documents.kNew,
            filter: t.documents.filter,
          ),
        ),
        selectedId: selected == null
            ? null
            : (selected.isSkill ? '$kSkillRowPrefix${selected.id}' : selected.id),
        onSelect: (id) => ref.read(selectedDocProvider.notifier).select(docSelectionForRowId(id)),
        // The New row creates a root page (skill creation lives in the skill editor, P4c). New 建根页。
        onNew: _newDocument,
        editingRowId: _editingId,
        onRenameCommit: _renameDocument,
        onRenameCancel: () => setState(() => _editingId = null),
        rowActionsBuilder: (rowId) => [_rowMenu(t, rowId, tree)],
        // Tree drag-reorder: pages drag (reparent via nest, reorder via insertion lines); skills sit out
        // (flat, no position in their contract). 树内拖拽:页可拖(嵌入=改父、插线=重排);skill 不参与(无位次)。
        onRowDropped: _onDrop,
        canDragRow: (id) => !id.startsWith(kSkillRowPrefix),
      ),
    );
  }

  /// Translate the drop into `:move` args (pure [planDocMove] — cycle/self/skill guarded there), run it,
  /// refetch the tree. 落点经纯 planDocMove 译成 :move 参数(环/自落/skill 皆在彼守),执行后重取树。
  Future<void> _onDrop(String dragged, String target, AnRowDropZone zone) async {
    final tree = ref.read(documentTreeProvider).value ?? const <DocumentNode>[];
    final plan = planDocMove(tree, dragged, target, zone);
    if (plan == null) return;
    try {
      await _repo.moveDocument(dragged, parentId: plan.parentId, position: plan.position);
      if (!mounted) return;
      ref.invalidate(documentTreeProvider);
    } catch (_) {
      _toastFail();
    }
  }

  /// A row's hover ⋯ menu. Pages: Rename / Duplicate / Delete. Skills: Delete only (no rename — the slug is
  /// the identity). 行 ⋯ 菜单:页=改名/复制/删除;skill=仅删除(slug 即身份、不可改名)。
  Widget _rowMenu(Translations t, String rowId, List<DocumentNode> tree) {
    final sel = docSelectionForRowId(rowId);
    return AnMenu(
      anchorBuilder: (context, toggle, isOpen) => AnButton.iconOnly(
        AnIcons.more,
        size: AnButtonSize.sm,
        semanticLabel: t.a11y.moreActions,
        onPressed: toggle,
      ),
      entries: sel.isSkill
          ? [
              AnMenuItem(
                label: t.action.delete,
                icon: AnIcons.trash,
                danger: true,
                onTap: () => _confirmDeleteSkill(sel.id),
              ),
            ]
          : [
              AnMenuItem(
                label: t.documents.rename,
                icon: AnIcons.edit,
                onTap: () => setState(() => _editingId = rowId),
              ),
              AnMenuItem(label: t.documents.duplicate, icon: AnIcons.copy, onTap: () => _duplicate(sel.id)),
              AnMenuItem(
                label: t.action.delete,
                icon: AnIcons.trash,
                danger: true,
                onTap: () => _confirmDeleteDoc(sel.id, _docName(tree, sel.id)),
              ),
            ],
    );
  }

  String _docName(List<DocumentNode> tree, String id) {
    final doc = tree.where((d) => d.id == id).firstOrNull;
    final name = doc?.name.trim() ?? '';
    return name.isEmpty ? context.t.documents.untitled : name;
  }

  // ── actions (write → invalidate to refetch; toast on failure) 写→invalidate 重取;失败 toast ──

  Future<void> _newDocument() async {
    try {
      final doc = await _repo.createDocument(name: context.t.documents.untitled);
      if (!mounted) return;
      ref.invalidate(documentTreeProvider);
      ref.read(selectedDocProvider.notifier).select((isSkill: false, id: doc.id));
      // Drop straight into inline-rename on the fresh row. 新行直接进就地改名。
      setState(() => _editingId = doc.id);
    } catch (_) {
      _toastFail();
    }
  }

  /// Commit an inline rename: trim, treat empty-or-unchanged as a cancel. 提交改名:trim,空或未变即取消。
  Future<void> _renameDocument(String rowId, String value) async {
    final id = docSelectionForRowId(rowId).id;
    final next = value.trim();
    final current = ref.read(documentTreeProvider).value?.where((d) => d.id == id).firstOrNull?.name;
    setState(() => _editingId = null);
    if (next.isEmpty || next == current) return;
    try {
      await _repo.updateDocument(id, {'name': next});
      if (!mounted) return;
      ref.invalidate(documentTreeProvider);
    } catch (_) {
      _toastFail();
    }
  }

  Future<void> _duplicate(String id) async {
    try {
      final copy = await _repo.duplicateDocument(id);
      if (!mounted) return;
      ref.invalidate(documentTreeProvider);
      ref.read(selectedDocProvider.notifier).select((isSkill: false, id: copy.id));
    } catch (_) {
      _toastFail();
    }
  }

  Future<void> _confirmDeleteDoc(String id, String name) async {
    final t = context.t;
    final ok = await ref.read(overlayProvider.notifier).confirm(
          title: t.documents.deleteDocTitle,
          message: t.documents.deleteDocBody(name: name),
          confirmLabel: t.action.delete,
          cancelLabel: t.action.cancel,
          barrierLabel: t.feedback.dialogBarrier,
        );
    if (!ok) return;
    try {
      await _repo.deleteDocument(id);
      if (!mounted) return;
      ref.invalidate(documentTreeProvider);
      _clearIfSelected((isSkill: false, id: id));
    } catch (_) {
      _toastFail();
    }
  }

  Future<void> _confirmDeleteSkill(String name) async {
    final t = context.t;
    final ok = await ref.read(overlayProvider.notifier).confirm(
          title: t.documents.deleteSkillTitle,
          message: t.documents.deleteSkillBody(name: name),
          confirmLabel: t.action.delete,
          cancelLabel: t.action.cancel,
          barrierLabel: t.feedback.dialogBarrier,
        );
    if (!ok) return;
    try {
      await _repo.deleteSkill(name);
      if (!mounted) return;
      ref.invalidate(skillListProvider);
      _clearIfSelected((isSkill: true, id: name));
    } catch (_) {
      _toastFail();
    }
  }

  // Deleting the open selection leaves a dead center view — clear it. 删掉选中即清选区。
  void _clearIfSelected(DocSelection deleted) {
    final sel = ref.read(selectedDocProvider);
    if (sel != null && sel.isSkill == deleted.isSkill && sel.id == deleted.id) {
      ref.read(selectedDocProvider.notifier).clear();
    }
  }

  void _toastFail() {
    if (!mounted) return;
    ref.read(overlayProvider.notifier).showToast(context.t.documents.actionFailed, tone: AnToastTone.danger);
  }
}
