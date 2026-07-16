/// The EDITABLE document table — replaces super_editor's read-only `MarkdownTableComponent`.
///
/// Upstream's [TableBlockNode] is by design a read-only presentation block: block-level selection only, no
/// cell positions, arrows can land ON it but never IN it, and no context menu anywhere in the chain (still
/// true in dev.52 — upstream table editing is blocked on document tree-ification). So editing is built HERE
/// on the CODE-BLOCK PRECEDENT (an atomic BlockNode embedding real editable widgets): the node model stays
/// upstream's [TableBlockNode] (markdown codec round-trips untouched), each cell renders a [SuperTextField]
/// over the cell's own [AttributedText] (inline bold/code attributions survive an edit — the serializer
/// writes `cell.text.toMarkdown()`), and every mutation — a keystroke in a cell, or a structural op from
/// the right-click menu — rebuilds the grid through a PURE function and lands as one whole-node
/// [ReplaceNodeRequest] with the same id.
///
/// Interaction (the Notion matrix):
///  • click a cell → its field takes the caret;
///  • Tab / Shift+Tab walk cells (row-major); Tab on the LAST cell appends a row;
///  • Enter moves a row down (GFM cells hold no newlines), at the last row exits below;
///  • ↑/↓ move by row when the caret sits on the cell's first/last visual line, exiting the table at the
///    edges; ←/→ cross cell boundaries at the text ends;
///  • right-click any cell → context menu (insert/delete row/column, delete table) on [AnMenuSurface];
///  • from the document, Enter / ↓ / ↑ on the block-selected table enters the first/last row (the
///    editor-level keyboard action lives in an_editor.dart, keyed through [tableKeys]).
///
/// Trade-offs are the code block's, already signed (0714): the table is atomic to the document (a document
/// selection can't flow through individual cells) and cell edits carry the field's own undo.
///
/// 可编辑文档表格,替换上游只读组件。上游 TableBlockNode 是刻意的只读展示块(块级整选、无 cell 位置、方向键上
/// 得去进不去、全链无右键;dev.52 未变,上游卡在文档树化)。编辑按**代码块先例**建:节点模型保持上游原样
/// (codec 零改),每格渲 [SuperTextField] 编辑该格 AttributedText(行内 attribution 保真——序列化写
/// cell.text.toMarkdown()),一切变更(逐键/右键结构操作)走纯函数重建网格 + 同 id 整节点替换。交互按 Notion:
/// 点格落光标;Tab/Shift+Tab 走格、末格 Tab 加行;Enter 下移一行、末行退出;↑↓ 在首/末视觉行时跨行、边缘退出;
/// ←→ 在文本端点跨格;右键出菜单(增删行列/删表);文档侧 Enter/↓/↑ 在块选中的表上进首/末行。代价=代码块同款已签。
library;

import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_editor/super_editor.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../ui/an_menu_surface.dart';
import 'an_editor_caret.dart';

// ─── Pure grid operations ──────────────────────────────────────────────────────────────────────────
// Every mutation rebuilds the SAME-id node through one of these — trivially unit-testable, and the
// ReplaceNodeRequest seam stays one line. 纯网格操作:一切变更经此重建同 id 节点,可单测,替换缝一行。

List<List<TextNode>> _grid(TableBlockNode node) => [
      for (var r = 0; r < node.rowCount; r++) List<TextNode>.of(node.getRow(r)),
    ];

TextNode _emptyCell() => TextNode(id: Editor.createNodeId(), text: AttributedText(''));

TableBlockNode _rebuild(TableBlockNode node, List<List<TextNode>> cells) =>
    TableBlockNode(id: node.id, cells: cells, metadata: Map.of(node.metadata));

/// The grid with cell (row, col)'s text swapped (id + metadata kept). 换某格文本(id/metadata 保留)。
TableBlockNode tableWithCellText(TableBlockNode node, int row, int col, AttributedText text) {
  final cells = _grid(node);
  final old = cells[row][col];
  cells[row][col] = TextNode(id: old.id, text: text, metadata: Map.of(old.metadata));
  return _rebuild(node, cells);
}

