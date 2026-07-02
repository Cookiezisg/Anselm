import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../model/conversation_transcript.dart';
import '../state/chat_drafts.dart';
import '../state/conversation_stream_provider.dart';

/// The chat composer BEHAVIOUR host over the [AnComposer] chrome — docked in a thread (pass
/// [conversationId]) or on the New landing (pass [onSubmitNew]; the first send creates the thread).
///
/// Behaviour contract:
///  - **Enter sends / Shift+Enter newline / an IME-composing Enter NEVER sends** (a CJK candidate
///    commit must not fire the message).
///  - **Enter is gated while generating** (the send button is already a stop button then — the keyboard
///    path must agree, the documented backup gap).
///  - send↔stop ride the chrome's keyed trailing switcher; the send button exists only with content.
///  - The draft persists per thread ([ChatDrafts]) so switching away and back restores it; it clears on
///    a successful send.
///
/// composer 行为宿主(壳=AnComposer):线程内传 [conversationId],landing 传 [onSubmitNew](首发建线程)。
/// 行为契约:Enter 发 / Shift+Enter 换行 / **IME 合成期 Enter 绝不发**;**生成中 Enter 门控**(此时发送钮
/// 已是 stop,键盘路径必须一致——已记档的旧缺口);send↔stop 走壳的 keyed trailing;空无发送钮;草稿按线程
/// 存(切走切回恢复,发送成功即清)。
class ChatComposer extends ConsumerStatefulWidget {
  const ChatComposer({this.conversationId, this.onSubmitNew, super.key})
      : assert(conversationId != null || onSubmitNew != null,
            'ChatComposer needs a conversationId or onSubmitNew');

  final String? conversationId;
  final Future<void> Function(String text)? onSubmitNew;

  /// Landing (New page) — lifts the chrome with the float shadow. landing 浮起。
  bool get _floating => conversationId == null;

  @override
  ConsumerState<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends ConsumerState<ChatComposer> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;
  bool _hasText = false;
  bool _submittingNew = false;

  String get _draftKey => widget.conversationId ?? ChatDrafts.landingKey;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: ref.read(chatDraftsProvider).of(_draftKey));
    _hasText = _ctrl.text.trim().isNotEmpty;
    _ctrl.addListener(_onChanged);
    _focus = FocusNode(onKeyEvent: _onKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _ctrl
      ..removeListener(_onChanged)
      ..dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged() {
    ref.read(chatDraftsProvider).set(_draftKey, _ctrl.text);
    final has = _ctrl.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  bool get _generating {
    final id = widget.conversationId;
    if (id == null) return false;
    return ref.read(conversationStreamProvider(id).notifier).transcript.value.hasInFlight;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.enter && key != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    // An Enter that commits an East-Asian IME candidate must NOT send. IME 合成期的 Enter 不发。
    if (_ctrl.value.composing.isValid) return KeyEventResult.ignored;
    if (HardwareKeyboard.instance.isShiftPressed) return KeyEventResult.ignored; // newline 换行
    // While generating the send affordance is a STOP button — the keyboard path must agree: swallow
    // (never a concurrent turn), don't insert a newline either. 生成中键盘同 UI:吞掉、不发也不换行。
    if (_generating) return KeyEventResult.handled;
    _send();
    return KeyEventResult.handled;
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _submittingNew) return;
    final id = widget.conversationId;
    if (id != null) {
      // Optimistic — the bubble is on screen before the POST returns; clear the field NOW. 乐观:即清即发。
      _ctrl.clear();
      ref.read(chatDraftsProvider).clear(_draftKey);
      await ref.read(conversationStreamProvider(id).notifier).send(text);
      return;
    }
    // Landing: the first send creates the thread — keep the text until it succeeds (a failed create
    // must not eat the message; the failure surfaces as a toast). landing:首发建线程——成功前不清字
    // (建失败不吞消息,失败冒 toast)。
    setState(() => _submittingNew = true);
    try {
      await widget.onSubmitNew!(text);
      if (!mounted) return;
      _ctrl.clear();
      ref.read(chatDraftsProvider).clear(_draftKey);
    } catch (_) {
      if (mounted) {
        ref.read(overlayProvider.notifier).showToast(Translations.of(context).chat.sendFailed);
      }
    } finally {
      if (mounted) setState(() => _submittingNew = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final id = widget.conversationId;
    if (id == null) {
      return AnComposer(
        controller: _ctrl,
        focusNode: _focus,
        placeholder: t.chat.placeholder,
        floating: widget._floating,
        trailing: _hasText && !_submittingNew
            ? AnButton.iconOnly(AnIcons.send,
                key: const ValueKey('send'), semanticLabel: t.chat.placeholder, onPressed: _send)
            : null,
      );
    }
    // Docked: the send↔stop morph follows the live pipeline (re-read the listenable each build — it is
    // a fresh instance after a controller rebuild). 停靠:send↔stop 跟管道(listenable 每 build 重取)。
    final ctl = ref.watch(conversationStreamProvider(id).notifier);
    return ValueListenableBuilder<ConversationTranscript>(
      valueListenable: ctl.transcript,
      builder: (context, transcript, _) {
        final generating = transcript.hasInFlight;
        final Widget? trailing = generating
            ? AnButton.iconOnly(AnIcons.stop,
                key: const ValueKey('stop'),
                semanticLabel: t.chat.stoppedCancelled,
                onPressed: () => ctl.cancelTurn())
            : _hasText
                ? AnButton.iconOnly(AnIcons.send,
                    key: const ValueKey('send'), semanticLabel: t.chat.placeholder, onPressed: _send)
                : null;
        return AnComposer(
          controller: _ctrl,
          focusNode: _focus,
          placeholder: t.chat.placeholder,
          trailing: trailing,
        );
      },
    );
  }
}
