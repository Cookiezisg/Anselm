// Package readaloud is the zero-token read-aloud use case (WRK-082 批C, P10): turn a piece of
// text the user is already looking at into playable audio, without an LLM in the loop. It is
// deliberately NOT a tool — a tool call would spend tokens and a turn to do something the user
// already asked for unambiguously by pressing a button.
//
// Its whole design is the cache. Read-aloud is the one place in the system where a user re-issues
// the SAME request on purpose (listening to a message twice is normal), so the second press must
// cost nothing: same text + same voice + same route → the artifact already on disk.
//
// Package readaloud 是零 token 的朗读用例(批C,P10):把用户眼前的一段文字变成可播放音频,回路里
// 没有 LLM。它刻意**不是**工具——工具调用要花 token 和一个回合,去做一件用户按下按钮时已经毫无歧义
// 表达过的事。
//
// 它的整个设计就是那个缓存。朗读是系统里唯一一处用户会**刻意**重发同一请求的地方(同一条消息听两遍
// 很正常),故第二次按下必须零成本:同文本 + 同音色 + 同路由 → 盘上那件已有的产物。
package readaloud

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"sync"
	"unicode/utf8"

	"go.uber.org/zap"

	attachmentdomain "github.com/sunweilin/anselm/backend/internal/domain/attachment"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
	idgenpkg "github.com/sunweilin/anselm/backend/internal/pkg/idgen"
	reqctxpkg "github.com/sunweilin/anselm/backend/internal/pkg/reqctx"
)

// maxReadChars bounds one read-aloud request. It matches the tool's utterance cap: the router
// chunks below this, and a message longer than this is a document, not a message.
//
// maxReadChars 界一次朗读请求。与工具的整段上限一致:路由在其下切块,而比这更长的东西是文档、
// 不是一条消息。
const maxReadChars = 4000

var (
	ErrTextRequired = errorspkg.New(errorspkg.KindInvalid, "READALOUD_TEXT_REQUIRED", "text is required")
	ErrTextTooLong  = errorspkg.New(errorspkg.KindInvalid, "READALOUD_TEXT_TOO_LONG", "text exceeds the read-aloud limit")
)

// Synthesizer is the speech port (satisfied by *generate.Router): text in, audio plus the route's
// identity out. The identity rides back because it belongs in the cache key — and
// SpeechRouteIdentity answers that identity WITHOUT synthesizing, which is what lets a cache hit
// avoid the upstream entirely rather than discovering the hit after paying for it.
//
// Synthesizer 是语音端口(*generate.Router 结构满足):文字进,音频**连同路由身份**出。身份要回传,
// 因为它属于缓存键;而 SpeechRouteIdentity **不合成**就答出这个身份——正是它让命中缓存能完全绕开
// 上游,而不是付完钱才发现本来可以命中。
type Synthesizer interface {
	SynthesizeSpeech(ctx context.Context, text, voice string) (audio llminfra.GeneratedAudio, provider, model, resolvedVoice string, err error)
	SpeechRouteIdentity(ctx context.Context, voice string) (provider, model, resolvedVoice string, err error)
	SpeechAvailable(ctx context.Context) bool
}

// Uploader lands the artifact as a first-class attachment (the ONE media store, 不变量②) and can
// retire an evicted one. *attachmentapp.Service satisfies it structurally.
//
// Uploader 把产物落成一等附件(唯一一间库,不变量②),并能退休被淘汰的那件。
// *attachmentapp.Service 结构满足。
type Uploader interface {
	Upload(ctx context.Context, filename, mime string, data []byte) (*attachmentdomain.Attachment, error)
	Delete(ctx context.Context, id string) error
	Get(ctx context.Context, id string) (*attachmentdomain.Attachment, error)
}

// Service runs read-aloud over its cache.
type Service struct {
	synth       Synthesizer
	att         Uploader
	cache       attachmentdomain.SpeechCacheRepository
	log         *zap.Logger
	budgetBytes int64
	missMu      sync.Mutex
	misses      map[string]*readMiss
}

// readMiss is a per-workspace/key gate for the only part of read-aloud that may spend money. A
// database uniqueness constraint can prevent two rows, but it cannot refund two upstream
// syntheses that raced between Lookup and Put. The gate is process-local because this service is
// the single writer for a desktop backend; the cache's unique index remains the durable fallback.
//
// readMiss 是按 workspace/key 的朗读 miss 闸门,保护唯一可能花钱的那一段。数据库唯一约束可以防两
// 行,却无法退回 Lookup 与 Put 之间竞速的两次上游合成。本 service 是桌面 backend 的单写者,故闸门
// 按进程即可; durable cache 唯一索引仍是最后一道护栏。
type readMiss struct {
	token chan struct{}
	refs  int
}

