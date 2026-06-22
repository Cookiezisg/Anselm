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
}
