import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/contract/entities/document.dart';
import '../../../core/contract/entities/skill.dart';
import '../../../core/design/tokens.dart';
import '../../../core/entity/mention_source.dart';
import '../../../core/model/status_state.dart';
import '../../../core/notice/notice_center.dart';
import '../../../core/perf/debouncer.dart';
import '../../../core/shell/shell_chrome.dart';
import '../../../core/ui/an_crumbs.dart';
import '../../../core/ui/an_deferred_loading.dart';
import '../../../core/ui/an_page.dart';
import '../../../core/ui/an_skeleton.dart';
import '../../../core/ui/an_state.dart';
import '../../../core/ui/entity_ref_codec.dart';
import '../../../i18n/strings.g.dart';
import '../data/library_repository.dart';
import '../model/doc_outline.dart';
import '../state/library_state.dart';
import 'an_document_editor.dart';
import 'skill_file_preview.dart';

/// Resolves the display names for the `[[id]]` mentions in a document's markdown [content] — batched once
/// so the native editor can inflate its mention pills with names (not bare ids) at load. Keyed by the
/// load-time content (stable across edits, since a save doesn't invalidate `openDocumentProvider`), so it
/// stays cached while the doc is open; autoDispose frees it when you leave (else one instance per doc
/// opened lingers for the session). `[[id]]`→名批解析,autoDispose 与兄弟一致。
final documentMentionNamesProvider = FutureProvider.autoDispose
    .family<Map<String, String>, String>((ref, content) async {
      final ids = extractEntityRefIds(content);
      if (ids.isEmpty) return const {};
      return ref.read(mentionSourceProvider).resolveNames(ids);
    });

/// The breadcrumb parent PATH for a document — «Documents / …ancestor names… / direct parent», walking
/// [DocumentNode.parentId] up the [tree] (cycle-capped). It NEVER includes the doc itself (that is the big
/// title, 面包屑律). The root «Documents» deselects to the ocean home; each ancestor navigates to its page;
/// a deep tree folds its middle to «…» in [AnCrumbs]. 文档面包屑父路径:沿 parentId 上溯(防环封顶),绝不
/// 含自己;根「Documents」回海洋主页、各祖先导航到其页、深链在原语内折中段。
List<AnCrumb> libraryCrumbs(
  BuildContext context,
  List<DocumentNode> tree,
  String docId,
) {
  final t = context.t;
  final byId = {for (final d in tree) d.id: d};
  final ancestors = <DocumentNode>[];
  final seen = <String>{docId};
  var pid = byId[docId]?.parentId;
  var guard = 0;
  while (pid != null && guard++ < 64 && seen.add(pid)) {
    final node = byId[pid];
    if (node == null) break;
    ancestors.add(node);
    pid = node.parentId;
  }
  return [
    AnCrumb(t.library.documents, onTap: () => context.go('/')),
    for (final a in ancestors.reversed)
      AnCrumb(
        a.name.trim().isEmpty ? t.library.untitled : a.name,
        onTap: () => context.go(documentLocation(a.id)),
      ),
  ];
}

