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
    ln -s /Applications "$STAGE/Applications"
    hdiutil create -volname "Anselm $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
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
