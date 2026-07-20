import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The central app-level preferences service (WRK-062 S-13) — the ONE seam every `an.*` key goes
/// through. It is STORAGE, not state: providers keep owning their in-memory state and read/write here
/// (synchronously — the instance is loaded once before runApp), replacing the four hand-rolled
/// SharedPreferences call sites that each re-invented best-effort persistence.
///
/// Discipline:
///  - Every key is DECLARED in [SettingsKeys] (typed constant + default). The settings catalog gate
///    asserts `declared keys == catalog-registered keys`, so an undeclared ad-hoc key fails CI.
///  - Legacy `fy.*` keys migrate ONCE on load (copy → new name, delete old) — [_migrations].
///  - [resetAll] walks the DECLARED set (never a prefix wildcard) so "重置本地偏好" can't eat keys
///    some other subsystem owns.
///
/// 中央 app 级偏好服务(S-13)——一切 `an.*` 键的唯一缝。只管**存储**不管状态:provider 照旧持内存态,
/// 读写走这里(同步——实例在 runApp 前载入一次),替掉四处各自手写的 SharedPreferences。纪律:①每键在
/// [SettingsKeys] 声明(类型化常量+默认值),目录门禁断言「声明键集==catalog 登记键集」;②旧 `fy.*` 键
/// 载入时一次性迁移(拷新名删旧);③[resetAll] 遍历**声明集**(禁前缀通配),别家子系统的键永不误伤。
class SettingsPrefs {
  SettingsPrefs._(this._sp);

  /// A live instance over real SharedPreferences — call once in main() BEFORE runApp. Runs the
  /// fy.* migration. 真存储实例(main 里 runApp 前载入一次;顺手跑 fy.* 迁移)。
  static Future<SettingsPrefs> load() async {
    final sp = await SharedPreferences.getInstance();
    for (final m in _migrations) {
      if (!sp.containsKey(m.from)) continue;
      final v = sp.get(m.from);
      // Copy under the new name only if the new name isn't already written. 新名未写才拷。
      if (!sp.containsKey(m.to)) {
        switch (v) {
          case final bool b:
            await sp.setBool(m.to, b);
          case final double d:
            await sp.setDouble(m.to, d);
          case final int i:
            await sp.setInt(m.to, i);
          case final String s:
            await sp.setString(m.to, s);
        }
      }
      await sp.remove(m.from);
    }
    return SettingsPrefs._(sp);
  }

  /// An in-memory instance — the provider default, so tests and the gallery never touch disk.
  /// 内存实例(provider 默认;测试/gallery 零落盘)。
  factory SettingsPrefs.inMemory([Map<String, Object> seed = const {}]) =>
      SettingsPrefs._(null).._mem.addAll(seed);

  final SharedPreferences? _sp;
  final Map<String, Object> _mem = {};

  // ── typed reads (declared default when absent) 类型化读(缺省回声明默认) ──

  bool getBool(SettingsKey<bool> key) => _read(key.key) as bool? ?? key.def;
  double getDouble(SettingsKey<double> key) => _read(key.key) as double? ?? key.def;
  String getString(SettingsKey<String> key) => _read(key.key) as String? ?? key.def;

  Object? _read(String key) => _sp != null ? _sp.get(key) : _mem[key];

  // ── typed writes (fire-and-forget persistence; memory is source of truth for the session)
  //    类型化写(持久化 best-effort;会话内以内存为准) ──

  void setBool(SettingsKey<bool> key, bool value) => _write(key.key, value);
  void setDouble(SettingsKey<double> key, double value) => _write(key.key, value);
  void setString(SettingsKey<String> key, String value) => _write(key.key, value);

  void _write(String key, Object value) {
    if (_sp == null) {
      _mem[key] = value;
      return;
    }
    switch (value) {
      case final bool b:
        _sp.setBool(key, b);
      case final double d:
        _sp.setDouble(key, d);
      case final String s:
        _sp.setString(key, s);
      case final int i:
        _sp.setInt(key, i);
    }
  }

  /// Remove one declared key (falls back to its default on next read). 清一键(下次读回默认)。
  void remove(SettingsKey<dynamic> key) =>
      _sp != null ? _sp.remove(key.key) : _mem.remove(key.key);

  /// «重置本地偏好»: clear every DECLARED key + every member of the declared prefix families.
  /// Walks the declaration table — never a wildcard. 遍历声明表清空(含声明前缀族),绝不通配。
  Future<void> resetAll() async {
    for (final key in SettingsKeys.all) {
      _sp != null ? await _sp.remove(key.key) : _mem.remove(key.key);
    }
    final existing = _sp != null ? _sp.getKeys() : Set.of(_mem.keys);
    for (final prefix in SettingsKeys.families) {
      for (final k in existing.where((k) => k.startsWith(prefix))) {
        _sp != null ? await _sp.remove(k) : _mem.remove(k);
      }
    }
  }

  // ── declared prefix families (dynamic member keys) 声明前缀族(动态成员键) ──

  bool getFamilyBool(String prefix, String member, {required bool def}) {
    assert(SettingsKeys.families.contains(prefix), 'undeclared family: $prefix');
    return _read('$prefix$member') as bool? ?? def;
  }

  void setFamilyBool(String prefix, String member, bool value) {
    assert(SettingsKeys.families.contains(prefix), 'undeclared family: $prefix');
    _write('$prefix$member', value);
  }
}

