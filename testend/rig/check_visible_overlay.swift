import CoreGraphics
import Foundation

guard CommandLine.arguments.count == 5,
      let targetWindow = CGWindowID(CommandLine.arguments[1]),
      let appPID = pid_t(CommandLine.arguments[2]),
      let recorderPID = pid_t(CommandLine.arguments[3]) else {
    fputs("usage: check_visible_overlay.swift <window-id> <app-pid> <recorder-pid> <x,y,w,h>\n", stderr)
    exit(2)
}

let boundsParts = CommandLine.arguments[4].split(separator: ",").compactMap { Double($0) }
guard boundsParts.count == 4 else {
    fputs("invalid app bounds\n", stderr)
    exit(2)
}

let appBounds = CGRect(
    x: boundsParts[0],
    y: boundsParts[1],
    width: boundsParts[2],
    height: boundsParts[3]
)
let windows = CGWindowListCopyWindowInfo(
    [.optionOnScreenOnly, .excludeDesktopElements],
    kCGNullWindowID
) as? [[String: Any]] ?? []

let chromeOwners: Set<String> = [
    "Window Server",
    "Dock",
    "Control Center",
    "Bartender 6",
    "SystemUIServer",
    // Codex's host window owns the Computer Use surface while an app-state
    // capture is in flight. It is instrumentation chrome, not app evidence;
    // every other unknown owner remains a hard overlay failure.
    "ChatGPT",
    "ChatGPT Computer Use",
]

func rect(_ window: [String: Any]) -> CGRect? {
    guard let raw = window[kCGWindowBounds as String] as? [String: Any],
          let x = (raw["X"] as? NSNumber)?.doubleValue,
          let y = (raw["Y"] as? NSNumber)?.doubleValue,
          let width = (raw["Width"] as? NSNumber)?.doubleValue,
          let height = (raw["Height"] as? NSNumber)?.doubleValue else {
        return nil
    }
    return CGRect(x: x, y: y, width: width, height: height)
}

guard let appIndex = windows.firstIndex(where: { window in
    (window[kCGWindowNumber as String] as? NSNumber)?.uint32Value == targetWindow
}) else {
    fputs("Anselm window is not on screen\n", stderr)
    exit(3)
}

var overlays: [String] = []
for window in windows.prefix(appIndex) {
    let owner = window[kCGWindowOwnerName as String] as? String ?? "<unknown>"
    let pid = (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value ?? -1
    let layer = (window[kCGWindowLayer as String] as? NSNumber)?.intValue ?? -1
    let name = window[kCGWindowName as String] as? String ?? ""

    if pid == appPID || pid == recorderPID || owner == "Anselm" || chromeOwners.contains(owner) || layer < 0 {
        continue
    }
    guard let windowBounds = rect(window), !windowBounds.isEmpty,
          windowBounds.intersects(appBounds) else {
        continue
    }
    overlays.append("owner=\(owner) name=\(name) pid=\(pid) layer=\(layer) bounds=\(windowBounds)")
}

if !overlays.isEmpty {
    print(overlays.joined(separator: "\n"))
    exit(1)
}
