import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../i18n/strings.g.dart';
import 'follow_mode.dart';
import 'settings_prefs.dart';

/// App-level preference state (WRK-062 S1) — the theme / UI-locale axes both the MaterialApp root
/// and the settings general panel consume. Persisted via [SettingsPrefs] (`an.theme` / `an.locale`),
/// restored synchronously, applied instantly (no restart language).
/// app 级偏好状态(S1)——主题/界面语言两轴,MaterialApp 根与设置通用面板共同消费。经 SettingsPrefs
/// 持久化(an.theme/an.locale),同步恢复,即时生效(没有「重启生效」这回事)。

/// The theme preference. `dark` stays a DECLARED value while S1b (the dark lighting pass) lands —
/// the control renders it disabled until then, but a persisted choice must survive the wait.
/// 主题三态。dark 在 S1b(暗色点亮)落地前控件渲 disabled,但持久化值本身照样合法存续。
enum ThemePreference { light, dark, system }

class ThemePreferenceController extends Notifier<ThemePreference> {
  @override
  ThemePreference build() {
    final v = ref.read(settingsPrefsProvider).getString(SettingsKeys.theme);
    return ThemePreference.values.asNameMap()[v] ?? ThemePreference.light;
  }

  void set(ThemePreference pref) {
    if (pref == state) return;
    state = pref;
    ref.read(settingsPrefsProvider).setString(SettingsKeys.theme, pref.name);
  }
}

final themePreferenceProvider =
    NotifierProvider<ThemePreferenceController, ThemePreference>(ThemePreferenceController.new);

/// The [ThemeMode] the MaterialApp consumes — a pure projection of the preference. MaterialApp 消费的投影。
final themeModeProvider = Provider<ThemeMode>((ref) => switch (ref.watch(themePreferenceProvider)) {
      ThemePreference.light => ThemeMode.light,
      ThemePreference.dark => ThemeMode.dark,
      ThemePreference.system => ThemeMode.system,
    });

/// The UI locale preference: `system` (follow the device) or a concrete tag ('en' / 'zh-CN').
/// Setting it applies slang's locale IMMEDIATELY (TranslationProvider rebuilds every t-consumer);
/// the workspace AI-language double-write (拍板 #2) is the settings panel's job — this axis owns the
/// UI side only, so core stays free of backend seams.
/// 界面语言:system(跟随设备)或具体 tag。写入即时应用 slang locale(TranslationProvider 全树重建);
/// workspace AI 语言双写(拍板 #2)归设置面板动作——本轴只管 UI 侧,core 不沾后端缝。
class LocalePreferenceController extends Notifier<String> {
  @override
  String build() {
    final v = ref.read(settingsPrefsProvider).getString(SettingsKeys.locale);
    // Apply a CONCRETE stored tag at build so the persisted choice takes effect at startup. `system`
    // applies NOTHING here — main's useDeviceLocaleSync already established it, and re-applying from
    // a build would stomp whatever locale the host (or a test) set. 建时只应用**具体** tag;system 不动
    // ——main 已定设备语言,build 里重应用会踩宿主/测试设定。
    if (v != 'system') _apply(v);
    return v;
  }

  void set(String value) {
    if (value == state) return;
    state = value;
    ref.read(settingsPrefsProvider).setString(SettingsKeys.locale, value);
    _apply(value);
  }

  void _apply(String value) {
    if (value == 'system') {
      LocaleSettings.useDeviceLocaleSync();
    } else {
      final locale = AppLocaleUtils.parse(value);
      LocaleSettings.setLocaleSync(locale);
    }
  }
}

final localePreferenceProvider =
    NotifierProvider<LocalePreferenceController, String>(LocalePreferenceController.new);


/// Reactive bool preference — one family instance per declared key, so an [AnSwitch] wires in two
/// lines and `modified` falls out of `state != key.def`. 响应式 bool 偏好族:每声明键一实例,开关两行
/// 接线,modified=偏离默认。
class BoolSettingController extends Notifier<bool> {
  BoolSettingController(this.key);

  final SettingsKey<bool> key;

  @override
  bool build() => ref.read(settingsPrefsProvider).getBool(key);

  void set(bool value) {
    if (value == state) return;
    state = value;
    ref.read(settingsPrefsProvider).setBool(key, value);
  }

  void reset() {
    state = key.def;
    ref.read(settingsPrefsProvider).remove(key);
  }
}

final boolSettingProvider = NotifierProvider.family<BoolSettingController, bool, SettingsKey<bool>>(
    BoolSettingController.new);


/// Reactive string preference — the [BoolSettingController]'s string sibling (segmented / dropdown
/// rows). 响应式 string 偏好族(分段/下拉行)。
class StringSettingController extends Notifier<String> {
  StringSettingController(this.key);

  final SettingsKey<String> key;

  @override
  String build() => ref.read(settingsPrefsProvider).getString(key);

  void set(String value) {
    if (value == state) return;
    state = value;
    ref.read(settingsPrefsProvider).setString(key, value);
  }

  void reset() {
    state = key.def;
    ref.read(settingsPrefsProvider).remove(key);
  }
}

final stringSettingProvider =
    NotifierProvider.family<StringSettingController, String, SettingsKey<String>>(
        StringSettingController.new);

/// The sidestage follow intent (default «每次»), persisted via [SettingsPrefs] (`an.stage.follow`,
/// synchronous read). The chat sidestage head sets it; the settings chat panel mirrors it — one state,
/// two homes, and neither feature imports the other. 跟随三档;一份状态两处家,两 feature 互不 import。
class FollowModeController extends Notifier<FollowMode> {
  @override
  FollowMode build() {
    final v = ref.read(settingsPrefsProvider).getString(SettingsKeys.chatAutoStage);
    return FollowMode.values.asNameMap()[v] ?? FollowMode.always;
  }

  void set(FollowMode mode) {
    state = mode;
    ref.read(settingsPrefsProvider).setString(SettingsKeys.chatAutoStage, mode.name);
  }
}

final followModeProvider =
    NotifierProvider<FollowModeController, FollowMode>(FollowModeController.new);
