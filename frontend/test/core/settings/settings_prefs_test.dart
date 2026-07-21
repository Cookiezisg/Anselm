import 'package:anselm/core/settings/settings_prefs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// The central prefs service (WRK-062 S-13): typed roundtrip over declared keys, the one-shot fy.*
// migration, declared-set-only resetAll (foreign keys survive), and the declaration invariants the
// catalog gate builds on. 中央偏好服务电池:类型化往返/一次性 fy.* 迁移/声明集 resetAll(外键存活)/声明表不变量。

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('typed roundtrip 类型化往返', () {
    test('reads fall back to the declared default; writes stick', () {
      final p = SettingsPrefs.inMemory();
      expect(p.getString(SettingsKeys.theme), 'light');
      expect(p.getBool(SettingsKeys.notifyOs), isTrue);
      expect(p.getDouble(SettingsKeys.windowZoom), 1.0);
      p.setString(SettingsKeys.theme, 'dark');
      p.setBool(SettingsKeys.notifyOs, false);
      p.setDouble(SettingsKeys.windowZoom, 1.25);
      expect(p.getString(SettingsKeys.theme), 'dark');
      expect(p.getBool(SettingsKeys.notifyOs), isFalse);
      expect(p.getDouble(SettingsKeys.windowZoom), 1.25);
      p.remove(SettingsKeys.theme);
      expect(
        p.getString(SettingsKeys.theme),
        'light',
        reason: 'remove → default 清除回默认',
      );
    });

    test('declared prefix family roundtrip + undeclared family asserts', () {
      final p = SettingsPrefs.inMemory();
      expect(p.getFamilyBool('an.right.collapsed.', 'chat', def: true), isTrue);
      p.setFamilyBool('an.right.collapsed.', 'chat', false);
      expect(
        p.getFamilyBool('an.right.collapsed.', 'chat', def: true),
        isFalse,
      );
      expect(
        () => p.getFamilyBool('an.rogue.', 'x', def: false),
        throwsA(isA<AssertionError>()),
        reason: 'undeclared family is a programming error 未声明族=编程错误',
      );
    });
  });

  group('fy.* migration 一次性迁移', () {
    test('legacy keys copy to an.* and the old names are deleted', () async {
      SharedPreferences.setMockInitialValues({
        'fy.side.collapsed': true,
        'fy.side.w': 400.0,
        'fy.ocean': 'documents',
        'fy.stage.follow': 'never',
      });
      final p = await SettingsPrefs.load();
      expect(p.getBool(SettingsKeys.sideCollapsed), isTrue);
      expect(p.getDouble(SettingsKeys.sideWidth), 400.0);
      expect(p.getString(SettingsKeys.ocean), 'documents');
      expect(p.getString(SettingsKeys.chatAutoStage), 'never');
      final sp = await SharedPreferences.getInstance();
      expect(
        sp.containsKey('fy.side.collapsed'),
        isFalse,
        reason: 'old name deleted 旧名已删',
      );
      expect(sp.containsKey('fy.ocean'), isFalse);
    });

    test('an existing an.* value wins over the legacy one', () async {
      SharedPreferences.setMockInitialValues({
        'fy.ocean': 'documents',
        'an.ocean': 'entities',
      });
      final p = await SettingsPrefs.load();
      expect(p.getString(SettingsKeys.ocean), 'entities', reason: '新名已写则旧值不覆盖');
    });
  });

  group('resetAll 重置本地偏好', () {
    test(
      'clears every declared key + family members, leaves foreign keys alone',
      () async {
        SharedPreferences.setMockInitialValues({
          'an.theme': 'dark',
          'an.side.w': 480.0,
          'an.right.collapsed.chat': false,
          'someone.elses.key': 'precious',
        });
        final p = await SettingsPrefs.load();
        await p.resetAll();
        expect(p.getString(SettingsKeys.theme), 'light');
        expect(p.getDouble(SettingsKeys.sideWidth), 320);
        final sp = await SharedPreferences.getInstance();
        expect(
          sp.containsKey('an.right.collapsed.chat'),
          isFalse,
          reason: '声明族成员清除',
        );
        expect(
          sp.getString('someone.elses.key'),
          'precious',
          reason: 'NEVER a prefix wildcard — foreign keys survive 绝不通配,外键存活',
        );
      },
    );
  });

  group('declaration invariants 声明表不变量', () {
    test(
      'key names are unique, an.*-prefixed, and every all-member is declared once',
      () {
        final names = SettingsKeys.all.map((k) => k.key).toList();
        expect(
          names.toSet().length,
          names.length,
          reason: 'no duplicate keys 无重复键',
        );
        for (final n in names) {
          expect(n.startsWith('an.'), isTrue, reason: '$n must be an.* 统一前缀');
        }
        for (final f in SettingsKeys.families) {
          expect(f.startsWith('an.'), isTrue);
          expect(f.endsWith('.'), isTrue, reason: 'family is a prefix 族名以点结尾');
        }
      },
    );
  });
}
