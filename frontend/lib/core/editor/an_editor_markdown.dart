/// The document ↔ markdown codec for the native editor (E9). super_editor dev.40 ships the block + inline
/// serializers we need (heading/blockquote/code/list/task + bold/italic/strike/inline-code), so this is a
/// THIN wrapper that adds the TWO things it can't do:
///
///  1. **The entity @mention round-trip.** A mention lives in the editor as an inline
///     [MentionPlaceholder] pill but must persist as the backend's `[[<id>]]` wikilink (the ONLY content
///     the `pkg/wikilink` parser reads to build `link` relation edges — round-trip fidelity here is a
///     backend contract, NOT cosmetic). On SAVE each pill flattens to the literal `[[id]]`; on LOAD every
///     `[[id]]` re-inflates into a pill, name from [names], kind from the id prefix.
///  2. **The fenced-code LANGUAGE tag.** The built-in codec drops ```` ```dart ```` both ways (the parser
///     never stores it, the serializer always writes a bare fence) — a mere open+save would strip every
///     language tag and dirty the document. On LOAD the source is scanned for fence languages, stamped
///     onto the code nodes' metadata in document order; on SAVE they're re-injected onto the opening
///     fences in the same order.
///
/// 文档↔markdown codec:内置序列化管全部块/行内类型,本层补两件——①mention 往返(药丸↔`[[id]]`,后端关系边
/// 契约、须逐字保真);②围栏代码**语言标**(内置 codec 双向丢 ```` ```dart ````,开档即存就会弄脏文档——载入按
/// 序盖进节点 metadata、存出按序回写围栏行)。
library;

import 'package:super_editor/super_editor.dart';

import 'an_editor_components.dart';
import 'an_editor_inline_code.dart';
import 'an_editor_quote.dart';
import 'an_editor_mention.dart';

/// `[[<prefix>_<16 hex>]]` — the stored wire form (mirrors pkg/wikilink + core/ui/entity_ref_codec). 存储线缆形。
final RegExp _wikiRe = RegExp(r'\[\[([a-z]+_[0-9a-f]{16})\]\]');

/// The metadata key a code node's fence language rides on (see the header note #2). 语言标的 metadata 键。
const String codeLanguageKey = 'language';

bool _isCodeNode(DocumentNode node) =>
    node is ParagraphNode && node.getMetadataValue('blockType') == codeAttribution;

/// The editor holds a fenced code block as an embedded-widget [CodeBlockNode] (a BlockNode), but the
/// built-in serializer only understands a code ParagraphNode — so at the SAVE seam each [CodeBlockNode]
/// becomes a code [ParagraphNode] (text = the raw code, language stamped on metadata for the fence
/// re-injection pass). Mirror of the LOAD-seam conversion in [documentFromMarkdown].
/// 编辑器里代码块是嵌件 CodeBlockNode(BlockNode),内置序列化器只认 code 段落——存时缝处转回 code 段落(文本=原始
/// 代码,语言标进 metadata 供回写围栏)。与 documentFromMarkdown 载入缝对称。
ParagraphNode _codeBlockToParagraph(CodeBlockNode node) => ParagraphNode(
      id: node.id,
      text: AttributedText(node.code),
      metadata: {
        'blockType': codeAttribution,
        if (node.language != null && node.language!.isNotEmpty) codeLanguageKey: node.language,
      },
    );

/// SAVE — convert embedded code blocks back to code paragraphs + flatten every mention pill to `[[id]]`
/// text, then serialize with the built-in block/inline serializers, then re-inject each code node's
/// language tag onto its opening fence.
/// 存:代码块转回 code 段落 + 药丸摊平成 `[[id]]` 文本,内置序列化,再按序回写语言标。
String markdownFromDocument(Document document) => _serializeRun(document.toList());

