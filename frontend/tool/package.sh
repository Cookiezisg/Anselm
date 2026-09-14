#!/usr/bin/env bash
# Package a release artifact for the current host: bundle the Go sidecar next to the Flutter
# executable (where BackendController looks for it), sign what the platform needs, and emit one
# archive under dist/. Used verbatim by .github/workflows/release.yml and by `make -C frontend package`.
#
#   tool/package.sh <version> <sidecar-binary> [out-dir]
#
# 为当前宿主打一个发行包:把 Go sidecar 放到 Flutter 可执行文件旁(BackendController 从那里找它),按平台
# 签名,在 dist/ 下产出一个归档。release 工作流与 `make -C frontend package` 都原样调用本脚本。
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?version required, e.g. 0.1.0}"
SIDECAR="${2:?path to the built anselm-server binary}"
OUT="${3:-dist}"
mkdir -p "$OUT"

case "$(uname -s)" in
  Darwin)
    APP="build/macos/Build/Products/Release/anselm.app"
    [[ -d "$APP" ]] || { echo "✗ $APP missing — run: flutter build macos --release --no-tree-shake-icons" >&2; exit 1; }
    install -m 0755 "$SIDECAR" "$APP/Contents/MacOS/anselm-server"
    # Ad-hoc signatures only: there is no Developer ID in the pipeline yet, so Gatekeeper will ask
    # the user to open the app explicitly the first time. The sidecar is signed first with the
    # inherit entitlements, then the bundle is re-sealed with the app's own entitlements (adding a
    # file invalidated the seal Flutter produced).
    # 目前只有 ad-hoc 签名(流水线里没有 Developer ID),首次打开要用户手动放行。先给 sidecar 签继承
    # entitlements,再用 app 自己的 entitlements 重新封印 bundle(塞进一个文件已使 Flutter 的签名失效)。
    codesign --force --sign - --entitlements macos/Runner/Sidecar.entitlements "$APP/Contents/MacOS/anselm-server"
    codesign --force --sign - --entitlements macos/Runner/Release.entitlements "$APP"
    codesign --verify --deep --strict "$APP"
    DMG="$OUT/Anselm-$VERSION-macos.dmg"
    rm -f "$DMG"
    STAGE="$(mktemp -d)"
    cp -R "$APP" "$STAGE/Anselm.app"
    # A designed installer window: brand backdrop, large icons, app on the left, Applications on
    # the right. appdmg writes the Finder view state into .DS_Store itself (no Finder, no
    # AppleScript, works on a headless runner) and keeps the picture in `.background/`, which is
    # the layout Finder on macOS 26 still resolves; dmgbuild's root-level `.background.png` renders
    # blank there. Slot coordinates must match tool/dmg_background.py. `npm install -g appdmg`.
    # 设计过的安装窗口:品牌底、大图标、app 在左、Applications 在右。appdmg 自己把 Finder 视图状态写进
    # .DS_Store(不经 Finder/AppleScript,无头 runner 可用),且把图放在 .background/ 里——macOS 26 的
    # Finder 仍能解析这个布局;dmgbuild 放在卷根的 .background.png 在那里显示为空白。坐标须与背景脚本一致。
    command -v appdmg >/dev/null || { echo "✗ appdmg missing — npm install -g appdmg" >&2; exit 1; }
    cp macos/dmg/background.png "$STAGE/background.png"
    cat >"$STAGE/appdmg.json" <<JSON
{
  "title": "Anselm $VERSION",
  "icon": "$PWD/$APP/Contents/Resources/AppIcon.icns",
  "background": "$STAGE/background.png",
  "icon-size": 176,
  "window": { "position": { "x": 200, "y": 140 }, "size": { "width": 800, "height": 500 } },
  "contents": [
    { "x": 230, "y": 235, "type": "file", "path": "$STAGE/Anselm.app" },
    { "x": 570, "y": 235, "type": "link", "path": "/Applications" }
  ]
}
JSON
    appdmg "$STAGE/appdmg.json" "$DMG" >/dev/null
    rm -rf "$STAGE"
    echo "✓ $DMG"
    ;;
  Linux)
    BUNDLE="build/linux/x64/release/bundle"
    [[ -x "$BUNDLE/anselm" ]] || { echo "✗ $BUNDLE missing — run: flutter build linux --release" >&2; exit 1; }
    install -m 0755 "$SIDECAR" "$BUNDLE/anselm-server"
    STAGE="$(mktemp -d)"
    cp -R "$BUNDLE" "$STAGE/Anselm-$VERSION"
    TAR="$OUT/Anselm-$VERSION-linux-x64.tar.gz"
    tar -C "$STAGE" -czf "$TAR" "Anselm-$VERSION"
    rm -rf "$STAGE"
    echo "✓ $TAR"
    ;;
  *)
    echo "✗ unsupported host $(uname -s); Windows packaging lives in the release workflow" >&2
    exit 1
    ;;
esac
