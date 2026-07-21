import 'package:flutter/widgets.dart';

import '../design/an_fonts.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'an_chip.dart';
import 'an_crumbs.dart';
import 'an_inline_edit.dart';
import 'an_tags.dart';
import 'icons.dart';

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
    required this.crumbs,
    required this.name,
    this.nameEditable = true,
    this.autofocusName = false,
    this.namePlaceholder,
    this.description = '',
    this.descriptionPlaceholder,
    this.tags = const [],
    this.showTags = true,
    this.addTagLabel,
    this.onMetaChanged,
    this.prose,
    super.key,
  });

  /// The parent PATH above the title — `Documents / …树母链 / 父` for a page, `Documents / Skills` for a
  /// skill (用户 0719 面包屑律:到上一级为止,绝不含自己). Each segment is navigable; the «/» separator and
  /// the deep-tree middle-fold («…») are [AnCrumbs]'. 标题上方的父路径(每段可点、斜杠与深链折叠归原语)。
  final List<AnCrumb> crumbs;

  /// The document/skill title — the reading-column H1. 标题=阅读列 H1。
  final String name;

  /// Whether the title renames in place. Skills aren't renamable (the name is the identity). 可否就地改名。
  final bool nameEditable;

  /// Open the title in edit mode (select-all) on mount — the active «+ New page» path lands focus on the
  /// title so the first keystroke names it. 挂载即进标题编辑(全选):主动新建把焦点落在标题上。
  final bool autofocusName;

  /// Empty-title GUIDE (空字段引导律) — grey placeholder shown when [name] is empty (the passive draft
  /// landing). null → blank. 空标题灰引导(被动草稿着陆)。
  final String? namePlaceholder;

  /// The reading-style description under the title. 标题下的 reading 描述。
  final String description;

  /// Empty-description GUIDE — grey, clickable «add a description…» placeholder. 空简介灰引导(可点)。
  final String? descriptionPlaceholder;

  /// The tag labels (documents only). 标签(仅 document)。
  final List<String> tags;

  /// Whether the tags row renders — skills have no `tags` frontmatter, so an editable tags row there is a
  /// phantom edit. skill 无 tags,故不渲标签行。
  final bool showTags;

  /// Empty-tags GUIDE label — a grey dummy pill wearing the tag shape («add a tag») that opens the add
  /// field on tap (空字段引导律:穿目标形态). null → the plain always-present add field. 空标签灰 dummy 药丸。
  final String? addTagLabel;

  /// Reports a metadata edit — `{name?, description?, tags?}` (the host diffs + persists). Null → the
  /// title/description/tags still render but commits are inert. 元数据编辑回调(宿主 diff+存);null=只读渲染。
  final ValueChanged<Map<String, dynamic>>? onMetaChanged;

  /// The CONTENT (②) font override for the reading-column title + description (the「含文档大标题」clause of
  /// the content axis辖区) — from `contentFaceProvider`. `null` = default sans. The crumb + tags stay on the
  /// UI face (chrome). 大标题+描述的内容字体覆盖(内容轴辖区「含文档大标题」);null=默认 sans;面包屑+标签守 UI 脸。
  final AnFace? prose;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    void meta(String key, Object value) => onMetaChanged?.call({key: value});
    return Padding(
      padding: const EdgeInsets.only(top: AnSpace.s24, bottom: AnSpace.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The reading-scale crumb path — a deep document tree folds its middle to «…» past 3 segments
          // (Notion 同款). 阅读尺度面包屑路径;深链超 3 段折中段。
          AnCrumbs(crumbs, style: AnText.meta, foldAfter: 3),
          const SizedBox(height: AnSpace.s8),
          // Renamable H1 title (skills aren't renamable — the name is the identity). 可改名 H1(skill 不可)。
          AnInlineEdit(
            value: name,
            enabled: nameEditable,
            startEditing: autofocusName,
            placeholder: namePlaceholder,
            style: applyContentFace(
              prose,
              AnText.readingH1,
            ).copyWith(color: c.ink),
            minHeight: AnSize.islandHead,
            // A doc page: an idle click elsewhere while renaming should SAVE (not silently drop). 点别处即存。
            commitOnTapOutside: true,
            onCommit: (v) => meta('name', v),
          ),
          const SizedBox(height: AnSpace.s4),
          AnInlineEdit(
            value: description,
            placeholder: descriptionPlaceholder,
            style: applyContentFace(
              prose,
              AnText.reading,
            ).copyWith(color: c.inkMuted),
            commitOnTapOutside: true,
            onCommit: (v) => meta('description', v),
          ),
          if (showTags && (tags.isNotEmpty || onMetaChanged != null)) ...[
            const SizedBox(height: AnSpace.s8),
            _HeaderTagsRow(
              tags: tags,
              addTagLabel: addTagLabel,
              onChanged: onMetaChanged == null ? null : (t) => meta('tags', t),
            ),
          ],
        ],
      ),
    );
  }
}

/// The header's tags row with the empty-field GUIDE (空字段引导律). Empty + editable + an [addTagLabel] →
/// a grey dummy [AnChip] wearing the tag-pill shape; tapping it opens the [AnTags] add field (the guide
/// previews the target shape). Non-empty (or no guide label) → the plain [AnTags] with its always-present
/// field. Stateful only to own the dummy-pill ↔ field toggle. 头标签行:空+可编+有引导 → 灰 dummy 药丸,点开
/// AnTags 输入框;非空 → 普通 AnTags。
class _HeaderTagsRow extends StatefulWidget {
  const _HeaderTagsRow({
    required this.tags,
    required this.addTagLabel,
    this.onChanged,
  });

  final List<String> tags;
  final String? addTagLabel;
  final ValueChanged<List<String>>? onChanged;

  @override
  State<_HeaderTagsRow> createState() => _HeaderTagsRowState();
}

class _HeaderTagsRowState extends State<_HeaderTagsRow> {
  bool _adding = false;

  @override
  Widget build(BuildContext context) {
    final editable = widget.onChanged != null;
    // The dummy-pill guide only when there's nothing yet, we're not mid-add, it's editable, and a guide
    // label was supplied. 灰 dummy 药丸只在:空 + 未在添加 + 可编 + 有引导词。
    if (widget.tags.isEmpty &&
        !_adding &&
        editable &&
        widget.addTagLabel != null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: AnChip(
          widget.addTagLabel!,
          look: AnChipLook.outlined,
          icon: AnIcons.plus,
          onTap: () => setState(() => _adding = true),
        ),
      );
    }
    return AnTags(
      tags: [for (final tag in widget.tags) AnTag(tag)],
      showAddField: _adding ? true : null,
      onChanged: widget.onChanged == null
          ? null
          : (t) => widget.onChanged!([for (final tag in t) tag.label]),
      onAddDismissed: () {
        if (_adding && mounted) setState(() => _adding = false);
      },
    );
  }
}