/// Serialize a run of nodes, grouping consecutive `quoteDepth >= 1` nodes into blockquote regions (mirror of
/// the LOAD-side segment split). A quote region is serialized by stripping ONE depth level, serializing the
/// inner run RECURSIVELY (so nesting reconstructs), and prefixing every line with `> `. 存出:按引用/非引用分组,
/// 引用组剥一层深度→递归序列化内层→每行加 `> `(与载入对称,天然重建嵌套)。
String _serializeRun(List<DocumentNode> nodes) {
  final parts = <String>[];
  var i = 0;
  while (i < nodes.length) {
    final quoted = quoteDepthOf(nodes[i]) >= 1;
    final run = <DocumentNode>[];
    while (i < nodes.length && (quoteDepthOf(nodes[i]) >= 1) == quoted) {
      run.add(nodes[i]);
      i++;
    }
    parts.add(quoted ? _serializeQuoteRun(run) : _serializePlainRun(run));
  }
  return parts.join('\n\n');
}

/// Strip one `>` level off a run of quoted nodes, serialize the inner run, prefix each line with `> `. 引用组序列化。
String _serializeQuoteRun(List<DocumentNode> nodes) {
  final inner = [for (final n in nodes) n.copyWithAddedMetadata({quoteDepthKey: quoteDepthOf(n) - 1})];
  final innerMd = _serializeRun(inner);
  return innerMd.split('\n').map((line) => line.isEmpty ? '>' : '> $line').join('\n');
}

/// Serialize a run of NON-quote nodes (code blocks → code paragraphs, mention pills → `[[id]]`, fence language
/// re-injected). 非引用组序列化(代码块回段落、药丸摊平、语言标回写)。
String _serializePlainRun(List<DocumentNode> nodes) {
  final flattened = MutableDocument(
    nodes: [
      for (final node in nodes)
        if (node is CodeBlockNode)
          _codeBlockToParagraph(node)
        else if (node is TextNode)
          _flattenNode(node)
        else
          node,
    ],
  );
  final languages = [
    for (final node in flattened)
      if (_isCodeNode(node)) (node.getMetadataValue(codeLanguageKey) as String?) ?? '',
  ];
  final markdown = serializeDocumentToMarkdown(flattened);
  // Trim per-line trailing whitespace: the built-in code-block serializer ADDS trailing spaces each round.
  final trimmed = markdown.split('\n').map((line) => line.trimRight()).join('\n');
  return _restoreFenceLanguages(trimmed, languages);
}

/// LOAD — deserialize with the built-in parsers, re-inflate `[[id]]` runs into mention pills, and stamp
/// each code node's fence language (scanned off the SOURCE, in document order — the built-in parser
/// discards it). [names] resolves display names (from `MentionSource.resolveNames`); unknown ids show the
/// bare id. 载:内置解析后回填药丸 + 按序盖回语言标(内置 parser 丢弃、从源文扫)。
MutableDocument documentFromMarkdown(String markdown, {Map<String, String> names = const {}}) {
  // BLOCKQUOTES first: super_editor's parser collapses an entire blockquote (all lines, nested `> >`, and any
  // list/paragraph inside) into ONE merged paragraph — its block model is flat. To render blockquotes 1:1 with
  // chat (which recursively renders quote content), we split the markdown into quote / non-quote segments,
  // deserialize the non-quote parts normally, and parse each quote region RECURSIVELY into flat nodes tagged
  // with a `quoteDepth` (strip one `>` level → re-parse → depth+1). The An component builders then wrap every
  // quoteDepth>0 node in the left bar(s), reconstructing the nesting on the flat model. 引用块先拆:super_editor 把
  // 整个引用(含嵌套/引用内列表)拍平成一段(块模型扁平)。故按引用/非引用拆段,非引用照常反序列化,引用段递归解析成
  // 扁平节点 + 打 quoteDepth(剥一层→重解析→深度+1);组件层据 quoteDepth 包左条,在扁平模型上重建嵌套。
  final nodes = <DocumentNode>[];
  for (final seg in _blockSegments(markdown)) {
    nodes.addAll(seg.isQuote ? _parseQuote(seg.text, names) : _plainNodes(seg.text, names));
  }
  return MutableDocument(nodes: nodes);
}

