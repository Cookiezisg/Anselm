import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/entity/mention_source.dart';
import '../../../core/model/status_state.dart';
import '../../../core/overlay/an_overlay.dart';
import '../../../core/perf/debouncer.dart';
import '../../../core/shell/shell_chrome.dart';
import '../../../core/ui/an_deferred_loading.dart';
import '../../../core/ui/an_page.dart';
import '../../../core/ui/an_skeleton.dart';
import '../../../core/ui/an_state.dart';
import '../../../core/ui/entity_ref_codec.dart';
import '../../../i18n/strings.g.dart';
import '../data/document_repository.dart';
import '../model/doc_outline.dart';
import '../state/document_state.dart';
import 'an_document_editor.dart';

/// Resolves the display names for the `[[id]]` mentions in a document's markdown [content] — batched once
/// so the native editor can inflate its mention pills with names (not bare ids) at load. Keyed by the
/// load-time content (stable across edits, since a save doesn't invalidate `openDocumentProvider`), so it
/// stays cached while the doc is open; autoDispose frees it when you leave (else one instance per doc
/// opened lingers for the session). `[[id]]`→名批解析,autoDispose 与兄弟一致。
final documentMentionNamesProvider =
    FutureProvider.autoDispose.family<Map<String, String>, String>((ref, content) async {
  final ids = extractEntityRefIds(content);
  if (ids.isEmpty) return const {};
  return ref.read(mentionSourceProvider).resolveNames(ids);
});

/// The Documents ocean center — the native [AnDocumentEditor] fills the ocean, its title/description/tags
/// header co-scrolling with the body in one page scroll (a product characteristic). This host stays thin:
/// it binds the doc name to the shell's floating breadcrumb, collapses it as the page scrolls (onScroll),
/// drives the inspector's live outline focus (onActiveHeading), and answers outline jumps
/// (scrollToHeading). No selection → an empty "pick" state. 文档海洋中心:原生 AnDocumentEditor 填满海洋,
/// 标题头与正文同页同滚;宿主只绑浮层头 + 随滚折叠 + 喂大纲焦点 + 应答跳转。
class DocumentOcean extends ConsumerWidget {
  const DocumentOcean({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final selected = ref.watch(selectedDocProvider);
    // Deselection (navigating home / deleting the open node) clears the floating head + stale outline.
    // 取消选区即清浮层头 + 陈旧大纲。
    ref.listen(selectedDocProvider, (prev, next) {
      if (next == null) {
        ref.read(shellHeadProvider.notifier).clear();
        ref.read(docOutlineProvider.notifier).clear();
        ref.read(docOutlineActiveProvider.notifier).set(null);
      } else if (prev != null && prev != next) {
        // Doc-to-doc switch: a fresh page opens at the top with its big title visible. 换文档从顶部开。
        ref.read(shellHeadProvider.notifier).setCollapsed(false);
      }
    });
    if (selected == null) {
      return AnState(kind: AnStateKind.empty, title: t.documents.pickTitle, hint: t.documents.pickHint);
    }
    // Key by id so switching remounts the editor + its debouncer cleanly. 按 id 键控,换选即重建。
    return selected.isSkill
        ? _SkillEditView(key: ValueKey('skill:${selected.id}'), name: selected.id)
        : _DocEditView(key: ValueKey(selected.id), id: selected.id);
  }
}

/// The thin chrome shared by both edit views: it binds the doc name to the shell's floating breadcrumb
/// (tap = scroll the page to top), collapses it past the header height as the page scrolls, mirrors the
/// editor's active-heading into the inspector outline, seeds/refeeds the outline LIST from the markdown,
/// and forwards an outline-jump to the editor. 薄壳:绑浮层头 + 随滚折叠 + 镜像活动标题 + 从 markdown
/// 播种大纲 + 转发跳转。
mixin _DocPageChrome<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  final GlobalKey<AnDocumentEditorState> editorKey = GlobalKey<AnDocumentEditorState>();
  String? _seededOutlineFor;

