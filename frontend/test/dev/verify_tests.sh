#!/usr/bin/env bash
# The verify TEST stage, parallelized by DIRECTORY GROUPS — not `--total-shards`: runtime sharding
# makes every process compile the WHOLE suite's kernel (×N compile tax measured SLOWER than serial:
# 6:11 vs ~5:00), while directory groups let each process compile only its slice. Four groups sized
# to balance (the gallery matrix ≈42% of the suite rides alone; chat is the biggest feature; core is
# its own world; a DYNAMIC remainder group sweeps everything else so a new feature dir lands in a
# group automatically — nothing to maintain). Each group logs to its own file; failures print their
# blocks (nobody greps thousands of scrolled lines). Coverage identical: the groups PARTITION test/.
#
# verify 测试段按目录分组并行——不用 --total-shards:运行时分片让每个进程编译全量 kernel(×N 编译税,
# 实测比串行还慢 6:11 vs ~5:00);目录分组让每进程只编自己那片。四组配平(gallery 矩阵≈42% 独走一组;
# chat 最大 feature;core 自成一组;兜底组动态扫其余——新 feature 目录自动落组,零维护)。各组独立
# log,失败自动打失败块。覆盖等同:四组是 test/ 的完全划分。
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
pids=()
for i in 0 1 2 3; do
  # shellcheck disable=SC2086 — group lists are intentionally word-split 组列表按词分割是本意
  $RUN flutter test -j "$JOBS" ${groups[$i]} > "$LOGDIR/group$i.log" 2>&1 &
  pids+=($!)
done

fail=0
for i in 0 1 2 3; do
  if ! wait "${pids[$i]}"; then
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
