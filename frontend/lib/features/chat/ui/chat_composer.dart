import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/tokens.dart';
import '../../../core/entity/mention_source.dart';
import '../../../core/perf/debouncer.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../model/conversation_transcript.dart';
import '../model/mention_query.dart';
import '../model/mention_spans.dart';
import 'mention_text_controller.dart';
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
///  - **@ typeahead** (the combobox standard): typing `@` at line start / after whitespace — or the lead
///    @ button — opens [AnMentionPanel] ABOVE the composer (full width, empty query = browse); further
///    typing filters server-side; no match closes it. ↑↓ move (wrapping), Enter/Tab pick (Enter is
///    INTERCEPTED before send while open), Esc dismisses and that token stays closed. FOCUS never
///    leaves the field. A pick inserts `@name ` tinted as a pseudo pill; one backspace right after a
///    pill deletes it whole. On send, snapshots whose `@name` still lives in the text go up as
///    `mentions` (the backend freezes name+content server-side).
///
/// composer 行为宿主(壳=AnComposer):线程内传 [conversationId],landing 传 [onSubmitNew](首发建线程)。
/// 行为契约:Enter 发 / Shift+Enter 换行 / IME 合成期 Enter 绝不发;生成中 Enter 门控;send↔stop 走壳的
/// keyed trailing;草稿按线程存。**@ typeahead**(combobox 标准):行首/空白后打 `@` 或点 lead @ 钮 →
/// composer 上方开面板(整宽,空 query=浏览);续打服务端过滤;无匹配即关。↑↓ 循环移动、Enter/Tab 选中
/// (面板开着时 Enter 先于发送被拦)、Esc 关闭且该 token 不再弹;**焦点永不离输入框**。选中插 `@name `
/// 染伪药丸;药丸后一次退格整删。发送时文本里仍在的 `@name` 快照作 mentions 上行(后端冻结)。
class ChatComposer extends ConsumerStatefulWidget {
  const ChatComposer({this.conversationId, this.onSubmitNew, super.key})
      : assert(conversationId != null || onSubmitNew != null,
            'ChatComposer needs a conversationId or onSubmitNew');

  final String? conversationId;
  final Future<void> Function(String text, List<MentionSnapshot> mentions)? onSubmitNew;

  /// Landing (New page) — lifts the chrome with the float shadow. landing 浮起。
  bool get _floating => conversationId == null;