/// Deserialize a NON-quote markdown segment into An nodes (the built-in parse + fence-language stamp + code
/// block + mention inflation). 非引用段:内置反序列化 + 语言标 + 代码块 + 药丸回填。
List<DocumentNode> _plainNodes(String markdown, Map<String, String> names) {
  final document = deserializeMarkdownToDocument(markdown);
  final languages = _fenceLanguages(markdown);
  var codeIndex = 0;
  final nodes = <DocumentNode>[];
  for (final node in document) {
    // Code is checked BEFORE mention inflation — the embedded editor owns code as an atomic [CodeBlockNode]
    // (no pills), so a `[[id]]`-looking run inside code stays literal. 代码在 mention 回填前处理。
    if (_isCodeNode(node)) {
      final lang = codeIndex < languages.length ? languages[codeIndex] : '';
      codeIndex += 1;
      final code = node as ParagraphNode;
      var text = code.text.toPlainText();
      if (text.endsWith('\n')) text = text.substring(0, text.length - 1);
      nodes.add(CodeBlockNode(id: code.id, code: text, language: lang.isEmpty ? null : lang));
      continue;
    }
    nodes.add(node is TextNode ? _inflateNode(node, names) : node);
  }
  return nodes;
}

/// Parse one blockquote region: strip ONE `>` level off each line, re-parse the inner content recursively (so
/// nested quotes, lists, and paragraphs inside all work), then bump every resulting node's [quoteDepthKey] by 1.
/// 解析一个引用区域:每行剥一层 `>`,递归重解析内层(嵌套/列表/段落都自然处理),再把所有节点的 quoteDepth +1。
List<DocumentNode> _parseQuote(String quoteMarkdown, Map<String, String> names) {
  final inner = quoteMarkdown.split('\n').map(_stripOneQuote).join('\n');
  final innerDoc = documentFromMarkdown(inner, names: names);
  return [
    for (final n in innerDoc) n.copyWithAddedMetadata({quoteDepthKey: quoteDepthOf(n) + 1}),
  ];
}

/// Strip a single leading `>` (and one optional following space) from a blockquote line. 剥一层 `>`(及一个空格)。
String _stripOneQuote(String line) {
  final trimmed = line.trimLeft();
  if (!trimmed.startsWith('>')) return line;
  final rest = trimmed.substring(1);
  return rest.startsWith(' ') ? rest.substring(1) : rest;
}

/// Split markdown into maximal runs of consecutive quote / non-quote lines, in order. A blockquote region is a
/// run of lines each starting (after leading whitespace) with `>`. 按行把 markdown 拆成引用/非引用的最大连续段。
List<({bool isQuote, String text})> _blockSegments(String markdown) {
  final segs = <({bool isQuote, List<String> lines})>[];
  for (final line in markdown.split('\n')) {
    final isQuote = line.trimLeft().startsWith('>');
    if (segs.isNotEmpty && segs.last.isQuote == isQuote) {
      segs.last.lines.add(line);
    } else {
      segs.add((isQuote: isQuote, lines: [line]));
    }
  }
  return [for (final s in segs) (isQuote: s.isQuote, text: s.lines.join('\n'))];
}

/// The language tag of every fence OPENING in [markdown], in order ('' when untagged) — a line-scan fence
/// state machine (a ``` inside an open fence CLOSES it, never opens a nested one). 逐围栏开口的语言标(态机扫行)。
List<String> _fenceLanguages(String markdown) {
  final languages = <String>[];
  var inFence = false;
  for (final line in markdown.split('\n')) {
    final lead = line.trimLeft();
    if (!lead.startsWith('```')) continue;
    if (inFence) {
      inFence = false;
    } else {
      inFence = true;
      languages.add(lead.substring(3).trim());
    }
  }
  return languages;
}

