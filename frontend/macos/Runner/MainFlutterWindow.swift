import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  // Traffic-light geometry, PUSHED FROM DART (WindowChrome) so the lights line up with the
  // app's chrome bar — the position's source of truth is design tokens in Dart, not a magic
  // number here. macOS resets the standard window buttons on every resize, so we store the
  // desired values and re-apply them on each resize. Defaults are harmless fallbacks used only
  // until Dart's first call lands.
  // 红绿灯几何由 Dart(WindowChrome)下发,使灯对齐顶栏条——位置事实源是 Dart 的 design token,
  // 不在此写死。macOS 每次 resize 都重置按钮,故存下目标值、每次 resize 重应用。默认值只是 Dart
  // 首次下发前的无害兜底。
  private var trafficLightLeft: CGFloat = 21 // matches AnSize.trafficLightLeft 与 token 一致
  private var trafficLightCenterY: CGFloat = 37 // from the window top; matches AnSize.trafficLightCenterY

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Dart → native: receive the chrome-bar-aligned traffic-light geometry. Dart→原生:接收对齐顶栏条的灯位。
    let channel = FlutterMethodChannel(
      name: "anselm/window_chrome",
      binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      if call.method == "alignTrafficLights", let args = call.arguments as? [String: Any] {
        if let left = args["left"] as? Double { self.trafficLightLeft = CGFloat(left) }
        if let centerY = args["centerY"] as? Double { self.trafficLightCenterY = CGFloat(centerY) }
        self.repositionTrafficLights()
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()

    // Re-pin on resize AND on every window-update tick. macOS re-lays-out the standard buttons
    // after our reposition (so they drift back to the OS default and clicks miss — they look
    // right but barely respond); didUpdate fires after each event-loop pass, keeping them pinned
    // so the full hit area stays where we drew them. The reposition is guarded to a no-op once
    // they're already in place, so this never churns or loops.
    // resize + 每次窗口更新都重钉:macOS 会在我们摆好后重排按钮(它们漂回默认位、看着对却点不动);
    // didUpdate 每轮事件后触发,把它们钉住,使命中区与绘制位一致。已在位即 no-op,绝不抖动/死循环。
    for name in [NSWindow.didResizeNotification, NSWindow.didUpdateNotification] {
      NotificationCenter.default.addObserver(
        self, selector: #selector(repositionTrafficLights), name: name, object: self)
    }
  }

  override func setFrame(_ frameRect: NSRect, display flag: Bool) {
    super.setFrame(frameRect, display: flag)
    repositionTrafficLights()
  }

  // Shift the buttons horizontally so the leftmost starts at trafficLightLeft (OS spacing kept)
  // and set each button's vertical origin so its center sits trafficLightCenterY below the top.
  // Skip when already in place — keeps the didUpdate observer cheap and loop-free.
  // 横向平移使最左按钮起于 trafficLightLeft(保留 OS 间距);纵向使各按钮中心距窗顶 trafficLightCenterY。
  // 已在位则跳过——令 didUpdate 观察者廉价且无环。
  @objc private func repositionTrafficLights() {
    let types: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]
    let buttons = types.compactMap { self.standardWindowButton($0) }
    guard let container = buttons.first?.superview else { return }
    let minX = buttons.map { $0.frame.origin.x }.min() ?? trafficLightLeft
    let dx = trafficLightLeft - minX
    for button in buttons {
      let h = button.frame.height
      let targetX = button.frame.origin.x + dx
      let targetY = container.bounds.height - trafficLightCenterY - h / 2
      let cur = button.frame.origin
      if abs(cur.x - targetX) > 0.5 || abs(cur.y - targetY) > 0.5 {
        button.setFrameOrigin(NSPoint(x: targetX, y: targetY))
      }
    }
  }
}
