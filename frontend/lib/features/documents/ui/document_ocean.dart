import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/entities/skill.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/entity/mention_source.dart';
import '../../../core/perf/debouncer.dart';
import '../../../core/ui/an_deferred_loading.dart';
import '../../../core/ui/an_doc_editor.dart';
import '../../../core/ui/an_markdown.dart';
import '../../../core/ui/an_page.dart';
import '../../../core/ui/an_skeleton.dart';
import '../../../core/ui/an_state.dart';
import '../../../i18n/strings.g.dart';
import '../data/document_repository.dart';
import '../state/document_state.dart';

/// The Documents ocean center — a document opens in the Notion-style [AnDocEditor] (P3: editable WYSIWYG,
/// markdown source of truth, debounced content save); a skill still renders a read-only preview (its full
/// structured editor is P4). No selection → an empty "pick a document" state. All content flows through the
/// repository seam. 文档海洋中心:文档进 Notion 式可编辑器(去抖保存);skill 暂只读(P4);无选区=空态。
class DocumentOcean extends ConsumerWidget {
  const DocumentOcean({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final selected = ref.watch(selectedDocProvider);
    if (selected == null) {
      return AnState(kind: AnStateKind.empty, title: t.documents.pickTitle, hint: t.documents.pickHint);
    }
    // Key the doc edit view by id so switching documents resets the editor + its debouncer cleanly. 按 id 键控,换文档即重建。
    return selected.isSkill
        ? _skill(context, ref, selected.id)
        : _DocEditView(key: ValueKey(selected.id), id: selected.id);
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

  static Widget _title(BuildContext context, String text) =>
      Text(text, style: AnText.h2.weight(AnText.emphasisWeight).copyWith(color: context.colors.ink));
}

/// Maps the i18n slash strings into the editor's [SlashMenuLabels] (AnDocEditor is a core/ui primitive and
/// stays i18n-free — the feature layer injects the labels). i18n → 编辑器块菜单文案(core/ui 不碰 i18n)。
SlashMenuLabels _slashLabels(Translations t) => SlashMenuLabels(
      text: t.documents.slash.text,
      h1: t.documents.slash.h1,
      h2: t.documents.slash.h2,
      h3: t.documents.slash.h3,
      bulleted: t.documents.slash.bulleted,
      numbered: t.documents.slash.numbered,
      quote: t.documents.slash.quote,
    );

/// The editable document view — a fixed title bar (the doc NAME, aligned to the editor's 720/pageX column)
/// over the [AnDocEditor] which fills the rest + scrolls internally. Edits serialize to markdown and save
/// via `updateDocument` (debounced 600ms; the open provider is NOT invalidated, so the editor keeps its
/// cursor). 可编辑文档视图:固定标题栏 + 占余高内部滚的 AnDocEditor;编辑去抖 600ms 存 content(不 invalidate、保光标)。
class _DocEditView extends ConsumerStatefulWidget {
  const _DocEditView({required this.id, super.key});

  final String id;

  @override
  ConsumerState<_DocEditView> createState() => _DocEditViewState();
}

class _DocEditViewState extends ConsumerState<_DocEditView> {
  final _save = Debouncer(const Duration(milliseconds: 600));

  @override
  void dispose() {
    _save.dispose();
    super.dispose();
  }

  void _onChanged(String markdown) => _save.run(() {
        if (!mounted) return;
        // Content PATCH IS the save (no versioning). 存正文=PATCH content。
        ref.read(documentsRepositoryProvider).updateDocument(widget.id, {'content': markdown});
      });

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    return ref.watch(openDocumentProvider(widget.id)).when(
          loading: () => const AnDeferredLoading(child: AnSkeleton.lines(8)),
          error: (_, _) => AnState(kind: AnStateKind.error, title: t.documents.loadFailed, hint: t.documents.errorHint),
          data: (doc) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title bar — the doc NAME, LEFT-aligned to the editor's reading column (720 + pageX). Align
                // fills the column so the title's left edge matches the editor body (not centered as a narrow
                // Text). 标题左对齐到编辑器列(Align 撑满列宽,左缘对齐正文,不被当窄内容居中)。
                Padding(
                  padding: const EdgeInsets.only(top: AnFlow.headingTop),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: AnSize.content),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AnInset.pageX),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: DocumentOcean._title(
                              context, doc.name.isEmpty ? t.documents.untitled : doc.name),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AnFlow.headBody),
                Expanded(
                  child: AnDocEditor(
                    initialMarkdown: doc.content,
                    onChanged: _onChanged,
                    // The @ typeahead reuses chat's entity mention seam (function/handler/agent/workflow).
                    // @ 预输入复用 chat 的实体 mention 缝。
                    mentionSource: ref.watch(mentionSourceProvider),
                    // The `/` slash block menu — labels injected here (core/ui stays i18n-free). `/` 块菜单文案注入。
                    slashLabels: _slashLabels(t),
                  ),
                ),
              ],
            );
          },
        );
  }
}
