import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

/// The kit's ONE screen-reader push. Two verbs, because the desktop embedders leave exactly two
/// different holes — and telling them apart is the whole point of this seam existing (writing
/// `SemanticsService.sendAnnouncement` by hand at a call site means re-deciding the platform rule
/// every time, and the two hand-rolled copies this replaced had each carried a 10-line comment
/// re-deriving it).
///
/// WHY a push at all — `Semantics.liveRegion` is NOT the mechanism on this project: `embedder.h`
/// carries `is_live_region`, but no desktop bridge ever reads it (`ax_event_generator` never finds
/// `kLiveStatus`, so nothing fires) → a verified silent no-op on all three desktops (flutter#167318,
/// open). It only works on Android/iOS, which this project does not ship. See design-system §2
/// "桌面 a11y 的真实边界".
///
/// WHY `sendAnnouncement` and not `announce` — `announce` is deprecated, and its deprecation reason is
/// MULTI-WINDOW (it can't say which view), NOT "desktop-broken". All three desktop embedders really do
/// consume the announcement: mac → `NSAccessibilityAnnouncementRequested`, win → `NotifyWinEvent(kAlert)`,
/// linux → ATK ≥2.46.
///
/// 套件唯一的读屏推送。两个动词,因为桌面 embedder 恰好留下两个**不同**的洞——分清它们正是这条缝存在的理由
/// (在调用点手写 sendAnnouncement = 每次重新判一遍平台规则;被本缝取代的两份手抄各自扛着 10 行注释重推一遍)。
/// liveRegion 不是本项目的机制:三桌面桥从不读 is_live_region → 静默 no-op(flutter#167318 至今 OPEN),它只在
/// Android/iOS 有效、而本项目不出这两端。announce 的废弃因是**多窗口**、不是桌面坏。
abstract final class AnA11y {
  /// Speak information that has just APPEARED and that the user cannot otherwise discover — a toast,
  /// an alert bar, a page flipping to error. Nothing on any desktop announces these on its own (they
  /// take no focus), so this fires on ALL platforms.
  ///
  /// [assertiveness] follows the ARIA convention the platforms implement: polite (`role="status"`) waits
  /// for a gap, assertive (`role="alert"`) interrupts. Reserve assertive for warn/danger.
  ///
  /// 念出**刚出现**、用户无从发现的信息(toast / 提示条 / 整页翻成错误)——它们不夺焦,三桌面都不会自己念,故
  /// **三端都推**。assertiveness 走 ARIA 惯例:polite=status 等空档,assertive=alert 打断(只留给 warn/danger)。
  static void announce(
    BuildContext context,
    String message, {
    Assertiveness assertiveness = Assertiveness.polite,
  }) {
    if (message.isEmpty) return;
    // Nothing is listening → don't post. 无辅助技术在听 → 不发。
    if (!SemanticsBinding.instance.semanticsEnabled) return;
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
      assertiveness: assertiveness,
    );
  }

  /// Speak a keyboard cursor's new address — **macOS only, and that is not a preference**. The mechanism
  /// for a moving cursor is THE FOCUSED NODE, which Windows (`kFocus`) and Linux (`ATK_STATE_FOCUSED`)
  /// both fire; announcing on top of those makes the screen reader read everything twice
  /// (flutter#153020). But macOS's bridge drops `FOCUS_CHANGED` into its "notifications that aren't
  /// meaningful on Mac" skip group (`AccessibilityBridgeMac.mm`) → a focused node is SILENT there. So
  /// this is not a second channel; it is a patch over one platform's hole.
  ///
  /// Call it AFTER `requestFocus()`, with the same sentence the focused node carries.
  ///
  /// 念出键盘光标的新地址——**只在 macOS,且这不是偏好**:机制是**被聚焦的节点**(Win/Linux 都会发焦点通知,再
  /// 叠一发 = 双读,flutter#153020);而 mac bridge 把 FOCUS_CHANGED 归进「在 Mac 上没意义」的跳过组 → 那里的
  /// 焦点是**哑的**。故这不是第二条通道,是给一个平台补的洞。在 requestFocus() 之后调,句子与焦点节点所带的同一句。
  static void announceFocusMove(BuildContext context, String message) {
    if (defaultTargetPlatform != TargetPlatform.macOS) return;
    announce(context, message);
  }

  /// The ONE place that decides how a "selected" state reaches the platform — «say no by not saying».
  /// Returns `true` for a selected surface and `null` for everything else, so **`selected: false` is
  /// never emitted**.
  ///
  /// WHY — a **live defect in the pinned engine** (3.41.9 / revision `42d3d75a56`).
  /// `shell/platform/common/accessibility_bridge.cc:445` passes the tristate straight into a bool:
  ///
  /// ```cpp
  /// node_data.AddBoolAttribute(ax::mojom::BoolAttribute::kSelected, flags->is_selected);
  /// ```
  ///
  /// and `embedder.h:271` defines `kFlutterTristateFalse = 2` → non-zero → **truthy** → an explicit
  /// `selected: false` is handed to the screen reader as **selected**. On a rail that is not a nit: every
  /// unselected row announces "selected" and the one real selection becomes unfindable. macOS + Windows
  /// share that bridge and both carry it; **Linux does not** (`fl_accessible_node.cc:108` compares
  /// `== kFlutterTristateTrue`, correctly). It is an isolated slip, not a pattern — `is_expanded` /
  /// `is_toggled` / `is_focused` / `is_checked` in the same file all compare explicitly.
  ///
  /// **EXIT CONDITION — this helper is temporary.** Fixed upstream by flutter#184058 / PR #184223
  /// (commit `d04108d6bf40`, 2026-03-27), which landed AFTER the 3.41 branch cut (2026-01-08) and so is
  /// absent from every 3.41.x. Stable **3.44.6 already carries the fix**. When `mise.toml` moves off
  /// 3.41.x, DELETE this helper and pass the bool through: a genuinely selectable-but-unselected surface
  /// should say `hasSelectedState` + `!isSelected` (the ARIA tab contract). Until then that truthful
  /// reading is unreachable on 2 of our 3 platforms, and silence beats a lie.
  ///
  /// 「说否即不说」的唯一裁决点:选中返 true,其余一律 null,**绝不发 selected: false**。
  /// 因为**钉住的引擎里有一个活着的缺陷**(3.41.9):common bridge 把 tristate 直接塞进 bool 形参,而
  /// `kFlutterTristateFalse = 2` = 真值 → 显式 false 被读屏念成**已选中**。在 rail 上这不是小疵:每一行未选中的
  /// 都喊「已选中」,真正的选中反而找不着。macOS + Windows 共用该桥、都中招;**Linux 不受影响**(显式比较、是对的)。
  /// **退出条件**:上游已修(#184058/PR #184223),但修复晚于 3.41 切枝、故 3.41.x 全系没有;**3.44.6 已含**。
  /// mise 一旦升离 3.41.x,**删掉本 helper**、把 bool 直接透传(未选中的可选面本该说 hasSelectedState + !isSelected
  /// = ARIA tab 契约)。在那之前,这句真话在 3 个平台里的 2 个上根本发不出去,而**沉默胜过撒谎**。
  static bool? selected(bool? selected) => selected == true ? true : null;
}
