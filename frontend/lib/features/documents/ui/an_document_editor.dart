import 'package:flutter/widgets.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/editor/an_editor.dart';
import '../../../core/entity/mention_source.dart';
import '../../../core/ui/an_inline_edit.dart';
import '../../../core/ui/an_tags.dart';

/// The native documents view (E9c) — the Flutter replacement for the webview `AnDocEditor`. A co-scroll
/// column (the product characteristic): the header (crumb + renamable title + description + tags) scrolls
/// WITH the body inside ONE outer scrollable, and the body is the native [AnEditor] (shrink-wrapped so the
/// outer scroll owns the whole page). It forwards edits as markdown (the host debounces the save), reports
/// the scroll offset (the shell collapses its floating breadcrumb) + the active heading (the inspector
/// outline's live focus), and answers scroll-to-top / scroll-to-heading via its [GlobalKey] state.
/// 原生文档视图:替 webview AnDocEditor。同滚列(头随正文同滚于一个外层),正文=native AnEditor(shrinkWrap、外层滚);
/// 吐 markdown(宿主防抖存)、报滚动位(壳折叠浮标)+ 活动标题(右岛大纲焦点),应答 scrollToTop/scrollToHeading。
class AnDocumentEditor extends StatefulWidget {
  const AnDocumentEditor({
    required this.crumb,
    required this.name,
    this.nameEditable = true,
    this.description = '',
    this.tags = const [],
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

  static const double _measure = 720; // the An reading column 阅读列
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

  /// Scroll so the index-th heading sits near the viewport top. Its content-space Y IS the scroll offset.
  /// 滚到第 index 个标题:其内容 Y 即滚动位。
  void scrollToHeading(int index) {
    final ids = _editorKey.currentState?.headingNodeIds ?? const [];
    if (index < 0 || index >= ids.length || !_scroll.hasClients) return;
    final top = _editorKey.currentState?.contentTopForNode(ids[index]);
    if (top == null) return;
    final target = (top - AnSpace.s16).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(target, duration: AnMotion.mid, curve: Curves.easeOutCubic);
  }

  void _emitActiveHeading() {
    final cb = widget.onActiveHeading;
    if (cb == null || !_scroll.hasClients) return;
    final ids = _editorKey.currentState?.headingNodeIds ?? const [];
    final scrolled = _scroll.offset + _activeBand;
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
    // A fixed header over the scrolling body: the editor owns its own vertical scroll (its content is a
    // sliver, so it can't be co-nested in a box-sliver page). We hook the editor's [_scroll] for the
    // floating-breadcrumb collapse + outline focus. 固定头 + 正文自滚(编辑器内容是 sliver、不能盒嵌);挂其滚动。
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _centered(_header(context)),
        Expanded(
          child: _centered(
            AnEditor(
              key: _editorKey,
              initialMarkdown: widget.initialMarkdown,
              resolvedNames: widget.resolvedNames,
              mentionSource: widget.mentionSource,
              onChangedMarkdown: widget.onChangedMarkdown,
              scrollController: _scroll, // the editor owns the scroll; we listen for offset + heading nav
            ),
          ),
        ),
      ],
    );
  }

  // The 720 reading measure, centred, with the editor's own horizontal padding matched by the header. 居中 720。
  Widget _centered(Widget child) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _measure),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: AnSpace.s24), child: child),
        ),
      );

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
          if (widget.tags.isNotEmpty || widget.onMetaChanged != null) ...[
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
