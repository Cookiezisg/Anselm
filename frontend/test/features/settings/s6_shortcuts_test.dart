import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/settings/settings_prefs.dart';
import 'package:anselm/core/shortcuts/shortcut_bindings.dart';
import 'package:anselm/core/shortcuts/shortcut_catalog.dart';
import 'package:anselm/features/settings/ui/panels/shortcuts_panel.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// S6 panel: every command renders its keycap; a captured chord rebinds live; a chord already bound
// elsewhere is refused. S6 面板:每命令渲键帽;录入组合键即改绑;已占用组合键被拒。
void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  Widget host(SettingsPrefs prefs) => ProviderScope(
        overrides: [settingsPrefsProvider.overrideWithValue(prefs)],
        child: TranslationProvider(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AnTheme.light(),
            home: const Scaffold(body: SingleChildScrollView(child: ShortcutsPanel())),
          ),
        ),
      );

  testWidgets('every command renders with its current keycap', (tester) async {
    await tester.pumpWidget(host(SettingsPrefs.inMemory()));
    await tester.pumpAndSettle();
    final t = Translations.of(tester.element(find.byType(ShortcutsPanel)));
    for (final cmd in ShortcutCommand.values) {
      expect(find.text(commandLabel(t, cmd)), findsOneWidget, reason: '命令 $cmd 一行');
    }
    // The resting face is PER-KEY caps (0719 紧凑档): every command shows a ⌘ cap plus its key
    // fragment — no single whole-chord text anymore. 静息=逐键帽:每命令一枚 ⌘ 帽+键片段帽。
    expect(find.text('⌘'), findsNWidgets(ShortcutCommand.values.length));
    expect(find.text(','), findsOneWidget, reason: '⌘, (打开设置) 的键片段帽');
    expect(find.text(kShortcutDefaults[ShortcutCommand.openSettings]!.display), findsNothing,
        reason: '整弦文本不再渲——拆成逐键帽');
  });

  testWidgets('capturing a fresh chord rebinds the command live', (tester) async {
    final prefs = SettingsPrefs.inMemory();
    await tester.pumpWidget(host(prefs));
    await tester.pumpAndSettle();
    final el = tester.element(find.byType(ShortcutsPanel));
    final container = ProviderScope.containerOf(el, listen: false);
    final t = Translations.of(el);

    // Tap the toggle-left keycap to record. 点左岛键帽录入。
    await tester.tap(find.text(commandLabel(t, ShortcutCommand.toggleLeftIsland)));
    await tester.pump();
    // Click the keycap container itself (last mono text = its chord). Use the recording affordance.
    final cap = find.descendant(
        of: find.ancestor(
            of: find.text(commandLabel(t, ShortcutCommand.toggleLeftIsland)),
            matching: find.byType(Row)),
        matching: find.byType(GestureDetector));
    await tester.tap(cap.first);
    await tester.pump();

    // Send ⌘ + J. 发 ⌘J。
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyJ);
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyJ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();

    final bound = container.read(shortcutBindingsProvider)[ShortcutCommand.toggleLeftIsland]!;
    expect(bound.key, LogicalKeyboardKey.keyJ, reason: '录入即改绑');
    expect(bound.cmd, isTrue);
  });

  // Regression (real-machine caught): once a capture completes the row must RELEASE the keyboard —
  // otherwise it keeps swallowing every chord (silently re-recording the command and starving the
  // shell's global shortcuts). 回归:一次录制完成后本行必须交还键盘,否则会持续吞掉后续组合键。
  testWidgets('after a capture completes the row stops intercepting (stray chords do not rebind)',
      (tester) async {
    final prefs = SettingsPrefs.inMemory();
    await tester.pumpWidget(host(prefs));
    await tester.pumpAndSettle();
    final el = tester.element(find.byType(ShortcutsPanel));
    final container = ProviderScope.containerOf(el, listen: false);
    final t = Translations.of(el);

    final cap = find.descendant(
        of: find.ancestor(
            of: find.text(commandLabel(t, ShortcutCommand.toggleLeftIsland)),
            matching: find.byType(Row)),
        matching: find.byType(GestureDetector));
    await tester.tap(cap.first);
    await tester.pump();
    // Complete a capture with ⌘J. 用 ⌘J 完成一次录制。
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyJ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyJ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();
    expect(container.read(shortcutBindingsProvider)[ShortcutCommand.toggleLeftIsland]!.key,
        LogicalKeyboardKey.keyJ);

    // Now press a DIFFERENT chord ⌘K WITHOUT re-entering recording. The row must no longer be
    // listening, so the binding stays ⌘J (pre-fix it silently re-recorded to ⌘K). 杂散 ⌘K 不得改绑。
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();

    expect(container.read(shortcutBindingsProvider)[ShortcutCommand.toggleLeftIsland]!.key,
        LogicalKeyboardKey.keyJ, reason: '录制结束后杂散按键不得再被本行捕获');
  });
}
