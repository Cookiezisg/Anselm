import 'package:flutter/widgets.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_inline_edit.dart';
import 'an_tags.dart';

/// The READING-scale page header — the reading-column counterpart to [AnOceanHeader]. Where the ocean
/// header sits at the CHROME scale (H2 title, label crumb) atop the entity/settings oceans, this one
/// renders at the CONTENT/READING scale (readingH1 title, reading description) for a file-like document
/// or skill: a faint crumb, a renamable big title, an editable description, and (documents only) an
/// editable tags row. Every element is an existing primitive ([AnInlineEdit]/[AnTags]/[Text]); the value
/// of the primitive is that the ARRANGEMENT (the crumb→title→desc→tags rhythm) lives in ONE named place
/// with a gallery specimen instead of being re-invented inside a feature (WRK-066 A-113).
///
/// The host wraps this in a measured [KeyedSubtree] to derive the floating-breadcrumb collapse threshold
/// from the real header height — this widget owns no scroll and no measurement, it just renders.
///
/// 阅读尺度页头——[AnOceanHeader] 的阅读列对位件。海洋头走 chrome 尺度(H2/label),此件走内容/阅读尺度
/// (readingH1 标题 + reading 描述),供文件式 document/skill:灰面包屑 + 可改名大标题 + 可编描述 +
/// (仅 document)可编标签行。元件皆既有原语,价值在于把「排布文法」(crumb→标题→描述→标签 的节奏)收进
/// 一个具名+有 gallery specimen 的地方,而非在 feature 里现场发明(A-113)。宿主用测量 KeyedSubtree 包它派生
/// 浮层头折叠阈;本件无滚动、无测量,只渲染。
class AnDocHeader extends StatelessWidget {
  const AnDocHeader({
    required this.crumb,
    required this.name,
    this.nameEditable = true,
    this.description = '',
    this.tags = const [],
    this.showTags = true,
    this.onMetaChanged,
    super.key,
  });

  /// The parent path / kind line above the title. 标题上方的路径/类型行。
  final String crumb;

  /// The document/skill title — the reading-column H1. 标题=阅读列 H1。
  final String name;

  /// Whether the title renames in place. Skills aren't renamable (the name is the identity). 可否就地改名。
  final bool nameEditable;

  /// The reading-style description under the title. 标题下的 reading 描述。
  final String description;

  /// The tag labels (documents only). 标签(仅 document)。
  final List<String> tags;

  /// Whether the tags row renders — skills have no `tags` frontmatter, so an editable tags row there is a
  /// phantom edit. skill 无 tags,故不渲标签行。
  final bool showTags;

  /// Reports a metadata edit — `{name?, description?, tags?}` (the host diffs + persists). Null → the
  /// title/description/tags still render but commits are inert. 元数据编辑回调(宿主 diff+存);null=只读渲染。
  final ValueChanged<Map<String, dynamic>>? onMetaChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    void meta(String key, Object value) => onMetaChanged?.call({key: value});
    return Padding(
      padding: const EdgeInsets.only(top: AnSpace.s24, bottom: AnSpace.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(crumb, style: AnText.meta.copyWith(color: c.inkFaint)),
          const SizedBox(height: AnSpace.s8),
          // Renamable H1 title (skills aren't renamable — the name is the identity). 可改名 H1(skill 不可)。
          AnInlineEdit(
            value: name,
            enabled: nameEditable,
            style: AnText.readingH1.copyWith(color: c.ink),
            minHeight: AnSize.islandHead,
            // A doc page: an idle click elsewhere while renaming should SAVE (not silently drop). 点别处即存。
            commitOnTapOutside: true,
            onCommit: (v) => meta('name', v),
          ),
          const SizedBox(height: AnSpace.s4),
          AnInlineEdit(
            value: description,
            style: AnText.reading.copyWith(color: c.inkMuted),
            commitOnTapOutside: true,
            onCommit: (v) => meta('description', v),
          ),
          if (showTags && (tags.isNotEmpty || onMetaChanged != null)) ...[
            const SizedBox(height: AnSpace.s8),
            AnTags(
              tags: [for (final tag in tags) AnTag(tag)],
              onChanged: (t) => meta('tags', [for (final tag in t) tag.label]),
            ),
          ],
        ],
      ),
    );
  }
}
