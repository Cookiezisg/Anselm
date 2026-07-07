import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The four top-level oceans the left-island switcher chooses between (mirrors the demo's `manifest.js`
/// nav). [chat], [entities] and [documents] are built; the rest are placeholders ("coming soon") until
/// their feature lands — the switcher shows all four so it reads as complete. Order = switcher order.
///
/// 左岛切换器的四个一级海洋(镜像 demo manifest.js 导航)。chat/entities/documents 已建,其余为占位
/// (即将推出),待各 feature 落地。切换器四个全列,读起来完整。枚举顺序 = 切换器顺序。
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
  bool get isBuilt =>
      this == OceanKind.entities || this == OceanKind.chat || this == OceanKind.documents;

  /// Shown in the top switcher (the gear-reached [settings] is not). 出现在顶部切换器里(齿轮进的 settings 不在)。
  bool get inTopSwitcher => index < OceanKind.settings.index;
}

/// The currently selected ocean — left-island switcher state, owned at the app root (kept in `core/shell`
/// like [shellChromeProvider] so it isn't an `app`-only concern). FIRST launch lands on [OceanKind.chat]
/// (the chat landing / initial page); thereafter the LAST-selected ocean is restored (persisted via
/// SharedPreferences, mirroring [shellChromeProvider]'s left-island restore). The app always boots at the
/// router's `/` (no deep selection), so this provider is the sole "last page" memory — restore only sets
/// the OCEAN, never a stale entity/conversation id, so it can't fight the URL. Ocean switching is NOT
/// routed yet (in-ocean selection stays URL-driven; the go_router fold-in is a follow-up).
///
/// 当前选中海洋——左岛切换器状态(放 core/shell,同 shellChromeProvider)。首次启动落 chat(对话初始页);此后恢复
/// **上次选中的海洋**(SharedPreferences 持久化,镜像左岛恢复)。app 恒从 `/` 启(无深选区),故本 provider 是唯一
/// 「上次页面」记忆;恢复只设海洋、不设过期 id,不与 URL 相顶。海洋切换暂未路由化(并入 go_router 是后续)。
class SelectedOceanController extends Notifier<OceanKind> {
  static const _kOcean = 'fy.ocean';

  @override
  OceanKind build() {
    _restore();
    return OceanKind.chat;
  }

  Future<void> _restore() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_kOcean);
      if (saved == null) return;
      // Guard byName against a renamed/removed enum value (a stale pref from an older build). 防旧枚举名。
      final restored = OceanKind.values.where((o) => o.name == saved).firstOrNull;
      // Only override the chat default if the user never navigated away in this session yet (state still
      // the seed) — a fast switch before restore lands must win. 仅当本会话尚未切换过(仍为种子)才覆盖:抢先手动切换优先。
      if (restored != null && ref.mounted && state == OceanKind.chat) state = restored;
    } catch (_) {
      /* best-effort 尽力而为 */
    }
  }

  void select(OceanKind kind) {
    if (kind == state) return;
    state = kind;
    _persist(kind);
  }

  Future<void> _persist(OceanKind kind) async {
    try {
      (await SharedPreferences.getInstance()).setString(_kOcean, kind.name);
    } catch (_) {
      /* best-effort */
    }
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
