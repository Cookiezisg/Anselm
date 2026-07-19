// Notion-parity block markdown-on-type shortcuts (an_editor_markdown_shortcuts.dart): typing the trigger +
// space at the start of a paragraph converts it. Verified at the editor/document layer. 块级即打即转快捷。
import 'package:anselm/core/editor/an_editor_components.dart';
import 'package:anselm/core/editor/an_editor_markdown_shortcuts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

Editor _build() {
  final doc = MutableDocument(nodes: [ParagraphNode(id: '1', text: AttributedText(''))]);
  final editor = createDefaultDocumentEditor(document: doc, composer: MutableDocumentComposer(), isHistoryEnabled: true);
  editor.reactionPipeline.addAll(const [
    TodoConversionReaction(),
    CodeFenceConversionReaction(),
    PlusBulletConversionReaction(),
  ]);
  return editor;
}

DocumentNode _node(Editor e) => e.context.find<MutableDocument>(Editor.documentKey).first;

// Type [text] at the caret in node '1', starting from a fresh caret at offset 0. 从行首打字。
void _type(Editor e, String text) {
  e.execute([
    ChangeSelectionRequest(
      const DocumentSelection.collapsed(
        position: DocumentPosition(nodeId: '1', nodePosition: TextNodePosition(offset: 0)),
      ),
      SelectionChangeType.placeCaret,
      SelectionReason.userInteraction,
    ),
    InsertStyledTextAtCaretRequest(AttributedText(text)),
  ]);
}

void main() {
  test('typing `[] ` converts the paragraph to an unchecked to-do (Notion gesture, not `- [ ]`)', () {
    final editor = _build();
    _type(editor, '[] ');
    final node = _node(editor);
    expect(node, isA<TaskNode>(), reason: 'converted to a to-do');
    expect((node as TaskNode).isComplete, isFalse);
    expect(node.text.toPlainText(), isEmpty, reason: 'the `[] ` trigger text is dropped');
  });

  test('typing ```` ``` ```` + space converts the paragraph to the embedded CodeBlockNode', () {
    final editor = _build();
    _type(editor, '``` ');
    expect(_node(editor), isA<CodeBlockNode>(), reason: 'the opening fence alone triggers a code block');
  });

  test('typing `+ ` converts the paragraph to an unordered list item (Notion bullet alias)', () {
    final editor = _build();
    _type(editor, '+ ');
    final node = _node(editor);
    expect(node, isA<ListItemNode>());
    expect((node as ListItemNode).type, ListItemType.unordered);
  });

  test('a `[]` WITHOUT a trailing space does not convert (still a paragraph)', () {
    final editor = _build();
    _type(editor, '[]');
    expect(_node(editor), isA<ParagraphNode>(), reason: 'no trailing space → no conversion');
  });
}
