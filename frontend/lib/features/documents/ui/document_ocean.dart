import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/entities/skill.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/ui/an_deferred_loading.dart';
import '../../../core/ui/an_markdown.dart';
import '../../../core/ui/an_page.dart';
import '../../../core/ui/an_skeleton.dart';
import '../../../core/ui/an_state.dart';
import '../../../i18n/strings.g.dart';
import '../state/document_state.dart';

/// The Documents ocean center — for P1/P2 a READ-ONLY preview of the selected node (the Notion WYSIWYG
/// editor on super_editor lands in P3). A document renders its markdown [content]; a skill renders a
/// compact frontmatter line + its markdown body. No selection → an empty "pick a document" state. All
/// content flows through the repository seam. 文档海洋中心(P1/P2 只读预览;Notion 编辑器 P3):文档渲正文,
/// skill 渲 frontmatter 摘要 + body;无选区=空态。
class DocumentOcean extends ConsumerWidget {
  const DocumentOcean({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final selected = ref.watch(selectedDocProvider);
    if (selected == null) {
      return AnState(kind: AnStateKind.empty, title: t.documents.pickTitle, hint: t.documents.pickHint);
    }
    return selected.isSkill ? _skill(context, ref, selected.id) : _doc(context, ref, selected.id);
  }

  Widget _doc(BuildContext context, WidgetRef ref, String id) {
    final t = context.t;
    return ref.watch(openDocumentProvider(id)).when(
          loading: () => const AnDeferredLoading(child: AnSkeleton.lines(8)),
          error: (_, _) => AnState(kind: AnStateKind.error, title: t.documents.loadFailed, hint: t.documents.errorHint),
          data: (doc) => AnPage(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _title(context, doc.name.isEmpty ? t.documents.untitled : doc.name),
                const SizedBox(height: AnFlow.headBody), // title → body (12) 标题→正文
                // Read-only render of the markdown source of truth (the editor replaces this in P3). 只读渲染真相 markdown。
                if (doc.content.trim().isEmpty)
                  AnState(kind: AnStateKind.empty, size: AnStateSize.inset, title: t.documents.emptyDoc)
                else
                  AnMarkdown(doc.content),
              ],
            ),
          ),
        );
  }

  Widget _skill(BuildContext context, WidgetRef ref, String name) {
    final t = context.t;
    final c = context.colors;
    return ref.watch(openSkillProvider(name)).when(
          loading: () => const AnDeferredLoading(child: AnSkeleton.lines(8)),
          error: (_, _) => AnState(kind: AnStateKind.error, title: t.documents.loadFailed, hint: t.documents.errorHint),
          data: (skill) => AnPage(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _title(context, skill.name),
                const SizedBox(height: AnFlow.headBodyTight), // title → meta (8) 标题→meta
                // A compact frontmatter line — the full structured properties panel is P4. 紧凑 frontmatter 摘要(完整面板 P4)。
                Text(_skillMeta(skill), style: AnText.meta.copyWith(color: c.inkFaint)),
                const SizedBox(height: AnFlow.headBody), // meta → body (12) meta→正文
                if (skill.body.trim().isEmpty)
                  AnState(kind: AnStateKind.empty, size: AnStateSize.inset, title: t.documents.emptyDoc)
                else
                  AnMarkdown(skill.body),
              ],
            ),
          ),
        );
  }

  String _skillMeta(Skill skill) {
    final parts = <String>[
      if (skill.context.isNotEmpty) skill.context,
      if (skill.source.isNotEmpty) skill.source,
      if (skill.frontmatter.allowedTools.isNotEmpty) '${skill.frontmatter.allowedTools.length} tools',
    ];
    return parts.join(' · ');
  }

  Widget _title(BuildContext context, String text) =>
      Text(text, style: AnText.h2.weight(AnText.emphasisWeight).copyWith(color: context.colors.ink));
}