  @override
  ConsumerState<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends ConsumerState<ChatComposer> {
  late final MentionTextEditingController _ctrl;
  late final FocusNode _focus;
  bool _hasText = false;
  bool _submittingNew = false;

  // ── @ typeahead state @ 预输入态 ──
  final LayerLink _link = LayerLink();
  late final OverlayPortalController _portal = OverlayPortalController();
  final Debouncer _searchDebounce = Debouncer(const Duration(milliseconds: 150));
  List<MentionCandidate> _candidates = const [];
  int _activeIndex = 0;
  int _tokenStart = -1; // the open token's '@' index 活跃 token 的 @ 下标
  int _dismissedStart = -1; // Esc'd token — stays closed until the caret leaves it 已 Esc 的 token 不再弹
  double _panelWidth = 0;
  int _searchSeq = 0; // stale async guard 迟到结果守卫

  /// Picked snapshots by name — only those whose `@name` survives in the text are sent. 按名存快照。
  final Map<String, MentionSnapshot> _picked = {};

  String get _draftKey => widget.conversationId ?? ChatDrafts.landingKey;

  @override
  void initState() {
    super.initState();
    _ctrl = MentionTextEditingController(text: ref.read(chatDraftsProvider).of(_draftKey));
    _hasText = _ctrl.text.trim().isNotEmpty;
    _ctrl.addListener(_onChanged);
    _focus = FocusNode(onKeyEvent: _onKey);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchDebounce.dispose();
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
    _syncMentionQuery();
  }

  bool get _generating {
    final id = widget.conversationId;
    if (id == null) return false;
    return ref.read(conversationStreamProvider(id).notifier).transcript.value.hasInFlight;
  }

  // ── @ typeahead ──

  bool get _pickerOpen => _portal.isShowing;

  void _syncMentionQuery() {
    final sel = _ctrl.selection;
    final token = sel.isValid && sel.isCollapsed
        ? activeMentionQuery(_ctrl.text, sel.baseOffset)
        : null;
    if (token == null) {
      _dismissedStart = -1; // caret left the token — a fresh '@' may open again 离开 token,新 @ 可再弹
      _closePicker();
      return;
    }
    if (token.start == _dismissedStart) return; // Esc'd — stay closed for THIS token 该 token 已被 Esc
    _tokenStart = token.start;
    _searchDebounce.run(() async {
      if (!mounted) return;
      final seq = ++_searchSeq;
      final List<MentionCandidate> found;
      try {
        found = await ref.read(mentionSourceProvider).search(token.query);
      } catch (_) {
        return; // a failed lookup just doesn't open — typing is never blocked 查询失败不弹、不挡输入
      }
      if (!mounted || seq != _searchSeq) return; // stale 迟到
      // Re-check the token still holds (text may have changed during the await). 复核 token 仍在。
      final now = _ctrl.selection;
      final still = now.isValid && now.isCollapsed
          ? activeMentionQuery(_ctrl.text, now.baseOffset)
          : null;
      if (still == null || still.start == _dismissedStart) return;
      setState(() {
        _candidates = found;
        _activeIndex = 0;
        _tokenStart = still.start;
      });
      found.isEmpty ? _closePicker() : _openPicker();
    });
  }

  void _openPicker() {
    if (!_portal.isShowing) _portal.show();
  }

  void _closePicker() {
    if (_portal.isShowing) _portal.hide();
  }

  /// The lead @ button — equivalent to typing '@' at the caret (whitespace-padded so the trigger rule
  /// holds); the listener then opens the panel. lead @ 钮=在光标处打 '@'(需要则补空格),listener 接手弹面板。
  void _insertMentionTrigger() {
    final sel = _ctrl.selection;
    final at = sel.isValid ? sel.baseOffset : _ctrl.text.length;
    final before = _ctrl.text.substring(0, at);
    final needsSpace = before.isNotEmpty && !before.endsWith(' ') && !before.endsWith('\n');
    final insert = needsSpace ? ' @' : '@';
    _ctrl.value = TextEditingValue(
      text: before + insert + _ctrl.text.substring(sel.isValid ? sel.extentOffset : at),
      selection: TextSelection.collapsed(offset: at + insert.length),
    );
    _focus.requestFocus();
  }

  void _pick(int index) {
    if (index < 0 || index >= _candidates.length) return;
    final cand = _candidates[index];
    final sel = _ctrl.selection;
    if (!sel.isValid || _tokenStart < 0) return;
    final replaced = '@${cand.name} ';
    _ctrl.pillNames.add(cand.name);
    _picked[cand.name] = MentionSnapshot(type: cand.type, id: cand.id, name: cand.name);
    _ctrl.value = TextEditingValue(
      text: _ctrl.text.replaceRange(_tokenStart, sel.baseOffset, replaced),
      selection: TextSelection.collapsed(offset: _tokenStart + replaced.length),
    );
    _closePicker();
  }

  /// One backspace right after a pseudo pill deletes the WHOLE `@name` (the atomic-token deal). Returns
  /// true when handled. 药丸后一次退格整删 token。
  bool _atomicBackspace() {
    final sel = _ctrl.selection;
    if (!sel.isValid || !sel.isCollapsed) return false;
    final cursor = sel.baseOffset;
    // The pill may be followed by the space the pick inserted — eat "…@name<caret>" only (the space
    // deletes normally first, keeping plain char-wise feel). 只吃 "@name|" 形态(尾空格先常规删)。
    for (final name in _ctrl.pillNames) {
      final start = cursor - name.length - 1;
      if (start < 0 || _ctrl.text.substring(start, cursor) != '@$name') continue;
      if (start > 0 && !RegExp(r'\s').hasMatch(_ctrl.text[start - 1])) continue; // boundary 边界
      _ctrl.value = TextEditingValue(
        text: _ctrl.text.replaceRange(start, cursor, ''),
        selection: TextSelection.collapsed(offset: start),
      );
      return true;
    }
    return false;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;

    // While an IME composition is open, every key belongs to the IME (candidate navigation included).
    // IME 合成期按键全归 IME(含候选导航)。
    if (_ctrl.value.composing.isValid) return KeyEventResult.ignored;

    // ── the open picker owns its keys (combobox standard; focus stays here) 面板开着时按键归它 ──
    if (_pickerOpen && _candidates.isNotEmpty) {
      if (key == LogicalKeyboardKey.arrowDown) {
        setState(() => _activeIndex = (_activeIndex + 1) % _candidates.length);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        setState(() => _activeIndex = (_activeIndex - 1 + _candidates.length) % _candidates.length);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.enter ||
          key == LogicalKeyboardKey.numpadEnter ||
          key == LogicalKeyboardKey.tab) {
        _pick(_activeIndex); // Enter picks — INTERCEPTED before send 拦在发送前
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.escape) {
        _dismissedStart = _tokenStart; // this token stays closed 该 token 不再弹
        _closePicker();
        return KeyEventResult.handled;
      }
    }

    if (key == LogicalKeyboardKey.backspace && event is KeyDownEvent) {
      if (_atomicBackspace()) return KeyEventResult.handled;
      return KeyEventResult.ignored;
    }

    if (key != LogicalKeyboardKey.enter && key != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (HardwareKeyboard.instance.isShiftPressed) return KeyEventResult.ignored; // newline 换行
    // While generating the send affordance is a STOP button — the keyboard path must agree: swallow
    // (never a concurrent turn), don't insert a newline either. 生成中键盘同 UI:吞掉、不发也不换行。
    if (_generating) return KeyEventResult.handled;
    _send();
    return KeyEventResult.handled;
  }

  /// Snapshots whose `@name` still lives in the text (deleted pills drop off). 仍在文本里的快照。
  List<MentionSnapshot> _liveMentions(String text) =>
      [for (final m in _picked.values) if (text.contains('@${m.name}')) m];

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _submittingNew) return;
    final mentions = _liveMentions(text);
    _closePicker();
    final id = widget.conversationId;
    if (id != null) {
      // Optimistic — the bubble is on screen before the POST returns; clear the field NOW. 乐观:即清即发。
      _ctrl.clear();
      _picked.clear();
      _ctrl.pillNames.clear();
      ref.read(chatDraftsProvider).clear(_draftKey);
      await ref.read(conversationStreamProvider(id).notifier).send(text, mentions: mentions);
      return;
    }
    // Landing: the first send creates the thread — keep the text until it succeeds (a failed create
    // must not eat the message; the failure surfaces as a toast). landing:首发建线程——成功前不清字
    // (建失败不吞消息,失败冒 toast)。
    setState(() => _submittingNew = true);
    try {
      await widget.onSubmitNew!(text, mentions);
      if (!mounted) return;
      _ctrl.clear();
      _picked.clear();
      _ctrl.pillNames.clear();
      ref.read(chatDraftsProvider).clear(_draftKey);
    } catch (_) {
      if (mounted) {
        ref.read(overlayProvider.notifier).showToast(Translations.of(context).chat.sendFailed);
      }
    } finally {
      if (mounted) setState(() => _submittingNew = false);
    }
  }