func NewService(synth Synthesizer, att Uploader, cache attachmentdomain.SpeechCacheRepository, log *zap.Logger) *Service {
	return NewServiceWithBudget(synth, att, cache, attachmentdomain.SpeechCacheBudget, log)
}

// NewServiceWithBudget is the constructor used by the acceptance rig when it needs to make an
// otherwise expensive byte-budget transition observable. Production callers use NewService and
// therefore retain the domain's 50 MiB budget.
//
// NewServiceWithBudget 是验收台架用来把本来昂贵的字节预算转移变得可观察的构造器。生产调用者走
// NewService，故仍然使用领域层固定的 50 MiB 预算。
func NewServiceWithBudget(synth Synthesizer, att Uploader, cache attachmentdomain.SpeechCacheRepository, budgetBytes int64, log *zap.Logger) *Service {
	if log == nil {
		log = zap.NewNop()
	}
	if budgetBytes <= 0 {
		budgetBytes = attachmentdomain.SpeechCacheBudget
	}
	return &Service{
		synth:       synth,
		att:         att,
		cache:       cache,
		log:         log.Named("readaloud"),
		budgetBytes: budgetBytes,
		misses:      make(map[string]*readMiss),
	}
}

// Result is one read-aloud outcome. Cached says whether this press cost anything upstream — the
// front end shows nothing different, but the money story is observable in tests and logs.
//
// Result 是一次朗读的结果。Cached 说明这次按下有没有向上游花钱——前端不会因此显示不同,但这条钱的
// 事实在测试与日志里可观测。
type Result struct {
	Attachment *attachmentdomain.Attachment
	Cached     bool
}

// Available reports whether read-aloud can run at all (honest absence: the button hides when no
// key can speak, exactly like the tool's injection gate).
//
// Available 报告朗读是否根本可用(诚实缺席:没有 key 能说话时按钮就不出现,与工具的注入闸同律)。
func (s *Service) Available(ctx context.Context) bool {
	return s != nil && s.synth != nil && s.synth.SpeechAvailable(ctx)
}

// Read returns playable audio for text, synthesizing only on a cache miss.
//
// Read 返回 text 的可播放音频,只在缓存未命中时才合成。
func (s *Service) Read(ctx context.Context, text, voice string) (*Result, error) {
	text = strings.TrimSpace(text)
	if text == "" {
		return nil, ErrTextRequired
	}
	if utf8.RuneCountInString(text) > maxReadChars {
		return nil, ErrTextTooLong
	}

	// Probe BEFORE synthesizing: the route identity is resolvable without calling any upstream, so
	// a repeat listen never reaches the provider at all. Probing after synthesis would still be
	// correct and still cost money — which is the entire thing this feature must not do.
	// 合成**之前**先探:路由身份不打上游就能解析出来,故重听根本不会走到 provider。合成后再探同样
	// 正确、同样花钱——而那恰是这个功能绝不能做的事。
	if hit, err := s.probe(ctx, text, voice); err == nil && hit != nil {
		return hit, nil
	}

	// A second request may have passed the first probe at the same time. Serialize only cache
	// misses, then probe again after taking the gate; the follower now returns the first request's
	// attachment without touching the synthesizer.
	// 第二个请求可能同时通过第一次探测。只串行化 miss,拿到闸后再次探测; follower 此时直接返回
	// 第一个请求的附件,完全不碰 synthesizer。
	release, err := s.acquireMiss(ctx, text, voice)
	if err != nil {
		return nil, err
	}
	defer release()
	if hit, err := s.probe(ctx, text, voice); err == nil && hit != nil {
		return hit, nil
	}

	audio, provider, model, resolvedVoice, err := s.synth.SynthesizeSpeech(ctx, text, voice)
	if err != nil {
		return nil, err
	}
	key := attachmentdomain.SpeechCacheKey(text, resolvedVoice, provider, model)
	// Between the pre-probe and here another press may have landed the same artifact; take theirs
	// rather than paying for a second copy of identical bytes.
	// 预探到此之间,另一次按下可能已经落了同一件产物;用它们那件,而不是为一份完全相同的字节再付一次。
	if hit, err := s.lookup(ctx, key); err == nil && hit != nil {
		return hit, nil
	}

	att, err := s.att.Upload(reqctxpkg.SetMediaSource(ctx, "read_aloud"),
		readFilename(audio.Mime), audio.Mime, audio.Bytes)
	if err != nil {
		return nil, fmt.Errorf("save read-aloud artifact: %w", err)
	}
	entry := &attachmentdomain.SpeechCacheEntry{
		ID: idgenpkg.New("spc"), CacheKey: key, AttachmentID: att.ID, SizeBytes: att.SizeBytes,
	}
	evicted, err := s.cache.Put(ctx, entry, s.budgetBytes)
	if err != nil {
		// A cache write failure must not lose the audio the user is waiting for — the artifact is
		// already persisted and playable; the only cost is that the next press re-synthesizes.
		// 缓存写失败不得弄丢用户正在等的音频——产物已落盘可播;唯一代价是下次按下要重合成。
		s.log.Warn("read-aloud cache write failed (artifact kept)", zap.Error(err))
		return &Result{Attachment: att}, nil
	}
	for _, id := range evicted {
		if err := s.att.Delete(ctx, id); err != nil {
			s.log.Warn("evicted read-aloud artifact not deleted", zap.String("attachmentId", id), zap.Error(err))
		}
	}
	return &Result{Attachment: att}, nil
}

