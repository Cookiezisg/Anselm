import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/an_rail_states.dart';
import '../../../core/ui/an_sidebar_list.dart';
import '../../../i18n/strings.g.dart';
import '../state/document_state.dart';
import 'document_rail_model.dart';

/// The left-island Documents navigator — one [AnSidebarList] over two sections (the recursive document
/// page tree + the flat skill list). Watches [documentTreeProvider] + [skillListProvider], resolves the
/// four rail states (loading / error / empty / list), and drives [selectedDocProvider] on select. Filtering
/// is client-side inside AnSidebarList (the whole bounded tree is loaded), so no server search is wired.
/// All data flows through the repository seam → the demo + tests drive it with a fixture.
///
/// 左岛文档导航:一个 AnSidebarList 双段(文档页树 + skill 扁平列)。watch 树+skill,解四态,选区写 provider。
/// AnSidebarList 内建客户端过滤(整棵有界树已载),不接服务端搜索。全数据过 repository 缝。
class DocumentRail extends ConsumerWidget {
  const DocumentRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final treeAsync = ref.watch(documentTreeProvider);
    final skillsAsync = ref.watch(skillListProvider);
    final selected = ref.watch(selectedDocProvider);

    final tree = treeAsync.value ?? const [];
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
        // Creation (New document / New skill) lands with the editor phase; the rail is read+select for now.
        // 新建随编辑器阶段接;当前 rail 只读+选择。
        showNew: false,
        onSelect: (id) => ref.read(selectedDocProvider.notifier).select(docSelectionForRowId(id)),
      ),
    );
  }
}
