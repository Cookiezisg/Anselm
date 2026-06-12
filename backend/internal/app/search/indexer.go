package search

import (
	"context"
	"sync"
	"time"

	"go.uber.org/zap"

	searchdomain "github.com/sunweilin/forgify/backend/internal/domain/search"
	reqctxpkg "github.com/sunweilin/forgify/backend/internal/pkg/reqctx"
)

// queueSize bounds the change queue. Enqueue never blocks a business write:
// overflow drops the event and boot reconcile heals the gap.
//
// queueSize 限定变更队列。Enqueue 绝不阻塞业务写：溢出丢事件，boot 对账兜底。
const queueSize = 1024

// stampSlack absorbs the driver's datetime round-trip precision loss when
// comparing live vs indexed timestamps — without it every reconcile would
// re-index everything.
//
// stampSlack 吸收驱动 datetime 往返的精度损耗——没有它每次对账都会全量重索。
const stampSlack = time.Millisecond

type change struct {
	ws     string
	t      searchdomain.EntityType
	id     string
	anchor string
}

// Indexer is the write side: a non-blocking queue drained by ONE worker (no
// row-level races by construction), plus the reconcile that diffs sources
// against the index at boot / on demand. It is the searchdomain.Notifier the
// entity Services call.
//
// Indexer 是写侧：非阻塞队列 + 单 worker 消费（构造性无行级竞态），外加 boot/按需
// 把 source 与索引求差的对账。它就是实体 Service 调用的 searchdomain.Notifier。
type Indexer struct {
	repo    searchdomain.Repository
	sources map[searchdomain.EntityType]Source
	log     *zap.Logger

	ch   chan change
	quit chan struct{}
	wg   sync.WaitGroup

	// onApplied fires after a successful projection write — the embed backfill
	// kick (set by the Service before start).
	// onApplied 在投影写成功后触发——嵌入补算 kick（Service 在 start 前设置）。
	onApplied func(ws string)
}

var _ searchdomain.Notifier = (*Indexer)(nil)

func newIndexer(repo searchdomain.Repository, sources map[searchdomain.EntityType]Source, log *zap.Logger) *Indexer {
	return &Indexer{
		repo:    repo,
		sources: sources,
		log:     log,
		ch:      make(chan change, queueSize),
		quit:    make(chan struct{}),
	}
}

func (ix *Indexer) start() {
	ix.wg.Go(func() {
		for {
			select {
			case c := <-ix.ch:
				ix.apply(c)
			case <-ix.quit:
				return
			}
		}
	})
}

// close stops the worker; queued events are dropped (reconcile heals on next
// boot), which keeps shutdown prompt.
//
// close 停 worker；在队事件丢弃（下次 boot 对账兜底），保证关停迅速。
func (ix *Indexer) close() {
	close(ix.quit)
	ix.wg.Wait()
}

// Changed implements searchdomain.Notifier: capture the workspace now (the
// worker runs detached), enqueue without blocking.
//
// Changed 实现 searchdomain.Notifier：当下捕获 workspace（worker 跑 detached），
// 非阻塞入队。
func (ix *Indexer) Changed(ctx context.Context, t searchdomain.EntityType, entityID, anchor string) {
	wsID, err := reqctxpkg.RequireWorkspaceID(ctx)
	if err != nil {
		ix.log.Warn("search: change without workspace dropped", zap.String("type", string(t)), zap.String("id", entityID))
		return
	}
	select {
	case ix.ch <- change{ws: wsID, t: t, id: entityID, anchor: anchor}:
	default:
		ix.log.Warn("search: index queue full, change dropped (boot reconcile heals)",
			zap.String("type", string(t)), zap.String("id", entityID))
	}
}

// apply projects one change under a detached workspace ctx (S9): incremental
// anchor first, else full re-projection; an empty projection means the entity
// is gone.
//
// apply 在 detached workspace ctx（S9）下投影一个变更：先走 anchor 增量，否则整体
// 重投影；投影为空即实体已无。
func (ix *Indexer) apply(c change) {
	ctx := reqctxpkg.Detached(c.ws)
	src, ok := ix.sources[c.t]
	if !ok {
		ix.log.Warn("search: no source registered", zap.String("type", string(c.t)))
		return
	}
	if c.anchor != "" {
		if inc, ok := src.(IncrementalSource); ok {
			doc, found, err := inc.DocAt(ctx, c.id, c.anchor)
			if err != nil {
				ix.log.Warn("search: DocAt failed", zap.String("type", string(c.t)), zap.String("id", c.id), zap.Error(err))
				return
			}
			if found {
				if doc == nil {
					return // nothing to index for this anchor. 该锚无可索。
				}
				if err := ix.repo.UpsertDocAt(ctx, c.t, c.id, *doc); err != nil {
					ix.log.Warn("search: upsert failed", zap.String("id", c.id), zap.Error(err))
				} else if ix.onApplied != nil {
					ix.onApplied(c.ws)
				}
				return
			}
			// Anchor unknown (e.g. purged) — fall through to a full projection.
			// anchor 不在（如已清）——落到整体投影。
		}
	}
	docs, err := src.Docs(ctx, c.id)
	if err != nil {
		ix.log.Warn("search: Docs failed", zap.String("type", string(c.t)), zap.String("id", c.id), zap.Error(err))
		return
	}
	if err := ix.repo.ReplaceDocs(ctx, c.t, c.id, docs); err != nil {
		ix.log.Warn("search: replace failed", zap.String("type", string(c.t)), zap.String("id", c.id), zap.Error(err))
	} else if ix.onApplied != nil {
		ix.onApplied(c.ws)
	}
}

// reconcile diffs every source against the index for ONE workspace ctx and
// enqueues the difference: changed/new entities re-project, orphans delete.
// The index is derived data — this loop is the single self-healing mechanism
// behind dropped events, crashes and schema rebuilds.
//
// reconcile 在单个 workspace ctx 内把每个 source 与索引求差并入队：变更/新增重投影、
// 孤儿删除。索引是派生数据——这条循环是丢事件/崩溃/schema 重建背后唯一的自愈机制。
func (ix *Indexer) reconcile(ctx context.Context, wsID string) {
	for t, src := range ix.sources {
		live, err := src.Stamps(ctx)
		if err != nil {
			ix.log.Warn("search reconcile: stamps failed", zap.String("type", string(t)), zap.Error(err))
			continue
		}
		indexed, err := ix.repo.EntityStamps(ctx, t)
		if err != nil {
			ix.log.Warn("search reconcile: index stamps failed", zap.String("type", string(t)), zap.Error(err))
			continue
		}
		for id, ts := range live {
			if idxTS, ok := indexed[id]; !ok || ts.Sub(idxTS) > stampSlack {
				ix.enqueue(change{ws: wsID, t: t, id: id})
			}
		}
		for id := range indexed {
			if _, ok := live[id]; !ok {
				ix.enqueue(change{ws: wsID, t: t, id: id}) // Docs → empty → delete. Docs → 空 → 删。
			}
		}
	}
}

// enqueue blocks (unlike Changed): reconcile is a background loop, losing its
// own backlog would defeat the healing.
//
// enqueue 阻塞（与 Changed 不同）：对账是后台循环，丢自己的积压就谈不上自愈了。
func (ix *Indexer) enqueue(c change) {
	select {
	case ix.ch <- c:
	case <-ix.quit:
	}
}
