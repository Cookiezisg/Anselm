// swift-tools-version: 5.9
// The macOS half of the in-app updater: a thin bridge over Sparkle 2, pulled in as a Swift
// package so the host stays CocoaPods-free. Sparkle is pinned to an exact release because its
// framework is re-signed and notarized as part of the app; an unreviewed bump must not slip in
// through a version range.
// 应用内更新的 macOS 半边:Sparkle 2 之上的薄桥,以 Swift 包引入,宿主继续不碰 CocoaPods。Sparkle 钉死
// 精确版本:它的 framework 会随 app 一起重签与公证,不能让未审阅的升级从版本区间溜进来。
import PackageDescription

let package = Package(
    name: "anselm_updater",
    platforms: [
        .macOS("12.0")
    ],
    products: [
        .library(name: "anselm-updater", targets: ["anselm_updater"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0"),
    ],
    targets: [
        .target(
            name: "anselm_updater",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "Sparkle", package: "Sparkle"),
            ]
        )
    ]
)