  /// Bind the doc name to the floating breadcrumb; tapping it scrolls the page back to the top.
  void bindHead(String title) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(shellHeadProvider.notifier).bind(title, () => editorKey.currentState?.scrollToTop());
    });
  }

  /// The page scroll offset → collapse the floating breadcrumb once the big title has scrolled under.
  /// Threshold = the editor's MEASURED header height (crumb + big title + desc + tags) past the island
  /// head — the entity ocean's formula, so both oceans fold at the same moment; s64 pre-measure fallback.
  /// 阈值=实测头高−岛头(同 entity 公式,两海洋同刻折叠);测量前兜底 s64。
  void onScroll(double offset) {
    if (!mounted) return;
    final h = editorKey.currentState?.headerHeight;
    final threshold = h == null ? AnSpace.s64 : h - AnSize.islandHead;
    ref.read(shellHeadProvider.notifier).setCollapsed(offset > threshold);
  }

  /// The editor's active heading → the inspector outline's live focus (-1 = none).
  void onActive(int index) {
    if (!mounted) return;
    ref.read(docOutlineActiveProvider.notifier).set(index >= 0 ? index : null);
  }

  /// Feed the inspector's outline LIST (post-frame — a Notifier must not mutate mid-build), deduped by
  /// source markdown. 喂右岛大纲(帧后),按源 markdown 去重。
  void seedOutline(String markdown) {
    if (_seededOutlineFor == markdown) return;
    _seededOutlineFor = markdown;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(docOutlineProvider.notifier).set(extractDocOutline(markdown));
    });
  }

  /// An edit re-feeds the outline synchronously (already outside build). 编辑即时重喂。
  void feedOutlineOnEdit(String markdown) {
    _seededOutlineFor = markdown;
    ref.read(docOutlineProvider.notifier).set(extractDocOutline(markdown));
  }

  void listenOutlineJumps() {
    ref.listen(outlineJumpProvider, (prev, next) {
      if (next != null && next != prev) editorKey.currentState?.scrollToHeading(next.index);
    });
  }
}

/// The editable document view — the native [AnDocumentEditor] (crumb `Documents` + renamable title +
/// description + tags in its co-scroll header, over the body). Content saves via `updateDocument`
/// (debounced 600ms; the open provider is NOT invalidated on a content save, so the editor keeps its
/// cursor). Title/description edits in the header report via onMetaChanged → a partial meta PATCH.
/// 可编辑文档视图:原生编辑器(头含面包屑/可改名标题/描述/标签,同滚)。存正文去抖 600ms 不 invalidate;
/// 头部改名/描述经 onMetaChanged → 分部 PATCH。
class _DocEditView extends ConsumerStatefulWidget {
  const _DocEditView({required this.id, super.key});

  final String id;

  @override
  ConsumerState<_DocEditView> createState() => _DocEditViewState();
}

class _DocEditViewState extends ConsumerState<_DocEditView> with _DocPageChrome {
  final _save = Debouncer(AnMotion.autosave);

  @override
  void dispose() {
    _save.dispose();
    super.dispose();
  }

  void _onChanged(String markdown) {
    feedOutlineOnEdit(markdown);
    _save.run(() async {
      if (!mounted) return;
      // Content PATCH IS the save. The editor already serializes mentions back to `[[id]]`. A failed save
      // must surface (content PATCH is the document's ONLY persistence). 存正文=PATCH content;失败必冒头。
      try {
        await ref.read(documentsRepositoryProvider).updateDocument(widget.id, {'content': markdown});
      } catch (_) {
        if (!mounted) return;
        ref
            .read(overlayProvider.notifier)
            .showToast(context.t.documents.actionFailed, tone: AnTone.danger);
      }
    });
  }

