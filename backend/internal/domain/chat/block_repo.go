// block_repo.go — BlockV2Repository port for Phase 1. Coexists with the
// legacy Repository (which still owns Save/Get/List for messages +
// legacy Block) until the Phase 4 cutover, after which BlockV2 paths
// fold into Repository and this file goes away.
//
// block_repo.go ——Phase 1 的 BlockV2Repository port。在 Phase 4 cutover 前
// 与 legacy Repository（仍管 messages + legacy Block 的 Save/Get/List）共
// 存；cutover 后 BlockV2 路径并入 Repository，本文件删除。
package chat

import "context"

// BlockV2Repository is the persistence port for the new event-log
// blocks. The chat-loop dual-writer (Phase 2) calls Save / AppendDelta
// / FinalizeStop alongside the eventlog Bridge so DB and SSE never
// disagree.
//
// BlockV2Repository 是新事件日志 block 的持久化 port。chat-loop 的
// dual-writer（Phase 2）与 eventlog Bridge 同步调 Save / AppendDelta /
// FinalizeStop，避免 DB 与 SSE 分叉。
type BlockV2Repository interface {
	// Save inserts (or overwrites) the row by primary key. Used at
	// block_start emit (status=streaming, content="") and at block_stop
	// emit (status=completed/error/cancelled). Concurrent appends to
	// content are owned by AppendDelta.
	//
	// Save 按主键插入（或覆盖）行。block_start emit 时调（status=streaming
	// content=""）和 block_stop emit 时调（status=completed/error/cancelled）。
	// 对 content 的并发追加由 AppendDelta 拥有。
	Save(ctx context.Context, b *BlockV2) error

	// AppendDelta atomically appends delta to blockID's content.
	// Returns ErrBlockNotFound if blockID does not exist.
	//
	// AppendDelta 原子地把 delta 追加到 blockID 的 content。
	// blockID 不存在时返 ErrBlockNotFound。
	AppendDelta(ctx context.Context, blockID, delta string) error

	// FinalizeStop sets status + error on blockID. Convenience wrapper
	// around Save that callers use at block_stop without rebuilding the
	// full BlockV2 struct.
	//
	// FinalizeStop 给 blockID 设 status + error。调用方在 block_stop 时
	// 用，免去重建完整 BlockV2 struct。
	FinalizeStop(ctx context.Context, blockID, status, errStr string) error

	// GetByID returns blockID's row. ErrBlockNotFound when absent.
	//
	// GetByID 返 blockID 的行。缺失返 ErrBlockNotFound。
	GetByID(ctx context.Context, blockID string) (*BlockV2, error)

	// ListByConversation returns all live blocks of conversationID
	// ordered by seq ASC. Used for history replay (DB → events → UI).
	// Phase 5 will add cursor pagination once we see how big real
	// conversations get; for Phase 1 a simple list is fine since
	// conversations are bounded (~hundreds of events typical).
	//
	// ListByConversation 返 conversationID 的所有 live block，按 seq ASC
	// 排序。给历史回放用（DB → events → UI）。Phase 5 视真实对话规模
	// 加 cursor 分页；Phase 1 简单列表够用（典型 ~百条）。
	ListByConversation(ctx context.Context, conversationID string) ([]*BlockV2, error)

	// ListByMessage returns all blocks belonging to messageID, ordered
	// by seq ASC. Useful for rendering a single message's full block
	// tree without fetching the entire conversation.
	//
	// ListByMessage 返 messageID 的所有 block，按 seq ASC 排序。
	// 渲染单条 message 的完整 block 树时用，不需要拉整个对话。
	ListByMessage(ctx context.Context, messageID string) ([]*BlockV2, error)

	// ReplayEventsAfter returns the blocks-as-events sequence for
	// conversationID with seq > fromSeq, ordered by seq ASC. Used by the
	// /api/v1/conversations/{id}/eventlog?from=<seq> HTTP endpoint when
	// a client receives 410 Gone from the live SSE replay buffer and
	// needs to refetch state from DB.
	//
	// Implementation note: each row produces three envelopes (block_start
	// + block_delta carrying the full Content + block_stop), all sharing
	// the row's seq (logical group). Message_start / message_stop are
	// NOT emitted here — Phase 3 minimal scope; clients combine this
	// with GET /api/v1/conversations/{id}/messages to get message
	// metadata. Phase 5 may extend.
	//
	// ReplayEventsAfter 返 conversationID 中 seq > fromSeq 的 blocks-as-events
	// 序列（seq ASC）。客户端从实时 SSE replay buffer 收到 410 Gone 时
	// 经 /api/v1/conversations/{id}/eventlog?from=<seq> 端点 refetch DB 状态。
	//
	// 实现说明：每行产 3 个 envelope（block_start + block_delta 携完整
	// Content + block_stop），共享行 seq（逻辑组）。message_start /
	// message_stop 不在此发——Phase 3 最小范围；客户端配合
	// GET /api/v1/conversations/{id}/messages 取 message 元数据。Phase 5 扩。
	ReplayEventsAfter(ctx context.Context, conversationID string, fromSeq int64) ([]ReplayEnvelope, error)
}

// ReplayEnvelope is a self-describing wire shape for replayed events.
// Mirrors eventlogdomain.Envelope but flattens type + seq into the
// JSON body so callers reading from HTTP get a uniform shape (the live
// SSE wire puts type/seq into headers; the HTTP refetch endpoint puts
// them in the body).
//
// ReplayEnvelope 是 replayed 事件的自描述 wire 形状。镜像
// eventlogdomain.Envelope 但把 type + seq 拍到 JSON body——HTTP refetch
// 端点客户端拿到统一形状（live SSE wire 把 type/seq 放 header；HTTP refetch
// 放 body）。
type ReplayEnvelope struct {
	Type    string         `json:"type"`
	Seq     int64          `json:"seq"`
	Payload map[string]any `json:"payload"`
}
