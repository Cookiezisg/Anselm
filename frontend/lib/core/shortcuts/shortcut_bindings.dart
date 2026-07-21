import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../settings/settings_prefs.dart';
import 'shortcut_catalog.dart';

/// The EFFECTIVE global-shortcut bindings (WRK-062 S6): the default table with per-command user
/// overrides layered on (persisted as one JSON map under `an.shortcuts`). The app-shell / app root
/// watch this to (re)build their CallbackShortcuts, so a rebind takes effect live — no restart. A
/// rebind conflict check lives here too (a chord already bound to another command).
///
/// 生效的全局快捷键绑定(S6):默认表叠加用户逐命令覆写(单 JSON map 存 an.shortcuts)。壳/根 watch 它
/// 重建 CallbackShortcuts,改绑即时生效;冲突检测(某组合键已绑别的命令)亦在此。
class ShortcutBindings extends Notifier<Map<ShortcutCommand, ShortcutChord>> {
  @override
  Map<ShortcutCommand, ShortcutChord> build() {
    final raw = ref
        .watch(settingsPrefsProvider)
        .getString(SettingsKeys.shortcuts);
    final overrides = <ShortcutCommand, ShortcutChord>{};
    if (raw.isNotEmpty) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        for (final e in map.entries) {
          final cmd = ShortcutCommand.values.asNameMap()[e.key];
          final chord = ShortcutChord.parse(e.value as String);
          if (cmd != null && chord != null) overrides[cmd] = chord;
        }
      } catch (_) {
        /* malformed → defaults 坏值回默认 */
      }
    }
    return {
      for (final cmd in ShortcutCommand.values)
        cmd: overrides[cmd] ?? kShortcutDefaults[cmd]!,
    };
  }

  /// The command currently bound to [chord], excluding [self] — a rebind conflict. null = free.
  /// 当前绑到该组合键的命令(排除自身)=冲突;null=空闲。
  ShortcutCommand? conflictFor(ShortcutChord chord, {ShortcutCommand? self}) {
    for (final e in state.entries) {
      if (e.key != self && e.value == chord) return e.key;
    }
    return null;
  }

  /// Rebind [cmd] to [chord] and persist. Persists ONLY the non-default overrides (so a reset-all of
  /// declared keys cleanly restores defaults). 改绑并持久化;只存非默认覆写。
  Future<void> rebind(ShortcutCommand cmd, ShortcutChord chord) async {
    final next = {...state, cmd: chord};
    await _persist(next);
    state = next;
  }

  /// Restore one command to its default. 单命令回默认。
  Future<void> reset(ShortcutCommand cmd) async {
    final next = {...state, cmd: kShortcutDefaults[cmd]!};
    await _persist(next);
    state = next;
  }

  /// Restore every command. 全部回默认。
  Future<void> resetAll() async {
    ref.read(settingsPrefsProvider).setString(SettingsKeys.shortcuts, '');
    state = {
      for (final cmd in ShortcutCommand.values) cmd: kShortcutDefaults[cmd]!,
    };
  }

  Future<void> _persist(Map<ShortcutCommand, ShortcutChord> bindings) async {
    final overrides = <String, String>{
      for (final e in bindings.entries)
        if (e.value != kShortcutDefaults[e.key])
          e.key.name: e.value.serialize(),
    };
    ref
        .read(settingsPrefsProvider)
        .setString(
          SettingsKeys.shortcuts,
          overrides.isEmpty ? '' : jsonEncode(overrides),
        );
  }
}

final shortcutBindingsProvider =
    NotifierProvider<ShortcutBindings, Map<ShortcutCommand, ShortcutChord>>(
      ShortcutBindings.new,
    );
