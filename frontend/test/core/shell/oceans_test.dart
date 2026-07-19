import 'package:anselm/core/settings/settings_prefs.dart';
import 'package:anselm/core/shell/oceans.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// B8 (issue #8): the app boots on the CHAT landing (its initial page), then REMEMBERS the last-opened
// ocean across launches (persisted via shared_preferences, mirroring shellChrome). Restore only sets the
// ocean; a manual switch that lands before the async restore must win (never clobber user interaction).

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('fresh launch (no persisted ocean) lands on chat — the initial page', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(selectedOceanProvider), OceanKind.chat);
    await pumpEventQueue();
    expect(c.read(selectedOceanProvider), OceanKind.chat); // restore of an empty pref is a no-op
  });

  test('restore reads the persisted last ocean (entities) SYNCHRONOUSLY at build', () {
    final c = ProviderContainer(overrides: [
      settingsPrefsProvider.overrideWithValue(SettingsPrefs.inMemory({'an.ocean': 'entities'})),
    ]);
    addTearDown(c.dispose);
    expect(c.read(selectedOceanProvider), OceanKind.entities);
  });

  test('select persists the chosen ocean (becomes the next launch default)', () {
    final prefs = SettingsPrefs.inMemory();
    final c = ProviderContainer(overrides: [settingsPrefsProvider.overrideWithValue(prefs)]);
    addTearDown(c.dispose);
    c.read(selectedOceanProvider.notifier).select(OceanKind.documents);
    expect(c.read(selectedOceanProvider), OceanKind.documents);
    expect(prefs.getString(SettingsKeys.ocean), 'documents');
  });

  test('restore is synchronous — a manual switch can never race it', () {
    final c = ProviderContainer(overrides: [
      settingsPrefsProvider.overrideWithValue(SettingsPrefs.inMemory({'an.ocean': 'entities'})),
    ]);
    addTearDown(c.dispose);
    expect(c.read(selectedOceanProvider), OceanKind.entities); // restored at build 建时即恢复
    c.read(selectedOceanProvider.notifier).select(OceanKind.documents);
    expect(c.read(selectedOceanProvider), OceanKind.documents, reason: 'manual interaction sticks');
  });

  test('a stale / unknown persisted enum name is ignored (stays on the chat default)', () async {
    SharedPreferences.setMockInitialValues({'fy.ocean': 'a_removed_ocean'});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(selectedOceanProvider);
    await pumpEventQueue();
    expect(c.read(selectedOceanProvider), OceanKind.chat);
  });

  test('selecting the ocean already active is a no-op (no redundant persist churn)', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(selectedOceanProvider.notifier).select(OceanKind.chat); // already chat
    await pumpEventQueue();
    // no write happened — the pref stays absent (select short-circuits when kind == state)
    expect((await SharedPreferences.getInstance()).getString('fy.ocean'), isNull);
  });
}
