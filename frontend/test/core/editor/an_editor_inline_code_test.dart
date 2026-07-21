// Inline code in the paint-beneath model (an_editor_inline_code.dart): it is a plain codeAttribution TEXT run
// (wrapping, editable, with a rounded background painted beneath by AnTextComponent), NOT a chip. Here we test
// the on-type conversion + the placeholder guard at the pure editor/document layer. 行内代码=codeAttribution 文本
// (paint-beneath 底层圆角背景),非芯片;测即打即转 + 占位符守卫。
import 'package:anselm/core/editor/an_editor_inline_code.dart';
import 'package:anselm/core/editor/an_editor_mention.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

Editor _build(MutableDocument doc) {
  final editor = createDefaultDocumentEditor(
    document: doc,
    composer: MutableDocumentComposer(),
    isHistoryEnabled: true,
  );
  editor.reactionPipeline.insert(0, const InlineMarkdownReaction());
  // Same pipeline order as the real editor: the reconcile keeps inline code padded with NBSP spacers. 同真实管线。
  editor.reactionPipeline.add(const CodePadReconcileReaction());
  return editor;
}

const _nbsp = ' '; // U+00A0

List<String> _codeRunTexts(ParagraphNode n) {
  final spans = n.text.getAttributionSpans({codeAttribution}).toList()
    ..sort((a, b) => a.start.compareTo(b.start));
  return [
    for (final s in spans) n.text.copyText(s.start, s.end + 1).toPlainText(),
  ];
}

ParagraphNode _p(Editor e) =>
    e.context.find<MutableDocument>(Editor.documentKey).first as ParagraphNode;

void _caret(Editor e, int offset) => e.execute([
  ChangeSelectionRequest(
    DocumentSelection.collapsed(
      position: DocumentPosition(
        nodeId: '1',
        nodePosition: TextNodePosition(offset: offset),
      ),
    ),
    SelectionChangeType.placeCaret,
    SelectionReason.userInteraction,
  ),
]);

void main() {
  test(
    'typing a closed `code` converts it to a codeAttribution run — plain editable text, NOT a chip',
    () {
      final doc = MutableDocument(
        nodes: [ParagraphNode(id: '1', text: AttributedText('x `code'))],
      );
      final editor = _build(doc);
      _caret(editor, 7);
      editor.execute([
        InsertStyledTextAtCaretRequest(AttributedText('`')),
      ]); // type the closing backtick

      final n = _p(editor);
      expect(
        n.text.getAttributionSpans({codeAttribution}).length,
        1,
        reason: 'closed `code` became a code run',
      );
      expect(
        n.text.toPlainText().contains('`'),
        isFalse,
        reason: 'the backtick syntax was consumed',
      );
      // No placeholder — inline code is TEXT now, not an atomic chip. 无占位符,行内代码是文本非原子芯片。
      expect(
        n.text.placeholders,
        isEmpty,
        reason: 'stays codeAttribution text, no chip placeholder',
      );
    },
  );

  test(
    'the reconcile pads a freshly-created code run with a real NBSP spacer on each side',
    () {
      final doc = MutableDocument(
        nodes: [ParagraphNode(id: '1', text: AttributedText('x `code'))],
      );
      final editor = _build(doc);
      _caret(editor, 7);
      editor.execute([
        InsertStyledTextAtCaretRequest(AttributedText('`')),
      ]); // closes → codeAttribution + reconcile pads

      final n = _p(editor);
      expect(
        _codeRunTexts(n),
        ['${_nbsp}code$_nbsp'],
        reason: 'the run is [NBSP]code[NBSP] — real padding chars',
      );
      // Idempotent: another benign edit does not add more spacers. 幂等:再动一下不会再加内距。
      _caret(editor, n.text.length);
      editor.execute([InsertStyledTextAtCaretRequest(AttributedText('.'))]);
      expect(_codeRunTexts(_p(editor)), [
        '${_nbsp}code$_nbsp',
      ], reason: 'still exactly one spacer each side');
    },
  );

  test(
    'the reconcile re-adds a spacer that was deleted (padding is "undeletable")',
    () {
      final doc = MutableDocument(
        nodes: [ParagraphNode(id: '1', text: AttributedText('x `code'))],
      );
      final editor = _build(doc);
      _caret(editor, 7);
      editor.execute([InsertStyledTextAtCaretRequest(AttributedText('`'))]);
      var n = _p(editor);
      // Delete the trailing spacer directly, then make a benign edit — the reconcile must restore it. 删尾内距→补回。
      final end = n.text.length; // length incl. spacers
      editor.execute([
        DeleteContentRequest(
          documentRange: DocumentRange(
            start: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: end - 1),
            ),
            end: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: end),
            ),
          ),
        ),
        ChangeSelectionRequest(
          DocumentSelection.collapsed(
            position: DocumentPosition(
              nodeId: '1',
              nodePosition: TextNodePosition(offset: end - 1),
            ),
          ),
          SelectionChangeType.deleteContent,
          SelectionReason.userInteraction,
        ),
        // A trivial no-op-ish insert to trigger the reaction pipeline again. 触发一次 reaction。
        InsertStyledTextAtCaretRequest(AttributedText(' ')),
      ]);
      n = _p(editor);
      expect(
        _codeRunTexts(n).single.startsWith(_nbsp),
        isTrue,
        reason: 'leading spacer intact',
      );
      expect(
        _codeRunTexts(n).single.endsWith(_nbsp),
        isTrue,
        reason: 'trailing spacer re-added by the reconcile',
      );
    },
  );

  test(
    'the code run stays editable text after the caret leaves (no fold to a chip)',
    () {
      final doc = MutableDocument(
        nodes: [ParagraphNode(id: '1', text: AttributedText('x `code'))],
      );
      final editor = _build(doc);
      _caret(editor, 7);
      editor.execute([InsertStyledTextAtCaretRequest(AttributedText('`'))]);
      _caret(
        editor,
        0,
      ); // move the caret far away — in the old chip model this folded; now it must NOT

      final n = _p(editor);
      expect(
        n.text.getAttributionSpans({codeAttribution}).length,
        1,
        reason: 'still an editable code run',
      );
      expect(
        n.text.placeholders,
        isEmpty,
        reason: 'never becomes a chip — paint-beneath keeps it as text',
      );
    },
  );

  test(
    'InlineMarkdownReaction skips (no crash) when a placeholder is upstream of the caret (dev.40 guard)',
    () {
      // A mention pill upstream would crash the dev.40 parser (it casts every char to String). The guard skips.
      final doc = MutableDocument(
        nodes: [
          ParagraphNode(
            id: '1',
            text: AttributedText('a b', null, {
              2: const MentionPlaceholder(
                id: 'fn_0000000000000001',
                name: 'x',
                kind: 'function',
              ),
            }),
          ),
        ],
      );
      final editor = _build(doc);
      _caret(editor, 4);
      expect(
        () => editor.execute([
          InsertStyledTextAtCaretRequest(AttributedText('x')),
        ]),
        returnsNormally,
      );
    },
  );
}
