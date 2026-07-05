import 'package:flutter/foundation.dart' show listEquals;
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
import '../../../core/ui/an_field.dart';
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
        ref.read(docOutlineActiveProvider.notifier).set(null);
      } else if (prev != null && prev != next) {
        // Doc-to-doc switch: bind() PRESERVES collapsed (so mid-scroll rebinds can't pop the
        // breadcrumb), so the selection change must reset it — a fresh page opens at the top with
        // its big title visible. 换文档:bind 保留 collapsed(防滚动中弹开),故选区切换在此复位——
        // 新页从顶部开、大标题在场。
        ref.read(shellHeadProvider.notifier).setCollapsed(false);
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
      code: t.documents.slash.code,
      divider: t.documents.slash.divider,
      todo: t.documents.slash.todo,
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
  bool _jumping = false; // an outline jump owns the active highlight until its animation ends 跳转动画期间高亮归点击项
  bool _trackScheduled = false; // coalesce the post-frame spy derivation (one per frame) 帧后推导去重

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
    // A jump owns the highlight while its animation runs (the fly-by must not repaint every row);
    // manual scrolling re-derives — POST-FRAME: a scroll notification fires before the frame lays out,
    // so reading render positions here would be one frame stale (the resting tick would judge with the
    // previous offset's geometry). 跳转动画期间高亮归点击项;手动滚动帧后重推导——滚动通知先于布局,当场读
    // 渲染位置会陈旧一帧(停下那跳会拿上个 offset 的几何判断)。
    if (_jumping || _trackScheduled) return;
    _trackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _trackScheduled = false;
      if (mounted && scroll.hasClients && !_jumping) trackActiveHeading();
    });
  }

  /// The outline's LIVE focus — scroll-spy: the LAST heading whose origin scrolled up past the head band;
  /// pinned to the LAST entry when the scroll is clamped at its end (bottom sections can physically never
  /// reach the band — without this clause they could never highlight). Global-y compare, same space as the
  /// editor's origins. 大纲实时焦点(scroll-spy):最后一个滚过头带的标题;滚到底时钉最后一项(底部章节物理够
  /// 不到头带,无此条永远点不亮)。全局 y 同空间比较。
  void trackActiveHeading() {
    final origins = editorKey.currentState?.headingOriginsGlobal() ?? const [];
    final notifier = ref.read(docOutlineActiveProvider.notifier);
    if (origins.isEmpty) {
      notifier.set(null);
      return;
    }
    final position = scroll.position;
    if (position.maxScrollExtent > 0 && scroll.offset >= position.maxScrollExtent - 1) {
      notifier.set(origins.length - 1);
      return;
    }
    final box = position.context.storageContext.findRenderObject() as RenderBox?;
    if (box == null) return;
    final bandY = box.localToGlobal(Offset.zero).dy + AnSize.islandHead + AnSpace.s24 + 1;
    int? active;
    for (var i = 0; i < origins.length; i++) {
      if (origins[i].dy <= bandY) {
        active = i;
      } else {
        break;
      }
    }
    notifier.set(active);
  }

  void scrollToTop() {
    if (scroll.hasClients) {
      scroll.animateTo(0, duration: AnMotion.mid, curve: AnMotion.easeOut);
    }
  }

  /// After layout: measure the big header (collapse threshold = its height past the head band), bind the
  /// floating head, and seed the outline's live focus. 布局后测大头高定阈值 + 绑浮层头 + 播种大纲焦点。
  void bindHead(String title) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = headerKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        _threshold = (box.size.height - AnSize.islandHead).clamp(8.0, 600.0);
      }
      ref.read(shellHeadProvider.notifier).bind(title, scrollToTop);
      if (scroll.hasClients) trackActiveHeading();
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
  /// offset (leaving the head band + a breath of space above). The CLICKED entry owns the highlight for the
  /// ride (a bottom section clamps at maxScrollExtent and can never reach the band — deriving would light a
  /// passed-by sibling instead of the user's pick). 跳转:标题全局位→滚动局部 y→offset(留头带+呼吸)。点击项
  /// 直接持有高亮(底部章节被 maxScrollExtent 夹断、永远够不到头带,推导会点亮路过的别项而非用户所点)。
  void jumpToHeading(int index) {
    final origin = editorKey.currentState?.headingOriginGlobal(index);
    if (origin == null || !scroll.hasClients) return;
    final box = scroll.position.context.storageContext.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(origin);
    final target = (scroll.offset + local.dy - AnSize.islandHead - AnSpace.s24)
        .clamp(0.0, scroll.position.maxScrollExtent);
    _jumping = true;
    ref.read(docOutlineActiveProvider.notifier).set(index);
    scroll
        .animateTo(target, duration: AnMotion.mid, curve: AnMotion.easeOut)
        .whenComplete(() => _jumping = false);
  }

  void listenOutlineJumps() {
    ref.listen(outlineJumpProvider, (prev, next) {
      if (next != null && next != prev) jumpToHeading(next.index);
    });
  }

  /// The one-scroll page as SLIVERS — SuperEditor detects the ancestor Scrollable and renders AS A SLIVER
  /// (a box parent throws), so the doc page can't ride AnPage's SingleChildScrollView: this is AnPage's
  /// exact chrome (overlay RawScrollbar + centered 720 column + head-band top pad) in sliver form. The
  /// header is box-land (`Center > 720 > pageX pad` — AnPage's literal geometry); the editor sliver spans
  /// the FULL ocean and its single-column layout centers each block itself (stylesheet maxWidth 720 + pageX,
  /// the same numbers), so the title and the body text left-align exactly. ⚠️ NOT SliverConstrainedCrossAxis:
  /// it LEFT-aligns its child (never centers), which pinned the whole page to the ocean's left edge.
  /// 单滚页的 sliver 形:SuperEditor 见祖先滚动即渲染成 sliver(盒父会崩),不能走 AnPage 的 SingleChildScrollView——
  /// 这里是 AnPage 同款 chrome 的 sliver 版。头走盒(Center>720>pageX,AnPage 原几何);编辑器 sliver 铺满海洋、
  /// 由单列布局自己把每块居中(样式表 720+pageX 同数),标题与正文精确对齐。⚠️ 不能用 SliverConstrainedCrossAxis:
  /// 它贴左不居中,整页会钉死在海洋左缘。
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
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: AnSize.content),
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: AnSize.islandHead + AnSpace.s12,
                      left: AnSpace.s24,
                      right: AnSpace.s24,
                    ),
                    child: KeyedSubtree(key: headerKey, child: header),
                  ),
                ),
              ),
            ),
            editor,
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
    _save.run(() async {
      if (!mounted) return;
      // Content PATCH IS the save (no versioning). The editor already collapsed mention links → `[[id]]`.
      // A FAILED save must surface (content PATCH is the document's ONLY persistence — silence loses
      // edits past the last success while the user keeps typing believing they're saved); same
      // try/catch + danger toast as every sibling writer in this file.
      // 存正文=PATCH content;编辑器已把 mention 链接塌回 `[[id]]`。保存失败必须冒头(content PATCH 是
      // 文档唯一持久化——静默失败让用户边打边丢),同本文件其余写手的 try/catch + danger toast。
      try {
        await ref.read(documentsRepositoryProvider).updateDocument(widget.id, {'content': markdown});
      } catch (_) {
        if (!mounted) return;
        ref
            .read(overlayProvider.notifier)
            .showToast(context.t.documents.actionFailed, tone: AnToastTone.danger);
      }
    });
  }

  /// A meta PATCH (name / description / tags — the head's fields). Safe for the editor: the content
  /// string is unchanged, so AnDocEditor.didUpdateWidget no-ops on the refetch. meta PATCH(头上的字段);
  /// 对编辑器安全:content 串没变,重取后 didUpdateWidget 不动。
  Future<void> _patchMeta(Map<String, dynamic> fields) async {
    try {
      await ref.read(documentsRepositoryProvider).updateDocument(widget.id, fields);
      if (!mounted) return;
      if (fields.containsKey('name')) ref.invalidate(documentTreeProvider);
      ref.invalidate(openDocumentProvider(widget.id));
    } catch (_) {
      if (mounted) {
        ref.read(overlayProvider.notifier).showToast(context.t.documents.actionFailed, tone: AnToastTone.danger);
      }
    }
  }

  Future<void> _rename(String value) async {
    final next = value.trim();
    if (next.isEmpty) return;
    await _patchMeta({'name': next});
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
            final p = t.documents.props;
            return buildDocPage(
              context,
              header: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnOceanHeader(
                    title: title,
                    crumbs: [t.documents.documents],
                    onTitleChange: _rename,
                  ),
                  // The page's own properties live UNDER the big title (the entities-overview AnKv
                  // pattern) — the right island keeps only outline / file meta / backlinks. 页属性在大标题
                  // 下(entities overview 同款 AnKv);右岛只留大纲/文件 meta/反链。
                  AnKv(
                    rows: [
                      AnKvRow(p.description, doc.description, editable: true),
                      AnKvRow.tags(p.tags, doc.tags, tagsPlaceholder: p.addTag),
                    ],
                    onChanged: (rows) {
                      final desc = rows[0].value ?? '';
                      final tags = rows[1].tags ?? const [];
                      final patch = <String, dynamic>{};
                      if (desc != doc.description) patch['description'] = desc;
                      if (!listEquals(tags, doc.tags)) patch['tags'] = tags;
                      if (patch.isNotEmpty) _patchMeta(patch);
                    },
                  ),
                ],
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

  /// The head's description edit — the same PUT read-modify-write as a body save (fetch the freshest
  /// frontmatter+body, replace only the description). 头部描述编辑:同款读-改-写 PUT(只换 description)。
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
        ref.read(overlayProvider.notifier).showToast(context.t.documents.actionFailed, tone: AnToastTone.danger);
      }
    }
  }

  String _meta(Skill skill) {
    final parts = <String>[
      if (skill.context.isNotEmpty) skill.context,
      if (skill.source.isNotEmpty) skill.source,
      if (skill.frontmatter.allowedTools.isNotEmpty)
        context.t.documents.toolCount(n: skill.frontmatter.allowedTools.length),
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
              header: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AnOceanHeader(
                    title: skill.name,
                    crumbs: [t.documents.skills],
                    meta: [
                      if (_meta(skill).isNotEmpty)
                        Text(_meta(skill), style: AnText.label.copyWith(color: c.inkFaint)),
                    ],
                  ),
                  // The skill's description edits UNDER the title (same AnKv pattern as documents); the
                  // right island keeps only outline + the frontmatter CONFIG. skill 描述在标题下编辑;右岛
                  // 只留大纲 + frontmatter 配置。
                  AnKv(
                    rows: [AnKvRow(t.documents.props.description, skill.description, editable: true)],
                    onChanged: (rows) => _putDescription(rows[0].value ?? ''),
                  ),
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
