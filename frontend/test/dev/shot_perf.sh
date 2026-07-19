#!/usr/bin/env bash
# W0 perf-gate real-run capture (WRK-061): launches the PROFILE-built gallery (built with
# --dart-define=GALLERY_CAT=10 + PERF_AUTOPLAY=true; the three pressure beds start STAGGERED at
# ~1s / ~15s / ~29s so frame timings are attributable), captures the gallery WINDOW BY ID
# (`screencapture -l`: reads the window's own buffer even when occluded — no activation, never
# steals focus from a present user), mid-stream of each bed + once settled, then quits.
# Read the HUD lines: 最差 <16.7ms = gate green. Profile mode is the honest timing tier.
# W0 性能门禁真跑截图(profile;按窗口 ID 截,被遮挡也准、全程不抢焦点;三床错峰各截流中+终局)。
set -euo pipefail
cd "$(dirname "$0")/../.."   # frontend/
APP="build/macos/Build/Products/Profile/anselm.app"
OUT="test/dev/out"; mkdir -p "$OUT"
[ -d "$APP" ] || { echo "✗ build the PROFILE gallery first"; exit 1; }

WINID_SWIFT=$(mktemp -t winid).swift
cat > "$WINID_SWIFT" <<'EOF'
import CoreGraphics
import Foundation
let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as! [[String: Any]]
for w in list {
    if let owner = w["kCGWindowOwnerName"] as? String, owner == "anselm",
       let num = w["kCGWindowNumber"] as? Int,
       let b = w["kCGWindowBounds"] as? [String: Any],
       (b["Width"] as? Double ?? 0) > 200, (b["Height"] as? Double ?? 0) > 200 {
        print(num)
        break
    }
}
EOF

open "$APP"
WID=""
for _ in $(seq 1 40); do
  WID=$(swift "$WINID_SWIFT" 2>/dev/null | head -1)
  [ -n "$WID" ] && break
  osascript -e 'delay 0.5'
done
[ -z "$WID" ] && { echo "✗ anselm window never appeared"; exit 1; }
echo "→ window id $WID"

osascript -e 'delay 7'     # bed 1 (1MB) mid-stream 一床流中
screencapture -l"$WID" -o "$OUT/perf_1mb.png"
osascript -e 'delay 13'    # bed 2 (50 op/s) mid-stream 二床流中(t≈20s)
screencapture -l"$WID" -o "$OUT/perf_ops.png"
osascript -e 'delay 14'    # bed 3 (5000 词) mid-stream 三床流中(t≈34s)
screencapture -l"$WID" -o "$OUT/perf_prompt.png"
osascript -e 'delay 12'    # all settled 全落定(t≈46s)
screencapture -l"$WID" -o "$OUT/perf_end.png"
osascript -e 'tell application "anselm" to quit' >/dev/null 2>&1 || true
rm -f "$WINID_SWIFT"
echo "✓ $OUT/perf_{1mb,ops,prompt,end}.png  (window $WID)"