/// A fresh empty row inserted at [index] (0-based over ALL rows; the header is row 0, so data inserts use
/// index ≥ 1). 在 index 插空行(表头=第 0 行,数据行从 1 起)。
TableBlockNode tableWithRowInserted(TableBlockNode node, int index) {
  final cells = _grid(node);
  cells.insert(index, [for (var c = 0; c < node.columnCount; c++) _emptyCell()]);
  return _rebuild(node, cells);
}

TableBlockNode tableWithRowRemoved(TableBlockNode node, int index) {
  final cells = _grid(node)..removeAt(index);
  return _rebuild(node, cells);
}

/// A fresh empty column inserted at [index] in every row. 每行在 index 插一空格。
TableBlockNode tableWithColumnInserted(TableBlockNode node, int index) {
  final cells = _grid(node);
  for (final row in cells) {
    row.insert(index, _emptyCell());
  }
  return _rebuild(node, cells);
}

TableBlockNode tableWithColumnRemoved(TableBlockNode node, int index) {
  final cells = _grid(node);
  for (final row in cells) {
    row.removeAt(index);
  }
  return _rebuild(node, cells);
}

// ─── Component builder ─────────────────────────────────────────────────────────────────────────────

/// Builds the EDITABLE An table for every [TableBlockNode]. Extends the upstream builder for its view-model
/// pass, with the header-follows-the-column fix (GFM: the delimiter row aligns the whole column, header AND
/// body; upstream hardcodes headers to centre) — then swaps the read-only component for [AnEditableTable].
/// 每个 TableBlockNode 渲可编辑 An 表。复用上游 vm 造建 + 表头跟随列对齐修正(GFM 标准,上游硬编码居中),
/// 组件换成可编辑体。
class AnTableComponentBuilder extends MarkdownTableComponentBuilder {
  const AnTableComponentBuilder(this.editor, this.document, this.editorFocusNode, this.tableKeys);

  final Editor editor;
  final Document document;

  /// The document editor's focus node — cells hand focus BACK on exit (arrows at the edges / Escape).
  /// 文档编辑器焦点结点:cell 在退出时交还焦点。
  final FocusNode editorFocusNode;

  /// One stable [GlobalKey] per table node id (mirror of the code block's `codeKeys`): keeps every cell's
  /// field State (controller / focus / caret) alive across the whole-node replace each edit runs, and gives
  /// the editor-level "enter the table with the keyboard" action a handle to focus a cell.
  /// 每表一把稳定 key(镜像 codeKeys):cell State 跨整节点替换存活,也供编辑器级「键盘进表」动作取用。
  final Map<String, GlobalKey<AnEditableTableState>> tableKeys;

  @override
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node) {
    final vm = super.createViewModel(document, node);
    // Header follows the column: copy alignment from the first data row (which carries the real column
    // alignment). Header-only tables (no data) keep super_editor's centre — a degenerate, rare case.
    // 表头跟随列对齐(取第一数据行);无数据行的退化表保持上游居中。
    if (vm is MarkdownTableViewModel && vm.cells.length > 1) {
      final header = vm.cells.first;
      final firstData = vm.cells[1];
      for (var i = 0; i < header.length && i < firstData.length; i++) {
        header[i].textAlign = firstData[i].textAlign;
      }
    }
    return vm;
  }

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! MarkdownTableViewModel) return null;
    final tableKey = tableKeys.putIfAbsent(componentViewModel.nodeId, GlobalKey<AnEditableTableState>.new);
    // BoxComponent supplies the block geometry super_editor needs while letting pointers reach the cells
    // (the code-block contract; componentKey on the returned subtree's ROOT). BoxComponent 供块几何不挡指针。
    return BoxComponent(
      key: componentContext.componentKey,
      child: AnEditableTable(
        key: tableKey,
        viewModel: componentViewModel,
        editor: editor,
        document: document,
        editorFocusNode: editorFocusNode,
      ),
    );
  }
}

// ─── The editable table ────────────────────────────────────────────────────────────────────────────

class AnEditableTable extends StatefulWidget {
  const AnEditableTable({
    super.key,
    required this.viewModel,
    required this.editor,
    required this.document,
    required this.editorFocusNode,
  });

