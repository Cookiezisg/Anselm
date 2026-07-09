import 'package:flutter/widgets.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/editor/an_editor.dart';
import '../../../core/entity/mention_source.dart';
import '../../../core/ui/an_inline_edit.dart';
import '../../../core/ui/an_tags.dart';

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
class AnDocumentEditor extends StatefulWidget {
  const AnDocumentEditor({
    required this.crumb,
    required this.name,
    this.nameEditable = true,
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

  final String crumb;
  final String name;
  final bool nameEditable;
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
  State<AnDocumentEditor> createState() => AnDocumentEditorState();
}

class AnDocumentEditorState extends State<AnDocumentEditor> {
  final ScrollController _scroll = ScrollController();
  final GlobalKey<AnEditorState> _editorKey = GlobalKey<AnEditorState>();
  final GlobalKey _headerKey = GlobalKey();

  // The An reading column. Uses the same [AnSize.content] token as AnPage oceans. NOTE: AnPage subtracts
  // 2×pageX for its text (→672) whereas this pure reading surface uses the full column — whether documents
  // should match 672 is a taste call left to the product. 阅读列(与 AnPage 同 token;是否收到 672 是口味,留给产品)。
  static const double _measure = AnSize.content; // 720
  static const double _activeBand = 72; // a heading within this of the viewport top is "active" 活动带

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    widget.onScroll?.call(_scroll.offset);
    _emitActiveHeading();
  }

  /// Scroll the whole page back to the big title. 滚回大标题。
  void scrollToTop() {
    if (_scroll.hasClients) _scroll.animateTo(0, duration: AnMotion.mid, curve: Curves.easeOutCubic);
  }

  /// The page-scroll offset where the EDITOR's content begins — the bridge between the editor's content
  /// space (contentTopForNode) and the page's scroll space. The editor sliver starts right after the
  /// header sliver, so this is simply the header's laid-out height (its own padding included).
  /// 编辑器内容在页滚动空间的起点(两空间换算桥)——编辑器 sliver 紧跟头 sliver,即头的实测高。
  double? _editorRevealOffset() {
    final box = _headerKey.currentContext?.findRenderObject();
    return (box is RenderBox && box.hasSize) ? box.size.height : null;
  }

  /// Scroll so the index-th heading sits near the viewport top. Page target = the editor's reveal offset
  /// + the heading's content-space Y. 滚到第 index 个标题:页目标=编辑器 reveal 位+标题内容 Y。
  void scrollToHeading(int index) {
    final ids = _editorKey.currentState?.headingNodeIds ?? const [];
    if (index < 0 || index >= ids.length || !_scroll.hasClients) return;
    final top = _editorKey.currentState?.contentTopForNode(ids[index]);
    final editorTop = _editorRevealOffset();
    if (top == null || editorTop == null) return;
    final target = (editorTop + top - AnSpace.s16).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(target, duration: AnMotion.mid, curve: Curves.easeOutCubic);
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
        active = i; // the last heading scrolled past the band is the active one 最后越过带的即活动
      } else {
        break;
      }
    }
    cb(active);
  }

  @override
  Widget build(BuildContext context) {
    // ONE outer CustomScrollView owns the page. SuperEditor with shrinkWrap renders as a SLIVER (box
    // hosts can't nest it — the fixed-head era's constraint), so header + editor ride the same sliver
    // list: the header co-scrolls with the body, and the caret's keep-visible auto-scroll drives this
    // scrollable. The 720 reading measure is a computed symmetric SliverPadding on both slivers.
    // 单一外层 CustomScrollView:shrinkWrap 的 SuperEditor 是 sliver(盒宿主嵌不了——固定头时代的约束),
    // 头与编辑器同列同滚,光标跟随自动滚驱动本滚动;720 阅读列=两 sliver 对称算距。
    return LayoutBuilder(builder: (context, box) {
      final side = box.maxWidth > _measure + AnSpace.s24 * 2
          ? (box.maxWidth - _measure) / 2
          : AnSpace.s24;
      final hpad = EdgeInsets.symmetric(horizontal: side);
      return CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverPadding(
            padding: hpad,
            sliver: SliverToBoxAdapter(child: KeyedSubtree(key: _headerKey, child: _header(context))),
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
            ),
          ),
        ],
      );
    });
  }

  Widget _header(BuildContext context) {
    final c = context.colors;
    void meta(String key, Object value) => widget.onMetaChanged?.call({key: value});
    return Padding(
      padding: const EdgeInsets.only(top: AnSpace.s24, bottom: AnSpace.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.crumb, style: AnText.meta.copyWith(color: c.inkFaint)),
          const SizedBox(height: AnSpace.s8),
          // Renamable H1 title (skills aren't renamable — the name is the identity). 可改名 H1(skill 不可)。
          AnInlineEdit(
            value: widget.name,
            enabled: widget.nameEditable,
            style: AnText.readingH1.copyWith(color: c.ink),
            minHeight: AnSize.islandHead,
            onCommit: (v) => meta('name', v),
          ),
          const SizedBox(height: AnSpace.s4),
          AnInlineEdit(
            value: widget.description,
            style: AnText.reading.copyWith(color: c.inkMuted),
            onCommit: (v) => meta('description', v),
          ),
          if (widget.showTags && (widget.tags.isNotEmpty || widget.onMetaChanged != null)) ...[
            const SizedBox(height: AnSpace.s8),
            AnTags(
              tags: [for (final tag in widget.tags) AnTag(tag)],
              onChanged: (tags) => meta('tags', [for (final tag in tags) tag.label]),
            ),
          ],
        ],
      ),
    );
  }
}
