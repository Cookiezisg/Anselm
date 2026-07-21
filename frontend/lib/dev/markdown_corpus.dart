// The MARKDOWN CORPUS — one exhaustive kitchen-sink document that exercises every markdown element, every inline
// type in every block context, and the tricky adjacency / nesting / CJK edge cases. It is the SINGLE source of
// truth used three ways: (1) the editor⇄chat 1:1 comparison harness (test/dev), (2) the permanent 1:1 guard
// test (test/), (3) a real demo document in `make demo` so shallow bugs are eyeball-visible in the live editor.
//
// 唯一 markdown 全谱语料:程序化生成「每种 inline × 每种 block 上下文」矩阵 + 手写嵌套/紧贴/CJK/edge。三处复用:
// 编辑器⇄chat 对比 harness、常驻 1:1 守卫、make demo 全谱文档。改这里,三处同步。
//
// Note on mentions: `[[id]]` wikilinks are a DOCUMENT-only concept — the chat renderer (AnMarkdown) does not
// inflate them, so they have no chat counterpart and are verified against the AnInlineCapsule spec, not chat.
// mention 是文档专属(AnMarkdown 不渲 wikilink),不与 chat 比、按 AnInlineCapsule 验。
library;

/// A resolvable demo entity id for the `[[id]]` mention samples (legal `<prefix>_<16hex>`). 可解析的演示实体 id。
const kCorpusMentionId = 'fn_00000000000c0de1';

/// Display name the harness/demo should resolve [kCorpusMentionId] to. 该 id 的显示名。
const kCorpusMentionName = 'fetch_weather';

/// Inline markdown fragments, each labelled — the columns of the "inline × context" matrix. 行内片段(矩阵的列)。
const Map<String, String> kInlineFragments = {
  'plain': 'plain',
  'bold': '**bold**',
  'italic': '*italic*',
  'strike': '~~strike~~',
  'code': '`code()`',
  'link': '[a link](https://anselm.website)',
  'bold+italic': '***both***',
  'code+bold': 'a `snippet` and **strong**',
  'bold-CJK': '**中文加粗**',
  'code-CJK': '`中文注释`',
  'glued-code': 'x`y`z',
  'glued-bold': 'a**b**c',
  'glued-CJK-code': '前`fn`后',
  'long-code':
      '`this_is_a_very_long_inline_code_identifier_that_should_wrap_across_lines`',
};

/// The block contexts we drop every inline fragment into. 每个上下文都塞一遍所有 inline 片段。
const List<String> _headingContexts = [
  '# ',
  '## ',
  '### ',
  '#### ',
  '##### ',
  '###### ',
];

String _matrixSection() {
  final b = StringBuffer();

  b.writeln('# §A · Inline × Paragraph matrix\n');
  for (final e in kInlineFragments.entries) {
    b.writeln(
      'A paragraph with **${e.key}**: 前置文字 ${e.value} 后置文字 and a tail.\n',
    );
  }

  b.writeln('# §B · Inline × Headings\n');
  for (var i = 0; i < _headingContexts.length; i++) {
    // Rotate through a few representative inline types per heading level. 每级标题轮几种代表 inline。
    final frags = kInlineFragments.entries.toList();
    final pick = frags[(i * 2) % frags.length].value;
    final pick2 = frags[(i * 2 + 1) % frags.length].value;
    b.writeln('${_headingContexts[i]}H${i + 1} 标题里的 $pick 和 $pick2\n');
  }

  for (final list in [
    ('§C · Unordered list', '- '),
    ('§D · Ordered list', '1. '),
    ('§E · Task list', '- [ ] '),
  ]) {
    b.writeln('# ${list.$1}\n');
    for (final e in kInlineFragments.entries) {
      b.writeln('${list.$2}${e.key}: 前 ${e.value} 后');
    }
    b.writeln();
    // The edge case: the inline element is the FIRST word of the item (the reported list bug). 首词是行内元素。
    b.writeln('${list.$2}`code_first` 首词是代码的列表项');
    b.writeln('${list.$2}**bold_first** 首词是粗体的列表项');
    b.writeln('${list.$2}`only_code`');
    b.writeln('${list.$2}[link_first](https://anselm.website) 首词是链接');
    b.writeln();
  }

  b.writeln('# §F · Inline × Blockquote\n');
  for (final e in kInlineFragments.entries) {
    b.writeln('> ${e.key}: 前 ${e.value} 后');
  }
  b.writeln();

  return b.toString();
}

String _structureSection() =>
    '''
# §G · Nesting & structure

## Nested unordered (3 levels)

- Level 1 item with `code`
  - Level 2 with **bold** and 中文
    - Level 3 deepest, [a link](https://anselm.website)
  - Level 2 sibling
- Level 1 sibling with ~~strike~~

## Nested ordered

1. First with `snippet`
   1. Nested one
   2. Nested two with **强调**
2. Second

## Mixed nesting (ul in ol, ol in ul)

1. Ordered parent
   - Unordered child `x`
   - Unordered child with 中文注释 `注释`
2. Ordered parent two
   1. Ordered child
      - Deep unordered `deep`

## Task list nesting

- [x] Done top with `code`
  - [ ] Sub task **bold**
  - [x] Sub done 中文
- [ ] Pending with [link](https://anselm.website)

## Blockquote nesting & content

> Outer quote with `code` and **bold**.
>
> > Nested quote, second level, 中文内容.
>
> - A list inside a quote `item`
> - Second quote-list item **强调**

# §H · Code blocks

Plain fence, no language:

```
def plain(x):
    return x  # 中文注释在代码块里
```

Dart with a long line:

```dart
final result = someVeryLongFunctionName(withSeveralArguments, andMore, evenMoreArgumentsHere, stillGoing);
// 中文注释 mixed with English comment
```

Bash and SQL:

```bash
git commit -m "同轨 — 行内代码 1:1"
```

```sql
CREATE UNIQUE INDEX idx_frn_once ON flowrun_nodes (flowrun_id, node_id, iteration);
```

# §I · Tables

Left / center / right alignment, with inline formatting and code in cells:

| Name | Kind | Detail |
|:-----|:----:|-------:|
| `fetch_weather` | function | returns a **payload** |
| 每日销量对账 | workflow | 中文 `注释` right-aligned |
| [a link](https://anselm.website) | agent | ~~deprecated~~ |

# §J · Horizontal rule & adjacency

Text immediately before a rule.

---

Heading immediately after a rule, then a list with no blank gap:

## Tight heading
- item right after a heading
- second item

# §K · Edge cases

- A list item whose entire content is one very long inline code that must wrap: `this_is_an_extremely_long_inline_code_run_inside_a_list_item_that_definitely_wraps_across_two_visual_lines`
- 全中文列表项:调用 `天气接口` 之前先 `校验` 参数,注意**边界**情况。
- Glued everything: a`b`c**d**e*f*g and 中`文`英`mix`。
- A mention pill: 见 [[$kCorpusMentionId]] 的定义(编辑器渲成药丸,chat 不渲)。

The very last paragraph — plain text to check trailing spacing.
''';

/// Builds the full corpus markdown. 生成全谱 markdown。
String buildMarkdownCorpus() => '${_matrixSection()}\n${_structureSection()}';
