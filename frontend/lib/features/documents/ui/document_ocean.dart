import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/entities/skill.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/entity/mention_source.dart';
import '../../../core/overlay/an_overlay.dart';
import '../../../core/perf/debouncer.dart';
import '../../../core/shell/shell_chrome.dart';
import '../../../core/ui/an_deferred_loading.dart';
import '../../../core/ui/an_doc_editor.dart';
import '../../../core/ui/an_ocean_header.dart';
import '../../../core/ui/an_page.dart';
import '../../../core/ui/an_scroll_behavior.dart';
import '../../../core/ui/an_skeleton.dart';
import '../../../core/ui/an_state.dart';
import '../../../core/ui/an_toast.dart';
import '../../../i18n/strings.g.dart';
import '../data/document_repository.dart';
import '../model/doc_outline.dart';
import '../state/document_state.dart';

/// The Documents ocean center — one [AnPage] document per selection (the entities model): a big
/// [AnOceanHeader] (breadcrumb + renamable title) and the [AnDocEditor] body share ONE scroll; scrolling
/// the big title under the head band collapses the floating-head breadcrumb to the document's name
/// (shellHeadProvider, same linkage as the entity detail). The editor feeds the LIVE outline (the
/// inspector's table of contents) and answers its jump intents. No selection → an empty "pick" state
/// (and the floating head clears). 文档海洋中心:一份 AnPage 文档(entities 模型)——大头(面包屑+可改名标题)
/// 与编辑器正文**同一滚动**;大标题滚过头带即浮层头显示文档名。编辑器喂活大纲 + 应答跳转;无选=空态并清浮层头。
class DocumentOcean extends ConsumerWidget {
  const DocumentOcean({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final selected = ref.watch(selectedDocProvider);
    // Deselection (navigating home / deleting the open node) leaves no big title — clear the floating
    // head + the stale outline. 取消选区即清浮层头 + 陈旧大纲。
    ref.listen(selectedDocProvider, (prev, next) {
      if (next == null) {
        ref.read(shellHeadProvider.notifier).clear();
        ref.read(docOutlineProvider.notifier).clear();
      }
    });
    if (selected == null) {
      return AnState(kind: AnStateKind.empty, title: t.documents.pickTitle, hint: t.documents.pickHint);
    }
    // Key the edit views by id so switching resets the editor + its debouncer cleanly. 按 id 键控,换选即重建。
    return selected.isSkill
        ? _SkillEditView(key: ValueKey('skill:${selected.id}'), name: selected.id)
        : _DocEditView(key: ValueKey(selected.id), id: selected.id);
  }
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

/// The shared scroll/head/outline plumbing of both edit views (document + skill) — the entity-detail
/// pattern verbatim: an owned ScrollController drives the floating-head collapse (offset past the measured
/// big-header height); the outline is seeded from the loaded markdown and re-fed on every edit; an
/// outline-jump intent converts the heading's GLOBAL origin into this scroll's offset and animates there.
/// 两个编辑视图共用的滚动/浮层头/大纲管线(逐字 entity-detail 范式):自有滚动控制器驱动浮层头折叠(滚过实测
/// 大头高);大纲载入播种+每次编辑重喂;跳转把标题全局位置换算成本滚动偏移。
mixin _DocPageChrome<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  final ScrollController scroll = ScrollController();
  final GlobalKey headerKey = GlobalKey();
  final GlobalKey<AnDocEditorState> editorKey = GlobalKey<AnDocEditorState>();
  double _threshold = 96;
  String? _seededOutlineFor; // last markdown fed to the outline (dedup the per-build seed) 上次喂过的 markdown

  @override
  void initState() {
    super.initState();
    scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    scroll.removeListener(_onScroll);
    scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted || !scroll.hasClients) return;
    ref.read(shellHeadProvider.notifier).setCollapsed(scroll.offset > _threshold);
  }

  void scrollToTop() {
    if (scroll.hasClients) {
      scroll.animateTo(0, duration: AnMotion.mid, curve: AnMotion.easeOut);
    }
  }