/// The one-shot legacy renames (fy.* era → an.*). Copy-then-delete, existing an.* value wins.
/// 一次性旧键迁移(fy.*→an.*):拷后删旧,已有 an.* 值优先。
const List<({String from, String to})> _migrations = [
  (from: 'fy.side.collapsed', to: 'an.side.collapsed'),
  (from: 'fy.side.w', to: 'an.side.w'),
  (from: 'fy.side.rightw', to: 'an.side.rightw'),
  (from: 'fy.ocean', to: 'an.ocean'),
  (from: 'fy.stage.follow', to: 'an.stage.follow'),
];

/// One declared preference key: name + type + default. 一条声明键:名+类型+默认值。
class SettingsKey<T> {
  const SettingsKey(this.key, this.def);

  final String key;
  final T def;
}

/// THE declaration table — every `an.*` preference key the app owns, in one place. The settings
/// catalog gate cross-checks this set against the catalog registrations (三相等门禁 material).
/// 唯一声明表——app 全部 `an.*` 偏好键。目录门禁拿它与 catalog 登记互查(三相等门禁原料)。
abstract final class SettingsKeys {
  // ── shell chrome 壳 ──
  static const sideCollapsed = SettingsKey<bool>('an.side.collapsed', false);
  static const sideWidth = SettingsKey<double>('an.side.w', AnSize.sidebar);
  static const rightWidth = SettingsKey<double>('an.side.rightw', AnSize.rightIsland);
  static const ocean = SettingsKey<String>('an.ocean', 'chat');
  static const settingsPanel = SettingsKey<String>('an.settings.panel', 'general');

  // ── appearance / window 外观与窗口 ──
  static const theme = SettingsKey<String>('an.theme', 'light'); // light|dark|system
  static const locale = SettingsKey<String>('an.locale', 'system'); // system|en|zh-CN
  static const windowZoom = SettingsKey<double>('an.window.zoom', 1.0);
  static const windowRemember = SettingsKey<bool>('an.window.remember', true);
  static const windowBounds = SettingsKey<String>('an.window.bounds', ''); // "x,y,w,h"
  static const launchAtStartup = SettingsKey<bool>('an.startup.atLogin', false);
  static const updateCheck = SettingsKey<bool>('an.update.check', true);

  // ── notifications 通知 ──
  static const notifyLevel = SettingsKey<String>('an.notify.level', 'important'); // all|important|silent
  static const notifyOs = SettingsKey<bool>('an.notify.os', true);
  static const notifyToast = SettingsKey<bool>('an.notify.toast', true);
  // Capsule event registry (which classes may pop the band capsule, 用户 0720): failures/approvals
  // default ON, attention default OFF. 胶囊事件登记:失败/审批默认开,需关注默认关。
  static const capsuleFailures = SettingsKey<bool>('an.capsule.failures', true);
  static const capsuleApprovals = SettingsKey<bool>('an.capsule.approvals', true);
  static const capsuleAttention = SettingsKey<bool>('an.capsule.attention', false);

  // ── fonts 字体 (WRK: 三正交字体轴, machine-level) ──
  // Wire values are the FIRST option of each axis = today's bundled faces (zero-perception default).
  // ① UI + ③ code are RESTART-applied (an_fonts.dart / applyAtBoot); ② content is HOT (contentFaceProvider).
  // 线值=各轴首项=现状随包脸(零感知默认);①UI+③代码=重启生效,②内容=热切换。
  static const fontUi = SettingsKey<String>('an.font.ui', 'bundled'); // bundled|system
  static const fontContent = SettingsKey<String>('an.font.content', 'sans'); // sans|serif|system
  static const fontCode = SettingsKey<String>('an.font.code', 'jetbrainsMono'); // jetbrainsMono|firaCode|cascadiaCode|system

  // ── chat 对话 ──
  static const chatSendKey = SettingsKey<String>('an.chat.sendKey', 'enter'); // enter|cmdEnter
  static const chatAutoStage = SettingsKey<String>('an.stage.follow', 'always'); // never|conversation|always
  static const chatShowArchived = SettingsKey<bool>('an.chat.showArchived', false);
  static const chatShowGroupCount = SettingsKey<bool>('an.chat.showGroupCount', true);
  static const chatShowTime = SettingsKey<bool>('an.chat.showTime', true);

  // ── shortcuts 快捷键 (S6: JSON map of rebound global commands) ──
  static const shortcuts = SettingsKey<String>('an.shortcuts', ''); // {"commandId":"cmd+keyB"}

  /// Every declared single key (the resetAll walk + the gate's denominator). 全部声明单键。
  static const List<SettingsKey<dynamic>> all = [
    sideCollapsed, sideWidth, rightWidth, ocean, settingsPanel,
    theme, locale, windowZoom, windowRemember, windowBounds, launchAtStartup, updateCheck,
    fontUi, fontContent, fontCode,
    notifyLevel, notifyOs, notifyToast, capsuleFailures, capsuleApprovals, capsuleAttention,
    chatSendKey, chatAutoStage, chatShowArchived, chatShowGroupCount, chatShowTime,
    shortcuts,
  ];

  /// Declared dynamic-member prefix families (e.g. per-ocean right-island collapse). 声明前缀族。
  static const Set<String> families = {'an.right.collapsed.'};
}

/// The DI seam. Defaults to in-memory (tests / gallery); `main` overrides with the loaded live
/// instance. 注入缝:默认内存(测试/gallery);main 用已载实例 override。
final settingsPrefsProvider = Provider<SettingsPrefs>((ref) => SettingsPrefs.inMemory());
