import 'dart:io';

import 'package:anselm/core/settings/app_prefs_providers.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter_test/flutter_test.dart';

// WRK-083 B7 — the persisted UI language must be applied AT BOOT, not when some panel happens to read
// a provider.
//
// User report: «到这个页面后突然意识到我是中文然后切换到». Reproduced verbatim: this machine's device
// locale is en-SG and the stored preference is zh-CN, so the app booted fully ENGLISH — rail, landing,
// everything — and the entire tree flipped to Chinese the moment Settings was opened.
//
// The cause is lazy evaluation, not a missing write. `main` calls `useDeviceLocaleSync()` and the
// persisted concrete tag is applied inside `LocalePreferenceController.build()` — and Riverpod builds a
// provider only when something WATCHES it. Its one and only consumer in the whole app is the General
// settings panel. So the user's own choice sat unapplied until they opened that panel, and opening it
// was what "switched" the language.
//
// The fix follows the shape the codebase already uses for the other restart-time axes: `AnFonts
// .applyAtBoot` resolves the persisted font choice once, after prefs load, before `runApp`. The locale
// is the same kind of axis and now resolves the same way.
//
// WRK-083 B7——持久化的界面语言必须在**启动时**应用,而不是等某个面板碰巧读了某个 provider 才应用。
//
// 用户报告:「到这个页面后突然意识到我是中文然后切换到」。逐字复现:本机设备语言是 en-SG、存的偏好是 zh-CN,
// 于是 app **整个以英文启动**——rail、landing、全部——而在打开设置的那一刻整棵树翻成中文。
//
// 病因是**惰性求值**、不是漏写。`main` 调 `useDeviceLocaleSync()`,而持久化的具体 tag 是在
// `LocalePreferenceController.build()` 里应用的——Riverpod 只在有人 **watch** 时才 build 它。而它在整个 app 里
// **唯一**的消费者就是设置的「通用」面板。于是用户自己的选择一直没被应用,直到他打开那个面板——而打开这个动作
// 本身就是那次「切换」。
//
// 修法沿用代码库对其他**重启期轴**已有的形状:`AnFonts.applyAtBoot` 在 prefs 载入后、`runApp` 前把持久化的字体
// 选择解析一次。语言是同一种轴,现在走同一条路。

void main() {
  // useDeviceLocaleSync reads the platform locale through the binding. 读设备语言要经 binding。
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'applyLocalePreference: a concrete tag wins, `system` keeps the device',
    () {
      LocaleSettings.useDeviceLocaleSync();
      final device = LocaleSettings.currentLocale;

      applyLocalePreference('zh-CN');
      expect(LocaleSettings.currentLocale, AppLocale.zhCn);

      applyLocalePreference('en');
      expect(LocaleSettings.currentLocale, AppLocale.en);

      // `system` must NOT pin a language — it hands the axis back to the device.
      // `system` 不得钉住任何语言——它把这条轴交还设备。
      applyLocalePreference('system');
      expect(LocaleSettings.currentLocale, device);
    },
  );

  // The behavioural test above proves the helper works; it says nothing about whether STARTUP calls it.
  // That is the whole bug: the machinery existed and ran too late. So the boot call is pinned at the
  // source, the same way `AnFonts.applyAtBoot` sits there.
  // 上面的行为测试证明这个帮手可用,却说明不了**启动是否调用它**。而那正是整个 bug:机器一直都在,只是跑得太晚。
  // 故启动这一调用钉在源码层,与 `AnFonts.applyAtBoot` 并排。
  test('main applies the persisted locale before runApp', () {
    final src = File('lib/main.dart').readAsStringSync();
    final applyAt = src.indexOf('applyLocalePreference(');
    final runAppAt = src.indexOf('runApp(');
    expect(
      applyAt,
      greaterThan(0),
      reason:
          'startup must resolve the persisted language itself — leaving it to a settings panel\'s '
          'provider means the app boots in the WRONG language and flips when that panel opens '
          '(WRK-083 B7)',
    );
    expect(
      applyAt,
      lessThan(runAppAt),
      reason:
          'the language must be settled BEFORE the first frame, not after it',
    );
  });
}
