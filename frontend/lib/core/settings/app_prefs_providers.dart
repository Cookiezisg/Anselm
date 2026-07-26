import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../i18n/strings.g.dart';
import '../design/an_fonts.dart';
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
    NotifierProvider<ThemePreferenceController, ThemePreference>(
      ThemePreferenceController.new,
    );

/// The [ThemeMode] the MaterialApp consumes — a pure projection of the preference. MaterialApp 消费的投影。
final themeModeProvider = Provider<ThemeMode>(
  (ref) => switch (ref.watch(themePreferenceProvider)) {
    ThemePreference.light => ThemeMode.light,
    ThemePreference.dark => ThemeMode.dark,
    ThemePreference.system => ThemeMode.system,
  },
);

/// The UI locale preference: `system` (follow the device) or a concrete tag ('en' / 'zh-CN').
/// Setting it applies slang's locale IMMEDIATELY (TranslationProvider rebuilds every t-consumer);
/// the workspace AI-language double-write (拍板 #2) is the settings panel's job — this axis owns the
/// UI side only, so core stays free of backend seams.
/// 界面语言:system(跟随设备)或具体 tag。写入即时应用 slang locale(TranslationProvider 全树重建);
/// workspace AI 语言双写(拍板 #2)归设置面板动作——本轴只管 UI 侧,core 不沾后端缝。
/// Apply a stored UI-language value — the SINGLE definition of what a stored value means, shared by
/// startup and by the settings panel. `system` hands the axis back to the device; anything else pins
/// that language.
///
/// It is top-level on purpose (WRK-083 B7). It used to live inside [LocalePreferenceController.build],
/// which meant the user's persisted choice was applied only when something WATCHED that provider — and
/// its one consumer in the whole app is the General settings panel. So the app booted in the DEVICE
/// language and flipped the entire tree the moment that panel opened. Startup now resolves it itself,
/// exactly like [AnFonts.applyAtBoot] does for the restart-time font axes.
///
/// 应用一个已存的界面语言值——「一个存下来的值是什么意思」的**唯一**定义,启动与设置面板共用。`system` 把这条轴
/// 交还设备,其余值钉住那门语言。
///
/// 它**刻意**是顶层函数(WRK-083 B7)。它原本住在 [LocalePreferenceController.build] 里,这意味着用户持久化的选择
/// 只有在有人 **watch** 那个 provider 时才会被应用——而它在整个 app 里唯一的消费者是设置的「通用」面板。于是 app 以
/// **设备**语言启动,并在那个面板被打开的一刻把整棵树翻过去。现在启动自己解析它,与 [AnFonts.applyAtBoot] 处理重启期
/// 字体轴的做法一模一样。
void applyLocalePreference(String value) {
  if (value == 'system') {
    LocaleSettings.useDeviceLocaleSync();
  } else {
    LocaleSettings.setLocaleSync(AppLocaleUtils.parse(value));
  }
}

class LocalePreferenceController extends Notifier<String> {
  @override
  String build() {
    final v = ref.read(settingsPrefsProvider).getString(SettingsKeys.locale);
    // Startup already applied it ([applyLocalePreference] in main, before the first frame) — this
    // re-application is the belt to that braces, for hosts that boot the tree WITHOUT main (demo,
    // gallery, widget tests). `system` still applies nothing: re-running it from a build would stomp
    // whatever locale the host (or a test) deliberately set.
    // 启动时已经应用过了(main 里的 [applyLocalePreference],首帧之前)——这里的再应用是它的第二道保险,给那些
    // **不经过 main** 就把树跑起来的宿主(demo/gallery/widget 测试)。`system` 仍然什么都不做:从 build 里重跑它
    // 会踩掉宿主(或测试)有意设定的语言。
    if (v != 'system') _apply(v);
    return v;
  }

  void set(String value) {
    if (value == state) return;
    state = value;
    ref.read(settingsPrefsProvider).setString(SettingsKeys.locale, value);
    _apply(value);
  }

  void _apply(String value) => applyLocalePreference(value);
}

final localePreferenceProvider =
    NotifierProvider<LocalePreferenceController, String>(
      LocalePreferenceController.new,
    );

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

final boolSettingProvider =
    NotifierProvider.family<BoolSettingController, bool, SettingsKey<bool>>(
      BoolSettingController.new,
    );

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
    NotifierProvider.family<
      StringSettingController,
      String,
      SettingsKey<String>
    >(StringSettingController.new);

/// The CONTENT font axis (② 内容轴), HOT — the ONE reactive seam the prose reading surfaces (chat
/// message bubble markdown + the documents editor body/title) read to layer a serif / system face over
/// their reading styles. `null` = sans = FOLLOW the UI face already baked into [AnText] (a zero-touch
/// pass-through), so the default install renders byte-for-byte as today. Watching the string pref makes
/// the switch LIVE (no restart) — the surfaces build their styles at runtime. The UI (①) + code (③) axes
/// are RESTART-applied at boot ([AnFonts.applyAtBoot]) and have NO runtime provider — the settings rows
/// write the pref (persisted) and say「重启后生效」.
/// 内容字体轴(热):prose 阅读面读它覆盖衬线/系统脸;null=sans=跟随已烤进 AnText 的 UI 脸(零改直通,默认=现状)。
/// watch 串偏好→即时切换(样式运行时构造);UI/代码轴启动生效、无运行时 provider(面板写偏好+标「重启后生效」)。
final contentFaceProvider = Provider<AnFace?>(
  (ref) => AnFonts.contentOverrideFor(
    ref.watch(stringSettingProvider(SettingsKeys.fontContent)),
  ),
);

/// The sidestage follow intent (default «每次»), persisted via [SettingsPrefs] (`an.stage.follow`,
/// synchronous read). The chat sidestage head sets it; the settings chat panel mirrors it — one state,
/// two homes, and neither feature imports the other. 跟随三档;一份状态两处家,两 feature 互不 import。
class FollowModeController extends Notifier<FollowMode> {
  @override
  FollowMode build() {
    final v = ref
        .read(settingsPrefsProvider)
        .getString(SettingsKeys.chatAutoStage);
    return FollowMode.values.asNameMap()[v] ?? FollowMode.always;
  }

  void set(FollowMode mode) {
    state = mode;
    ref
        .read(settingsPrefsProvider)
        .setString(SettingsKeys.chatAutoStage, mode.name);
  }
}

final followModeProvider = NotifierProvider<FollowModeController, FollowMode>(
  FollowModeController.new,
);