  /// The composer chrome wrapped as the picker's ANCHOR: the portal's follower hangs the panel above
  /// the composer at full composer width. 壳作锚:follower 把面板挂 composer 上方、整 composer 宽。
  Widget _anchored(BuildContext context, Widget composer) {
    return LayoutBuilder(builder: (context, constraints) {
      _panelWidth = constraints.maxWidth;
      return OverlayPortal(
        controller: _portal,
        overlayChildBuilder: (context) => Positioned(
          width: _panelWidth,
          child: CompositedTransformFollower(
            link: _link,
            targetAnchor: Alignment.topLeft,
            followerAnchor: Alignment.bottomLeft,
            offset: const Offset(0, -AnSpace.s8),
            showWhenUnlinked: false,
            child: AnMentionPanel(
              items: [
                for (final c in _candidates)
                  AnMentionRowData(kind: c.type, name: c.name, description: c.description),
              ],
              activeIndex: _activeIndex,
              onPick: _pick,
            ),
          ),
        ),
        child: CompositedTransformTarget(link: _link, child: composer),
      );
    });
  }

  List<Widget> _lead(Translations t) => [
        AnButton.iconOnly(AnIcons.mention,
            size: AnButtonSize.sm, semanticLabel: t.chat.mentionEntity, onPressed: _insertMentionTrigger),
      ];

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final id = widget.conversationId;
    if (id == null) {
      return _anchored(
        context,
        AnComposer(
          controller: _ctrl,
          focusNode: _focus,
          placeholder: t.chat.placeholder,
          floating: widget._floating,
          lead: _lead(t),
          trailing: _hasText && !_submittingNew
              ? AnButton.iconOnly(AnIcons.send,
                  key: const ValueKey('send'), semanticLabel: t.chat.placeholder, onPressed: _send)
              : null,
        ),
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
        return _anchored(
          context,
          AnComposer(
            controller: _ctrl,
            focusNode: _focus,
            placeholder: t.chat.placeholder,
            lead: _lead(t),
            trailing: trailing,
          ),
        );
      },
    );
  }
}
