package catalog

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"sort"
	"time"

	"go.uber.org/zap"

	catalogdomain "github.com/sunweilin/forgify/backend/internal/domain/catalog"
	idgenpkg "github.com/sunweilin/forgify/backend/internal/pkg/idgen"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

func historyID() string { return idgenpkg.New("ch") }

// Start loads the disk cache then launches the polling goroutine.
//
// Start 加载磁盘 cache 后启动 polling goroutine。
func (s *Service) Start(ctx context.Context) error {
	cached, err := loadFromDisk(s.cachePath)
	switch {
	case err == nil && cached != nil:
		s.cache.Store(cached)
		s.lastFP.Store(cached.Fingerprint)
		s.versionMu.Lock()
		s.version = cached.Version
		s.versionMu.Unlock()
		s.log.Info("catalog cache loaded from disk",
			zap.String("path", s.cachePath),
			zap.Int("version", cached.Version),
			zap.String("fingerprint", cached.Fingerprint))
	case err != nil:
		s.log.Warn("catalog cache load failed; starting with empty cache",
			zap.String("path", s.cachePath), zap.Error(err))
		s.lastFP.Store("")
	default:
		s.lastFP.Store("")
	}

	pollCtx, pollCancel := context.WithCancel(ctx)
	s.stopCancel = pollCancel
	s.pollDone = make(chan struct{})
	go func() {
		defer close(s.pollDone)
		s.pollLoop(pollCtx)
	}()
	return nil
}

// Stop cancels the polling goroutine and blocks until it drains; idempotent.
//
// Stop 取消 polling goroutine 并阻塞到完全 drain，幂等。
func (s *Service) Stop() {
	s.stopOnce.Do(func() {
		if s.stopCancel != nil {
			s.stopCancel()
		}
		if s.pollDone != nil {
			<-s.pollDone
		}
	})
}

func (s *Service) pollLoop(ctx context.Context) {
	s.tryRefresh(ctx)

	ticker := time.NewTicker(s.pollInterval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			s.tryRefresh(ctx)
		}
	}
}

func (s *Service) tryRefresh(ctx context.Context) {
	if !s.busy.CompareAndSwap(false, true) {
		return
	}
	defer s.busy.Store(false)
	s.RefreshAll(ctx)
}

// RefreshAll fans out Refresh over every user. The polling loop calls this.
// Zero users (fresh install) → silent no-op. nil userList → no-op.
//
// RefreshAll 给每个 user 跑一次 Refresh;0 user 或 nil userList 静默 no-op。
func (s *Service) RefreshAll(ctx context.Context) {
	if s.userList == nil {
		return
	}
	users, err := s.userList.List(context.Background())
	if err != nil {
		s.log.Warn("catalog: list users failed; skipping tick", zap.Error(err))
		return
	}
	for _, u := range users {
		uctx := reqctxpkg.SetUserID(context.Background(), u.ID)
		if err := s.Refresh(uctx); err != nil {
			s.log.Warn("catalog refresh failed for user",
				zap.String("user_id", u.ID), zap.Error(err))
		}
	}
}

// Refresh is the regen entry point used by both the polling fan-out and the
// per-request HTTP refresh handler. Caller MUST supply a ctx with userID
// (reqctxpkg.SetUserID); no fallback.
//
// Refresh 是重新生成入口:polling 和 HTTP :refresh 共用;调用方必须传带 userID 的 ctx。
func (s *Service) Refresh(ctx context.Context) error {
	if _, ok := reqctxpkg.GetUserID(ctx); !ok {
		return fmt.Errorf("catalog.Refresh: %w", reqctxpkg.ErrMissingUserID)
	}

	sources := s.snapshotSources()
	if len(sources) == 0 {
		return nil
	}

	items := []catalogdomain.Item{}
	sourcesAt := map[string]time.Time{}
	gMap := map[string]catalogdomain.Granularity{}
	failedCount := 0

	for _, src := range sources {
		srcItems, err := src.ListItems(ctx)
		if err != nil {
			s.log.Warn("catalog source ListItems failed; substituting empty",
				zap.String("source", src.Name()), zap.Error(err))
			failedCount++
			continue
		}
		items = append(items, srcItems...)
		sourcesAt[src.Name()] = time.Now().UTC()
		gMap[src.Name()] = src.Granularity()
	}

	if failedCount == len(sources) {
		return fmt.Errorf("catalogapp.Refresh: all %d sources failed; keeping previous cache: %w",
			len(sources), catalogdomain.ErrAllSourcesFailed)
	}

	fp := fingerprint(items)
	if last, _ := s.lastFP.Load().(string); last == fp {
		return nil
	}

	var cat *catalogdomain.Catalog
	if s.generator != nil {
		var err error
		cat, err = s.generator.Generate(ctx, items, gMap)
		if err != nil {
			s.log.Warn("catalog Generator failed; using mechanical fallback",
				zap.Error(err))
			cat = mechanicalFallback(items, gMap)
		}
	} else {
		cat = mechanicalFallback(items, gMap)
	}

	cat.Fingerprint = fp
	cat.GeneratedAt = time.Now().UTC()
	cat.Version = s.nextVersion()
	cat.SourcesAt = sourcesAt

	s.cache.Store(cat)
	s.lastFP.Store(fp)
	if err := saveToDisk(s.cachePath, cat); err != nil {
		s.log.Warn("catalog write to disk failed; in-memory cache still updated",
			zap.String("path", s.cachePath), zap.Error(err))
	}
	// §4.7: persist version row for diff inspection (no-op when historyRepo nil).
	//
	// §4.7:持久化版本行(historyRepo nil 时跳过)。
	if s.historyRepo != nil {
		h := &catalogdomain.HistoryEntry{
			ID:          historyID(),
			Version:     cat.Version,
			Summary:     cat.Summary,
			Coverage:    cat.Coverage,
			Fingerprint: cat.Fingerprint,
			GeneratedBy: cat.GeneratedBy,
			SourcesAt:   cat.SourcesAt,
			GeneratedAt: cat.GeneratedAt,
			CreatedAt:   time.Now().UTC(),
		}
		if err := s.historyRepo.Save(ctx, h); err != nil {
			s.log.Warn("catalog history save failed (non-fatal)",
				zap.Int("version", cat.Version), zap.Error(err))
		}
	}
	s.notif.Publish(ctx, "catalog", cat.Fingerprint,
		map[string]any{
			"fingerprint": cat.Fingerprint,
			"version":     cat.Version,
			"generatedAt": cat.GeneratedAt,
		}, "")
	return nil
}

// fingerprint hashes (source + name + description) for each item, sorted.
//
// fingerprint 对每个 item 的 (source + name + description) 排序后哈希。
func fingerprint(items []catalogdomain.Item) string {
	sorted := make([]catalogdomain.Item, len(items))
	copy(sorted, items)
	sort.Slice(sorted, func(i, j int) bool {
		if sorted[i].Source != sorted[j].Source {
			return sorted[i].Source < sorted[j].Source
		}
		return sorted[i].Name < sorted[j].Name
	})
	h := sha256.New()
	for _, it := range sorted {
		h.Write([]byte(it.Source))
		h.Write([]byte{0})
		h.Write([]byte(it.Name))
		h.Write([]byte{0})
		h.Write([]byte(it.Description))
		h.Write([]byte{0})
	}
	return hex.EncodeToString(h.Sum(nil))
}
