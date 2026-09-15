import Cocoa
import FlutterMacOS
import Sparkle

/// Sparkle behind a method channel. The updater is created once at plugin registration so its
/// scheduled background checks run for the app's whole life; Dart only asks for a user-initiated
/// check, toggles automatic checks, and reads the feed URL for the About panel. Everything else
/// (download, EdDSA verification, sandbox-safe install via Installer.xpc, relaunch) is Sparkle's
/// own standard UI and is configured through Info.plist.
/// Sparkle 藏在 method channel 后面。updater 在插件注册时建一次,后台定时检查伴随 app 全程;Dart 只发起
/// 手动检查、开关自动检查、读 feed URL 给「关于」面板。其余(下载、EdDSA 校验、经 Installer.xpc 在沙箱外
/// 安装、重启)都是 Sparkle 自带的标准流程,由 Info.plist 配置。
public class AnselmUpdaterPlugin: NSObject, FlutterPlugin {
  private let controller = SPUStandardUpdaterController(
    startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "website.anselm.app/updater", binaryMessenger: registrar.messenger)
    registrar.addMethodCallDelegate(AnselmUpdaterPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let updater = controller.updater
    switch call.method {
    case "checkForUpdates":
      // User-initiated: Sparkle shows progress and an "up to date" sheet, unlike the silent
      // scheduled check. 用户手动触发:Sparkle 显示进度与「已是最新」,不同于静默的定时检查。
      controller.checkForUpdates(nil)
      result(nil)
    case "canCheckForUpdates":
      result(updater.canCheckForUpdates)
    case "automaticallyChecksForUpdates":
      result(updater.automaticallyChecksForUpdates)
    case "setAutomaticallyChecksForUpdates":
      if let args = call.arguments as? [String: Any], let on = args["enabled"] as? Bool {
        updater.automaticallyChecksForUpdates = on
        result(nil)
      } else {
        result(FlutterError(code: "bad-args", message: "enabled: bool required", details: nil))
      }
    case "lastUpdateCheckDate":
      result(updater.lastUpdateCheckDate.map { $0.timeIntervalSince1970 * 1000 })
    case "feedURL":
      result(updater.feedURL?.absoluteString)
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