  /// After layout: measure the big header (collapse threshold = its height past the head band) and bind
  /// the floating head. 布局后测大头高定阈值 + 绑浮层头。
  void bindHead(String title) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = headerKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        _threshold = (box.size.height - AnSize.islandHead).clamp(8.0, 600.0);
      }
      ref.read(shellHeadProvider.notifier).bind(title, scrollToTop);
    });
  }

  /// Feed the inspector's outline (post-frame — a Notifier must not mutate mid-build), deduped by source
  /// markdown. 喂右岛大纲(帧后——Notifier 不得在 build 中改),按源 markdown 去重。
  void seedOutline(String markdown) {
    if (_seededOutlineFor == markdown) return;
    _seededOutlineFor = markdown;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(docOutlineProvider.notifier).set(extractDocOutline(markdown));
    });
  }

  /// An edit re-feeds the outline synchronously (already outside build). 编辑即时重喂(已在 build 外)。
  void feedOutlineOnEdit(String markdown) {
    _seededOutlineFor = markdown;
    ref.read(docOutlineProvider.notifier).set(extractDocOutline(markdown));
  }

  /// Jump the shared scroll to the N-th heading: heading GLOBAL origin → this scroll viewport's local y →
  /// offset (leaving the head band + a breath of space above). 跳转:标题全局位→滚动局部 y→offset(留头带+呼吸)。
  void jumpToHeading(int index) {
    final origin = editorKey.currentState?.headingOriginGlobal(index);
    if (origin == null || !scroll.hasClients) return;
    final box = scroll.position.context.storageContext.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(origin);
    final target = (scroll.offset + local.dy - AnSize.islandHead - AnSpace.s24)
        .clamp(0.0, scroll.position.maxScrollExtent);
    scroll.animateTo(target, duration: AnMotion.mid, curve: AnMotion.easeOut);
  }

  void listenOutlineJumps() {
    ref.listen(outlineJumpProvider, (prev, next) {
      if (next != null && next != prev) jumpToHeading(next.index);
    });
  }

  /// The one-scroll page as SLIVERS — SuperEditor detects the ancestor Scrollable and renders AS A SLIVER
  /// (a box parent throws), so the doc page can't ride AnPage's SingleChildScrollView: this is AnPage's
  /// exact chrome (overlay RawScrollbar + centered 720 column + head-band top pad) in sliver form. The
  /// editor sliver carries NO extra padding — its own stylesheet pads pageX inside the 720 extent, which
  /// lines it up with the header's padded box. 单滚页的 sliver 形:SuperEditor 见祖先滚动即渲染成 sliver(盒父
  /// 会崩),故不能走 AnPage 的 SingleChildScrollView——这里是 AnPage 同款 chrome(overlay 滚条+居中 720+头带顶
  /// pad)的 sliver 版。编辑器 sliver 不另加 padding(自带 stylesheet 在 720 内 pad pageX),与头对齐。
  Widget buildDocPage(BuildContext context, {required Widget header, required Widget editor}) {
    final c = context.colors;
    return RawScrollbar(
      controller: scroll,
      thumbColor: c.lineStrong,
      radius: const Radius.circular(AnRadius.pill),
      thickness: AnSpace.s4,
      minThumbLength: AnSize.controlSm,
      child: ScrollConfiguration(
        behavior: const AnScrollBehavior(),
        child: CustomScrollView(
          controller: scroll,
          slivers: [
            SliverConstrainedCrossAxis(
              maxExtent: AnSize.content,
              sliver: SliverPadding(
                padding: const EdgeInsets.only(
                  top: AnSize.islandHead + AnSpace.s12,
                  left: AnSpace.s24,
                  right: AnSpace.s24,
                ),
                sliver: SliverToBoxAdapter(child: KeyedSubtree(key: headerKey, child: header)),
              ),
            ),
            SliverConstrainedCrossAxis(maxExtent: AnSize.content, sliver: editor),
          ],
        ),
      ),
    );
  }
}

/// The editable document view — [AnOceanHeader] (breadcrumb `Documents` + the doc name, renamed in place
/// via meta PATCH) over the embedded [AnDocEditor], one scroll. Content saves via `updateDocument`
/// (debounced 600ms; the open provider is NOT invalidated, so the editor keeps its cursor — a rename DOES
/// invalidate it, which is safe: the content string is unchanged, so the editor doesn't rebuild).
/// 可编辑文档视图:AnOceanHeader(面包屑+就地改名)+ 嵌入式 AnDocEditor 同滚。存正文去抖 600ms 不 invalidate
/// (保光标);改名 invalidate 是安全的(content 串没变,编辑器不重建)。
class _DocEditView extends ConsumerStatefulWidget {
  const _DocEditView({required this.id, super.key});

  final String id;

  @override
  ConsumerState<_DocEditView> createState() => _DocEditViewState();
}

class _DocEditViewState extends ConsumerState<_DocEditView> with _DocPageChrome {
  final _save = Debouncer(const Duration(milliseconds: 600));

  @override
  void dispose() {
    _save.dispose();
    super.dispose();
  }

  void _onChanged(String markdown) {
    feedOutlineOnEdit(markdown);
    _save.run(() {
      if (!mounted) return;
      // Content PATCH IS the save (no versioning). The editor already collapsed mention links → `[[id]]`.
      // 存正文=PATCH content;编辑器已把 mention 链接塌回 `[[id]]`。
      ref.read(documentsRepositoryProvider).updateDocument(widget.id, {'content': markdown});
    });
  }

