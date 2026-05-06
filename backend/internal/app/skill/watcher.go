// watcher.go — fsnotify-driven live rescan of ~/.forgify/skills/. The
// user can drop a new skill folder, edit a SKILL.md, or delete a skill
// without restarting backend; debounced 500ms after burst events to
// collapse "save 12 files in a row" editor patterns into one Scan.
//
// Per skill.md §6 + §9.5:
//   - Watches every subdirectory recursively (so editing a nested file
//     under skills/foo/scripts/ also triggers rescan)
//   - EvalSymlinks + visited-set guards against symlink loops that would
//     otherwise have fsnotify recurse forever
//   - On Linux the kernel fd limit can rejected the AddWatch call; we
//     fail-soft (log Warn, fall back to a 5-min poll loop) rather than
//     refuse to start
//   - SSE 'skill' event publishing is owned by Service.Scan (called from
//     the watcher) — watcher itself never publishes
//
// Lifecycle: Watcher.Start blocks until ctx.Done; production calls it in
// a goroutine with the shutdown ctx. Cleanup closes the fsnotify.Watcher
// + the debounce ticker.
//
// watcher.go ——fsnotify 驱动的 ~/.forgify/skills/ 实时重扫。用户加目录、
// 编辑 SKILL.md、删 skill 无需重启后端；burst 事件 500ms debounce 让
// "一口气保存 12 个文件" 收敛成一次 Scan。
//
// skill.md §6 + §9.5：递归 watch 每个子目录；EvalSymlinks + visited-set
// 防 symlink 循环；Linux fd-limit 失败 fail-soft（5min poll fallback）；
// SSE 'skill' 由 Service.Scan 发，watcher 不发。
package skill

import (
	"context"
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"sync"
	"syscall"
	"time"

	"github.com/fsnotify/fsnotify"
	"go.uber.org/zap"
)

// debounceWindow collapses fsnotify event bursts into one Scan. Editors
// commonly write swap files / temp files in the same save → without
// debounce we'd Scan 5-10 times per "save". 500ms is enough to coalesce
// burst, short enough that the user perceives the rescan as instant.
//
// debounceWindow 把 fsnotify 事件 burst 收敛成一次 Scan。编辑器常在一次
// 保存里写 swap / temp → 无 debounce 会 Scan 5-10 次。500ms 足够收敛
// burst，短到用户感觉重扫即时。
const debounceWindow = 500 * time.Millisecond

// fallbackPollInterval is the 5-minute backstop when fsnotify is
// unavailable (Linux fd exhaust / NFS / etc.). User edits will surface
// within this window even if no events fire.
//
// fallbackPollInterval 是 fsnotify 不可用（Linux fd 耗尽 / NFS 等）时的
// 5-min 兜底。该窗口内必触发一次 rescan 兜住用户编辑。
const fallbackPollInterval = 5 * time.Minute

// Watcher binds the Service to fsnotify. One instance per Service —
// constructed in main.go after Scan, started in a goroutine with the
// shutdown ctx.
//
// Watcher 把 Service 绑到 fsnotify。每 Service 一份；main.go 在 Scan 后
// 构造，shutdown ctx goroutine 里启动。
type Watcher struct {
	svc *Service
	log *zap.Logger
}

// NewWatcher constructs a Watcher around svc.
//
// NewWatcher 围 svc 构造 Watcher。
func NewWatcher(svc *Service, log *zap.Logger) *Watcher {
	if log == nil {
		log = zap.NewNop()
	}
	return &Watcher{svc: svc, log: log.Named("skill.watcher")}
}

