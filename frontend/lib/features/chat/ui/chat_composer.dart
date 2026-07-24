import 'package:file_selector/file_selector.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pasteboard/pasteboard.dart';

import '../../../core/settings/settings_prefs.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/entity/mention_source.dart';
import '../../../core/perf/debouncer.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../model/conversation_transcript.dart';
import '../model/mention_query.dart';
import '../model/mention_spans.dart';
import 'mention_text_controller.dart';
import '../model/user_attachment.dart';
import '../state/chat_drafts.dart';
import '../state/pending_attachments.dart';
import '../state/conversation_stream_provider.dart';
import '../state/speech_input_provider.dart';

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
    : assert(
        conversationId != null || onSubmitNew != null,
        'ChatComposer needs a conversationId or onSubmitNew',
      );

  final String? conversationId;
  final Future<void> Function(
    String text,
    List<MentionSnapshot> mentions,
    List<String> attachmentIds,
  )?
  onSubmitNew;

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
  String? _speechBefore;
  String? _speechAfter;
  String? _speechLastMerged;
  bool _applyingSpeechMerge = false;

  // ── @ typeahead state @ 预输入态 ──
  final LayerLink _link = LayerLink();
  late final OverlayPortalController _portal = OverlayPortalController();

  /// TapRegion group linking the panel + composer: taps inside either never dismiss. 面板与壳同组。
  static const Object _mentionPanelGroup = 'chat-mention-panel';
  final Debouncer _searchDebounce = Debouncer(AnMotion.typeahead);
  List<MentionCandidate> _candidates = const [];
  int _activeIndex = 0;
  int _tokenStart = -1; // the open token's '@' index 活跃 token 的 @ 下标
  int _dismissedStart =
      -1; // Esc'd token — stays closed until the caret leaves it 已 Esc 的 token 不再弹
  double _panelWidth = 0;
  int _searchSeq = 0; // stale async guard 迟到结果守卫

  /// Picked snapshots by name — only those whose `@name` survives in the text are sent. 按名存快照。
  final Map<String, MentionSnapshot> _picked = {};

  String get _draftKey => widget.conversationId ?? ChatDrafts.landingKey;

  @override
  void initState() {
    super.initState();
    _ctrl = MentionTextEditingController(
      text: ref.read(chatDraftsProvider).of(_draftKey),
    );
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
    var needsBuild = has != _hasText;
    if (needsBuild) _hasText = has;
    if (!_applyingSpeechMerge &&
        _speechLastMerged != null &&
        _ctrl.text != _speechLastMerged &&
        !ref.read(speechInputProvider).active) {
      _clearSpeechAnchor();
      needsBuild = true;
    }
    if (needsBuild) setState(() {});
    _syncMentionQuery();
  }

  bool get _generating {
    final id = widget.conversationId;
    if (id == null) return false;
    return ref
        .read(conversationStreamProvider(id).notifier)
        .transcript
        .value
        .hasInFlight;
  }

  // ── @ typeahead ──

  bool get _pickerOpen => _portal.isShowing;

  void _syncMentionQuery() {
    final sel = _ctrl.selection;
    final token = sel.isValid && sel.isCollapsed
        ? activeMentionQuery(_ctrl.text, sel.baseOffset)
        : null;
    if (token == null) {
      _dismissedStart =
          -1; // caret left the token — a fresh '@' may open again 离开 token,新 @ 可再弹
      _closePicker();
      return;
    }
    if (token.start == _dismissedStart) {
      return; // Esc'd — stay closed for THIS token 该 token 已被 Esc
    }
    _tokenStart = token.start;
    _searchDebounce.run(() async {
      if (!mounted) return;
      final seq = ++_searchSeq;
      final List<MentionCandidate> found;
      try {
        found = await ref.read(mentionSourceProvider).search(token.query);
      } catch (_) {
        // A failed lookup must CLOSE the picker — never leave the PREVIOUS query's stale candidates
        // showing (picking one would insert a wrong mention). Typing is never blocked. 查询失败关面板、
        // 不留过期候选(否则会插错提及);不挡输入。
        if (mounted && seq == _searchSeq) _closePicker();
        return;
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
    // Use the NORMALIZED selection bounds (sel.start/end, min/max), NOT base/extent — a reverse drag has
    // base > extent, and `substring(0, base) + '@' + substring(extent)` would DUPLICATE the selected span
    // (`before` and the tail overlap). 用归一边界(非 base/extent);反向选区直接用会重复选中文本。
    final start = sel.isValid ? sel.start : _ctrl.text.length;
    final end = sel.isValid ? sel.end : start;
    final before = _ctrl.text.substring(0, start);
    final needsSpace =
        before.isNotEmpty && !before.endsWith(' ') && !before.endsWith('\n');
    final insert = needsSpace ? ' @' : '@';
    _ctrl.value = TextEditingValue(
      text: before + insert + _ctrl.text.substring(end),
      selection: TextSelection.collapsed(offset: start + insert.length),
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
    _picked[cand.name] = MentionSnapshot(
      type: cand.type,
      id: cand.id,
      name: cand.name,
    );
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
      if (start < 0 || _ctrl.text.substring(start, cursor) != '@$name') {
        continue;
      }
      if (start > 0 && !RegExp(r'\s').hasMatch(_ctrl.text[start - 1])) {
        continue; // left boundary 左边界
      }
      // Right boundary: the pill must END at the caret. If a word/CJK char is glued after (mid-word
      // `@alicexyz` / `@alice你好`), `@name` isn't a standalone token — fall back to char-wise backspace,
      // never atomic-delete the whole `@name`. 右边界:光标须在药丸末;后粘词/中文字符则逐字删、不整删。
      if (cursor < _ctrl.text.length &&
          RegExp('[\\w一-鿿]').hasMatch(_ctrl.text[cursor])) {
        continue;
      }
      _ctrl.value = TextEditingValue(
        text: _ctrl.text.replaceRange(start, cursor, ''),
        selection: TextSelection.collapsed(offset: start),
      );
      return true;
    }
    return false;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;

    // While an IME composition is open, every key belongs to the IME (candidate navigation included).
    // Guard = valid AND NON-COLLAPSED, spelled explicitly: after a macOS CJK commit the controller
    // often keeps a COLLAPSED composing range (start==end) whose isValid is still true — and this
    // SDK's `isComposingRangeValid` does NOT exclude collapsed either (probed) — so the old guard ate
    // every post-commit Enter and the platform inserted a newline instead of sending (用户 0718
    // 真机:「回车没有发送」根因). IME 合成期按键全归 IME;判据=有效且**非塌缩**(显式拼写——本 SDK 的
    // isComposingRangeValid 同样不排塌缩,实测探明):塌缩 composing=无活动合成。
    final composing = _ctrl.value.composing;
    if (composing.isValid && !composing.isCollapsed) {
      return KeyEventResult.ignored;
    }

    // ── the open picker owns its keys (combobox standard; focus stays here) 面板开着时按键归它 ──
    if (_pickerOpen && _candidates.isNotEmpty) {
      if (key == LogicalKeyboardKey.arrowDown) {
        setState(() => _activeIndex = (_activeIndex + 1) % _candidates.length);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowUp) {
        setState(
          () => _activeIndex =
              (_activeIndex - 1 + _candidates.length) % _candidates.length,
        );
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

    if (key != LogicalKeyboardKey.enter &&
        key != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (HardwareKeyboard.instance.isShiftPressed) {
      return KeyEventResult.ignored; // newline 换行
    }
    // The send-key preference (S1 对话面板): `enter` (default) = bare Enter sends; `cmdEnter` =
    // Enter inserts a newline, only ⌘Enter (Ctrl on non-mac) sends. IME-composing guard stays
    // upstream either way. 发送键偏好:enter=裸回车发;cmdEnter=回车换行、仅 ⌘Enter 发。
    final wantsCmd =
        ref.read(settingsPrefsProvider).getString(SettingsKeys.chatSendKey) ==
        'cmdEnter';
    final cmdHeld =
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    if (wantsCmd && !cmdHeld) return KeyEventResult.ignored; // newline 换行
    // While generating the send affordance is a STOP button — the keyboard path must agree: swallow
    // (never a concurrent turn), don't insert a newline either. 生成中键盘同 UI:吞掉、不发也不换行。
    if (_generating) return KeyEventResult.handled;
    _send();
    return KeyEventResult.handled;
  }

  // ── attachments: three intakes, one funnel 附件三入口一漏斗 ──

  PendingAttachments get _att =>
      ref.read(pendingAttachmentsProvider(_draftKey).notifier);

  Future<void> _pickFiles() async {
    final files = await openFiles();
    for (final f in files) {
      await _att.addBytes(
        await f.readAsBytes(),
        filename: f.name,
        mimeType: f.mimeType,
      );
    }
  }

  /// Clipboard triage, the platform convention: file URLs first (Finder copies also carry the file's
  /// ICON bitmap — image-first would paste an icon), then a bitmap (screenshots — PNG bytes), then let
  /// the DEFAULT paste run (text). 剪贴板判序:文件先(Finder 复制同时带图标位图,图先会贴成图标)→ 位图
  /// (截图,PNG 字节)→ 放行默认文本粘贴。
  Future<void> _pasteIntake(VoidCallback fallthrough) async {
    try {
      final files = await Pasteboard.files();
      if (files.isNotEmpty) {
        for (final path in files) {
          await _att.addPath(path);
        }
        return;
      }
      final image = await Pasteboard.image;
      if (image != null && image.isNotEmpty) {
        final stamp = DateTime.now().toIso8601String().replaceAll(
          RegExp(r'[:.]'),
          '-',
        );
        await _att.addBytes(
          image,
          filename: 'pasted-image-$stamp.png',
          mimeType: 'image/png',
        );
        return;
      }
    } catch (_) {
      /* clipboard read failed — fall through to text 剪贴板读失败,走文本 */
    }
    fallthrough();
  }

  /// Snapshots whose `@name` still lives in the text AT A TOKEN BOUNDARY (deleted pills drop off).
  /// Boundary-checked like the tint (`_tokenAt`) and the atomic backspace — a bare `contains` shipped
  /// a deleted pill whenever its name survived as a substring ('@alice' deleted but '@alice2' typed).
  /// 仍以 token 边界存在于文本的快照;与染色/整删同一边界规则——裸 contains 会把删掉的药丸当子串误发。
  List<MentionSnapshot> _liveMentions(String text) => [
    for (final m in _picked.values)
      if (_liveAtBoundary(text, m.name)) m,
  ];

  // EXACTLY the tint's boundary class (space/\n/\t — mention_text_controller._ws): a wider \s
  // (NBSP/\r/U+3000) shipped mentions that rendered untinted and weren't atomic-deletable.
  // 与染色同一边界字符集(空格/换行/制表)——更宽的 \s 会发出未染色、不可整删的提及。
  static bool _wsChar(String ch) => ch == ' ' || ch == '\n' || ch == '\t';

  static bool _liveAtBoundary(String text, String name) {
    final token = '@$name';
    var from = 0;
    while (true) {
      final at = text.indexOf(token, from);
      if (at < 0) return false;
      final end = at + token.length;
      final beforeOk = at == 0 || _wsChar(text[at - 1]);
      final afterOk = end == text.length || _wsChar(text[end]);
      if (beforeOk && afterOk) return true;
      from = at + 1;
    }
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    final attachmentIds = _att.readyIds;
    if ((text.isEmpty && attachmentIds.isEmpty) || _submittingNew) return;
    if (_att.hasUploading) {
      return; // the button is disabled too — never send half a payload 上传中不发
    }
    // Don't SILENTLY drop failed attachments (M5): the send takes only readyIds and then clears everything
    // (failed chips included) — tell the user which ones didn't make it before they vanish. 失败附件不静默丢。
    final failedCount = _att.failedCount;
    if (failedCount > 0) {
      ref
          .read(noticeCenterProvider.notifier)
          .show(
            Translations.of(
              context,
            ).chat.attachmentsFailedDropped(n: failedCount),
            tone: AnTone.warn,
          );
    }
    final mentions = _liveMentions(text);
    _closePicker();
    final id = widget.conversationId;
    if (id != null) {
      // Optimistic — the bubble is on screen before the POST returns; clear the field NOW. 乐观:即清即发。
      _ctrl.clear();
      _picked.clear();
      _ctrl.pillNames.clear();
      _att.clear();
      ref.read(chatDraftsProvider).clear(_draftKey);
      await ref
          .read(conversationStreamProvider(id).notifier)
          .send(text, mentions: mentions, attachmentIds: attachmentIds);
      return;
    }
    // Landing: the first send creates the thread — keep the text until it succeeds (a failed create
    // must not eat the message; the failure surfaces as a toast). landing:首发建线程——成功前不清字
    // (建失败不吞消息,失败冒 toast)。
    setState(() => _submittingNew = true);
    try {
      await widget.onSubmitNew!(text, mentions, attachmentIds);
      if (!mounted) return;
      _ctrl.clear();
      _picked.clear();
      _ctrl.pillNames.clear();
      _att.clear();
      ref.read(chatDraftsProvider).clear(_draftKey);
    } catch (_) {
      if (mounted) {
        ref
            .read(noticeCenterProvider.notifier)
            .show(
              Translations.of(context).chat.sendFailed,
              tone: AnTone.danger,
            );
      }
    } finally {
      if (mounted) setState(() => _submittingNew = false);
    }
  }

  Future<void> _startSpeechInput() async {
    if (!ref.read(speechInputAvailableProvider)) {
      ref
          .read(noticeCenterProvider.notifier)
          .show(
            Translations.of(context).chat.voiceInputUnavailable,
            tone: AnTone.warn,
          );
      return;
    }
    final sel = _ctrl.selection;
    final start = sel.isValid ? sel.start : _ctrl.text.length;
    final end = sel.isValid ? sel.end : start;
    _speechBefore = _ctrl.text.substring(0, start);
    _speechAfter = _ctrl.text.substring(end);
    _speechLastMerged = null;
    _focus.requestFocus();
    await ref.read(speechInputProvider.notifier).start();
  }

  Future<void> _finishSpeechInput() =>
      ref.read(speechInputProvider.notifier).finish();

  void _applySpeechInput(SpeechInputState? previous, SpeechInputState next) {
    final err = next.error;
    if (err != null && err != previous?.error) {
      final t = Translations.of(context).chat;
      _mergeSpeechText(next);
      if (!next.canRetry) _clearSpeechAnchor();
      ref
          .read(noticeCenterProvider.notifier)
          .show(
            switch (err) {
              speechInputErrorUnavailable => t.voiceInputUnavailable,
              speechInputErrorPermissionDenied => t.voiceInputPermissionDenied,
              speechInputErrorConnectionLost => t.voiceInputConnectionLost,
              _ => t.voiceInputFailed,
            },
            tone: switch (err) {
              speechInputErrorUnavailable ||
              speechInputErrorConnectionLost ||
              speechInputErrorPermissionDenied => AnTone.warn,
              _ => AnTone.danger,
            },
          );
      return;
    }
    _mergeSpeechText(next);
    if (!next.active) {
      if (!next.canRetry) _clearSpeechAnchor();
    }
  }

  void _mergeSpeechText(SpeechInputState next) {
    final before = _speechBefore;
    final after = _speechAfter;
    if (before == null || after == null) return;
    final inserted = next.text;
    final merged = before + inserted + after;
    if (_ctrl.text != merged) {
      _applyingSpeechMerge = true;
      _ctrl.value = TextEditingValue(
        text: merged,
        selection: TextSelection.collapsed(
          offset: before.length + inserted.length,
        ),
      );
      _applyingSpeechMerge = false;
    }
    _speechLastMerged = merged;
  }

  void _clearSpeechAnchor() {
    _speechBefore = null;
    _speechAfter = null;
    _speechLastMerged = null;
  }

  Future<void> _retrySpeechInput() async {
    if (_speechBefore == null || _speechAfter == null) return;
    _focus.requestFocus();
    await ref.read(speechInputProvider.notifier).retry();
  }

  Future<void> _discardSpeechRetry() async {
    final before = _speechBefore;
    final after = _speechAfter;
    if (before != null && after != null) {
      _applyingSpeechMerge = true;
      _ctrl.value = TextEditingValue(
        text: before + after,
        selection: TextSelection.collapsed(offset: before.length),
      );
      _applyingSpeechMerge = false;
    }
    _clearSpeechAnchor();
    await ref.read(speechInputProvider.notifier).discardRetry();
  }

  /// The composer chrome wrapped as the picker's ANCHOR: the portal's follower hangs the panel above
  /// the composer at full composer width. 壳作锚:follower 把面板挂 composer 上方、整 composer 宽。
  Widget _anchored(BuildContext context, Widget composer) {
    return LayoutBuilder(
      builder: (context, constraints) {
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
              // An outside click dismisses the panel (the combobox norm — a floating list must never
              // outlive the user's attention); typing in the field keeps it (the field is inside the
              // group via the target wrapper below). 点外即收(combobox 常规);输入框在组内,打字不收。
              child: TapRegion(
                groupId: _mentionPanelGroup,
                onTapOutside: (_) => _closePicker(),
                child: AnMentionPanel(
                  items: [
                    for (final c in _candidates)
                      AnMentionRowData(
                        kind: c.type,
                        name: c.name,
                        description: c.description,
                      ),
                  ],
                  activeIndex: _activeIndex,
                  onPick: _pick,
                ),
              ),
            ),
          ),
          child: CompositedTransformTarget(
            link: _link,
            child: TapRegion(groupId: _mentionPanelGroup, child: composer),
          ),
        );
      },
    );
  }

  // md tier (28 box / 16 glyph) — the accessory buttons retreat to «inline neighbours» of the 15
  // input (WRK-070 §A#2 用户三档同框样机拍板:28;the old lg tier is 32 box / 20 glyph, whose scale
  // over the 15 body read heavy). md 档(28 盒/16 形):配件钮退成正文的「行内邻居」(样机比选定 28,
  // 旧 lg 档 32 盒/20 形对 15 正文偏重).
  List<Widget> _lead(Translations t) => [
    AnButton.iconOnly(
      AnIcons.mention,
      size: AnButtonSize.md,
      semanticLabel: t.chat.mentionEntity,
      onPressed: _insertMentionTrigger,
    ),
    AnButton.iconOnly(
      AnIcons.attach,
      size: AnButtonSize.md,
      semanticLabel: t.chat.attachFile,
      onPressed: _pickFiles,
    ),
  ];

  /// The send/stop affordance — a FILLED ink circle (primary + round), the modern chat idiom, still
  /// monochrome per the product's no-decorative-hue rule. Same md tier as [_lead] (the single-row
  /// height is child-maxed — a different tier would grow the pill on the first keystroke). The send
  /// circle carries weight through its FILL, not its size (WRK-070 §A#2:28 圆+16 箭头).
  /// send/stop=实心墨圆(primary+round,现代聊天惯例、仍单色);与 lead 同 md 档(单行高取子件 max,异档
  /// 会首键撑高药丸);发送重量靠主色填充、不靠个头。
  Widget _trailingButton({
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) => AnButton.iconOnly(
    icon,
    key: key,
    variant: AnButtonVariant.primary,
    round: true,
    size: AnButtonSize.md,
    semanticLabel: label,
    onPressed: onPressed,
  );

  /// The pending strip for [AnComposer.attachments] — null when empty (presence flips pill→card).
  /// 待发条(空=null,有即触发形变)。
  Widget? _attachmentStrip(
    BuildContext context,
    Translations t,
    List<PendingAttachment> pending,
  ) {
    if (pending.isEmpty) return null;
    return Wrap(
      spacing: AnSpace.s6,
      runSpacing: AnSpace.s6,
      children: [
        for (final a in pending)
          // A pending IMAGE with bytes in hand shows a real thumbnail tile (memory-decoded, ✕ on the
          // corner); everything else is the filename chip. 有字节的图=真缩略瓦片(角上 ✕);其余=文件名 chip。
          if (a.isImage && a.bytes != null && a.status != 'failed')
            // The remove affordance is the primitive's own slot (批5 A-035 — the hand-rolled Stack
            // retires). 移除示能=原语自有槽(手搓 Stack 退役)。
            AnAttachmentThumb(
              key: ValueKey(a.localId),
              // ResizeImage caps the DECODE at the thumb's widest display (280 logical × dpr) —
              // a full-res pending photo would otherwise park tens of MB in the ImageCache for a
              // tile-sized slot; allowUpscaling stays false (its default). 解码封顶缩略最宽档,
              // 全分辨率待发照否则为一个瓦片位吃掉数十 MB;默认不放大。
              image: ResizeImage(
                MemoryImage(Uint8List.fromList(a.bytes!)),
                width:
                    (AnSize.thumbMaxW * MediaQuery.devicePixelRatioOf(context))
                        .round(),
              ),
              filename: a.filename,
              onRemove: () => _att.remove(a.localId),
              removeLabel: t.attach.remove,
            )
          else
            AnAttachmentChip(
              key: ValueKey(a.localId),
              kind: a.isImage ? 'image' : 'other',
              filename: a.filename,
              meta: switch (a.status) {
                'uploading' => t.attach.uploading,
                // Unreadable-at-intake failures kept no bytes — they are NOT retryable; only upload
                // failures (bytes in hand) offer the tap-to-retry. 入口不可读的失败无字节、不可重试;
                // 仅上传失败(字节在手)给「点按重试」。
                'failed' =>
                  a.bytes != null
                      ? t.attach.failedRetry
                      : t.attach.failedUnreadable,
                _ => attachmentMetaLine(
                  filename: a.filename,
                  mimeType: a.mimeType,
                  sizeBytes: a.sizeBytes,
                ),
              },
              uploading: a.status == 'uploading',
              failed: a.status == 'failed',
              onRetry: a.bytes != null ? () => _att.retry(a.localId) : null,
              onRemove: () => _att.remove(a.localId),
              removeLabel: t.feedback.dismiss,
            ),
      ],
    );
  }

  Widget? _composerStrip(
    BuildContext context,
    Translations t,
    List<PendingAttachment> pending,
    SpeechInputState speech,
  ) {
    final attachments = _attachmentStrip(context, t, pending);
    final voice = speech.active
        ? AnVoiceMeter(
            label: speech.finishing
                ? t.chat.voiceFinalizing
                : t.chat.voiceRecording,
            duration: speech.elapsed,
            level: speech.level,
            active: speech.recording,
            finalizing: speech.finishing,
          )
        : null;
    final retry =
        !speech.active &&
            speech.canRetry &&
            _speechBefore != null &&
            _speechAfter != null
        ? _speechRetryCard(context, t)
        : null;
    final parts = [?attachments, ?voice, ?retry];
    if (parts.isEmpty) return null;
    if (parts.length == 1) return parts.single;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0) const SizedBox(height: AnSpace.s8),
          parts[i],
        ],
      ],
    );
  }

  Widget _speechRetryCard(BuildContext context, Translations t) {
    final c = context.colors;
    return AnInfoCard(
      key: const ValueKey('voice-retry-card'),
      title: t.chat.voiceRetryTitle,
      icon: AnIcons.microphone,
      actions: [
        AnButton(
          label: t.chat.voiceRetryAction,
          icon: AnIcons.refresh,
          onPressed: _retrySpeechInput,
        ),
        AnButton(
          label: t.chat.voiceDiscardAction,
          icon: AnIcons.trash,
          variant: AnButtonVariant.danger,
          outline: true,
          onPressed: _discardSpeechRetry,
        ),
      ],
      child: Text(
        t.chat.voiceRetryBody,
        style: AnText.body.copyWith(color: c.inkMuted),
      ),
    );
  }

  /// Wrap the composer so Cmd+V / context-menu Paste triages the clipboard BEFORE the default text
  /// paste (Action.overridable — EditableText registers its paste as overridable; [callingAction] is
  /// that default). 拦粘贴:文件→位图→放行默认文本(Action.overridable 机制)。
  Widget _pasteInterceptor(Widget child) => Actions(
    actions: {PasteTextIntent: _ComposerPasteAction(this)},
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    ref.listen<SpeechInputState>(speechInputProvider, _applySpeechInput);
    final id = widget.conversationId;
    final pending = ref.watch(pendingAttachmentsProvider(_draftKey));
    final speech = ref.watch(speechInputProvider);
    final strip = _composerStrip(context, t, pending, speech);
    final speechAvailable = ref.watch(speechInputAvailableProvider);
    final uploading = pending.any((a) => a.status == 'uploading');
    final ready = pending.any((a) => a.status == 'ready');
    final canVoice = speechAvailable && !_hasText && !ready && !uploading;
    final voiceTrailing = speech.active
        ? _trailingButton(
            key: const ValueKey('voice-stop'),
            icon: AnIcons.stop,
            label: t.chat.stopVoiceInput,
            onPressed: _finishSpeechInput,
          )
        : canVoice
        ? _trailingButton(
            key: const ValueKey('voice'),
            icon: AnIcons.microphone,
            label: t.chat.voiceInput,
            onPressed: _startSpeechInput,
          )
        : null;
    if (id == null) {
      return _anchored(
        context,
        _pasteInterceptor(
          AnComposer(
            controller: _ctrl,
            focusNode: _focus,
            placeholder: t.chat.placeholder,
            floating: widget._floating,
            lead: _lead(t),
            attachments: strip,
            trailing: speech.active
                ? voiceTrailing
                : (_hasText || ready) && !uploading && !_submittingNew
                ? _trailingButton(
                    key: const ValueKey('send'),
                    icon: AnIcons.send,
                    label: t.chat.send,
                    onPressed: _send,
                  )
                : voiceTrailing,
          ),
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
            ? _trailingButton(
                key: const ValueKey('stop'),
                icon: AnIcons.stop,
                label: t.chat.stop,
                onPressed: () => ctl.cancelTurn(),
              )
            : speech.active
            ? voiceTrailing
            : (_hasText || ready) && !uploading
            ? _trailingButton(
                key: const ValueKey('send'),
                icon: AnIcons.send,
                label: t.chat.send,
                onPressed: _send,
              )
            : voiceTrailing;
        return _anchored(
          context,
          _pasteInterceptor(
            AnComposer(
              controller: _ctrl,
              focusNode: _focus,
              placeholder: t.chat.placeholder,
              lead: _lead(t),
              attachments: strip,
              trailing: trailing,
            ),
          ),
        );
      },
    );
  }
}

/// The overridable-paste hook: EditableText registers its paste action as [Action.overridable], so an
/// ancestor [Actions] map with this action intercepts Cmd+V AND the context-menu Paste; [callingAction]
/// is the default text paste we fall through to. 覆盖式粘贴钩:祖先 Actions 注册即拦 Cmd+V 与右键粘贴;
/// callingAction=默认文本粘贴(回落)。
class _ComposerPasteAction extends Action<PasteTextIntent> {
  _ComposerPasteAction(this._host);

  final _ChatComposerState _host;

  @override
  Object? invoke(PasteTextIntent intent) {
    final def = callingAction;
    _host._pasteIntake(() => def?.invoke(intent));
    return null;
  }
}
