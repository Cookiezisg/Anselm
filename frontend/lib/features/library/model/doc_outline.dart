/// One outline entry — a heading in the open document's markdown, in document order. [level] is the ATX
/// depth (1–3; deeper headings fold into 3, matching the editor's h1–h3 downshift). The list INDEX is the
/// jump key: the editor locates the N-th heading block the same way (document order), so no offsets are
/// stored. 大纲一项:markdown 标题(文档序)。level=ATX 深度(1–3,更深并入 3,同编辑器降档);**列表下标即跳转键**
/// (编辑器同样按文档序找第 N 个标题块,不存偏移)。
typedef DocOutlineEntry = ({int level, String text});

/// PURE extraction of the outline from markdown — fenced-code aware (a `# comment` inside ``` fences is
/// NOT a heading; toggled on any ``` / ~~~ line, mirroring how the editor's parser treats fences). Widget-
/// free so it unit-tests without pumping UI. 纯提取:围栏内的 # 不算标题(``` / ~~~ 行翻转);脱 widget 单测。
List<DocOutlineEntry> extractDocOutline(String markdown) {
  final out = <DocOutlineEntry>[];
  var inFence = false;
  for (final line in markdown.split('\n')) {
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
      inFence = !inFence;
      continue;
    }
    if (inFence) continue;
    final match = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(trimmed);
    if (match == null) continue;
    final text = match.group(2)!.trim();
    if (text.isEmpty) continue;
    out.add((level: match.group(1)!.length.clamp(1, 3), text: text));
  }
  return out;
}