// Start blocks running the fsnotify loop until ctx.Done. If fsnotify
// itself fails to initialize OR adding watches exhausts the fd budget,
// fall back to a 5-min poll loop so user edits still surface (slowly).
//
// Start 阻塞跑 fsnotify 循环直到 ctx.Done。fsnotify 起不来 OR 加 watch
// 耗 fd budget，回 5-min poll 兜住（慢，但起码能用）。
func (w *Watcher) Start(ctx context.Context) error {
	dir := w.svc.SkillsDir()
	if dir == "" {
		return errors.New("skill.Watcher.Start: SkillsDir is empty")
	}

	fsw, err := fsnotify.NewWatcher()
	if err != nil {
		w.log.Warn("fsnotify init failed; falling back to poll",
			zap.Error(err), zap.Duration("interval", fallbackPollInterval))
		return w.runPollFallback(ctx)
	}
	defer fsw.Close()

	// Add the root + every existing subdirectory recursively. New
	// subdirectories created later are picked up by the Create event
	// loop below (we add the watch on the fly).
	// 加根 + 每个已存在子目录递归。后续新建子目录由下面的 Create 事件
	// 即时加 watch。
	if err := w.addRecursive(fsw, dir); err != nil {
		// fd-limit failure here is non-fatal; we still have a partial
		// watch set + the poll fallback as backstop.
		// fd-limit 失败非致命；仍有部分 watch + poll 兜底。
		w.log.Warn("partial watch setup; some subdirs not monitored",
			zap.String("dir", dir), zap.Error(err))
	}

	// Debounce timer: fire deferred Scan after debounceWindow of quiet.
	// Reset on each event, so a burst of 50 events in 100ms = single Scan.
	// debounce timer：debounceWindow 静默后触发 Scan；每次事件 Reset，
	// 100ms 内 50 事件 burst = 单次 Scan。
	var debounceTimer *time.Timer
	var debounceMu sync.Mutex
	scheduleScan := func() {
		debounceMu.Lock()
		defer debounceMu.Unlock()
		if debounceTimer != nil {
			debounceTimer.Stop()
		}
		debounceTimer = time.AfterFunc(debounceWindow, func() {
			scanCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
			defer cancel()
			if err := w.svc.Scan(scanCtx); err != nil {
				w.log.Warn("rescan failed", zap.Error(err))
			}
		})
	}

	// Backstop poll alongside fsnotify in case events are missed (NFS,
	// container fs quirks). Cheap — one Scan every 5 min.
	// 与 fsnotify 并存的 backstop poll，覆盖丢事件场景（NFS / 容器 fs）。
	// 5 min 一次 Scan，几乎无成本。
	pollTicker := time.NewTicker(fallbackPollInterval)
	defer pollTicker.Stop()

	for {
		select {
		case <-ctx.Done():
			return nil

		case event, ok := <-fsw.Events:
			if !ok {
				return errors.New("skill.Watcher: fsnotify channel closed unexpectedly")
			}
			// New directory created → add it to the watch set so future
			// edits below it are observed. Best-effort; if we can't
			// stat/AddWatch, we'll catch up via the next poll.
			// 新目录 → 加入 watch 集让后续编辑被观察。Best-effort；stat /
			// AddWatch 失败靠下次 poll 兜住。
			if event.Op&fsnotify.Create == fsnotify.Create {
				if info, err := os.Stat(event.Name); err == nil && info.IsDir() {
					if err := w.addRecursive(fsw, event.Name); err != nil {
						w.log.Debug("addRecursive on new dir failed",
							zap.String("dir", event.Name), zap.Error(err))
					}
				}
			}
			scheduleScan()

		case err, ok := <-fsw.Errors:
			if !ok {
				return errors.New("skill.Watcher: fsnotify error channel closed unexpectedly")
			}
			w.log.Warn("fsnotify error", zap.Error(err))

		case <-pollTicker.C:
			scanCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
			if err := w.svc.Scan(scanCtx); err != nil {
				w.log.Warn("backstop poll rescan failed", zap.Error(err))
			}
			cancel()
		}
	}
}

// addRecursive adds dir and every nested directory under it to fsw.
// Symlink loops are detected via EvalSymlinks + visited set so a user
// who symlinks ~/.forgify/skills/foo back to the parent dir doesn't
// hang the watcher.
//
// addRecursive 把 dir 及其下每个嵌套目录加到 fsw。EvalSymlinks +
// visited 防 ~/.forgify/skills/foo 软链回父目录把 watcher 挂死。
func (w *Watcher) addRecursive(fsw *fsnotify.Watcher, dir string) error {
	visited := map[string]bool{}
	return w.addRecursiveInner(fsw, dir, visited)
}

func (w *Watcher) addRecursiveInner(fsw *fsnotify.Watcher, dir string, visited map[string]bool) error {
	real, err := filepath.EvalSymlinks(dir)
	if err != nil {
		// Dir might not exist (we're called on Create events that race
		// the dir's removal). Caller logs at Debug.
		// 目录可能不存在（Create 事件与删除竞态）。调用方 Debug log。
		return err
	}
	if visited[real] {
		w.log.Warn("symlink loop detected; skipping",
			zap.String("dir", dir), zap.String("real", real))
		return nil
	}
	visited[real] = true

	if err := fsw.Add(real); err != nil {
		// ENOSPC on Linux = inotify watch limit reached. Surface once;
		// subsequent failures suppressed at Debug since the message is
		// the same and the user already knows from the first.
		// Linux ENOSPC = inotify watch 上限。首次 Warn；后续 Debug 抑制
		// 重复（用户首次已知）。
		if errors.Is(err, syscall.ENOSPC) {
			w.log.Warn("inotify watch limit reached; skipping rest of tree (poll fallback active)",
				zap.String("dir", real))
			return err
		}
		w.log.Debug("add watch failed", zap.String("dir", real), zap.Error(err))
		return err
	}

	entries, err := os.ReadDir(real)
	if err != nil {
		if errors.Is(err, fs.ErrNotExist) {
			return nil
		}
		return err
	}
	for _, ent := range entries {
		if ent.IsDir() {
			child := filepath.Join(real, ent.Name())
			if err := w.addRecursiveInner(fsw, child, visited); err != nil {
				// Don't abort the walk on per-child failures — log
				// debug + continue. addRecursive top-level callers
				// only care about the root succeeding.
				// per-child 失败不中断走查——debug log 续行。顶层调用者
				// 只关心根成功。
				w.log.Debug("subdir add failed",
					zap.String("dir", child), zap.Error(err))
			}
		}
	}
	return nil
}

// runPollFallback is what we run when fsnotify init outright fails
// (rare; usually a permissions or kernel-config issue). One Scan every
// fallbackPollInterval until ctx.Done.
//
// runPollFallback 在 fsnotify init 完全失败时跑（罕见；权限或内核配置
// 问题）。fallbackPollInterval 一次 Scan 直到 ctx.Done。
func (w *Watcher) runPollFallback(ctx context.Context) error {
	ticker := time.NewTicker(fallbackPollInterval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return nil
		case <-ticker.C:
			scanCtx, cancel := context.WithTimeout(ctx, 30*time.Second)
			if err := w.svc.Scan(scanCtx); err != nil {
				w.log.Warn("poll-fallback rescan failed", zap.Error(err))
			}
			cancel()
		}
	}
}
