import 'package:flutter/services.dart';
import 'package:super_editor/src/infrastructure/_logging.dart';

/// Base class for [TextInputConnection] decorators.
///
/// A decorator is an object that forwards calls to another, existing implementation
/// of a given interface, but adds or alters some of those behaviors.
abstract class TextInputConnectionDecorator implements TextInputConnection {
  TextInputConnectionDecorator([this.client]);

  TextInputConnection? client;

  @override
  bool get attached => client?.attached ?? false;

  @override
  bool get scribbleInProgress => client?.scribbleInProgress ?? false;

  @override
  void show() => client?.show();

  @override
  void setEditingState(TextEditingValue value) => client?.setEditingState(value);

  @override
  void updateConfig(TextInputConfiguration configuration) => client?.updateConfig(configuration);

  @override
  void setCaretRect(Rect rect) => client?.setCaretRect(rect);

  @override
  void setSelectionRects(List<SelectionRect> selectionRects) => client?.setSelectionRects(selectionRects);

  @override
  void setComposingRect(Rect rect) => client?.setComposingRect(rect);

  @override
  void setStyle(
          {required String? fontFamily,
          required double? fontSize,
          required FontWeight? fontWeight,
          required TextDirection textDirection,
          required TextAlign textAlign}) =>
      client?.setStyle(
          fontFamily: fontFamily,
          fontSize: fontSize,
          fontWeight: fontWeight,
          textDirection: textDirection,
          textAlign: textAlign);

  // VENDOR PATCH (Anselm, Flutter 3.44) — `TextInputConnection.setStyle` was deprecated in favour of
  // `updateStyle(TextInputStyle)`. A DECORATOR must forward every member of the interface it
  // decorates, so the new one has to be added here or the whole class stops compiling ("missing
  // implementations for TextInputConnection.updateStyle"). Forwarding is all this file ever does;
  // there is no behaviour to decide.
  //
  // Keep BOTH: the deprecated setStyle is still on the interface, and dropping it would break any
  // caller Flutter has not migrated yet. Delete it only when Flutter removes it.
  //
  // vendor 补丁(Anselm,Flutter 3.44)—— `setStyle` 被 `updateStyle(TextInputStyle)` 取代。装饰器
  // **必须**转发它所装饰接口的每一个成员,故新成员不加在这里,整个类就编译不过(报「缺 updateStyle
  // 实现」)。本文件做的全部事情就是转发,没有行为可裁决。
  //
  // **两个都留**:被弃用的 setStyle 仍在接口上,删了会让 Flutter 尚未迁移的调用方断掉。等 Flutter
  // 真正移除它时再删。
  @override
  void updateStyle(TextInputStyle style) => client?.updateStyle(style);

  @override
  void requestAutofill() => client?.requestAutofill();

  @override
  void setEditableSizeAndTransform(Size editableBoxSize, Matrix4 transform) =>
      client?.setEditableSizeAndTransform(editableBoxSize, transform);

  @override
  void connectionClosedReceived() => client?.connectionClosedReceived();

  @override
  void close() => client?.close();
}

/// A [DeltaTextInputClient] that forwards all calls to the given [_client].
///
/// Subclass [DeltaTextInputClientDecorator] to override specific
/// [DeltaTextInputClient] messages. To add behavior, instead of replacing it,
/// call the `super` method within an override.
class DeltaTextInputClientDecorator with TextInputClient, DeltaTextInputClient {
  DeltaTextInputClientDecorator([this._client]);

  set client(DeltaTextInputClient? client) => _client = client;
  DeltaTextInputClient? _client;

  @override
  AutofillScope? get currentAutofillScope => _client?.currentAutofillScope;

  @override
  TextEditingValue? get currentTextEditingValue => _client?.currentTextEditingValue;

  @override
  void didChangeInputControl(TextInputControl? oldControl, TextInputControl? newControl) {
    _client?.didChangeInputControl(oldControl, newControl);
  }

  @override
  void insertTextPlaceholder(Size size) {
    _client?.insertTextPlaceholder(size);
  }

  @override
  void performAction(TextInputAction action) {
    _client?.performAction(action);
  }

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {
    _client?.performPrivateCommand(action, data);
  }

  @override
  void performSelector(String selectorName) {
    _client?.performSelector(selectorName);
  }

  @override
  void removeTextPlaceholder() {
    _client?.removeTextPlaceholder();
  }

  @override
  void showAutocorrectionPromptRect(int start, int end) {
    _client?.showAutocorrectionPromptRect(start, end);
  }

  @override
  void showToolbar() {
    _client?.showToolbar();
  }

  @override
  void updateEditingValue(TextEditingValue value) {
    _client?.updateEditingValue(value);
  }

  @override
  void updateEditingValueWithDeltas(List<TextEditingDelta> textEditingDeltas) {
    _client?.updateEditingValueWithDeltas(textEditingDeltas);
  }

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {
    _client?.updateFloatingCursor(point);
  }

  @override
  void connectionClosed() {
    _client?.connectionClosed();
  }
}

/// A [DeltaTextInputClientDecorator] that notifies [_onConnectionClosed] when
/// the IME connection closes.
///
/// This decorator is needed because [TextInputConnection] has no way to listen
/// for when its connection is closed. By wrapping a [TextInputClient] with
/// this decorator, the code that owns the [TextInputConnection] can receive
/// a notification when the connection closes.
class ClosureAwareDeltaTextInputClientDecorator extends DeltaTextInputClientDecorator {
  ClosureAwareDeltaTextInputClientDecorator(
    this._onConnectionClosed, [
    DeltaTextInputClient? client,
  ]) : super(client);

  final VoidCallback _onConnectionClosed;

  @override
  void connectionClosed() {
    editorImeLog.fine("[ClosureAwareDeltaTextInputClientDecorator] - IME connection was closed");
    _onConnectionClosed();
    _client?.connectionClosed();
  }
}
