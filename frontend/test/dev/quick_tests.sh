#!/usr/bin/env bash
# `make quick` — the INNER-LOOP gate: format check + analyze + only the tests your diff touches.
# NOT a replacement for `make verify` (the pre-push gate stays full-suite); this is the between-edits
# loop that answers "did I break what I'm working on" in seconds instead of minutes.
#
# Selection: repo paths changed vs QUICK_BASE (default HEAD — i.e. staged+unstaged+untracked) map to
# test dirs by the suite's own mirror layout:
#   lib/features/<x>/**            → test/features/<x>/
#   lib/core/<y>/**                → test/core/<y>/
#   lib/core/{ui,design}/** or
#   lib/dev/gallery*               → + test/dev/ (the gallery matrix — primitives' visual regression;
#                                     feature-only diffs skip it, that's the point)
#   lib/app/**                     → test/app/
#   test/**_test.dart              → that file itself
#   test/guards/                   → ALWAYS runs (seconds; a new lib file must go red early, not at push)
# One `flutter test` invocation for all targets (shared compile). Codegen is NOT run — if the diff
# touches i18n JSON / contract DTOs a reminder is printed (quick never hides a needed `make gen`).
#
# make quick——内环门禁:format 检查 + analyze + 只跑 diff 涉及的测试。不是 verify 的替代(pre-push
# 仍全量);按套件自身的镜像布局把改动路径映射到测试目录,gallery 矩阵只在动了原语/design/gallery 时
# 陪跑,guards 恒跑(新文件要尽早红)。一次 flutter test 跑全部目标(共享编译);不代跑 codegen,
# 触及 i18n/契约时打印提醒。
set -euo pipefail
cd "$(dirname "$0")/../.."   # frontend/
MISE="${MISE:-mise}"
RUN="$MISE exec --"
BASE="${QUICK_BASE:-HEAD}"

# Changed paths relative to frontend/: diff (repo-root-relative, strip the prefix) + untracked
# (cwd-relative already). 改动路径归一为 frontend 相对:diff 剥仓库前缀,untracked 天然 cwd 相对。
changed="$( { git diff --name-only "$BASE" -- . | sed 's|^frontend/||'; \
              git ls-files --others --exclude-standard; } | sort -u )"

targets="test/guards"          # guards always ride along 守卫恒跑
gallery=0
genhint=0
add() { # dedup + only-existing 去重+存在才加
  [ -e "$1" ] || return 0
  case " $targets " in *" $1 "*) return 0 ;; esac
  targets="$targets $1"
}

while IFS= read -r f; do
  [ -n "$f" ] || continue
  case "$f" in
    lib/features/*/*)             add "test/features/$(echo "$f" | cut -d/ -f3)" ;;
    lib/core/ui/*|lib/core/design/*)
                                  gallery=1
                                  add "test/core/$(echo "$f" | cut -d/ -f3)" ;;
    lib/core/contract/*)          genhint=1
                                  add "test/core/contract" ;;
    lib/core/*/*)                 add "test/core/$(echo "$f" | cut -d/ -f3)" ;;
    lib/dev/gallery*)             gallery=1 ;;
    lib/app/*)                    add "test/app" ;;
    lib/i18n/*)                   genhint=1 ;;
    test/*_test.dart)             add "$f" ;;
  esac
done <<EOF
$changed
EOF
[ "$gallery" = 1 ] && add "test/dev"

echo "→ format check…" && $RUN dart format --output=none --set-exit-if-changed lib test \
  || { echo "✗ needs formatting — run: make -C frontend format"; exit 1; }
[ "$genhint" = 1 ] && echo "⚠ diff touches i18n/contract — remember: make -C frontend gen (quick does not run codegen)"
# analyze (~7s) and the tests are independent — run them CONCURRENTLY, wall = max not sum.
# analyze 与测试彼此独立——并发跑,墙钟=max 非 sum。
alog="$(mktemp "${TMPDIR:-/tmp}/anselm-quick-analyze-XXXXXX")"
$RUN flutter analyze > "$alog" 2>&1 &
apid=$!
echo "→ tests (analyze running alongside): $targets"
testrc=0
# shellcheck disable=SC2086 — word-splitting the target list is intended 目标列表按词分割是本意
$RUN flutter test $targets || testrc=$?
if wait "$apid"; then arc=0; else arc=1; fi
if [ "$arc" != 0 ]; then echo "" && echo "✗ analyze:" && cat "$alog"; fi
rm -f "$alog"
[ "$testrc" = 0 ] && [ "$arc" = 0 ] || exit 1
echo "" && echo "✓ quick 绿(analyze + 受影响范围;推送前仍需 make verify 全量)"
