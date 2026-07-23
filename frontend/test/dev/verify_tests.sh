#!/usr/bin/env bash
# The verify TEST stage keeps directory groups for readable failure logs and a
# complete, zero-maintenance partition of test/. They run SEQUENTIALLY on macOS:
# concurrent `flutter test` processes share build/native_assets and can race
# while codesigning a dylib (a false CI failure). `-j` still parallelizes tests
# safely inside each Flutter invocation. Reliability is worth the small wall-time
# trade-off in a release gate.
#
# verify 测试段仍按目录分组，便于失败日志阅读且完整、自动覆盖 test/；但 macOS 上**顺序**运行：
# 多个 flutter test 会共享 build/native_assets，签名 dylib 时会竞争并制造假失败。每个 Flutter
# 进程内部仍以 -j 安全并行。发布门禁优先选择可复现性，而不是这点墙钟时间。
set -uo pipefail
cd "$(dirname "$0")/../.."   # frontend/
MISE="${MISE:-mise}"
RUN="$MISE exec --"
JOBS="${VERIFY_JOBS:-2}"
LOGDIR="$(mktemp -d "${TMPDIR:-/tmp}/anselm-verify-XXXXXX")"

# Explicit heavy groups; the remainder group is computed so the four PARTITION test/ exactly.
# 显式重组;兜底组现算,保证四组恰好划分 test/。
G0="test/dev"
G1="test/features/chat"
G2="test/core"
G3=""
for d in test/features/*/ test/guards test/app test/perf; do
  d="${d%/}"
  [ -e "$d" ] || continue
  case "$d" in "$G1") continue ;; esac
  G3="$G3 $d"
done

declare -a groups=("$G0" "$G1" "$G2" "$G3")
fail=0
for i in 0 1 2 3; do
	# shellcheck disable=SC2086 — group lists are intentionally word-split 组列表按词分割是本意
	if ! $RUN flutter test -j "$JOBS" ${groups[$i]} > "$LOGDIR/group$i.log" 2>&1; then
		fail=1
    echo ""
    echo "✗ test group $i (${groups[$i]}) FAILED — failure blocks:"
    grep -B1 -A30 "\[E\]$" "$LOGDIR/group$i.log" | head -160
    echo "  (full log: $LOGDIR/group$i.log)"
  fi
done

if [ "$fail" = 0 ]; then
  total=0
  for i in 0 1 2 3; do
    n=$(grep -oE '\+[0-9]+' "$LOGDIR/group$i.log" | tail -1 | tr -d '+')
    total=$((total + ${n:-0}))
  done
  echo "✓ tests green across 4 groups ($total tests)"
  rm -rf "$LOGDIR"
fi
exit "$fail"
