import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart';

import 'an_editor_components.dart';

/// Notion-parity block markdown-on-type reactions that super_editor's defaults don't ship. Each extends
/// [ParagraphPrefixConversionReaction] (same machinery as the built-in `#`→heading / `-`→bullet): the
/// pattern anchors the trigger at the paragraph start with a trailing space (`$` after the space, so it only
/// fires when the prefix is the WHOLE line), and [onPrefixMatched] replaces the paragraph — dropping the
/// trigger text, exactly like the built-ins. 向 Notion 靠齐的块级即打即转(补 super_editor 默认没有的):照内置
/// `#`/`-` 同款 ParagraphPrefixConversionReaction,前缀+空格锚定行首、`$` 保证整行只前缀时才触发,转换丢弃触发文本。

/// Notion backspace-revert: pressing Backspace at the very START of a heading or blockquote paragraph (or at
/// the start of an EMPTY to-do / list item) reverts the block to a plain paragraph, instead of super_editor's
/// default of merging it into the block above. This is Notion's signature "escape the formatting" feel.
/// Registered BEFORE the default IME keyboard actions so it intercepts the backspace first. Notion 退格回退:
/// 标题/引用行首(或空待办/列表项)按退格→变回普通段落,而非默认的上合并;招牌手感,注册在默认 IME 键动作前。
ExecutionInstruction backspaceRevertBlockAction({required SuperEditorContext editContext, required KeyEvent keyEvent}) {
  if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) return ExecutionInstruction.continueExecution;
  if (keyEvent.logicalKey != LogicalKeyboardKey.backspace) return ExecutionInstruction.continueExecution;

  final composer = editContext.editor.context.find<MutableDocumentComposer>(Editor.composerKey);
  final selection = composer.selection;
  if (selection == null || !selection.isCollapsed) return ExecutionInstruction.continueExecution;
  final position = selection.extent.nodePosition;
  if (position is! TextNodePosition || position.offset != 0) return ExecutionInstruction.continueExecution;

  final document = editContext.editor.context.find<MutableDocument>(Editor.documentKey);
  final node = document.getNodeById(selection.extent.nodeId);

  // A header/blockquote paragraph reverts to a plain paragraph. 标题/引用段落→普通段落。
  if (node is ParagraphNode) {
    final blockType = node.getMetadataValue('blockType');
    final isRevertable = blockType == header1Attribution ||
        blockType == header2Attribution ||
        blockType == header3Attribution ||
        blockType == header4Attribution ||
        blockType == header5Attribution ||
        blockType == header6Attribution ||
        blockType == blockquoteAttribution;
    if (isRevertable) {
      editContext.editor.execute([
        ChangeParagraphBlockTypeRequest(nodeId: node.id, blockType: paragraphAttribution),
      ]);
      return ExecutionInstruction.haltExecution;
    }
    return ExecutionInstruction.continueExecution;
  }

  // An EMPTY to-do or list item exits to a plain paragraph. 空待办/列表项→段落。
  if (node is TextNode && (node is TaskNode || node is ListItemNode) && node.text.toPlainText().isEmpty) {
    editContext.editor.execute([
      ReplaceNodeRequest(existingNodeId: node.id, newNode: ParagraphNode(id: node.id, text: AttributedText())),
    ]);
    return ExecutionInstruction.haltExecution;
  }

  return ExecutionInstruction.continueExecution;
}

/// `[]` + space → an unchecked to-do (Notion's exact gesture — NOT `- [ ]`, which would collide with the
/// `-`→bullet shortcut). `[]`+空格→待办(Notion 手势,非 `- [ ]`——那会撞无序列表快捷)。
class TodoConversionReaction extends ParagraphPrefixConversionReaction {
  const TodoConversionReaction();

  static final _pattern = RegExp(r'^\[\]\s+$');

  @override
  RegExp get pattern => _pattern;

  @override
  void onPrefixMatched(
    EditContext editContext,
    RequestDispatcher requestDispatcher,
    List<EditEvent> changeList,
    ParagraphNode paragraph,
    String match,
  ) {
    requestDispatcher.execute([
      ReplaceNodeRequest(
        existingNodeId: paragraph.id,
        newNode: TaskNode(id: paragraph.id, text: AttributedText(), isComplete: false),
      ),
      ChangeSelectionRequest(
        DocumentSelection.collapsed(
          position: DocumentPosition(nodeId: paragraph.id, nodePosition: const TextNodePosition(offset: 0)),
        ),
        SelectionChangeType.placeCaret,
        SelectionReason.contentChange,
      ),
    ]);
  }
}

/// ```` ``` ```` + space → the embedded [CodeBlockNode] (our AnCodeEditor code block — the SAME node the
/// markdown codec produces). Notion fires on the OPENING fence, no closing fence needed. The block is atomic
/// (a BlockNode), so the caret can't sit inside from super_editor's side — the user taps the embedded editor
/// to type (like any existing code block). ```` ``` ````+空格→嵌入 CodeBlockNode(与 codec 同款);Notion 开口
/// 即触发、无需闭合;原子块,点进嵌入编辑器打字。
class CodeFenceConversionReaction extends ParagraphPrefixConversionReaction {
  const CodeFenceConversionReaction();

  static final _pattern = RegExp(r'^```\s+$');

  @override
  RegExp get pattern => _pattern;

  @override
  void onPrefixMatched(
    EditContext editContext,
    RequestDispatcher requestDispatcher,
    List<EditEvent> changeList,
    ParagraphNode paragraph,
    String match,
  ) {
    requestDispatcher.execute([
      ReplaceNodeRequest(
        existingNodeId: paragraph.id,
        newNode: CodeBlockNode(id: paragraph.id, code: ''),
      ),
    ]);
  }
}

/// `+` + space → bullet (Notion accepts `-`, `*`, AND `+`; super_editor's default only does `-`/`*`).
/// `+`+空格→无序(Notion 三种起手,默认只 `-`/`*`)。
class PlusBulletConversionReaction extends ParagraphPrefixConversionReaction {
  const PlusBulletConversionReaction();

  static final _pattern = RegExp(r'^\+\s+$');

  @override
  RegExp get pattern => _pattern;

  @override
  void onPrefixMatched(
    EditContext editContext,
    RequestDispatcher requestDispatcher,
    List<EditEvent> changeList,
    ParagraphNode paragraph,
    String match,
  ) {
    requestDispatcher.execute([
      ReplaceNodeRequest(
        existingNodeId: paragraph.id,
        newNode: ListItemNode.unordered(id: paragraph.id, text: AttributedText()),
      ),
      ChangeSelectionRequest(
        DocumentSelection.collapsed(
          position: DocumentPosition(nodeId: paragraph.id, nodePosition: const TextNodePosition(offset: 0)),
        ),
        SelectionChangeType.placeCaret,
        SelectionReason.contentChange,
      ),
    ]);
  }
}