  /// A meta PATCH (name / description). Safe for the editor: the content string is unchanged, so the
  /// refetch's rebuild no-ops (a new key would remount; same content string doesn't). meta PATCH。
  Future<void> _patchMeta(Map<String, dynamic> fields) async {
    try {
      await ref.read(documentsRepositoryProvider).updateDocument(widget.id, fields);
      if (!mounted) return;
      if (fields.containsKey('name')) ref.invalidate(documentTreeProvider);
      ref.invalidate(openDocumentProvider(widget.id));
    } catch (_) {
      if (mounted) {
        ref.read(overlayProvider.notifier).showToast(context.t.documents.actionFailed, tone: AnTone.danger);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    listenOutlineJumps();
    return ref.watch(openDocumentProvider(widget.id)).when(
          loading: () => const AnPage(child: AnDeferredLoading(child: AnSkeleton.lines(8))),
          error: (_, _) =>
              AnState(kind: AnStateKind.error, title: t.documents.loadFailed, hint: t.documents.errorHint),
          data: (doc) {
            final title = doc.name.isEmpty ? t.documents.untitled : doc.name;
            bindHead(title);
            seedOutline(doc.content);
            // Resolve the `[[id]]` mention names BEFORE mounting the editor, so its pills load with names
            // (the editor reads names once at initState). A skeleton covers the batch. 载入前先解析提及名。
            return ref.watch(documentMentionNamesProvider(doc.content)).maybeWhen(
                  orElse: () => const AnPage(child: AnDeferredLoading(child: AnSkeleton.lines(8))),
                  data: (names) => AnDocumentEditor(
                    key: editorKey,
                    crumb: t.documents.documents,
                    name: title,
                    description: doc.description,
                    tags: doc.tags,
                    initialMarkdown: doc.content,
                    resolvedNames: names,
                    onChangedMarkdown: _onChanged,
                    onScroll: onScroll,
                    onActiveHeading: onActive,
                    // The @ typeahead reuses chat's entity mention seam (function/handler/agent/workflow).
                    mentionSource: ref.watch(mentionSourceProvider),
                    onMetaChanged: (m) {
                      final patch = <String, dynamic>{};
                      final name = (m['name'] as String?)?.trim();
                      final desc = m['description'] as String?;
                      final tags = (m['tags'] as List?)?.cast<String>();
                      if (name != null && name.isNotEmpty && name != doc.name) patch['name'] = name;
                      if (desc != null && desc != doc.description) patch['description'] = desc;
                      if (tags != null && !listEquals(tags, doc.tags)) patch['tags'] = tags;
                      if (patch.isNotEmpty) _patchMeta(patch);
                    },
                  ),
                );
          },
        );
  }
}

/// The editable SKILL view — the same native editor page: crumb `Skills` + the slug title (NOT renamable
/// — the name IS the identity) + description, over the body. A save is a PUT full-replace, so the CURRENT
/// frontmatter is fetched right before the write and carried through (read-modify-write). No @ mentions
/// here: the backend only parses `[[id]]` on DOCUMENTS. skill 可编辑视图:同款原生编辑器页,标题不可改名;
/// 存=PUT 全覆盖(写前取最新 frontmatter);不接 @。
class _SkillEditView extends ConsumerStatefulWidget {
  const _SkillEditView({required this.name, super.key});

  final String name;

  @override
  ConsumerState<_SkillEditView> createState() => _SkillEditViewState();
}

class _SkillEditViewState extends ConsumerState<_SkillEditView> with _DocPageChrome {
  final _save = Debouncer(AnMotion.autosave);

  @override
  void dispose() {
    _save.dispose();
    super.dispose();
  }

  void _onChanged(String markdown) {
    feedOutlineOnEdit(markdown);
    _save.run(() async {
      if (!mounted) return;
      final repo = ref.read(documentsRepositoryProvider);
      try {
        // Read-modify-write: the properties panel may have saved newer frontmatter than this view's
        // snapshot — fetch it fresh, then PUT the whole set with the new body. 写前取最新 frontmatter。
        final current = await repo.getSkill(widget.name);
        final f = current.frontmatter;
        await repo.replaceSkill(widget.name, {
          'description': f.description.isEmpty ? current.description : f.description,
          'body': markdown,
          'allowedTools': f.allowedTools,
          'context': f.context.isEmpty ? current.context : f.context,
          'agent': f.agent,
          'arguments': f.arguments,
          'disableModelInvocation': f.disableModelInvocation,
          'userInvocable': f.userInvocable,
        });
      } catch (_) {
        if (mounted) {
          ref.read(overlayProvider.notifier).showToast(context.t.documents.actionFailed, tone: AnTone.danger);
        }
      }
    });
  }

  /// The header's description edit — the same PUT read-modify-write as a body save (fetch the freshest
  /// frontmatter+body, replace only the description). 头部描述编辑:同款读-改-写 PUT。
  Future<void> _putDescription(String desc) async {
    final repo = ref.read(documentsRepositoryProvider);
    try {
      final current = await repo.getSkill(widget.name);
      final f = current.frontmatter;
      await repo.replaceSkill(widget.name, {
        'description': desc,
        'body': current.body,
        'allowedTools': f.allowedTools,
        'context': f.context.isEmpty ? current.context : f.context,
        'agent': f.agent,
        'arguments': f.arguments,
        'disableModelInvocation': f.disableModelInvocation,
        'userInvocable': f.userInvocable,
      });
      if (!mounted) return;
      // Safe for the editor: the body string is unchanged, so the rebuild no-ops. body 没变,重建无感。
      ref.invalidate(openSkillProvider(widget.name));
    } catch (_) {
      if (mounted) {
        ref.read(overlayProvider.notifier).showToast(context.t.documents.actionFailed, tone: AnTone.danger);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    listenOutlineJumps();
    return ref.watch(openSkillProvider(widget.name)).when(
          loading: () => const AnPage(child: AnDeferredLoading(child: AnSkeleton.lines(8))),
          error: (_, _) =>
              AnState(kind: AnStateKind.error, title: t.documents.loadFailed, hint: t.documents.errorHint),
          data: (skill) {
            bindHead(skill.name);
            seedOutline(skill.body);
            // Skills carry no @ mentions (the backend only parses `[[id]]` on DOCUMENTS) → no name resolve.
            // skill 不含 @(后端只在 document 上解析 `[[id]]`)→无需解析名。
            return AnDocumentEditor(
              key: editorKey,
              crumb: t.documents.skills,
              name: skill.name,
              nameEditable: false, // the name IS the identity — not renamable in place
              showTags: false, // skills have no tags frontmatter — no phantom tags editor 无 tags 字段
              description: skill.description,
              initialMarkdown: skill.body,
              onChangedMarkdown: _onChanged,
              onScroll: onScroll,
              onActiveHeading: onActive,
              onMetaChanged: (m) {
                final desc = m['description'] as String?;
                if (desc != null && desc != skill.description) _putDescription(desc);
              },
            );
          },
        );
  }
}
