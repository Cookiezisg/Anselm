package attachment

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"time"
)

// SpeechCacheEntry maps ONE synthesis request to the attachment it produced (WRK-082 批C, P10).
// Read-aloud is the only feature in the system where the user re-issues the SAME request on
// purpose — listening to a message twice is normal — so without this row the second listen pays
// the upstream again for bytes that are already on disk.
//
// It is a DERIVED CACHE, not business data: every row is reconstructible by re-synthesizing, and
// eviction is the point rather than an exception. That is why its rows are PHYSICALLY deleted
// (see database.md's speech_cache clause) while the attachment they point at is only
// soft-deleted — the blob GC then reclaims the bytes on its own schedule.
//
// SpeechCacheEntry 把**一次**合成请求映到它产出的附件(批C,P10)。朗读是系统里唯一一处用户会**刻意**
// 重发同一请求的功能——同一条消息听两遍很正常——故没有这行,第二次听就要为盘上已有的字节再向上游付一次钱。
//
// 它是**派生缓存**、不是业务数据:每一行都能靠重新合成重建,而淘汰是它的**目的**、不是例外。故其行
// **物理删**(见 database.md 的 speech_cache 条款),而它指向的附件只软删——字节由 blob GC 按自己的
// 节奏回收。
type SpeechCacheEntry struct {
	ID           string    `db:"id,pk"              json:"id"` // spc_<16hex>
	WorkspaceID  string    `db:"workspace_id,ws"    json:"-"`
	CacheKey     string    `db:"cache_key"          json:"cacheKey"`
	AttachmentID string    `db:"attachment_id"      json:"attachmentId"`
	SizeBytes    int64     `db:"size_bytes"         json:"sizeBytes"`
	CreatedAt    time.Time `db:"created_at,created" json:"createdAt"`
	LastUsedAt   time.Time `db:"last_used_at"       json:"lastUsedAt"`
}

// SpeechCacheBudget is the per-workspace byte ceiling for cached read-aloud audio (P10: 50 MB).
// At 24 kHz/16-bit/mono (~48 KB per second) that is roughly 18 minutes of speech — enough that
// re-reading a conversation costs nothing, small enough that it never becomes a disk problem.
//
// SpeechCacheBudget 是朗读缓存的 per-workspace 字节上限(P10:50MB)。按 24kHz/16bit/mono(≈48KB/秒)
// 约合 18 分钟语音——足以让重读一段对话零成本,又小到永远不会变成磁盘问题。
const SpeechCacheBudget = int64(50) << 20

// SpeechCacheKey is the identity of a synthesis request. Voice and provider/model are IN the key
// because the same text spoken by a different voice is a different artifact — keying on text
// alone would serve a user who switched voices the OLD voice forever, which reads as "the voice
// setting does nothing".
//
// SpeechCacheKey 是一次合成请求的身份。音色与 provider/model **在键里**,因为同一段文字换个音色就是
// 另一件产物——只按文本做键,会让换了音色的用户永远听到**旧**音色,读起来就是「音色设置没用」。
func SpeechCacheKey(text, voice, provider, model string) string {
	sum := sha256.Sum256([]byte(text + "\x00" + voice + "\x00" + provider + "\x00" + model))
	return hex.EncodeToString(sum[:])
}

// SpeechCacheRepository is the cache's storage contract.
//
// SpeechCacheRepository 是缓存的存储契约。
type SpeechCacheRepository interface {
	// Lookup returns the entry for a key, or ErrNotFound. It also refreshes LastUsedAt — the
	// recency signal only exists if reads write it.
	// Lookup 按键取行,无则 ErrNotFound。它同时刷新 LastUsedAt——读不写这个字段,近期性信号就不存在。
	Lookup(ctx context.Context, key string) (*SpeechCacheEntry, error)
	// Put records a new entry and evicts least-recently-used rows past the budget, returning the
	// attachment ids whose rows were dropped (the caller soft-deletes them).
	// Put 记一行并按 LRU 淘汰超预算的行,返回被丢弃行的附件 id(由调用方软删)。
	Put(ctx context.Context, e *SpeechCacheEntry, budgetBytes int64) (evicted []string, err error)
}