func (s *Service) acquireMiss(ctx context.Context, text, voice string) (func(), error) {
	key := missKey(ctx, text, voice)
	s.missMu.Lock()
	if s.misses == nil {
		s.misses = make(map[string]*readMiss)
	}
	gate := s.misses[key]
	if gate == nil {
		gate = &readMiss{token: make(chan struct{}, 1)}
		gate.token <- struct{}{}
		s.misses[key] = gate
	}
	gate.refs++
	s.missMu.Unlock()

	select {
	case <-gate.token:
		return func() { s.releaseMiss(key, gate, true) }, nil
	case <-ctx.Done():
		s.releaseMiss(key, gate, false)
		return nil, ctx.Err()
	}
}

func (s *Service) releaseMiss(key string, gate *readMiss, ownsToken bool) {
	if ownsToken {
		gate.token <- struct{}{}
	}
	s.missMu.Lock()
	gate.refs--
	if gate.refs == 0 {
		delete(s.misses, key)
	}
	s.missMu.Unlock()
}

func missKey(ctx context.Context, text, voice string) string {
	workspaceID, _ := reqctxpkg.GetWorkspaceID(ctx)
	return workspaceID + "\x00" + text + "\x00" + voice
}

// probe checks the cache for the route we are ABOUT to take, without synthesizing.
//
// probe 在**将要**走的路由上查缓存,不合成。
func (s *Service) probe(ctx context.Context, text, voice string) (*Result, error) {
	provider, model, resolvedVoice, err := s.synth.SpeechRouteIdentity(ctx, voice)
	if err != nil {
		return nil, err
	}
	return s.lookup(ctx, attachmentdomain.SpeechCacheKey(text, resolvedVoice, provider, model))
}

// lookup resolves a cache key to a still-live attachment. A row whose attachment is gone (a
// manual delete, a stale row) is treated as a miss rather than a 404 handed to the player.
//
// lookup 把缓存键解析成一个**仍在**的附件。附件已消失的行(手动删、陈旧行)按未命中处理,而不是把
// 一个 404 交给播放器。
func (s *Service) lookup(ctx context.Context, key string) (*Result, error) {
	entry, err := s.cache.Lookup(ctx, key)
	if err != nil || entry == nil {
		return nil, err
	}
	att, err := s.att.Get(ctx, entry.AttachmentID)
	if errors.Is(err, attachmentdomain.ErrNotFound) {
		// An attachment can be retired independently by manual cleanup or blob/cache maintenance.
		// Remove only the proven dangling mapping; preserving a row on an unrelated storage error is
		// safer than deleting a cache entry whose target may still exist.
		// 附件可能被手动清理或媒体回收独立退休。只清除已证实悬空的映射;无关存储错误不删缓存,
		// 因为目标可能仍然存在。
		if err := s.cache.Delete(ctx, key); err != nil {
			return nil, fmt.Errorf("remove stale read-aloud cache entry: %w", err)
		}
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	if att == nil {
		return nil, errors.New("attachment lookup returned nil without an error")
	}
	return &Result{Attachment: att, Cached: true}, nil
}

func readFilename(mime string) string {
	ext := "wav"
	switch mime {
	case "audio/mpeg", "audio/mp3":
		ext = "mp3"
	case "audio/ogg", "audio/opus":
		ext = "ogg"
	}
	return "read-aloud." + ext
}
