import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The pushed-in THIRD level of the settings ocean (WRK-062 §1: resource detail = center push, Esc /
/// breadcrumb returns). One detail at a time, owned per panel; switching panels pops it. [kind] is
/// the panel-local view name ('addKey' / 'editKey' / …), [id] the subject row when editing.
/// [category] is an OPTIONAL panel-local rider — e.g. models&keys threads the provider category
/// ('llm' | 'search') through 'addKey' so the vendor-logo grid filters to the matching family,
/// WITHOUT encoding it into [kind] (WRK-077 施工序⑪).
/// settings 中心的推入第三级(资源详情):一次一个,随面板切换弹出;kind=面板内视图名,id=编辑对象。
/// category=可选面板内随行值(如模型与密钥把 provider 类别 'llm'|'search' 穿过 'addKey',厂家 logo
/// 网格据此过滤同类家——不编进 kind)。
typedef SettingsDetail = ({String kind, String? id, String? category});

class SettingsDetailController extends Notifier<SettingsDetail?> {
  @override
  SettingsDetail? build() => null;

  void push(String kind, {String? id, String? category}) =>
      state = (kind: kind, id: id, category: category);
  void pop() => state = null;
}

final settingsDetailProvider =
    NotifierProvider<SettingsDetailController, SettingsDetail?>(
      SettingsDetailController.new,
    );
