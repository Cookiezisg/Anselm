import 'package:super_editor/super_editor.dart';

/// Guards super_editor's word/paragraph double-/triple-tap machinery against NON-TEXT blocks (code block /
/// image / hr / table): upstream's `_onDoubleTapDown` flips its state machine to word-selection BEFORE
/// checking what was hit, so a double-click on a box component leaves `_selectionType = word` with no
/// upstream word bound — the next drag dereferences it (`!`) and the gesture arena dies on the NPE, which
/// reads as "the mouse stops working" until the editor remounts (upstream #2789 family, still open in
/// dev.52). Content tap handlers run BEFORE that machinery (document_gestures_mouse.dart), so this delegate
/// intercepts: a double/triple tap on a non-text position selects the WHOLE block (the Notion behaviour for
/// atomic blocks) and halts — the poisoned state never forms.
///
/// 防「点着点着卡死」:上游双/三击先把状态机拨到 word 选择再看命中了什么,双击原子块(码块/图/hr/表)后
/// `_selectionType=word` 却无词锚,随后一拖就 NPE、手势竞技场死掉——表现为鼠标失灵(上游 #2789 族,dev.52 未修)。
/// content tap handler 在那套状态机**之前**跑,故此代理拦截:非文本位置的双/三击→整块选中(Notion 对原子块的
/// 行为)+halt,毒态根本不形成。
class AnBlockTapGuard extends ContentTapDelegate {
  AnBlockTapGuard(this._editContext);

  final SuperEditorContext _editContext;

  TapHandlingInstruction _selectWholeBlockIfNotText(DocumentTapDetails details) {
    final position = details.documentLayout.getDocumentPositionNearestToOffset(details.layoutOffset);
    if (position == null || position.nodePosition is TextNodePosition) {
      return TapHandlingInstruction.continueHandling;
    }
    _editContext.editor.execute([
      ChangeSelectionRequest(
        DocumentSelection(
          base: DocumentPosition(
            nodeId: position.nodeId,
            nodePosition: const UpstreamDownstreamNodePosition.upstream(),
          ),
          extent: DocumentPosition(
            nodeId: position.nodeId,
            nodePosition: const UpstreamDownstreamNodePosition.downstream(),
          ),
        ),
        SelectionChangeType.expandSelection,
        SelectionReason.userInteraction,
      ),
    ]);
    return TapHandlingInstruction.halt;
  }

  @override
  TapHandlingInstruction onDoubleTap(DocumentTapDetails details) => _selectWholeBlockIfNotText(details);

  @override
  TapHandlingInstruction onTripleTap(DocumentTapDetails details) => _selectWholeBlockIfNotText(details);
}

/// The [SuperEditor.contentTapDelegateFactories] entry for [AnBlockTapGuard] — registered ALONGSIDE the
/// default link-launch handler, never instead of it. 工厂:与默认链接点开 handler 并列注册、不顶掉它。
AnBlockTapGuard anBlockTapGuardFactory(SuperEditorContext editContext) => AnBlockTapGuard(editContext);
