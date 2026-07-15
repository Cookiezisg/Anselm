import Cocoa
import FlutterMacOS
import macos_window_utils

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let windowFrame = self.frame
    // macos_window_utils hosts the FlutterViewController so it can manipulate the NSWindow
    // (frameless chrome + traffic-light positioning) from Dart. 由 macos_window_utils 托管
    // FlutterViewController,以便从 Dart 操控窗口(无边框 chrome + 红绿灯定位)。
    let macOSWindowUtilsViewController = MacOSWindowUtilsViewController()
    self.contentViewController = macOSWindowUtilsViewController
    self.setFrame(windowFrame, display: true)

    MainFlutterWindowManipulator.start(mainFlutterWindow: self)

    // No native frame/size code here on purpose: window GEOMETRY (size / min / center / resize)
    // is owned by window_manager from Dart (scale-correct). Native meddling here caused the
    // ×2 resize blow-up. 这里刻意不碰窗口尺寸:尺寸由 Dart 的 window_manager 管(scale 正确);
    // 原生瞎设正是 resize ×2 炸开的根源。

    // Drop the unified toolbar BEFORE the full-screen zoom animation, not after. The toolbar carries no
    // items — it exists ONLY to heighten the title bar so macOS vertically centers the OS traffic lights
    // (see window_setup.dart). But entering full-screen, AppKit re-hosts that toolbar in a separate
    // full-screen container that IGNORES `titlebarAppearsTransparent` and paints its default OPAQUE
    // material — a white band across the top. window_manager only surfaces `windowDidEnterFullScreen`
    // (fires AFTER the animation), so the Dart-side removeToolbar() there runs too late and the band rides
    // the whole ~0.5s zoom (the reported bug). `willEnterFullScreenNotification` fires BEFORE the
    // animation begins, so nil-ing the toolbar here makes the very first animated frame already clean.
    //
    // Why a NotificationCenter OBSERVER and not a delegate method: NSWindow has ONE `delegate` slot and
    // window_manager owns it (that's how it emits enter/leave/move/resize). This notification is posted
    // UNCONDITIONALLY by NSWindow regardless of the delegate, so observing it (object: self) is purely
    // additive — it never contends for that slot, and window_manager keeps working untouched. Restore is
    // left to Dart's onWindowLeaveFullScreen (addToolbar) so ownership stays single-headed: native drops,
    // Dart rebuilds.
    //
    // 全屏缩放动画开始前撤掉统一 toolbar(而非动画后)。该 toolbar 不装任何东西,只为加高标题栏让 OS 红绿灯竖直居中
    // (见 window_setup.dart);但进全屏时 AppKit 把它移进独立全屏容器、无视 titlebarAppearsTransparent、渲成不透明
    // 白带。window_manager 只给 windowDidEnterFullScreen(动画后)回调,故 Dart 侧 removeToolbar() 撤得太晚、白带跟满
    // 整个 ~0.5s 动画(报告的 bug)。will 通知在动画前触发,此处置 nil 则首帧即干净。用 NotificationCenter 观察者而非
    // delegate 方法:NSWindow 只有一个 delegate 槽且被 window_manager 独占;此通知由 NSWindow 无条件 post、与 delegate
    // 无关,故观察它(object: self)纯属叠加、绝不抢槽,window_manager 照常工作。恢复留给 Dart 的 onWindowLeaveFullScreen
    // (addToolbar),保持单头所有权:原生撤、Dart 建。
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(dropToolbarBeforeFullScreen),
      name: NSWindow.willEnterFullScreenNotification,
      object: self
    )

    RegisterGeneratedPlugins(registry: macOSWindowUtilsViewController.flutterViewController)

    super.awakeFromNib()
  }

  // Pre-animation toolbar drop for a seamless full-screen enter (see awakeFromNib). 动画前撤 toolbar。
  @objc private func dropToolbarBeforeFullScreen() {
    self.toolbar = nil
  }

  // Hide the window on its VERY FIRST ordering so it never paints at the xib's 800×600 / off-center
  // contentRect; window_manager's show() (Dart, inside waitUntilReadyToShow AFTER size + center are
  // applied — see window_setup.dart) is the single reveal, so the first frame the user ever sees is
  // already at the final geometry — killing the launch reposition flash. `hiddenWindowAtLaunch()` is
  // window_manager's NSWindow extension (one-shot, guarded by its own `configured` flag); this is the
  // package's blessed recipe verbatim (no `import window_manager` — same as window_manager's own
  // example Runner). 首次 order 即隐藏,绝不在 xib 的 800×600/非居中 rect 先画一帧;几何就绪后由 Dart 的
  // windowManager.show() 一次性显示到最终位置 —— 消除启动重定位闪烁(window_manager 官方 recipe 原样照搬)。
  override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
    super.order(place, relativeTo: otherWin)
    hiddenWindowAtLaunch()
  }
}