  final MarkdownTableViewModel viewModel;
  final Editor editor;
  final Document document;
  final FocusNode editorFocusNode;

  @override
  State<AnEditableTable> createState() => AnEditableTableState();
}

class AnEditableTableState extends State<AnEditableTable> {
  // Cell field state keyed 'row:col' — controllers survive the per-keystroke whole-node replace because
  // THIS State survives (the stable tableKey), and the grid shape only changes on structural ops.
  // cell 字段态按 'r:c' 键:本 State 经稳定 tableKey 跨整节点替换存活,网格形状仅结构操作时变。
  final Map<String, AttributedTextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  // One key per cell field — [AnFieldCaret] reads the field's own textLayout through it for the caret
  // offset. 每格一把 key:AnFieldCaret 经它读该字段的 textLayout 取光标位置。
  final Map<String, GlobalKey<SuperTextFieldState>> _fieldKeys = {};

  final OverlayPortalController _menu = OverlayPortalController();
  Offset _menuGlobal = Offset.zero;
  int _menuRow = 0;
  int _menuCol = 0;

  int get _rows => widget.viewModel.cells.length;
  int get _cols => _rows == 0 ? 0 : widget.viewModel.cells[0].length;

  String _key(int row, int col) => '$row:$col';

  @override
  void initState() {
    super.initState();
    _reconcileCells();
  }