/// Re-inject [languages] onto the k-th opening fence of [markdown] (same state machine as the scan).
/// 把语言标按序写回第 k 个围栏开口。
String _restoreFenceLanguages(String markdown, List<String> languages) {
  if (languages.every((lang) => lang.isEmpty)) return markdown;
  final lines = markdown.split('\n');
  var inFence = false;
  var codeIndex = 0;
  for (var i = 0; i < lines.length; i += 1) {
    final lead = lines[i].trimLeft();
    if (!lead.startsWith('```')) continue;
    if (inFence) {
      inFence = false;
    } else {
      inFence = true;
      if (codeIndex < languages.length && languages[codeIndex].isNotEmpty && lead.trim() == '```') {
        lines[i] = lines[i].replaceFirst('```', '```${languages[codeIndex]}');
      }
      codeIndex += 1;
    }
  }
  return lines.join('\n');
}

// A TextNode with each mention placeholder replaced by literal `[[id]]` text (spans preserved via
// copyText/copyAndAppend). Non-mention placeholders (inline images) are left untouched. 药丸→`[[id]]` 文本。
TextNode _flattenNode(TextNode node) {
  // Strip the injected inline-code NBSP padding spacers FIRST so the serialized markdown is `` `code` ``, never
  // `` ` code ` `` (see [stripCodeSpacers]). 先剥离行内代码 NBSP 内距(存盘 markdown 恒无内距空格)。
  final stripped = stripCodeSpacers(node.text);
  final flat = _flattenText(stripped) ?? stripped;
  if (identical(flat, node.text)) return node; // no spacers and no mentions — unchanged
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

// A TextNode with each `[[id]]` run inflated into a mention pill. Inline code stays as the built-in parser's
// codeAttribution TEXT run (it renders as wrapping editable text with a rounded background painted beneath by
// AnTextComponent — paint-beneath). A `[[id]]` INSIDE an inline-code run stays literal (guarded in
// [_inflateText]). Mirror of _flattenNode. 行内代码保持 codeAttribution 文本(paint-beneath 底层圆角背景);`[[id]]`→药丸,码内保字面。
TextNode _inflateNode(TextNode node, Map<String, String> names) {
  // Inflate `[[id]]` → mention pills, THEN inject the inline-code NBSP padding spacers so freshly-loaded code
  // already shows the padded rounded background (the reconcile keeps them during editing). 回填药丸后注入行内代码内距。
  final inflated = _inflateText(node.text, names) ?? node.text;
  final text = padCodeRuns(inflated).text;
  if (identical(text, node.text)) return node; // no mentions and no inline code — unchanged
  if (node is ParagraphNode) {
    return ParagraphNode(id: node.id, text: text, metadata: node.metadata);
  }
  if (node is ListItemNode) {
    return ListItemNode(id: node.id, itemType: node.type, text: text, indent: node.indent);
  }
  if (node is TaskNode) {
    return TaskNode(id: node.id, text: text, isComplete: node.isComplete, indent: node.indent);
  }
  return node;
}

AttributedText? _flattenText(AttributedText source) {
  // Flatten mention pills to literal `[[id]]` text before serialization. Inline code is plain codeAttribution
  // text already (the built-in serializer wraps it in backticks), so there's nothing to flatten for it.
  // 药丸摊平成 `[[id]]` 文本;行内代码本就是 codeAttribution 文本(内置序列化器加反引号),无需摊平。
  final mentions = source.placeholders.entries.where((e) => e.value is MentionPlaceholder).toList()
    ..sort((a, b) => a.key.compareTo(b.key));
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
  // A `[[id]]` INSIDE an inline-code run stays literal — code content is verbatim, never a mention pill. Skip
  // matches whose start sits in any codeAttribution span. 码内 `[[id]]` 保字面(代码逐字),跳过落在 code run 的匹配。
  final codeSpans = source.getAttributionSpans({codeAttribution});
  bool inCode(int offset) => codeSpans.any((s) => offset >= s.start && offset <= s.end);
  final realMatches = matches.where((m) => !inCode(m.start)).toList();
  if (realMatches.isEmpty) return null; // every `[[id]]` is inside code — nothing to inflate
  var result = AttributedText('');
  var cursor = 0;
  for (final m in realMatches) {
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
