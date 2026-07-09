import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/shortcuts/shortcut_bindings.dart';
import '../../../../core/shortcuts/shortcut_catalog.dart';
import '../../../../core/ui/ui.dart';
import '../../../../i18n/strings.g.dart';

/// ⑫ 快捷键 (WRK-062 §3, S6, 拍板 #4): every global command from the catalog, each row showing its
/// current keycap + a rebind affordance (capture the next chord; a modifier is required; a conflict
/// with another command is refused with an inline reason) + reset. Bindings live in
/// [shortcutBindingsProvider] and take effect live (the app-shell rebuilds its CallbackShortcuts).
///
/// 快捷键面板:目录里每个全局命令一行(当前键帽+改绑[录下一组合键;须带修饰键;与别命令冲突则拒并说明]+
/// 恢复默认)。绑定即时生效(壳重建 CallbackShortcuts)。
class ShortcutsPanel extends ConsumerWidget {
  const ShortcutsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Translations.of(context);
    final bindings = ref.watch(shortcutBindingsProvider);

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const AnScopeBadge(AnSettingScope.machine),
        const Spacer(),
        AnButton(
          label: t.settings.shortcuts.resetAll,
          size: AnButtonSize.sm,
          onPressed: () => ref.read(shortcutBindingsProvider.notifier).resetAll(),
        ),
      ]),
      const SizedBox(height: AnSpace.s16),
      for (final cmd in ShortcutCommand.values)
        _ShortcutRow(command: cmd, chord: bindings[cmd]!),
    ]);
  }
}

String commandLabel(Translations t, ShortcutCommand cmd) => switch (cmd) {
      ShortcutCommand.toggleLeftIsland => t.settings.shortcuts.cmdToggleLeft,
      ShortcutCommand.toggleRightIsland => t.settings.shortcuts.cmdToggleRight,
      ShortcutCommand.openSettings => t.settings.shortcuts.cmdOpenSettings,
      ShortcutCommand.zoomIn => t.settings.shortcuts.cmdZoomIn,
      ShortcutCommand.zoomOut => t.settings.shortcuts.cmdZoomOut,
      ShortcutCommand.zoomReset => t.settings.shortcuts.cmdZoomReset,
    };

class _ShortcutRow extends ConsumerStatefulWidget {
  const _ShortcutRow({required this.command, required this.chord});

  final ShortcutCommand command;
  final ShortcutChord chord;

  @override
  ConsumerState<_ShortcutRow> createState() => _ShortcutRowState();
}

class _ShortcutRowState extends ConsumerState<_ShortcutRow> {
  final FocusNode _focus = FocusNode();
  bool _recording = false;
  String? _hint;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _startRecording() {
    setState(() {
      _recording = true;
      _hint = null;
    });
    _focus.requestFocus();
  }

  void _stop() {
    setState(() {
      _recording = false;
      _hint = null;
    });
    // Release focus so global chords (⌘B/⌘\/…) reach the shell again — otherwise this row keeps
    // eating every keypress. 交还焦点,否则本行会持续吞掉全局快捷键。
    _focus.unfocus();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    // Only intercept while actively capturing — never swallow the user's normal keystrokes.
    // 仅录制中拦截,绝不吞掉用户日常按键。
    if (!_recording) return KeyEventResult.ignored;
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final t = Translations.of(context);
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _stop();
      return KeyEventResult.handled;
    }
    // Ignore lone modifier presses — wait for a real key. 单独修饰键不成绑,等真键。
    if (_isModifier(key)) return KeyEventResult.handled;

    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final cmd = pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight) ||
        pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight);
    final shift = pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight);
    final alt = pressed.contains(LogicalKeyboardKey.altLeft) ||
        pressed.contains(LogicalKeyboardKey.altRight);
    if (!cmd) {
      setState(() => _hint = t.settings.shortcuts.hintModifier);
      return KeyEventResult.handled;
    }
    final chord = ShortcutChord(key, cmd: true, shift: shift, alt: alt);
    final conflict = ref
        .read(shortcutBindingsProvider.notifier)
        .conflictFor(chord, self: widget.command);
    if (conflict != null) {
      setState(() => _hint = t.settings.shortcuts.conflict(cmd: commandLabel(t, conflict)));
      return KeyEventResult.handled;
    }
    ref.read(shortcutBindingsProvider.notifier).rebind(widget.command, chord);
    _stop();
    return KeyEventResult.handled;
  }

  static bool _isModifier(LogicalKeyboardKey k) =>
      k == LogicalKeyboardKey.metaLeft ||
      k == LogicalKeyboardKey.metaRight ||
      k == LogicalKeyboardKey.controlLeft ||
      k == LogicalKeyboardKey.controlRight ||
      k == LogicalKeyboardKey.shiftLeft ||
      k == LogicalKeyboardKey.shiftRight ||
      k == LogicalKeyboardKey.altLeft ||
      k == LogicalKeyboardKey.altRight;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    final isDefault = widget.chord == kShortcutDefaults[widget.command];

    return AnSettingRow(
      label: commandLabel(t, widget.command),
      desc: _hint,
      modified: !isDefault,
      onReset: () => ref.read(shortcutBindingsProvider.notifier).reset(widget.command),
      resetLabel: t.settings.shortcuts.reset,
      child: Focus(
        focusNode: _focus,
        onKeyEvent: _onKey,
        onFocusChange: (has) {
          if (!has && _recording) _stop();
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _startRecording,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: AnSpace.s12, vertical: AnSpace.s6),
            decoration: BoxDecoration(
              color: _recording ? c.accentSoft : c.surfaceHover,
              borderRadius: BorderRadius.circular(AnRadius.button),
              border: Border.all(
                  color: _hint != null
                      ? c.danger
                      : _recording
                          ? c.accent
                          : c.line),
            ),
            child: Text(
              _recording ? t.settings.shortcuts.recording : widget.chord.display,
              style: AnText.mono.copyWith(
                  color: _recording ? c.accent : c.ink),
            ),
          ),
        ),
      ),
    );
  }
}