  Future<void> _rename(String value) async {
    final next = value.trim();
    if (next.isEmpty) return;
    try {
      await ref.read(documentsRepositoryProvider).updateDocument(widget.id, {'name': next});
      if (!mounted) return;
      ref.invalidate(documentTreeProvider);
      // Safe for the editor: the content string is unchanged, so AnDocEditor.didUpdateWidget no-ops.
      // 对编辑器安全:content 串没变,didUpdateWidget 不动。
      ref.invalidate(openDocumentProvider(widget.id));
    } catch (_) {
      if (mounted) {
        ref.read(overlayProvider.notifier).showToast(context.t.documents.actionFailed, tone: AnToastTone.danger);
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
            return buildDocPage(
              context,
              header: AnOceanHeader(
                title: title,
                crumbs: [t.documents.documents],
                onTitleChange: _rename,
              ),
              editor: ref.watch(openDocumentContentProvider(widget.id)).when(
                    loading: () => const SliverToBoxAdapter(
                        child: AnDeferredLoading(child: AnSkeleton.lines(8))),
                    error: (_, _) => _editor(t, doc.content),
                    data: (markdown) => _editor(t, markdown),
                  ),
            );
          },
        );
  }

  /// The embedded editor (renders as a SLIVER under the page's scrollable), with the @/slash seams wired —
  /// shared by the content provider's data/error branches. 嵌入式编辑器(祖先滚动下渲染成 sliver),两分支共用。
  Widget _editor(Translations t, String markdown) {
    seedOutline(markdown);
    return AnDocEditor(
      key: editorKey,
      initialMarkdown: markdown,
      onChanged: _onChanged,
      // The @ typeahead reuses chat's entity mention seam (function/handler/agent/workflow). @ 复用 chat mention 缝。
      mentionSource: ref.watch(mentionSourceProvider),
      // The `/` slash block menu — labels injected here (core/ui stays i18n-free). `/` 块菜单文案注入。
      slashLabels: _slashLabels(t),
    );
  }
}

/// The editable SKILL view — the same one-scroll page: [AnOceanHeader] (breadcrumb `Skills` + the slug
/// title, NOT renamable — the name IS the identity) with the frontmatter meta line, over the embedded
/// editor. A save is a PUT full-replace, so the CURRENT frontmatter is fetched right before the write and
/// carried through (read-modify-write — the right-island properties panel is a second writer on the same
/// skill). No @ mentions here: the backend only parses `[[id]]` wikilinks on DOCUMENTS.
/// skill 可编辑视图:同款单滚页——AnOceanHeader(面包屑+slug 标题,**不可改名**:名即身份)+ frontmatter 摘要行
/// + 嵌入式编辑器。存=PUT 全覆盖,写前取当前 frontmatter 带上(读-改-写,右岛是第二写者)。不接 @(后端只对
/// document 解析 [[id]])。
class _SkillEditView extends ConsumerStatefulWidget {
  const _SkillEditView({required this.name, super.key});

  final String name;

  @override
  ConsumerState<_SkillEditView> createState() => _SkillEditViewState();
}

class _SkillEditViewState extends ConsumerState<_SkillEditView> with _DocPageChrome {
  final _save = Debouncer(const Duration(milliseconds: 600));

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
        // description/context fall back to the top-level mirrors (the backend keeps both in sync; data
        // that only filled the mirror must not be blanked by the PUT). description/context 回落顶层镜像。
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
          ref.read(overlayProvider.notifier).showToast(context.t.documents.actionFailed, tone: AnToastTone.danger);
        }
      }
    });
  }

  String _meta(Skill skill) {
    final parts = <String>[
      if (skill.context.isNotEmpty) skill.context,
      if (skill.source.isNotEmpty) skill.source,
      if (skill.frontmatter.allowedTools.isNotEmpty) '${skill.frontmatter.allowedTools.length} tools',
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final c = context.colors;
    listenOutlineJumps();
    return ref.watch(openSkillProvider(widget.name)).when(
          loading: () => const AnPage(child: AnDeferredLoading(child: AnSkeleton.lines(8))),
          error: (_, _) =>
              AnState(kind: AnStateKind.error, title: t.documents.loadFailed, hint: t.documents.errorHint),
          data: (skill) {
            bindHead(skill.name);
            seedOutline(skill.body);
            return buildDocPage(
              context,
              header: AnOceanHeader(
                title: skill.name,
                crumbs: [t.documents.skills],
                meta: [
                  if (_meta(skill).isNotEmpty)
                    Text(_meta(skill), style: AnText.meta.copyWith(color: c.inkFaint)),
                ],
              ),
              editor: AnDocEditor(
                key: editorKey,
                initialMarkdown: skill.body,
                onChanged: _onChanged,
                slashLabels: _slashLabels(t),
              ),
            );
          },
        );
  }
}
