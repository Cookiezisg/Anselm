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
    [[ -x "$BUNDLE/anselm" ]] || { echo "✗ $BUNDLE missing — run: flutter build linux --release --no-tree-shake-icons" >&2; exit 1; }
    install -m 0755 "$SIDECAR" "$BUNDLE/anselm-server"
    STAGE="$(mktemp -d)"
    cp -R "$BUNDLE" "$STAGE/Anselm-$VERSION"
    TAR="$OUT/Anselm-$VERSION-linux-x64.tar.gz"
    tar -C "$STAGE" -czf "$TAR" "Anselm-$VERSION"
    echo "✓ $TAR"

    # AppImage: one double-clickable file. The bundle goes under usr/bin so relative lookups
    # (lib/, data/, the sidecar next to the executable) keep working; AppRun execs the binary.
    # appimagetool is fetched by the release workflow; locally it is optional.
    # AppImage:一个双击即用的文件。bundle 放在 usr/bin 下,相对查找(lib/、data/、旁边的 sidecar)不变;
    # AppRun 直接 exec 主程序。appimagetool 由发行工作流下载,本机可选。
    if command -v appimagetool >/dev/null; then
      APPDIR="$STAGE/Anselm.AppDir"
      mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/share/applications" "$APPDIR/usr/share/icons/hicolor/512x512/apps"
      cp -R "$BUNDLE"/. "$APPDIR/usr/bin/"
      install -m 0644 linux/packaging/anselm.desktop "$APPDIR/usr/share/applications/anselm.desktop"
      install -m 0644 linux/packaging/anselm.desktop "$APPDIR/anselm.desktop"
      install -m 0644 linux/packaging/anselm.png "$APPDIR/usr/share/icons/hicolor/512x512/apps/anselm.png"
      install -m 0644 linux/packaging/anselm.png "$APPDIR/anselm.png"
      printf '#!/bin/sh\nHERE="$(dirname "$(readlink -f "$0")")"\nexec "$HERE/usr/bin/anselm" "$@"\n' >"$APPDIR/AppRun"
      chmod 0755 "$APPDIR/AppRun"
      APPIMAGE="$OUT/Anselm-$VERSION-linux-x86_64.AppImage"
      ARCH=x86_64 appimagetool --appimage-extract-and-run "$APPDIR" "$APPIMAGE" >/dev/null 2>&1 \
        || ARCH=x86_64 appimagetool "$APPDIR" "$APPIMAGE" >/dev/null
      echo "✓ $APPIMAGE"
    else
      echo "· appimagetool not found, skipping AppImage"
    fi

    # .deb: installs to /opt/anselm with a launcher symlink, desktop entry and icon; apt handles
    # removal. Only the GTK runtime is declared — media libraries ship inside the bundle.
    # .deb:装到 /opt/anselm,加启动器软链、桌面项和图标;apt 负责卸载。只声明 GTK 运行时,媒体库随包自带。
    if command -v dpkg-deb >/dev/null; then
      DEB="$STAGE/deb"
      mkdir -p "$DEB/DEBIAN" "$DEB/opt/anselm" "$DEB/usr/bin" "$DEB/usr/share/applications" "$DEB/usr/share/icons/hicolor/512x512/apps"
      cp -R "$BUNDLE"/. "$DEB/opt/anselm/"
      ln -s /opt/anselm/anselm "$DEB/usr/bin/anselm"
      install -m 0644 linux/packaging/anselm.desktop "$DEB/usr/share/applications/anselm.desktop"
      install -m 0644 linux/packaging/anselm.png "$DEB/usr/share/icons/hicolor/512x512/apps/anselm.png"
      SIZE_KB="$(du -sk "$DEB/opt/anselm" | cut -f1)"
      cat >"$DEB/DEBIAN/control" <<CONTROL
Package: anselm
Version: $VERSION
Section: devel
Priority: optional
Architecture: amd64
Depends: libgtk-3-0, libglib2.0-0
Installed-Size: $SIZE_KB
Maintainer: Anselm <noreply@anselm.website>
Homepage: https://anselm.website
Description: The agentic workflow platform that builds itself
 Describe what you need; Anselm creates the functions, agents and workflows,
 schedules them, and runs them durably on this machine.
CONTROL
      DEBFILE="$OUT/anselm_${VERSION}_amd64.deb"
      dpkg-deb --build --root-owner-group "$DEB" "$DEBFILE" >/dev/null
      echo "✓ $DEBFILE"
    else
      echo "· dpkg-deb not found, skipping .deb"
    fi
    rm -rf "$STAGE"
    ;;
  *)
    echo "✗ unsupported host $(uname -s); Windows packaging lives in the release workflow" >&2
    exit 1
    ;;
esac
