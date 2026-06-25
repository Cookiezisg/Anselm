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

    RegisterGeneratedPlugins(registry: macOSWindowUtilsViewController.flutterViewController)

    super.awakeFromNib()
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
