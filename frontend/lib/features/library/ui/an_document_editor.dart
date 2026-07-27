import 'dart:async';

import 'package:flutter/widgets.dart';
import '../../../core/model/status_state.dart';
import '../../../core/notice/notice_center.dart';
import '../../../core/media/media_source.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/an_fonts.dart';
import '../../../core/design/tokens.dart';
import '../../../core/editor/an_editor.dart';
import '../../../core/entity/mention_source.dart';
import '../../../core/perf/frame_safe.dart';
import '../../../core/settings/app_prefs_providers.dart';
import '../../../core/ui/an_crumbs.dart';
import '../../../core/ui/an_doc_header.dart';
import '../../../i18n/strings.g.dart';

/// The native documents view — a CO-SCROLL column (the product characteristic): the header (crumb +
/// renamable title + description + tags) scrolls WITH the body inside ONE outer scrollable, and the body
/// is the native [AnEditor] (shrink-wrapped, so this widget's scrollable owns the whole page — the big
/// title genuinely scrolls under, which is what makes the shell's floating-breadcrumb collapse honest).
/// It forwards edits as markdown (the host debounces the save), reports the scroll offset (the shell
/// collapses its floating breadcrumb) + the active heading (the inspector outline's live focus), and
/// answers scroll-to-top / scroll-to-heading via its [GlobalKey] state. Heading math converts between the
/// editor's content space and the page's scroll space via the viewport's reveal offset (layout-agnostic).
/// 原生文档视图:**同滚列**(头随正文同滚于一个外层滚动;大标题真滚走,浮层头折叠才诚实),正文=AnEditor
/// (shrinkWrap,页滚动归本件);吐 markdown(宿主防抖存)、报滚动位 + 活动标题,应答 scrollToTop/scrollToHeading;
/// 标题坐标经 viewport reveal-offset 在编辑器内容空间↔页面滚动空间换算(对布局不敏感)。
class AnDocumentEditor extends ConsumerStatefulWidget {
  const AnDocumentEditor({
    required this.crumbs,
    required this.name,
    this.nameEditable = true,
    this.autofocusName = false,
    this.description = '',
    this.tags = const [],
    this.showTags = true,
    required this.initialMarkdown,
    this.resolvedNames = const {},
    this.mentionSource,
    required this.onChangedMarkdown,
    this.onScroll,
    this.onActiveHeading,
    this.onMetaChanged,
    super.key,
  });

  /// The parent PATH shown above the title (`Documents / …树母链 / 父`, or `Documents / Skills`) — built by
  /// the host from the document tree; never the doc's own name. 父路径(宿主据文档树构建,绝不含自己)。
  final List<AnCrumb> crumbs;
  final String name;
  final bool nameEditable;

  /// Open the title in edit mode on mount — the active «+ New page» path focuses the title. 挂载即聚焦标题。
  final bool autofocusName;
  final String description;
  final List<String> tags;

  /// Whether the tags editor renders. Skills have no `tags` frontmatter — showing an editable tags row
  /// there is a phantom edit (typed tags are silently dropped by the skill meta handler). skill 无 tags。
  final bool showTags;
  final String initialMarkdown;
  final Map<String, String> resolvedNames;
  final MentionSource? mentionSource;
  final ValueChanged<String> onChangedMarkdown;
  final ValueChanged<double>? onScroll;
  final ValueChanged<int>? onActiveHeading;

  /// Reports a metadata edit — `{name?, description?, tags?}` (the host diffs + PATCHes). 元数据编辑回调。
  final ValueChanged<Map<String, dynamic>>? onMetaChanged;

  @override
  ConsumerState<AnDocumentEditor> createState() => AnDocumentEditorState();
}