  @override
  void didUpdateWidget(AnEditableTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    _reconcileCells();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focusNodes.values) {
      f.dispose();
    }
    super.dispose();
  }

  // Create/drop cell field state to match the grid, and sync UNFOCUSED cells' text from the view model
  // (an external change — undo, a structural op — must reach the field; the focused cell's controller IS
  // the live source, syncing it would fight the IME). 对齐网格增删字段态;未聚焦格从 vm 同步文本(外部变更
  // 须达字段;聚焦格的 controller 即活源,同步会打架 IME)。
  void _reconcileCells() {
    final live = <String>{};
    for (var r = 0; r < _rows; r++) {
      for (var c = 0; c < _cols; c++) {
        final k = _key(r, c);
        live.add(k);
        final text = widget.viewModel.cells[r][c].text;
        final controller = _controllers[k];
        if (controller == null) {
          _controllers[k] = AttributedTextEditingController(text: text.copy())..addListener(() => _onCellChanged(r, c));
          _focusNodes[k] = FocusNode(debugLabel: 'an-table-cell $k');
          _fieldKeys[k] = GlobalKey<SuperTextFieldState>();
          // NOTE: "the document caret must not linger while a cell owns the keyboard" is NOT handled here —
          // AnEditor watches its OWN focus node for it (`hasFocus && !hasPrimaryFocus`), one rule covering
          // every embedded editable (cells AND code blocks). 「格持键盘时文档光标不得逗留」不在此处理:
          // AnEditor 盯自身焦点结点(hasFocus && !hasPrimaryFocus),一条规则覆盖所有内嵌可编辑件(格与码块)。
        } else if (!_focusNodes[k]!.hasFocus && controller.text != text) {
          controller.text = text.copy();
        }
      }
    }
    final dead = _controllers.keys.where((k) => !live.contains(k)).toList();
    for (final k in dead) {
      _controllers.remove(k)?.dispose();
      _focusNodes.remove(k)?.dispose();
      _fieldKeys.remove(k);
    }
  }

  TableBlockNode? get _node => widget.document.getNodeById(widget.viewModel.nodeId) as TableBlockNode?;

  // A cell keystroke: commit the controller's text into the node (same id — the codec seam and document
  // history see one replace). The controller also notifies on pure caret moves, so no-op when unchanged.
  // 逐键落盘:controller 文本写回节点(同 id);光标移动也触发 listener,故文本未变即跳过。
  void _onCellChanged(int row, int col) {
    final node = _node;
    if (node == null || row >= node.rowCount || col >= node.columnCount) return;
    final controller = _controllers[_key(row, col)];
    if (controller == null || controller.text == node.getCell(rowIndex: row, columnIndex: col).text) return;
    widget.editor.execute([
      ReplaceNodeRequest(
        existingNodeId: node.id,
        newNode: tableWithCellText(node, row, col, controller.text.copy()),
      ),
    ]);
  }

  // ── focus + navigation ─────────────────────────────────────────────────────────────────────────

  /// Focus cell (row, col), caret at the end — also the entry point for the editor-level keyboard action
  /// (Enter/↓/↑ on the block-selected table). 聚焦某格、光标置尾;也是编辑器级键盘进表的入口。
  void focusCell(int row, int col) {
    final k = _key(row.clamp(0, _rows - 1), col.clamp(0, _cols - 1));
    final controller = _controllers[k];
    final focus = _focusNodes[k];
    if (controller == null || focus == null) return;
    focus.requestFocus();
    controller.selection = TextSelection.collapsed(offset: controller.text.length);
    // The document caret drops itself when the cell takes the keyboard (AnEditor's focus rule) — no clear
    // needed here. 格拿到键盘时文档光标自会收起(AnEditor 的焦点规则),此处无需清。
  }

  void _focusDelta(int row, int col, int drow, int dcol) {
    var r = row, c = col + dcol;
    if (c >= _cols) {
      c = 0;
      r += 1;
    } else if (c < 0) {
      c = _cols - 1;
      r -= 1;
    }
    r += drow;
    if (r < 0) {
      _exit(above: true);
      return;
    }
    if (r >= _rows) {
      _exit(above: false);
      return;
    }
    focusCell(r, c);
  }

  /// Leave the table: hand focus back to the document editor with the caret at the neighbouring node
  /// (end of the node above / start of the node below); when no neighbour exists, select the table block.
  /// 退表:焦点还编辑器,光标落邻节点(上邻之尾/下邻之首);无邻则整块选中表。
  void _exit({required bool above}) {
    final node = _node;
    if (node == null) return;
    final index = widget.document.getNodeIndexById(node.id);
    final neighbour = above
        ? (index > 0 ? widget.document.getNodeAt(index - 1) : null)
        : (index < widget.document.nodeCount - 1 ? widget.document.getNodeAt(index + 1) : null);
    widget.editorFocusNode.requestFocus();
    if (neighbour == null) {
      _selectWholeTable(node);
      return;
    }
    widget.editor.execute([
      ChangeSelectionRequest(
        DocumentSelection.collapsed(
          position: DocumentPosition(
            nodeId: neighbour.id,
            nodePosition: above ? neighbour.endPosition : neighbour.beginningPosition,
          ),
        ),
        SelectionChangeType.placeCaret,
        SelectionReason.userInteraction,
      ),
    ]);
  }

  void _selectWholeTable(TableBlockNode node) {
    widget.editor.execute([
      ChangeSelectionRequest(
        DocumentSelection(
          base: DocumentPosition(nodeId: node.id, nodePosition: const UpstreamDownstreamNodePosition.upstream()),
          extent: DocumentPosition(nodeId: node.id, nodePosition: const UpstreamDownstreamNodePosition.downstream()),
        ),
        SelectionChangeType.expandSelection,
        SelectionReason.userInteraction,
      ),
    ]);
  }

  // Whether the collapsed caret sits on the cell's first/last VISUAL line (soft wraps included) — the
  // gate for ↑/↓ leaving the cell instead of moving within it. 光标是否在格的首/末视觉行(含软换行)——
  // ↑/↓ 出格还是格内移动的闸。
  bool _caretOnEdgeLine(SuperTextFieldContext ctx, {required bool first}) {
    final selection = ctx.controller.selection;
    if (!selection.isCollapsed) return false;
    final length = ctx.controller.text.length;
    if (length == 0) return true;
    final layout = ctx.getTextLayout();
    final caretY = layout.getOffsetForCaret(TextPosition(offset: selection.extentOffset)).dy;
    final edgeY = layout.getOffsetForCaret(TextPosition(offset: first ? 0 : length)).dy;
    return (caretY - edgeY).abs() < 1;
  }

  /// The cell's keyboard matrix, PREPENDED to the field defaults (a `handled` result stops the chain).
  /// 格键盘矩阵,前插于字段默认 handler(handled 即截断)。
  List<TextFieldKeyboardHandler> _cellKeyHandlers(int row, int col) {
    TextFieldKeyboardHandlerResult handler({
      required SuperTextFieldContext textFieldContext,
      required KeyEvent keyEvent,
    }) {
      if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) {
        return TextFieldKeyboardHandlerResult.notHandled;
      }
      final key = keyEvent.logicalKey;
      final selection = textFieldContext.controller.selection;
      switch (key) {
        case LogicalKeyboardKey.tab:
          if (HardwareKeyboard.instance.isShiftPressed) {
            if (row == 0 && col == 0) {
              _exit(above: true);
            } else {
              _focusDelta(row, col, 0, -1);
            }
          } else if (row == _rows - 1 && col == _cols - 1) {
            // Tab on the very last cell appends a row (the spreadsheet/Notion gesture). 末格 Tab 加行。
            final node = _node;
            if (node != null) {
              widget.editor.execute([
                ReplaceNodeRequest(existingNodeId: node.id, newNode: tableWithRowInserted(node, _rows)),
              ]);
              WidgetsBinding.instance.addPostFrameCallback((_) => focusCell(_rows, 0));
            }
          } else {
            _focusDelta(row, col, 0, 1);
          }
          return TextFieldKeyboardHandlerResult.handled;
        case LogicalKeyboardKey.enter:
        case LogicalKeyboardKey.numpadEnter:
          // GFM cells hold no newlines: Enter walks a row down, exits below the last row. Enter 下移/末行退出。
          row == _rows - 1 ? _exit(above: false) : focusCell(row + 1, col);
          return TextFieldKeyboardHandlerResult.handled;
        case LogicalKeyboardKey.escape:
          widget.editorFocusNode.requestFocus();
          final node = _node;
          if (node != null) _selectWholeTable(node);
          return TextFieldKeyboardHandlerResult.handled;
        case LogicalKeyboardKey.arrowUp:
          if (!_caretOnEdgeLine(textFieldContext, first: true)) {
            return TextFieldKeyboardHandlerResult.notHandled;
          }
          row == 0 ? _exit(above: true) : focusCell(row - 1, col);
          return TextFieldKeyboardHandlerResult.handled;
        case LogicalKeyboardKey.arrowDown:
          if (!_caretOnEdgeLine(textFieldContext, first: false)) {
            return TextFieldKeyboardHandlerResult.notHandled;
          }
          row == _rows - 1 ? _exit(above: false) : focusCell(row + 1, col);
          return TextFieldKeyboardHandlerResult.handled;
        case LogicalKeyboardKey.arrowLeft:
          if (!selection.isCollapsed || selection.extentOffset != 0) {
            return TextFieldKeyboardHandlerResult.notHandled;
          }
          if (row == 0 && col == 0) {
            _exit(above: true);
          } else {
            _focusDelta(row, col, 0, -1);
          }
          return TextFieldKeyboardHandlerResult.handled;
        case LogicalKeyboardKey.arrowRight:
          if (!selection.isCollapsed || selection.extentOffset != textFieldContext.controller.text.length) {
            return TextFieldKeyboardHandlerResult.notHandled;
          }
          if (row == _rows - 1 && col == _cols - 1) {
            _exit(above: false);
          } else {
            _focusDelta(row, col, 0, 1);
          }
          return TextFieldKeyboardHandlerResult.handled;
        default:
          return TextFieldKeyboardHandlerResult.notHandled;
      }
    }

    return [handler, ...defaultTextFieldKeyboardHandlers];
  }

  // ── structural ops (context menu) ──────────────────────────────────────────────────────────────

  void _run(TableBlockNode Function(TableBlockNode) op, {(int, int)? focusAfter}) {
    final node = _node;
    if (node == null) return;
    widget.editor.execute([ReplaceNodeRequest(existingNodeId: node.id, newNode: op(node))]);
    if (focusAfter != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) focusCell(focusAfter.$1, focusAfter.$2);
      });
    }
  }

  void _deleteTable() {
    final node = _node;
    if (node == null) return;
    widget.editorFocusNode.requestFocus();
    widget.editor.execute([DeleteNodeRequest(nodeId: node.id)]);
  }

  void _openMenu(int row, int col, Offset globalPosition) {
    setState(() {
      _menuRow = row;
      _menuCol = col;
      _menuGlobal = globalPosition;
    });
    _menu.show();
  }

  // ── build ──────────────────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final vm = widget.viewModel;
    final colors = context.colors;
    // A cross-block sweep block-selects the table — tint the whole block (the code-block pattern) so the
    // sweep doesn't show a hole here. 跨块划选把表整块选中——整块 tint,选区带不开洞。
    final blockSelection = vm.selection?.nodeSelection;
    final sweptThrough = blockSelection is UpstreamDownstreamNodeSelection && !blockSelection.isCollapsed;

    return OverlayPortal(
      controller: _menu,
      overlayChildBuilder: _buildMenu,
      child: Stack(
        children: [
          Table(
            border: vm.border ?? TableBorder.all(color: colors.line, width: AnSize.hairline),
            // Columns share the reading column's width and cell text WRAPS (the Notion default) — upstream's
            // FittedBox scaled the whole table down instead, shrinking the type. 列均分宽、格内换行;上游
            // FittedBox 整表缩小、字跟着缩。
            defaultColumnWidth: const FlexColumnWidth(),
            defaultVerticalAlignment: TableCellVerticalAlignment.top,
            children: [
              for (var r = 0; r < _rows; r++)
                TableRow(children: [for (var c = 0; c < _cols; c++) _buildCell(r, c, colors)]),
            ],
          ),
          if (sweptThrough)
            Positioned.fill(
              child: IgnorePointer(child: ColoredBox(color: vm.selectionColor)),
            ),
        ],
      ),
    );
  }

  Widget _buildCell(int row, int col, AnColors colors) {
    final cell = widget.viewModel.cells[row][col];
    final k = _key(row, col);
    // A RAW pointer listener, not a GestureDetector: the desktop field claims secondary-tap in the gesture
    // arena (an ancestor detector would lose and the menu would never open); a Listener sees every pointer-
    // down regardless. Down-timing is also the macOS context-menu standard. 右键用裸 Listener 非手势:桌面
    // 字段在竞技场抢占次键,祖先 detector 必输;Listener 不进竞技场,按下即开菜单(macOS 标准时机)。
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if (event.buttons == kSecondaryMouseButton) _openMenu(row, col, event.position);
      },
      child: Padding(
        padding: cell.padding,
        child: Stack(
          children: [
            SuperTextField(
              key: _fieldKeys[k],
              // A DESKTOP app: pin the desktop shell explicitly (mouse selection + our keyboardHandlers)
              // rather than platform-sniffing — also what makes the widget tests exercise the real shell.
              // 桌面 app:显式钉桌面壳(鼠标选区+键盘 handler),不猜平台;widget 测也走真壳。
              configuration: SuperTextFieldPlatformConfiguration.desktop,
              focusNode: _focusNodes[k],
              textController: _controllers[k],
              textStyleBuilder: cell.textStyleBuilder,
              textAlign: cell.textAlign,
              inputSource: TextInputSource.ime, // CJK 生命线(同编辑器)
              minLines: 1,
              maxLines: null, // wrap freely — the row grows (Notion) 自由换行、行随内容长
              lineHeight: AnText.reading.fontSize! * AnText.reading.height!,
              // The built-in caret is HIDDEN and re-painted by [AnFieldCaret] below: the package sizes its
              // caret to the full leaded line box (24 for reading 15/1.6) and CaretStyle has no height slot,
              // so the house law is unreachable through this parameter.
              // HIDE BY **ZERO WIDTH**, never by a transparent colour: the package paints the caret with
              // `style.color.withValues(alpha: blinkOpacity)` (super_text_layout caret_layer.dart:182) — that
              // OVERWRITES the alpha, so a transparent BLACK resurrects as OPAQUE BLACK (measured: a 2×24
              // pure-black bar painting right over ours, which read as "the cell caret is still huge").
              // A zero-width rect paints nothing, whatever the blink does to the alpha.
              // 内建光标藏起、由下方 AnFieldCaret 重画(包按整行盒定高、CaretStyle 无 height 槽,经此参数够不着房法)。
              // **用零宽藏、绝不用透明色**:包画光标时 `color.withValues(alpha: 闪烁值)` 会**覆写 alpha**,于是透明
              // 黑复活成**不透明黑**(实测:一根 2×24 的纯黑条盖在我们那根上,读作「格里光标还是很大」)。零宽矩形
              // 画不出任何东西,alpha 被怎么改都一样。
              caretStyle: const CaretStyle(width: 0),
              selectionColor: colors.selection,
              keyboardHandlers: _cellKeyHandlers(row, col),
            ),
            Positioned.fill(
              child: AnFieldCaret(
                fieldKey: _fieldKeys[k]!,
                controller: _controllers[k]!,
                focusNode: _focusNodes[k]!,
                fontSize: AnText.reading.fontSize!,
                color: colors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenu(BuildContext context) {
    final t = Translations.of(context).documents.table;
    final colors = context.colors;
    // Row 0 is the GFM HEADER — a table can't lose it (the serializer needs it); delete the whole table
    // instead. The last column can't be removed either (an empty grid is no table). 第 0 行=GFM 表头不可删
    // (序列化必需),删表代之;最后一列同理不可删。
    final canDeleteRow = _menuRow > 0;
    final canDeleteCol = _cols > 1;
    final items = <({String label, bool danger, bool enabled, VoidCallback run})>[
      (
        label: t.insertRowAbove,
        danger: false,
        // Above the header would be a second header — insert below it instead (menu keeps the op honest).
        // 表头之上无处插(会成第二表头)。
        enabled: _menuRow > 0,
        run: () => _run((n) => tableWithRowInserted(n, _menuRow), focusAfter: (_menuRow, _menuCol)),
      ),
      (
        label: t.insertRowBelow,
        danger: false,
        enabled: true,
        run: () => _run((n) => tableWithRowInserted(n, _menuRow + 1), focusAfter: (_menuRow + 1, _menuCol)),
      ),
      (
        label: t.deleteRow,
        danger: true,
        enabled: canDeleteRow,
        run: () => _run((n) => tableWithRowRemoved(n, _menuRow), focusAfter: (_menuRow - 1, _menuCol)),
      ),
      (
        label: t.insertColLeft,
        danger: false,
        enabled: true,
        run: () => _run((n) => tableWithColumnInserted(n, _menuCol), focusAfter: (_menuRow, _menuCol)),
      ),
      (
        label: t.insertColRight,
        danger: false,
        enabled: true,
        run: () => _run((n) => tableWithColumnInserted(n, _menuCol + 1), focusAfter: (_menuRow, _menuCol + 1)),
      ),
      (
        label: t.deleteCol,
        danger: true,
        enabled: canDeleteCol,
        run: () =>
            _run((n) => tableWithColumnRemoved(n, _menuCol), focusAfter: (_menuRow, _menuCol > 0 ? _menuCol - 1 : 0)),
      ),
      (label: t.deleteTable, danger: true, enabled: true, run: _deleteTable),
    ];

    // Clamp the panel inside the overlay (estimate via the surface's own height report). 面板钳入屏内。
    final overlaySize = MediaQuery.sizeOf(context);
    final estHeight = AnMenuSurface.estHeight(items.length);
    final left = _menuGlobal.dx.clamp(0.0, overlaySize.width - AnSize.menuMinWidth);
    final top = _menuGlobal.dy.clamp(0.0, overlaySize.height - estHeight);

    return Stack(
      children: [
        // Tap-outside dismiss barrier. 点外即收。
        Positioned.fill(
          child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _menu.hide, onSecondaryTap: _menu.hide),
        ),
        Positioned(
          left: left,
          top: top,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: AnSize.menuMinWidth, maxWidth: AnSize.menuMaxWidth),
            child: IntrinsicWidth(
              child: AnMenuSurface(
                children: [
                  for (final item in items)
                    AnMenuRow(
                      enabled: item.enabled,
                      danger: item.danger,
                      onTap: () {
                        _menu.hide();
                        item.run();
                      },
                      builder: (context, active) => Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          item.label,
                          style: AnText.body.copyWith(color: item.danger ? colors.danger : colors.ink),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
