import 'dart:convert';

import 'package:anselm/core/settings/settings_prefs.dart';
import 'package:anselm/core/shortcuts/shortcut_bindings.dart';
import 'package:anselm/core/shortcuts/shortcut_catalog.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// S6 shortcut engine: catalog == every bound command, chord round-trips, rebind persists only
// overrides, conflict detection, reset. S6:目录==全绑命令/序列化往返/只存覆写/冲突/重置。
void main() {
  ProviderContainer container(SettingsPrefs prefs) {
    final c = ProviderContainer(
      overrides: [settingsPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(c.dispose);
    return c;
  }

  test(
    'the GATE: every catalog command has a default and an effective binding',
    () {
      final c = container(SettingsPrefs.inMemory());
      final bindings = c.read(shortcutBindingsProvider);
      expect(
        bindings.keys.toSet(),
        ShortcutCommand.values.toSet(),
        reason: 'catalog == bound',
      );
      for (final cmd in ShortcutCommand.values) {
        expect(kShortcutDefaults[cmd], isNotNull, reason: '每命令有默认 $cmd');
        expect(bindings[cmd], isNotNull);
      }
    },
  );

  test('chord serialize/parse round-trips (stable key-id encoding)', () {
    const chord = ShortcutChord(
      LogicalKeyboardKey.keyK,
      cmd: true,
      shift: true,
    );
    final back = ShortcutChord.parse(chord.serialize());
    expect(back, chord);
    expect(ShortcutChord.parse('garbage'), isNull);
  });

  test(
    'rebind persists ONLY overrides; a reset clears its key from storage',
    () async {
      final prefs = SettingsPrefs.inMemory();
      final c = container(prefs);
      c.read(shortcutBindingsProvider);
      await c
          .read(shortcutBindingsProvider.notifier)
          .rebind(
            ShortcutCommand.openSettings,
            const ShortcutChord(LogicalKeyboardKey.keyP, cmd: true),
          );

      final raw = prefs.getString(SettingsKeys.shortcuts);
      final map = jsonDecode(raw) as Map<String, dynamic>;
      expect(map.keys, ['openSettings'], reason: '只存被改的那一条');
      expect(
        c.read(shortcutBindingsProvider)[ShortcutCommand.openSettings]!.key,
        LogicalKeyboardKey.keyP,
      );

      await c
          .read(shortcutBindingsProvider.notifier)
          .reset(ShortcutCommand.openSettings);
      expect(prefs.getString(SettingsKeys.shortcuts), '', reason: '回默认后无覆写残留');
      expect(
        c.read(shortcutBindingsProvider)[ShortcutCommand.openSettings],
        kShortcutDefaults[ShortcutCommand.openSettings],
      );
    },
  );

  test('conflictFor detects a chord already bound to another command', () {
    final c = container(SettingsPrefs.inMemory());
    c.read(shortcutBindingsProvider);
    final notifier = c.read(shortcutBindingsProvider.notifier);
    final settingsChord = kShortcutDefaults[ShortcutCommand.openSettings]!;
    expect(
      notifier.conflictFor(settingsChord, self: ShortcutCommand.zoomIn),
      ShortcutCommand.openSettings,
    );
    expect(
      notifier.conflictFor(settingsChord, self: ShortcutCommand.openSettings),
      isNull,
    );
    expect(
      notifier.conflictFor(
        const ShortcutChord(LogicalKeyboardKey.keyJ, cmd: true, shift: true),
      ),
      isNull,
    );
  });

  test('malformed persisted json degrades to defaults', () {
    final prefs = SettingsPrefs.inMemory({'an.shortcuts': 'not json'});
    final c = container(prefs);
    final bindings = c.read(shortcutBindingsProvider);
    expect(
      bindings[ShortcutCommand.toggleLeftIsland],
      kShortcutDefaults[ShortcutCommand.toggleLeftIsland],
    );
  });
}
