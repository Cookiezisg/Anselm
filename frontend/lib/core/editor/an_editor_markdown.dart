/// The document ↔ markdown codec for the native editor (E9). super_editor dev.40 ships the block + inline
/// serializers we need (heading/blockquote/code/list/task + bold/italic/strike/inline-code), so this is a
/// THIN wrapper that adds the ONE thing it can't do: the entity @mention round-trip. A mention lives in
/// the editor as an inline [MentionPlaceholder] pill but must persist as the backend's `[[<id>]]` wikilink
/// (the ONLY content the `pkg/wikilink` parser reads to build `link` relation edges — round-trip fidelity
/// here is a backend contract, NOT cosmetic). So: on SAVE we flatten each pill to the literal `[[id]]`
/// text before serializing; on LOAD we deserialize, then re-inflate every `[[id]]` back into a pill,
/// resolving its display name from [names] (unknown ids fall back to the bare id) and its kind from the id
/// prefix. 文档↔markdown codec:内置序列化管全部块/行内类型,本层只补 mention 往返(药丸↔`[[id]]`,后端关系边契约、须逐字保真)。
library;

import 'package:super_editor/super_editor.dart';

import 'an_editor_mention.dart';

/// `[[<prefix>_<16 hex>]]` — the stored wire form (mirrors pkg/wikilink + core/ui/entity_ref_codec). 存储线缆形。
final RegExp _wikiRe = RegExp(r'\[\[([a-z]+_[0-9a-f]{16})\]\]');

/// SAVE — flatten every mention pill to `[[id]]` text, then serialize with the built-in block/inline
/// serializers. 存:药丸摊平成 `[[id]]` 文本,再内置序列化。
String markdownFromDocument(Document document) {
  final flattened = MutableDocument(
    nodes: [for (final node in document) node is TextNode ? _flattenNode(node) : node],
  );
  final markdown = serializeDocumentToMarkdown(flattened);
  // Trim per-line trailing whitespace: the built-in code-block serializer ADDS trailing spaces each round
  // (they'd accumulate on repeated save/load), and trailing whitespace is noise in a prose doc anyway.
  // 逐行去尾空白:内置代码块序列化器每轮加尾空格(重复存/载会累积),prose 文档尾空白本就是噪声。
  return markdown.split('\n').map((line) => line.trimRight()).join('\n');
}

/// LOAD — deserialize with the built-in parsers, then re-inflate `[[id]]` runs into mention pills. [names]
/// resolves display names (from `MentionSource.resolveNames`); unknown ids show the bare id. 载:内置解析后回填药丸。
MutableDocument documentFromMarkdown(String markdown, {Map<String, String> names = const {}}) {
  final document = deserializeMarkdownToDocument(markdown);
  return MutableDocument(
    nodes: [for (final node in document) node is TextNode ? _inflateNode(node, names) : node],
  );
}

// A TextNode with each mention placeholder replaced by literal `[[id]]` text (spans preserved via
// copyText/copyAndAppend). Non-mention placeholders (inline images) are left untouched. 药丸→`[[id]]` 文本。
TextNode _flattenNode(TextNode node) {
  final flat = _flattenText(node.text);
  if (flat == null) return node; // no mentions — unchanged
  // Rebuild the same node kind with the flattened text. 重建同型节点。
  if (node is ParagraphNode) {
    return ParagraphNode(id: node.id, text: flat, metadata: node.metadata);
  }
  if (node is ListItemNode) {
    return ListItemNode(id: node.id, itemType: node.type, text: flat, indent: node.indent);
  }
  if (node is TaskNode) {
    return TaskNode(id: node.id, text: flat, isComplete: node.isComplete, indent: node.indent);
  }
  return node;
}

// A TextNode with each `[[id]]` run re-inflated into a mention pill (mirror of _flattenNode). `[[id]]`→药丸。
TextNode _inflateNode(TextNode node, Map<String, String> names) {
  final inflated = _inflateText(node.text, names);
  if (inflated == null) return node;
  if (node is ParagraphNode) {
    return ParagraphNode(id: node.id, text: inflated, metadata: node.metadata);
  }
  if (node is ListItemNode) {
    return ListItemNode(id: node.id, itemType: node.type, text: inflated, indent: node.indent);
  }
  if (node is TaskNode) {
    return TaskNode(id: node.id, text: inflated, isComplete: node.isComplete, indent: node.indent);
  }
  return node;
}

AttributedText? _flattenText(AttributedText source) {
  final mentions = source.placeholders.entries.where((e) => e.value is MentionPlaceholder).toList();
  if (mentions.isEmpty) return null;
  final fullLength = source.toPlainText().length;
  var result = AttributedText('');
  var cursor = 0;
  for (final entry in mentions) {
    if (entry.key > cursor) result = result.copyAndAppend(source.copyText(cursor, entry.key));
    result = result.copyAndAppend(AttributedText('[[${(entry.value as MentionPlaceholder).id}]]'));
    cursor = entry.key + 1; // skip the 1-char placeholder 跳过占位符
  }
  if (cursor < fullLength) result = result.copyAndAppend(source.copyText(cursor));
  return result;
}

AttributedText? _inflateText(AttributedText source, Map<String, String> names) {
  final plain = source.toPlainText();
  final matches = _wikiRe.allMatches(plain).toList();
  if (matches.isEmpty) return null;
  var result = AttributedText('');
  var cursor = 0;
  for (final m in matches) {
    if (m.start > cursor) result = result.copyAndAppend(source.copyText(cursor, m.start));
    final id = m.group(1)!;
    result = result.copyAndAppend(
      AttributedText('', null, {0: MentionPlaceholder(id: id, name: names[id] ?? id, kind: kindFromEntityId(id))}),
    );
    cursor = m.end;
  }
  if (cursor < plain.length) result = result.copyAndAppend(source.copyText(cursor));
  return result;
}

/// Maps an entity id's prefix → the wire kind string (for the pill glyph). `[[id]]` carries only the id, so
/// the kind is derived here. id 前缀→kind(药丸图标用;`[[id]]` 只带 id、kind 由前缀推)。
String kindFromEntityId(String id) {
  final prefix = id.split('_').first;
  return switch (prefix) {
    'fn' => 'function',
    'hd' => 'handler',
    'ag' => 'agent',
    'wf' => 'workflow',
    'doc' => 'document',
    'sk' => 'skill',
    _ => prefix,
  };
}

/// All entity ids a document references via mention pills — for the save-time `link` relation edges + the
/// load-time `resolveNames` batch. 文档引用的所有实体 id(存时建边 / 载时批解析名)。
List<String> mentionIdsInDocument(Document document) {
  final ids = <String>[];
  for (final node in document) {
    if (node is TextNode) {
      for (final ph in node.text.placeholders.values) {
        if (ph is MentionPlaceholder) ids.add(ph.id);
      }
    }
  }
  return ids;
}
