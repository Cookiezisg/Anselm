import Cocoa
import FlutterMacOS
import ObjectiveC
import macos_window_utils

// The macOS window's OUTER envelope radius — overrides NSThemeFrame's hardcoded Tahoe radius (26pt) so the
// window corner is CONCENTRIC with the shell's left island (= island chip 12 + shellPad 8 = Dart's
// AnRadius.window). A `var` so Dart can push the token value over `app/window_chrome`; defaults to 20 for the
// pre-channel first frame. 窗外圆角:覆写 NSThemeFrame 硬编码的 Tahoe 26pt,使窗角与左岛同心(=chip+shellPad=AnRadius.window)。
// var 以便 Dart 经通道送 token 值;默认 20 供通道前首帧。
private var kANWindowCornerRadius: CGFloat = 20

// Override NSThemeFrame's private corner-radius getters so the WHOLE window — its mask, its drop shadow, and
// the clip that even Flutter's Metal content obeys — rounds to `kANWindowCornerRadius` instead of the OS's
// 26pt. This is the ONLY lever that reshapes a titled window: content-side clips (a native layer's
// cornerRadius, a Flutter ClipRRect) can't, because NSThemeFrame owns the shape at the WINDOW level and masks
// everything below it (proven: our Metal content is currently masked to 26pt by this very frame). Keeping the
// window `.titled` means the OS still draws + vertically-centers the REAL traffic lights (unlike borderless,
// which would drop them). Each patch is nil-guarded → if a future macOS renames a getter, it silently falls
// back to the system radius, never crashes. Changing the radius VALUE reuses the system's own mask machinery
// (it is NOT a custom `_cornerMask` CGPath install — that is the one that pins a per-window mask and drives
// sustained Tahoe WindowServer GPU load; this does not). Private API is acceptable for this project: local-first,
// single-user, never App-Store distributed (CLAUDE.md).
// 覆写 NSThemeFrame 私有圆角 getter,使整只窗(mask+阴影+连 Flutter Metal 内容都遵守的裁剪)圆到 kANWindowCornerRadius 而非系统 26pt。
// 这是重塑 titled 窗形的唯一杠杆:内容侧裁剪(原生层 cornerRadius / Flutter ClipRRect)都不行——NSThemeFrame 在窗口级拥有窗形、mask 其下一切
// (实证:我们的 Metal 内容正被它 mask 成 26pt)。保 .titled → OS 照画并竖直居中真红绿灯(borderless 会丢灯)。每处判空:将来改名则静默回落系统半径、不崩。
// 改半径数值复用系统自己的 mask 机制(非装 _cornerMask CGPath——那个才钉 per-window mask、致 Tahoe GPU 高负载;此处不会)。私有 API 于本项目可接受:
// 本地优先、单用户、绝不上架(CLAUDE.md)。
private func anInstallWindowCornerRadius() {
  guard let cls = NSClassFromString("NSThemeFrame") else { return }
  let cgFloatImp: @convention(c) (AnyObject, Selector) -> CGFloat = { _, _ in kANWindowCornerRadius }
  let cgSizeImp: @convention(c) (AnyObject, Selector) -> CGSize = { _, _ in
    CGSize(width: kANWindowCornerRadius, height: kANWindowCornerRadius)
  }
  func patch(_ selector: String, _ imp: IMP) {
    if let method = class_getInstanceMethod(cls, NSSelectorFromString(selector)) {
      method_setImplementation(method, imp)
    }
  }
  patch("_cornerRadius", unsafeBitCast(cgFloatImp, to: IMP.self))
  patch("_getCachedWindowCornerRadius", unsafeBitCast(cgFloatImp, to: IMP.self))
  patch("_topCornerSize", unsafeBitCast(cgSizeImp, to: IMP.self))
  patch("_bottomCornerSize", unsafeBitCast(cgSizeImp, to: IMP.self))
}

class MainFlutterWindow: NSWindow {
  private var chromeChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    // Install the corner-radius override BEFORE the window is revealed. The window is hidden-at-launch (the
    // order hook below) and window_manager's show() is the single reveal, so with the getters already swizzled
    // the very first painted frame is already at kANWindowCornerRadius — no 26→20 pop. 在窗口显示前装好圆角覆写:
    // 窗 hidden-at-launch、show() 是唯一显示点,getter 已 swizzle 故首帧即 kANWindowCornerRadius、无 26→20 跳变。
    anInstallWindowCornerRadius()

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

    // A deliberately NARROW third channel — window_manager owns geometry, macos_window_utils owns chrome, and
    // this owns the ONE thing neither exposes: the window corner radius (no public NSWindow.cornerRadius). Dart
    // sends AnRadius.window (= chip + shellPad) so the radius stays SOURCED FROM THE DESIGN TOKEN; retuning the
    // island chip or shellPad moves the window corner in lockstep. 刻意窄的第三通道:几何归 window_manager、chrome 归
    // macos_window_utils,此通道只管两者都不给的一件事——窗口圆角(无公开 NSWindow.cornerRadius);Dart 送 AnRadius.window
    // (=chip+shellPad)使半径来自 token,改岛 chip/shellPad 窗角同步跟随。
    let messenger = macOSWindowUtilsViewController.flutterViewController.engine.binaryMessenger
    let channel = FlutterMethodChannel(name: "app/window_chrome", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      switch call.method {
      case "setCornerRadius":
        guard let radius = call.arguments as? Double else {
          result(FlutterError(code: "bad_args", message: "setCornerRadius expects a Double", details: nil))
          return
        }
        kANWindowCornerRadius = CGFloat(radius)
        // Bust NSThemeFrame's cached radius (`_getCachedWindowCornerRadius`) + reshape the OS shadow. Same
        // frame → no geometry change (unlike the ×2-blowup that came from a WRONG frame). 逼 NSThemeFrame 重取
        // 缓存半径 + 重画阴影;同 frame 不改几何(与 ×2 炸开的错误 frame 不同)。
        self.setFrame(self.frame, display: true)
        self.invalidateShadow()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.chromeChannel = channel

    super.awakeFromNib()
  }

  // Pre-animation toolbar drop for a seamless full-screen enter (white-band fix, see awakeFromNib).
  // 进全屏动画前撤 toolbar(白带修,见 awakeFromNib)。
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