/// The Documents ocean center — the native [AnDocumentEditor] fills the ocean, its title/description/tags
/// header co-scrolling with the body in one page scroll (a product characteristic). This host stays thin:
/// it binds the doc name to the shell's floating breadcrumb, collapses it as the page scrolls (onScroll),
/// drives the inspector's live outline focus (onActiveHeading), and answers outline jumps
/// (scrollToHeading). No selection → the passive-landing DRAFT editor ([_DraftDocView], uncreated until the
/// first edit). 文档海洋中心:原生 AnDocumentEditor 填满海洋,标题头与正文同页同滚;宿主只绑浮层头 + 随滚折叠 +
/// 喂大纲焦点 + 应答跳转;无选区=被动着陆草稿编辑器(首次编辑才建)。
class LibraryOcean extends ConsumerWidget {
  const LibraryOcean({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDocProvider);
    final adopted = ref.watch(adoptedDraftDocProvider);
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

    // Passive landing (no selection) → a DRAFT editor (uncreated); OR the just-created draft continuing
    // seamlessly under its own new id (the ocean keeps the SAME editor mounted so the create is jump-free,
    // B2/B6). The stable key means the draft view is NEVER remounted across «adopt + navigate».
    // 无选区=草稿编辑器;或刚建的草稿在其新 id 下无缝续命(海洋保持同一编辑器不重挂,建即无跳变)。常量 key 保证不重挂。
    final isAdoptedDraft =
        selected != null && !selected.isSkill && selected.id == adopted;
    if (selected == null || isAdoptedDraft) {
      return const _DraftDocView(key: ValueKey('doc-draft'));
    }
    // A real selection that isn't the adopted draft → any prior draft was left behind; drop the adoption
    // (post-frame — can't mutate a provider mid-build) so re-opening that doc later mounts a fresh live
    // editor. 真选区且非草稿 → 弃认领(帧后),使日后重开该 doc 挂全新编辑器。
    if (adopted != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          ref.read(adoptedDraftDocProvider.notifier).set(null);
        }
      });
    }
    // Key by id so switching remounts the editor + its debouncer cleanly. 按 id 键控,换选即重建。
    return selected.isSkill
        ? _SkillEditView(
            key: ValueKey('skill:${selected.id}'),
            name: selected.id,
          )
        : _DocEditView(key: ValueKey(selected.id), id: selected.id);
  }
}

