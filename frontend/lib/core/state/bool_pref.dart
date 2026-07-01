import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A single boolean UI preference (a ⚙ toggle): holds one bool with a fixed default, `toggle()` to flip and
/// `set()` to force a value. Reusable so each toggle is `NotifierProvider(() => BoolPrefNotifier(default))`
/// rather than a hand-copied `Notifier<bool>` class per switch (which drifted — some had set(), some didn't).
///
/// 单个布尔 UI 偏好(⚙ 开关):持一个 bool + 固定默认,toggle() 翻转、set() 强置。可复用:每个开关一行
/// NotifierProvider,不必每个开关手抄一个 `Notifier<bool>`(此前漂移过——有的有 set、有的没有)。
class BoolPrefNotifier extends Notifier<bool> {
  BoolPrefNotifier(this._initial);

  final bool _initial;

  @override
  bool build() => _initial;

  void toggle() => state = !state;

  void set(bool value) {
    if (value != state) state = value;
  }
}
