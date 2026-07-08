import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The pushed-in THIRD level of the settings ocean (WRK-062 §1: resource detail = center push, Esc /
/// breadcrumb returns). One detail at a time, owned per panel; switching panels pops it. [kind] is
/// the panel-local view name ('addKey' / 'editKey' / …), [id] the subject row when editing.
/// settings 中心的推入第三级(资源详情):一次一个,随面板切换弹出;kind=面板内视图名,id=编辑对象。
typedef SettingsDetail = ({String kind, String? id});

class SettingsDetailController extends Notifier<SettingsDetail?> {
  @override
  SettingsDetail? build() => null;

  void push(String kind, {String? id}) => state = (kind: kind, id: id);
  void pop() => state = null;
}

final settingsDetailProvider =
    NotifierProvider<SettingsDetailController, SettingsDetail?>(SettingsDetailController.new);
