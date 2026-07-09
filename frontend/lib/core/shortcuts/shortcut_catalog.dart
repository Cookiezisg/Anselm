import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The GLOBAL command registry (WRK-062 S6): the single source of truth for every app-level
/// keyboard command. The app-shell and the app root BUILD their `CallbackShortcuts` from this table
/// (not scattered inline `SingleActivator`s) so the shortcuts panel can display every binding, the
/// «catalog == bound» gate holds, and a rebind is one map edit. Per-widget shortcuts (editor Tab,
/// popover Esc, tab-strip arrows) are LOCAL behaviour and deliberately NOT here — they aren't
/// user-rebindable global commands.
///
/// 全局命令注册表(S6):所有 app 级键盘命令的唯一事实源。壳与根据此表**生成** CallbackShortcuts(非散落
/// 内联),使快捷键面板能列全、「catalog==已绑」门成立、改绑=一次 map 编辑。逐 widget 快捷键(编辑器 Tab/
/// 浮层 Esc/tab 箭头)是局部行为、故意不在此——它们不是用户可改绑的全局命令。
enum ShortcutCommand {
  toggleLeftIsland,
  toggleRightIsland,
  openSettings,
  zoomIn,
  zoomOut,
  zoomReset,
}

/// A platform-normalized chord. `cmd` is the primary accelerator — ⌘ on macOS, Ctrl elsewhere — so
/// one declaration binds correctly on every desktop. 平台归一的组合键;cmd=主加速键(mac ⌘/其余 Ctrl)。
class ShortcutChord {
  const ShortcutChord(this.key, {this.cmd = false, this.shift = false, this.alt = false});

  final LogicalKeyboardKey key;
  final bool cmd;
  final bool shift;
  final bool alt;

  static bool get _isMac => Platform.isMacOS;

  /// Build the [SingleActivator] to register — cmd maps to meta on macOS, control elsewhere.
  /// 构造要注册的 SingleActivator;cmd 在 mac→meta、其余→control。
  SingleActivator toActivator() => SingleActivator(
        key,
        meta: cmd && _isMac,
        control: cmd && !_isMac,
        shift: shift,
        alt: alt,
      );

  /// Stable serialization (uses the key's numeric id, never the label). 稳定序列化(用数字 id)。
  String serialize() => [
        if (cmd) 'cmd',
        if (shift) 'shift',
        if (alt) 'alt',
        '${key.keyId}',
      ].join('+');

  static ShortcutChord? parse(String s) {
    final parts = s.split('+');
    if (parts.isEmpty) return null;
    final id = int.tryParse(parts.last);
    if (id == null) return null;
    return ShortcutChord(
      LogicalKeyboardKey(id),
      cmd: parts.contains('cmd'),
      shift: parts.contains('shift'),
      alt: parts.contains('alt'),
    );
  }

  /// The human-readable chord (⌘⇧B / Ctrl+Shift+B). 人读组合键。
  String get display {
    final mod = _isMac
        ? [if (cmd) '⌘', if (alt) '⌥', if (shift) '⇧'].join()
        : [if (cmd) 'Ctrl', if (alt) 'Alt', if (shift) 'Shift'].join('+');
    final label = _keyLabel(key);
    if (mod.isEmpty) return label;
    return _isMac ? '$mod$label' : '$mod+$label';
  }

  static String _keyLabel(LogicalKeyboardKey key) => switch (key) {
        LogicalKeyboardKey.comma => ',',
        LogicalKeyboardKey.backslash => '\\',
        LogicalKeyboardKey.equal => '=',
        LogicalKeyboardKey.minus => '−',
        LogicalKeyboardKey.digit0 => '0',
        _ => key.keyLabel.isNotEmpty ? key.keyLabel.toUpperCase() : key.debugName ?? '?',
      };

  @override
  bool operator ==(Object other) =>
      other is ShortcutChord &&
      other.key == key &&
      other.cmd == cmd &&
      other.shift == shift &&
      other.alt == alt;

  @override
  int get hashCode => Object.hash(key, cmd, shift, alt);
}

/// The default binding for every command — the ONE place a chord is declared. 每命令默认绑定。
const Map<ShortcutCommand, ShortcutChord> kShortcutDefaults = {
  ShortcutCommand.toggleLeftIsland: ShortcutChord(LogicalKeyboardKey.keyB, cmd: true),
  ShortcutCommand.toggleRightIsland: ShortcutChord(LogicalKeyboardKey.backslash, cmd: true),
  ShortcutCommand.openSettings: ShortcutChord(LogicalKeyboardKey.comma, cmd: true),
  ShortcutCommand.zoomIn: ShortcutChord(LogicalKeyboardKey.equal, cmd: true),
  ShortcutCommand.zoomOut: ShortcutChord(LogicalKeyboardKey.minus, cmd: true),
  ShortcutCommand.zoomReset: ShortcutChord(LogicalKeyboardKey.digit0, cmd: true),
};
