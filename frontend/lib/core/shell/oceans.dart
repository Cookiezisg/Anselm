import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The four top-level oceans the left-island switcher chooses between (mirrors the demo's `manifest.js`
/// nav). [chat] and [entities] are built; the others are placeholders ("coming soon") until their
/// feature lands — the switcher shows all four so it reads as complete. Order = switcher order.
///
/// 左岛切换器的四个一级海洋(镜像 demo manifest.js 导航)。chat 与 entities 已建,其余为占位(即将推出),
/// 待各 feature 落地。切换器四个全列,读起来完整。枚举顺序 = 切换器顺序。
/// The first four are the TOP switcher ([AnOceanSwitcher]); [settings] is a footer ocean reached via the
/// gear (NOT in the top switcher — when active the switcher shows no selection). 前四个是顶部切换器;
/// settings 是底栏齿轮进的海洋(不在切换器里,激活时切换器无选中)。
enum OceanKind {
  chat,
  entities,
  scheduler,
  documents,
  settings;

  /// Whether the ocean's feature exists; the rest render a placeholder. 是否已构建(否则占位)。
  bool get isBuilt => this == OceanKind.entities || this == OceanKind.chat;

  /// Shown in the top switcher (the gear-reached [settings] is not). 出现在顶部切换器里(齿轮进的 settings 不在)。
  bool get inTopSwitcher => index < OceanKind.settings.index;
}

/// The currently selected ocean — left-island switcher state, owned at the app root (kept in `core/shell`
/// like [shellChromeProvider] so it isn't an `app`-only concern). Default [OceanKind.entities] so the app
/// opens on the only built ocean. NOT routed yet (entity selection inside the entities ocean stays
/// URL-driven; ocean switching is a follow-up to fold into go_router).
///
/// 当前选中海洋——左岛切换器状态,在 app 根持有(放 core/shell,同 shellChromeProvider)。默认 entities(开机即落在唯一已建海洋)。
/// 暂未路由化(entities 海洋内的实体选区仍走 URL;海洋切换并入 go_router 是后续)。
class SelectedOceanController extends Notifier<OceanKind> {
  @override
  OceanKind build() => OceanKind.entities;

  void select(OceanKind kind) {
    if (kind != state) state = kind;
  }
}

final selectedOceanProvider =
    NotifierProvider<SelectedOceanController, OceanKind>(SelectedOceanController.new);

/// Whether the NOTIFICATIONS tray is open — an axis ORTHOGONAL to [selectedOceanProvider]: it takes over
/// the left island's middle (the rail), leaving the center ocean untouched, so you can pull up
/// notifications while staying on any ocean. The bell toggles it. 通知托盘是否打开——与选中海洋正交的轴:
/// 接管左岛中段(rail)、不动中心海洋,故在任何海洋都能拉出通知。铃 toggle。
class NotificationsTray extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() => state = !state;
  void close() {
    if (state) state = false;
  }
}

final notificationsOpenProvider = NotifierProvider<NotificationsTray, bool>(NotificationsTray.new);