/// The thin chrome shared by both edit views: it binds the doc name to the shell's floating breadcrumb
/// (tap = scroll the page to top), collapses it past the header height as the page scrolls, mirrors the
/// editor's active-heading into the inspector outline, seeds/refeeds the outline LIST from the markdown,
/// and forwards an outline-jump to the editor. 薄壳:绑浮层头 + 随滚折叠 + 镜像活动标题 + 从 markdown
/// 播种大纲 + 转发跳转。
mixin _DocPageChrome<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  final GlobalKey<AnDocumentEditorState> editorKey =
      GlobalKey<AnDocumentEditorState>();
  String? _seededOutlineFor;

  /// Bind the doc name to the floating breadcrumb; tapping it scrolls the page back to the top.
  void bindHead(String title) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(shellHeadProvider.notifier)
          .bind(title, () => editorKey.currentState?.scrollToTop());
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
      if (mounted) {
        ref.read(docOutlineProvider.notifier).set(extractDocOutline(markdown));
      }
    });
  }

  /// An edit re-feeds the outline synchronously (already outside build). 编辑即时重喂。
  void feedOutlineOnEdit(String markdown) {
    _seededOutlineFor = markdown;
    ref.read(docOutlineProvider.notifier).set(extractDocOutline(markdown));
  }

  void listenOutlineJumps() {
    ref.listen(outlineJumpProvider, (prev, next) {
      if (next != null && next != prev) {
        editorKey.currentState?.scrollToHeading(next.index);
      }
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

class _DocEditViewState extends ConsumerState<_DocEditView>
    with _DocPageChrome {
  final _save = Debouncer(AnMotion.autosave);
  final _outline = Debouncer(
    AnMotion.searchDebounce,
  ); // C-008: the outline re-extract is O(doc); debounce it

  // One-shot: did the rail's active «+ New» path mark THIS doc for a title autofocus? Latched at mount
  // (keyed by id) + cleared, so an async rebuild before the editor mounts can't lose it. 主动新建标题聚焦一次性。
  late final bool _autofocusName;

  @override
  void initState() {
    super.initState();
    _autofocusName = ref.read(focusNewDocTitleProvider) == widget.id;
    if (_autofocusName) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(focusNewDocTitleProvider.notifier).set(null);
      });
    }
  }

  @override
  void dispose() {
    // flush, NOT dispose: deliver the last unsaved edit before unmounting — a doc-switch/deselect within
    // the 600ms autosave window used to CANCEL the pending save and silently drop it. mounted is still
    // true here so the save callback runs. flush 非 dispose:卸载前交付末次未存编辑(防抖窗口内切走曾丢存)。
    _save.flush();
    _outline.dispose();
    super.dispose();
  }

  void _onChanged(String markdown) {
    // C-008: extractDocOutline is O(doc) — a keystroke burst used to re-scan the whole doc each key.
    // Debounce it (the outline is a right-panel display; a ~250ms lag is imperceptible). 大纲重扫防抖。
    _outline.run(() {
      if (mounted) feedOutlineOnEdit(markdown);
    });
    // Capture the repo NOW (while mounted) so the save can be FLUSHED in dispose without touching `ref` —
    // Riverpod disposes the ref during unmount, so a `ref.read` there throws. 挂载时捕获 repo,使 dispose
    // flush 存不碰 ref(卸载期 ref 已释放,ref.read 会抛)。
    final repo = ref.read(libraryRepositoryProvider);
    _save.run(() async {
      // Content PATCH IS the save. The editor already serializes mentions back to `[[id]]`. A failed save
      // must surface (content PATCH is the document's ONLY persistence). 存正文=PATCH content;失败必冒头。
      try {
        await repo.updateDocument(widget.id, {'content': markdown});
      } catch (_) {
        if (!mounted) {
          return; // widget gone (e.g. flushed on dispose + save failed) → no toast 卸载后不弹
        }
        ref
            .read(noticeCenterProvider.notifier)
            .show(
              context.t.library.actionFailed,
              tone: AnTone.danger,
              coalesceKey: 'document-autosave:${widget.id}',
            );
      }
    });
  }

  /// A meta PATCH (name / description). Safe for the editor: the content string is unchanged, so the
  /// refetch's rebuild no-ops (a new key would remount; same content string doesn't). meta PATCH。
  Future<void> _patchMeta(Map<String, dynamic> fields) async {
    try {
      await ref
          .read(libraryRepositoryProvider)
          .updateDocument(widget.id, fields);
      if (!mounted) return;
      if (fields.containsKey('name')) ref.invalidate(documentTreeProvider);
      ref.invalidate(openDocumentProvider(widget.id));
    } catch (_) {
      if (mounted) {
        ref
            .read(noticeCenterProvider.notifier)
            .show(
              context.t.library.actionFailed,
              tone: AnTone.danger,
              coalesceKey: 'document-save:${widget.id}',
            );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    listenOutlineJumps();
    // The crumb parent chain follows the tree (an ancestor rename / a deep-link tree-load reflows it); the
    // watch only rebuilds this view's props — the GlobalKey editor keeps its State + cursor. 面包屑父链随树。
    final tree =
        ref.watch(documentTreeProvider).value ?? const <DocumentNode>[];
    return ref
        .watch(openDocumentProvider(widget.id))
        .when(
          loading: () => const AnPage(
            child: AnDeferredLoading(child: AnSkeleton.lines(8)),
          ),
          error: (_, _) => AnState(
            kind: AnStateKind.error,
            title: t.library.loadFailed,
            hint: t.library.errorHint,
          ),
          data: (doc) {
            final title = doc.name.isEmpty ? t.library.untitled : doc.name;
            bindHead(title);
            seedOutline(doc.content);
            // Resolve the `[[id]]` mention names BEFORE mounting the editor, so its pills load with names
            // (the editor reads names once at initState). A skeleton covers the batch. 载入前先解析提及名。
            return ref
                .watch(documentMentionNamesProvider(doc.content))
                .maybeWhen(
                  orElse: () => const AnPage(
                    child: AnDeferredLoading(child: AnSkeleton.lines(8)),
                  ),
                  data: (names) => AnDocumentEditor(
                    key: editorKey,
                    crumbs: libraryCrumbs(context, tree, widget.id),
                    name: title,
                    autofocusName: _autofocusName,
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
                      if (name != null && name.isNotEmpty && name != doc.name) {
                        patch['name'] = name;
                      }
                      if (desc != null && desc != doc.description) {
                        patch['description'] = desc;
                      }
                      if (tags != null && !listEquals(tags, doc.tags)) {
                        patch['tags'] = tags;
                      }
                      if (patch.isNotEmpty) _patchMeta(patch);
                    },
                  ),
                );
          },
        );
  }
}

/// The PASSIVE-landing DRAFT editor (B2/B6) — the documents center when nothing is selected. A real
/// [AnDocumentEditor] with NO documentId yet: empty title/description/tags/body wearing their grey guides
/// (空字段引导律). The FIRST meaningful edit (title / body / description / tags — the emptiness gate) POSTs
/// the create, ADOPTS the new id (so the ocean keeps THIS editor mounted — no remount, no cursor/content
/// loss), invalidates the tree (a row grows in the rail), and navigates the URL to the real id. Write
/// nothing then leave = nothing is kept (chat landing「首发才建线程」同心智).
/// 被动着陆草稿编辑器:无 documentId 的真编辑器,空字段穿灰引导;首次有意义编辑即 POST 创建 + 认领新 id(海洋据
/// 认领保持本编辑器不重挂→光标/内容不丢)+ invalidate 树 + 导航到真 id;什么都不写切走=不留。
class _DraftDocView extends ConsumerStatefulWidget {
  const _DraftDocView({super.key});

  @override
  ConsumerState<_DraftDocView> createState() => _DraftDocViewState();
}

class _DraftDocViewState extends ConsumerState<_DraftDocView>
    with _DocPageChrome {
  final _save = Debouncer(AnMotion.autosave);
  final _outline = Debouncer(AnMotion.searchDebounce);

  String? _liveId; // null = still an uncreated draft 未创建
  bool _creating = false;

  // The in-progress draft (header display + create payload + emptiness gate). 草稿态(头显示+创建载荷+判空)。
  String _draftName = '';
  String _draftDescription = '';
  List<String> _draftTags = const [];
  String _draftMarkdown = '';

  // The emptiness gate — title / body / description / tags all untouched (B2 判空标准). 判空标准。
  bool get _empty =>
      _draftName.trim().isEmpty &&
      _draftMarkdown.trim().isEmpty &&
      _draftDescription.trim().isEmpty &&
      _draftTags.isEmpty;

  @override
  void dispose() {
    _save
        .flush(); // deliver the last unsaved edit before unmounting (autosave-window switch). 卸载前交付末次未存。
    _outline.dispose();
    super.dispose();
  }

  /// First meaningful edit → create + adopt + navigate (once). 首次有意义编辑即创建+认领+导航(一次)。
  Future<void> _ensureCreated() async {
    if (_liveId != null || _creating || _empty) return;
    _creating = true;
    final repo = ref.read(libraryRepositoryProvider);
    final t = context.t;
    try {
      final doc = await repo.createDocument(
        name: _draftName.trim().isEmpty
            ? t.library.untitled
            : _draftName.trim(),
        content: _draftMarkdown,
        description: _draftDescription.trim(),
        tags: _draftTags,
      );
      if (!mounted) return;
      setState(() => _liveId = doc.id);
      // Adopt BEFORE navigating: the ocean keeps THIS view mounted (selected.id == adopted). 先认领后导航。
      ref.read(adoptedDraftDocProvider.notifier).set(doc.id);
      ref.invalidate(documentTreeProvider);
      if (context.mounted) context.go(documentLocation(doc.id));
      _scheduleSave(); // flush any keystrokes typed after the create snapshot. 补存创建后新增按键。
    } catch (_) {
      _creating = false;
      if (mounted) {
        ref
            .read(noticeCenterProvider.notifier)
            .show(t.library.actionFailed, tone: AnTone.danger);
      }
    }
  }

  void _onChanged(String markdown) {
    _draftMarkdown = markdown;
    _outline.run(() {
      if (mounted) feedOutlineOnEdit(markdown);
    });
    if (_liveId == null) {
      _ensureCreated();
    } else {
      _scheduleSave();
    }
  }

  // Debounced content PATCH once the draft is created (mirrors _DocEditView; repo captured while mounted so
  // a flush-on-dispose never touches a disposed ref). 创建后去抖存正文;repo 挂载时捕获,防 dispose flush 碰 ref。
  void _scheduleSave() {
    final id = _liveId;
    if (id == null) return;
    final repo = ref.read(libraryRepositoryProvider);
    _save.run(() async {
      try {
        await repo.updateDocument(id, {'content': _draftMarkdown});
      } catch (_) {
        if (!mounted) return;
        ref
            .read(noticeCenterProvider.notifier)
            .show(
              context.t.library.actionFailed,
              tone: AnTone.danger,
              coalesceKey: 'document-draft:$id',
            );
      }
    });
  }

  void _onMeta(Map<String, dynamic> m) {
    setState(() {
      if (m['name'] is String) _draftName = (m['name'] as String).trim();
      if (m['description'] is String) {
        _draftDescription = m['description'] as String;
      }
      if (m['tags'] is List) _draftTags = (m['tags'] as List).cast<String>();
    });
    if (_liveId == null) {
      _ensureCreated();
    } else {
      _patchMeta(m);
    }
  }

  Future<void> _patchMeta(Map<String, dynamic> fields) async {
    final id = _liveId;
    if (id == null) return;
    try {
      await ref.read(libraryRepositoryProvider).updateDocument(id, fields);
      if (!mounted) return;
      if (fields.containsKey('name')) ref.invalidate(documentTreeProvider);
    } catch (_) {
      if (mounted) {
        ref
            .read(noticeCenterProvider.notifier)
            .show(context.t.library.actionFailed, tone: AnTone.danger);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    listenOutlineJumps();
    bindHead(_draftName.trim().isEmpty ? t.library.untitled : _draftName);
    return AnDocumentEditor(
      key: editorKey,
      // A draft is created at root, so its parent path is just «Documents» (root deselects to home).
      // 草稿建于根级,父路径只有「Documents」(根回海洋主页)。
      crumbs: [AnCrumb(t.library.documents, onTap: () => context.go('/'))],
      name: _draftName, // empty → the header's grey «未命名» guide 空→头灰引导
      description: _draftDescription,
      tags: _draftTags,
      initialMarkdown:
          '', // constant — the AnEditor owns the live body (never reset across adopt). 正文归 AnEditor。
      onChangedMarkdown: _onChanged,
      onScroll: onScroll,
      onActiveHeading: onActive,
      // The @ typeahead reuses chat's entity mention seam — the same as a live document. @ 提及同实文档。
      mentionSource: ref.watch(mentionSourceProvider),
      onMetaChanged: _onMeta,
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

class _SkillEditViewState extends ConsumerState<_SkillEditView>
    with _DocPageChrome {
  final _save = Debouncer(AnMotion.autosave);
  final _outline = Debouncer(
    AnMotion.searchDebounce,
  ); // C-008: debounce the O(doc) outline re-extract

  @override
  void dispose() {
    // flush, NOT dispose: deliver the last unsaved edit before unmounting — a doc-switch/deselect within
    // the 600ms autosave window used to CANCEL the pending save and silently drop it. mounted is still
    // true here so the save callback runs. flush 非 dispose:卸载前交付末次未存编辑(防抖窗口内切走曾丢存)。
    _save.flush();
    _outline.dispose();
    super.dispose();
  }

  void _onChanged(String markdown) {
    // C-008: debounce the O(doc) outline re-extract (right-panel display; ~250ms lag imperceptible). 大纲防抖。
    _outline.run(() {
      if (mounted) feedOutlineOnEdit(markdown);
    });
    // Capture the repo NOW (while mounted) so the save survives a flush-on-dispose (ref is gone by then).
    // 挂载时捕获 repo,使 dispose flush 存不碰 ref。
    final repo = ref.read(libraryRepositoryProvider);
    _save.run(() async {
      try {
        // Read-modify-write: the properties panel may have saved newer frontmatter than this view's
        // snapshot — fetch it fresh, then PUT the whole set with the new body. 写前取最新 frontmatter。
        final current = await repo.getSkill(widget.name);
        final f = current.frontmatter;
        await repo.replaceSkill(widget.name, {
          'description': f.description.isEmpty
              ? current.description
              : f.description,
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
          ref
              .read(noticeCenterProvider.notifier)
              .show(context.t.library.actionFailed, tone: AnTone.danger);
        }
      }
    });
  }

  /// The header's description edit — the same PUT read-modify-write as a body save (fetch the freshest
  /// frontmatter+body, replace only the description). 头部描述编辑:同款读-改-写 PUT。
  Future<void> _putDescription(String desc) async {
    final repo = ref.read(libraryRepositoryProvider);
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
        ref
            .read(noticeCenterProvider.notifier)
            .show(context.t.library.actionFailed, tone: AnTone.danger);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    listenOutlineJumps();
    // File dispatch (WRK-076 F3): the inspector's file TREE is the navigator (the old file
    // strip is retired); the center renders whatever file is selected — manifest rich/raw by
    // the shared mode provider, siblings through the preview family (md rich text / code /
    // image / svg / csv / font / info+system-open). 文件分派:右岛树是导航器(文件条退役);
    // 清单双模走共享 provider,附属走预览族。
    final file = ref.watch(selectedSkillFileProvider);
    final sourceMode = ref.watch(skillManifestSourceModeProvider);
    final skillDir = ref.watch(openSkillProvider(widget.name)).value?.dir ?? '';
    final isBundled = file != null && file != kSkillManifestFileName;
    if (isBundled) {
      return SkillFilePreview(
        key: ValueKey('skillfile:$file'),
        name: widget.name,
        path: file,
        skillDir: skillDir,
      );
    }
    if (sourceMode) {
      return SkillFilePreview(
        key: const ValueKey('skillfile:manifest-source'),
        name: widget.name,
        path: kSkillManifestFileName,
        skillDir: skillDir,
        rawMode: true,
        onManifestSaved: () => ref.invalidate(openSkillProvider(widget.name)),
      );
    }
    return _richManifestView(context, t);
  }

  Widget _richManifestView(BuildContext context, Translations t) {
    return ref
        .watch(openSkillProvider(widget.name))
        .when(
          loading: () => const AnPage(
            child: AnDeferredLoading(child: AnSkeleton.lines(8)),
          ),
          error: (_, _) => AnState(
            kind: AnStateKind.error,
            title: t.library.loadFailed,
            hint: t.library.errorHint,
          ),
          data: (skill) {
            bindHead(skill.name);
            seedOutline(skill.body);
            // Skills carry no @ mentions (the backend only parses `[[id]]` on DOCUMENTS) → no name resolve.
            // skill 不含 @(后端只在 document 上解析 `[[id]]`)→无需解析名。
            return AnDocumentEditor(
              key: editorKey,
              // «Documents / Skills» — the skills collection is a flat list, so the parent path is fixed
              // (skills have no dedicated route, so «Skills» is inert). 父路径固定;Skills 无独立路由=惰性。
              crumbs: [
                AnCrumb(t.library.documents, onTap: () => context.go('/')),
                AnCrumb(t.library.skills),
              ],
              name: skill.name,
              nameEditable:
                  false, // the name IS the identity — not renamable in place
              showTags:
                  false, // skills have no tags frontmatter — no phantom tags editor 无 tags 字段
              description: skill.description,
              initialMarkdown: skill.body,
              onChangedMarkdown: _onChanged,
              onScroll: onScroll,
              onActiveHeading: onActive,
              onMetaChanged: (m) {
                final desc = m['description'] as String?;
                if (desc != null && desc != skill.description) {
                  _putDescription(desc);
                }
              },
            );
          },
        );
  }
}

// skill folder 的文件条与旧文件视图已退役(WRK-076 F3)——右岛文件树是唯一导航器,
// 预览族在 skill_file_preview.dart。The strip + old file view retired; tree navigates, previews
// live in skill_file_preview.dart.
