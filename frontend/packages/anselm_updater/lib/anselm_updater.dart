/// Dart face of the in-app updater.
///
/// On macOS every call reaches Sparkle through a method channel; the updater itself (scheduled
/// checks, download, signature verification, install, relaunch) lives natively and shows
/// Sparkle's standard dialogs. On other platforms [isSupported] is false and every method is a
/// no-op, so callers keep the GitHub Releases check as the only path there.
///
/// 应用内更新的 Dart 面。macOS 上每个调用经 method channel 到 Sparkle;updater 本体(定时检查、下载、
/// 验签、安装、重启)在原生侧,弹 Sparkle 标准对话框。其它平台 [isSupported] 为 false、方法全部空操作,
/// 调用方在那里只保留 GitHub Releases 检查这一条路。
library;

import 'dart:io';

import 'package:flutter/services.dart';

class AnselmUpdater {
  const AnselmUpdater();

  static const _channel = MethodChannel('website.anselm.app/updater');

  /// True where a native updater is wired (macOS only today). 原生 updater 是否接入(当前仅 macOS)。
  bool get isSupported => Platform.isMacOS;

  /// Run a user-initiated check: Sparkle shows progress and either the update sheet or an
  /// "up to date" message. 手动检查:Sparkle 显示进度,以及更新面板或「已是最新」。
  Future<void> checkForUpdates() async {
    if (!isSupported) return;
    await _channel.invokeMethod<void>('checkForUpdates');
  }

  /// False while a check or install is already in flight. 检查或安装进行中时为 false。
  Future<bool> canCheckForUpdates() async {
    if (!isSupported) return false;
    return await _channel.invokeMethod<bool>('canCheckForUpdates') ?? false;
  }

  Future<bool> automaticallyChecksForUpdates() async {
    if (!isSupported) return false;
    return await _channel.invokeMethod<bool>('automaticallyChecksForUpdates') ??
        false;
  }

  Future<void> setAutomaticallyChecksForUpdates(bool enabled) async {
    if (!isSupported) return;
    await _channel.invokeMethod<void>('setAutomaticallyChecksForUpdates', {
      'enabled': enabled,
    });
  }

  /// When Sparkle last checked, or null if never. 上次检查时间,从未检查为 null。
  Future<DateTime?> lastUpdateCheckDate() async {
    if (!isSupported) return null;
    final ms = await _channel.invokeMethod<double>('lastUpdateCheckDate');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms.round());
  }

  Future<String?> feedUrl() async {
    if (!isSupported) return null;
    return _channel.invokeMethod<String>('feedURL');
  }
}
