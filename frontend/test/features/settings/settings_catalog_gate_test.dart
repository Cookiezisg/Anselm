import 'package:anselm/core/settings/settings_prefs.dart';
import 'package:anselm/features/settings/model/settings_catalog.dart';
import 'package:anselm/features/settings/ui/settings_rail.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter_test/flutter_test.dart';

// THE three-equal gate (WRK-062 §1) — the settings surface's exhaustiveness is a CI invariant, not
// a hope: ① every panel enum value has exactly one catalog entry (and directory order is total);
// ② every declared preference key is owned by exactly one panel OR registered implicit — and
// nothing else; ③ the rail model renders exactly the catalog (same ids, same count). A new panel
// or key that skips registration fails HERE, not in a user's hands.
// 三相等门禁:①每个面板枚举恰一条目录项;②每个声明键恰归一个面板或隐式登记——不多不少;③rail 模型
// 与目录逐 id 相等。漏登记在 CI 挂,不到用户手里。

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  test('① panels ↔ catalog: exactly one entry per enum value', () {
    final catalogPanels = settingsCatalog.map((e) => e.panel).toList();
    expect(catalogPanels.toSet().length, catalogPanels.length, reason: 'no duplicate entries');
    expect(catalogPanels.toSet(), SettingsPanel.values.toSet(),
        reason: 'every panel registered — a new enum value must gain a catalog entry');
  });

  test('② declared keys ↔ owned ∪ implicit (exact partition)', () {
    final owned = [for (final e in settingsCatalog) ...e.ownedKeys.map((k) => k.key)];
    final implicit = settingsImplicitKeys.map((k) => k.key).toList();
    final union = [...owned, ...implicit];
    expect(union.toSet().length, union.length,
        reason: 'a key is owned by EXACTLY one bucket — overlap found 键归属唯一,发现重叠');
    final declared = SettingsKeys.all.map((k) => k.key).toSet();
    expect(union.toSet(), declared,
        reason: 'declaration table == catalog registration — an unregistered (or ghost) key exists '
            '声明表与目录登记不相等:有键漏登记或幽灵登记');
  });

  test('③ rail model ↔ catalog: same rows, same ids, three sections', () {
    final model = buildSettingsRailModel(t);
    final types = model.groups.single.types;
    expect(types, hasLength(3), reason: '偏好/资源/系统 三段');
    final rowIds = [for (final ty in types) ...ty.rows.map((r) => r.id)];
    expect(rowIds, settingsCatalog.map((e) => e.panel.name).toList(),
        reason: 'directory order == catalog order, one row per panel');
    // Labels resolve non-empty in both locales (a missing i18n key renders raw). 双语标签非空。
    for (final ty in types) {
      for (final r in ty.rows) {
        expect(r.label.trim(), isNotEmpty);
      }
    }
  });
}