class AnDocumentEditorState extends ConsumerState<AnDocumentEditor> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey<AnEditorState> _editorKey = GlobalKey<AnEditorState>();
  final GlobalKey _headerKey = GlobalKey();

  // The An reading text column — aligned pixel-for-pixel with the AnPage oceans (chat/entities/settings):
  // AnPage renders an [AnSize.content] (720) region with [AnInset.pageX] (24) padding, so its TEXT is
  // 672 wide. This surface centers a bare 672 column, and since (vw−672)/2 == (vw−720)/2 + pageX the text
  // occupies the exact same centered band. 阅读文字列与 AnPage 海洋逐像素对齐(720 列−2×24 内距=672 文字)。
  static const double _measure = AnSize.content - AnInset.pageX * 2; // 672
  static const double _activeBand =
      AnSpace.s64; // a heading within this of the viewport top is "active" 活动带

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  // C-029: _emitActiveHeading walks the headings + does a per-heading layout query — O(headings) per
  // scroll frame is scroll jank on a long, heading-dense doc. Throttle to ~50ms (the outline highlight
  // still tracks smoothly) with a trailing emit so the FINAL position lands after the scroll settles.
  // 活动标题计算节流:滚动中每 ~50ms(highlight 仍平滑跟随)+尾沿一发,滚停后落最终位置。
  final _headingThrottle = Stopwatch()..start();
  Timer? _headingTrailing;

  @override
  void dispose() {
    _headingTrailing?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    // The phase gate belongs HERE, at the seam, not in each consumer: past this point the callback is
    // arbitrary code we don't own, and it typically dirties a provider (library_ocean's onScroll folds
    // the shell breadcrumb, onActiveHeading drives the outline). Guarding the emitter makes every
    // consumer — present and future — safe from the layout-phase notification (CR-1b), and no consumer
    // has to know the rule exists. Note this site is invisible to a grep for scroll listeners that
    // dirty state: the side effect lives in another file behind a callback, which is exactly why the
    // CR-1 audit's list of nine missed it.
    // 相位闸该落在**这条缝**上,而非每个消费者里:越过此点就是我们不拥有的任意代码,而它通常会弄脏 provider
    // (library_ocean 的 onScroll 折叠壳面包屑,onActiveHeading 驱动大纲)。守住发射端,则所有消费者——现有的
    // 与将来的——都对布局期通知免疫(CR-1b),且没人需要知道这条规则存在。记一笔:本处对「找会弄脏状态的滚动
    // 监听器」这种 grep 是**隐形的**——副作用在另一个文件、隔着回调,CR-1 审计那份九处名单正是这样漏掉它的。
    final offset = _scroll.offset;
    runFrameSafe(() {
      if (mounted) widget.onScroll?.call(offset);
    });
    // Throttle the heading walk (C-029): emit at most every 50ms during a scroll, and a single trailing
    // emit after it settles so the final active heading is never stale. 节流+尾沿。
    _headingTrailing?.cancel();
    if (_headingThrottle.elapsedMilliseconds >= 50) {
      _headingThrottle.reset();
      _emitActiveHeading();
    } else {
      _headingTrailing = Timer(const Duration(milliseconds: 60), () {
        _headingThrottle.reset();
        _emitActiveHeading();
      });
    }
  }

  /// Scroll the whole page back to the big title. 滚回大标题。
  void scrollToTop() {
    if (_scroll.hasClients) {
      _scroll.animateTo(0, duration: AnMotion.mid, curve: AnMotion.easeOut);
    }
  }

  /// The measured header CONTENT height (crumb + big title + desc + tags), published for the ocean's
  /// floating-head collapse threshold — the SAME quantity the entity ocean measures (its `_headerKey`
  /// wraps only the AnOceanHeader, NOT AnPage's scrim-clearing top pad), so both oceans fold at the same
  /// moment (`headerHeight - islandHead`). null until laid out. 实测头**内容**高(不含清虚化带的顶 pad),
  /// 公开给海洋折叠阈值——与 entity 海洋量同一物(那边 _headerKey 只裹 AnOceanHeader、不含 AnPage 顶 pad),两海洋同刻折叠。
  double? get headerHeight {
    final box = _headerKey.currentContext?.findRenderObject();
    return (box is RenderBox && box.hasSize) ? box.size.height : null;
  }

  /// The scrim-clearing top pad on the header sliver — the exact height of the shell's floating-head band
  /// (mirrors AnPage's top inset, an_page.dart), so the big title lands BELOW the fade at rest instead of
  /// half-faded under it (issue: documents bypasses AnPage and hand-rolls its own CustomScrollView).
  /// 头 sliver 的顶 pad=浮层头带高(镜像 AnPage 顶内距),大标题坐虚化带之下、静息不被虚化。
  static const double _headTopPad = AnSize.islandHead + AnSpace.s12;

  /// The page-scroll offset where the EDITOR's content begins — the bridge between the editor's content
  /// space (contentTopForNode) and the page's scroll space. The editor sliver starts right after the FULL
  /// header sliver = the scrim-clearing top pad + the measured header content.
  /// 编辑器内容在页滚动空间的起点(两空间换算桥)=头 sliver 全高=顶 pad + 实测头内容高。
  double? _editorRevealOffset() {
    final h = headerHeight;
    return h == null ? null : _headTopPad + h;
  }

  /// Scroll so the index-th heading sits near the viewport top. Page target = the editor's reveal offset
  /// + the heading's content-space Y. 滚到第 index 个标题:页目标=编辑器 reveal 位+标题内容 Y。
  void scrollToHeading(int index) {
    final ids = _editorKey.currentState?.headingNodeIds ?? const [];
    if (index < 0 || index >= ids.length || !_scroll.hasClients) return;
    final top = _editorKey.currentState?.contentTopForNode(ids[index]);
    final editorTop = _editorRevealOffset();
    if (top == null || editorTop == null) return;
    // s16 = breathing room left above the heading after the jump (scroll-coordinate composition, not a
    // spacing tier). s16=跳转后标题上方呼吸位(滚动坐标合成,非档位)。
    final target = (editorTop + top - AnSpace.s16).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    _scroll.animateTo(target, duration: AnMotion.mid, curve: AnMotion.easeOut);
  }

  void _emitActiveHeading() {
    final cb = widget.onActiveHeading;
    if (cb == null || !_scroll.hasClients) return;
    final ids = _editorKey.currentState?.headingNodeIds ?? const [];
    final editorTop = _editorRevealOffset();
    if (editorTop == null) return;
    // Compare in the editor's content space: how far the page has scrolled INTO the editor. 换算进内容空间比。
    final scrolled = _scroll.offset - editorTop + _activeBand;
    var active = -1;
    for (var i = 0; i < ids.length; i += 1) {
      final top = _editorKey.currentState?.contentTopForNode(ids[i]);
      if (top == null) continue;
      if (top <= scrolled) {
        active =
            i; // the last heading scrolled past the band is the active one 最后越过带的即活动
      } else {
        break;
      }
    }
    // Same seam, same gate — this runs synchronously from _onScroll on the un-throttled branch, so it
    // inherits the layout phase. Inline in a safe phase, so the throttled Timer path is unchanged.
    // 同一条缝、同一道闸——未被节流的那条分支是从 _onScroll **同步**跑下来的,会继承布局相位;安全相位下
    // 是同步直执行,故节流 Timer 那条路径行为不变。
    runFrameSafe(() {
      if (mounted) cb(active);
    });
  }

  @override
  Widget build(BuildContext context) {
    // ONE outer CustomScrollView owns the page. SuperEditor with shrinkWrap renders as a SLIVER (box
    // hosts can't nest it — the fixed-head era's constraint), so header + editor ride the same sliver
    // list: the header co-scrolls with the body, and the caret's keep-visible auto-scroll drives this
    // scrollable. The 720 reading measure is a computed symmetric SliverPadding on both slivers.
    // 单一外层 CustomScrollView:shrinkWrap 的 SuperEditor 是 sliver(盒宿主嵌不了——固定头时代的约束),
    // 头与编辑器同列同滚,光标跟随自动滚驱动本滚动;720 阅读列=两 sliver 对称算距。
    // The CONTENT (②) font axis — HOT: the documents editor body + big title layer the serif / system
    // face over their reading styles (null = default sans). Watching here rebuilds the header + re-memoizes
    // the editor stylesheet on a live switch. 内容字体轴(热):正文+大标题覆盖衬线/系统脸(null=默认 sans);watch 即切换。
    final prose = ref.watch(contentFaceProvider);
    return LayoutBuilder(
      builder: (context, box) {
        final side =
            box.maxWidth >
                AnSize
                    .content // ≡ _measure + 2×pageX 恒等
            ? (box.maxWidth - _measure) / 2
            : AnInset.pageX;
        final hpad = EdgeInsets.symmetric(horizontal: side);
        return CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverPadding(
              // Top pad clears the shell's floating-head scrim band (like AnPage) — kept OUTSIDE the
              // [_headerKey] subtree so the measured [headerHeight] stays content-only (collapse-threshold
              // parity with the entity ocean). 顶 pad 让出虚化带(同 AnPage),置于 _headerKey 外→量得头高仍是纯内容(与 entity 折叠阈同源)。
              padding: EdgeInsets.only(
                top: _headTopPad,
                left: side,
                right: side,
              ),
              sliver: SliverToBoxAdapter(
                child: KeyedSubtree(
                  key: _headerKey,
                  child: _header(context, prose),
                ),
              ),
            ),
            SliverPadding(
              padding: hpad,
              sliver: AnEditor(
                key: _editorKey,
                initialMarkdown: widget.initialMarkdown,
                resolvedNames: widget.resolvedNames,
                mentionSource: widget.mentionSource,
                onChangedMarkdown: widget.onChangedMarkdown,
                shrinkWrap: true,
                prose: prose,
                pickAndUploadMedia: _pickAndUploadMedia,
              ),
            ),
          ],
        );
      },
    );
  }

  /// The `/media` command's host half: pick a file, land it as a first-class attachment, answer its
  /// id. The editor writes the markdown; this writes the bytes.
  ///
  /// It lives HERE rather than in `core/editor` because the editor is deliberately Riverpod-free —
  /// and it goes through `mediaSourceProvider`, the platform media seam, rather than chat's
  /// repository, because features must not depend on each other. The seam exists for exactly this.
  ///
  /// Null on cancel and on failure alike: from the document's side those are the same event — nothing
  /// to insert. The failure is surfaced to the user by the toast, not by a half-written document.
  ///
  /// `/media` 命令的**宿主**那一半:选文件、把它落成一等附件、答出 id。编辑器写 markdown,这里写字节。
  ///
  /// 它在**这里**而不在 `core/editor`,因为编辑器刻意不沾 Riverpod;而它走
  /// `mediaSourceProvider` 这层平台媒体缝、**不走 chat 的 repository**,因为 features 互不依赖。
  /// 这层缝存在的理由正是这个。
  ///
  /// 取消与失败**同样返 null**:从文档那一侧看它们是同一件事——没有东西可插。失败经 toast 告诉用户,
  /// 而不是靠一份写了一半的文档。
  Future<String?> _pickAndUploadMedia() async {
    final file = await openFile();
    if (file == null) return null;
    try {
      final meta = await ref
          .read(mediaSourceProvider)
          .upload(
            bytes: await file.readAsBytes(),
            filename: file.name,
            mimeType: file.mimeType ?? '',
          );
      return meta.id;
    } catch (_) {
      if (mounted) {
        ref
            .read(noticeCenterProvider.notifier)
            .show(context.t.attach.failedUnreadable, tone: AnTone.danger);
      }
      return null;
    }
  }

  // The reading-scale header is the [AnDocHeader] primitive (A-113 — the arrangement lives in gallery,
  // not invented here); this feature only supplies the data + wires the metadata callback + the empty-field
  // guides (空字段引导律). 阅读尺度头=AnDocHeader 原语,本 feature 喂数据+接元数据回调+空字段引导词。
  Widget _header(BuildContext context, AnFace? prose) {
    final t = context.t;
    return AnDocHeader(
      crumbs: widget.crumbs,
      name: widget.name,
      nameEditable: widget.nameEditable,
      autofocusName: widget.autofocusName,
      namePlaceholder: t.library.untitled,
      description: widget.description,
      descriptionPlaceholder: t.library.addDescription,
      tags: widget.tags,
      showTags: widget.showTags,
      addTagLabel: t.library.addTag,
      onMetaChanged: widget.onMetaChanged,
      prose: prose,
    );
  }
}
