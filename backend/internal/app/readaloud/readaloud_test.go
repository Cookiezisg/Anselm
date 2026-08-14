package readaloud

import (
	"context"
	"errors"
	"strings"
	"sync"
	"testing"
	"time"

	"go.uber.org/zap"

	attachmentdomain "github.com/sunweilin/anselm/backend/internal/domain/attachment"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
)

// The one thing this feature must never do is charge twice for the same listen. Every test here
// counts UPSTREAM CALLS, not just outcomes: a cache that returns the right bytes while still
// paying the provider would pass any assertion about the audio and fail the entire point.
//
// 这个功能唯一绝不能做的事,就是为同一次听收两遍钱。这里每个测试都数**上游调用次数**、而不只看结果:
// 一个「返回了正确字节但照样向上游付钱」的缓存,能通过任何关于音频的断言,却输掉了它的全部意义。

type fakeSynth struct {
	calls     int
	provider  string
	model     string
	voice     string
	available bool
	err       error
	routeErr  error
}

type gatedSynth struct {
	mu       sync.Mutex
	calls    int
	started  chan struct{}
	second   chan struct{}
	release  chan struct{}
	provider string
	model    string
	voice    string
}

func (f *gatedSynth) SynthesizeSpeech(_ context.Context, text, voice string) (llminfra.GeneratedAudio, string, string, string, error) {
	f.mu.Lock()
	f.calls++
	call := f.calls
	f.mu.Unlock()
	if call == 1 {
		close(f.started)
		<-f.release
	} else if call == 2 {
		close(f.second)
	}
	if voice == "" {
		voice = f.voice
	}
	return llminfra.GeneratedAudio{Bytes: []byte("audio:" + text), Mime: "audio/wav"}, f.provider, f.model, voice, nil
}

func (f *gatedSynth) SpeechRouteIdentity(_ context.Context, voice string) (string, string, string, error) {
	if voice == "" {
		voice = f.voice
	}
	return f.provider, f.model, voice, nil
}

func (f *gatedSynth) SpeechAvailable(context.Context) bool { return true }

func (f *fakeSynth) SynthesizeSpeech(_ context.Context, text, voice string) (llminfra.GeneratedAudio, string, string, string, error) {
	f.calls++
	if f.err != nil {
		return llminfra.GeneratedAudio{}, "", "", "", f.err
	}
	if voice == "" {
		voice = f.voice
	}
	return llminfra.GeneratedAudio{Bytes: []byte("audio:" + text), Mime: "audio/wav"}, f.provider, f.model, voice, nil
}

func (f *fakeSynth) SpeechRouteIdentity(_ context.Context, voice string) (string, string, string, error) {
	if f.routeErr != nil {
		return "", "", "", f.routeErr
	}
	if voice == "" {
		voice = f.voice
	}
	return f.provider, f.model, voice, nil
}

func (f *fakeSynth) SpeechAvailable(context.Context) bool { return f.available }

type fakeAtt struct {
	mu      sync.Mutex
	rows    map[string]*attachmentdomain.Attachment
	deleted []string
	n       int
	getErr  error
}

func newFakeAtt() *fakeAtt {
	return &fakeAtt{rows: map[string]*attachmentdomain.Attachment{}}
}

func (f *fakeAtt) Upload(_ context.Context, filename, mime string, data []byte) (*attachmentdomain.Attachment, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.n++
	a := &attachmentdomain.Attachment{
		ID:       "att_" + strings.Repeat("0", 15) + string(rune('a'+f.n-1)),
		Filename: filename, MimeType: mime, SizeBytes: int64(len(data)), Kind: attachmentdomain.KindAudio,
	}
	f.rows[a.ID] = a
	return a, nil
}

func (f *fakeAtt) Delete(_ context.Context, id string) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.deleted = append(f.deleted, id)
	delete(f.rows, id)
	return nil
}

func (f *fakeAtt) Get(_ context.Context, id string) (*attachmentdomain.Attachment, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.getErr != nil {
		return nil, f.getErr
	}
	a, ok := f.rows[id]
	if !ok {
		return nil, attachmentdomain.ErrNotFound
	}
	return a, nil
}

type fakeCache struct {
	mu      sync.Mutex
	rows    map[string]*attachmentdomain.SpeechCacheEntry
	putErr  error
	evicted []string
	deleted []string
}

func newFakeCache() *fakeCache {
	return &fakeCache{rows: map[string]*attachmentdomain.SpeechCacheEntry{}}
}

func (f *fakeCache) Lookup(_ context.Context, key string) (*attachmentdomain.SpeechCacheEntry, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	e, ok := f.rows[key]
	if !ok {
		return nil, attachmentdomain.ErrNotFound
	}
	return e, nil
}

func (f *fakeCache) Delete(_ context.Context, key string) error {
	f.mu.Lock()
	defer f.mu.Unlock()
	f.deleted = append(f.deleted, key)
	delete(f.rows, key)
	return nil
}

func (f *fakeCache) Put(_ context.Context, e *attachmentdomain.SpeechCacheEntry, _ int64) ([]string, error) {
	f.mu.Lock()
	defer f.mu.Unlock()
	if f.putErr != nil {
		return nil, f.putErr
	}
	f.rows[e.CacheKey] = e
	out := f.evicted
	f.evicted = nil
	return out, nil
}

func newSvc(synth Synthesizer, att *fakeAtt, cache *fakeCache) *Service {
	return NewService(synth, att, cache, zap.NewNop())
}

// TestRead_ConcurrentIdenticalPressesCostOnce is the race that sequential cache assertions miss:
// two requests can both observe a miss before either has written the row. The miss path must merge
// them before synthesis, not merely let the unique database index discard the second artifact.
func TestRead_ConcurrentIdenticalPressesCostOnce(t *testing.T) {
	synth := &gatedSynth{
		started:  make(chan struct{}),
		second:   make(chan struct{}),
		release:  make(chan struct{}),
		provider: "qwen",
		model:    "qwen-audio-3.0-tts-flash",
		voice:    "longanhuan_v3.6",
	}
	att, cache := newFakeAtt(), newFakeCache()
	svc := newSvc(synth, att, cache)
	type result struct {
		out *Result
		err error
	}
	results := make(chan result, 2)
	go func() {
		out, err := svc.Read(context.Background(), "并发朗读", "")
		results <- result{out: out, err: err}
	}()
	<-synth.started
	go func() {
		out, err := svc.Read(context.Background(), "并发朗读", "")
		results <- result{out: out, err: err}
	}()
	// Before the keyed gate existed, the follower reached the synthesizer here. With the fix it
	// waits on the gate instead; the bounded select keeps the regression deterministic in both
	// shapes while the final call count remains the money assertion.
	select {
	case <-synth.second:
	case <-time.After(50 * time.Millisecond):
	}
	close(synth.release)
	first, second := <-results, <-results
	if first.err != nil || second.err != nil {
		t.Fatalf("concurrent reads failed: first=%v second=%v", first.err, second.err)
	}
	if synth.calls != 1 {
		t.Fatalf("concurrent identical reads synthesized %d times, want 1", synth.calls)
	}
	if first.out == nil || second.out == nil || first.out.Attachment.ID != second.out.Attachment.ID {
		t.Fatalf("concurrent identical reads must share one attachment: first=%+v second=%+v", first.out, second.out)
	}
	if first.out.Cached == second.out.Cached {
		t.Fatalf("one reader must synthesize and the other observe cache: first=%+v second=%+v", first.out, second.out)
	}
}

// TestRead_SecondListenCostsNothing: the second identical press must not reach the provider at
// all — the probe happens BEFORE synthesis, so a repeat is served from disk without spending.
func TestRead_SecondListenCostsNothing(t *testing.T) {
	synth := &fakeSynth{provider: "qwen", model: "qwen3-tts-flash", voice: "Cherry", available: true}
	att, cache := newFakeAtt(), newFakeCache()
	svc := newSvc(synth, att, cache)

	first, err := svc.Read(context.Background(), "读一下这句话", "")
	if err != nil {
		t.Fatalf("first read: %v", err)
	}
	if first.Cached || synth.calls != 1 || att.n != 1 {
		t.Fatalf("first read: cached=%v calls=%d uploads=%d, want a fresh synthesis", first.Cached, synth.calls, att.n)
	}

	second, err := svc.Read(context.Background(), "读一下这句话", "")
	if err != nil {
		t.Fatalf("second read: %v", err)
	}
	if !second.Cached {
		t.Fatal("second read must report itself cached")
	}
	if synth.calls != 1 {
		t.Fatalf("upstream calls = %d after a repeat listen — the cache did not prevent the spend", synth.calls)
	}
	if att.n != 1 || second.Attachment.ID != first.Attachment.ID {
		t.Fatalf("repeat listen produced a second artifact (%d uploads, %s vs %s)", att.n, second.Attachment.ID, first.Attachment.ID)
	}
}

// TestRead_VoiceIsPartOfTheIdentity: the same text in a DIFFERENT voice is a different artifact.
// Keying on text alone would serve a user who switched voices the old voice forever, which reads
// as "the voice setting does nothing".
//
// 同一段文字换个音色就是另一件产物。只按文本做键会让换了音色的用户永远听到旧音色,读起来就是
// 「音色设置没用」。
func TestRead_VoiceIsPartOfTheIdentity(t *testing.T) {
	synth := &fakeSynth{provider: "qwen", model: "qwen3-tts-flash", voice: "Cherry", available: true}
	svc := newSvc(synth, newFakeAtt(), newFakeCache())

	if _, err := svc.Read(context.Background(), "同一句话", "Cherry"); err != nil {
		t.Fatalf("read: %v", err)
	}
	if _, err := svc.Read(context.Background(), "同一句话", "Dylan"); err != nil {
		t.Fatalf("read: %v", err)
	}
	if synth.calls != 2 {
		t.Fatalf("upstream calls = %d, want 2 — a voice change must miss the cache", synth.calls)
	}
	// …and the second voice is itself cached from then on.
	if _, err := svc.Read(context.Background(), "同一句话", "Dylan"); err != nil {
		t.Fatalf("read: %v", err)
	}
	if synth.calls != 2 {
		t.Fatalf("upstream calls = %d, want the second voice cached too", synth.calls)
	}
}

// TestRead_ModelChangeMissesTheCache: switching the route (a new provider/model) must not serve
// audio produced by the old one — the identity is in the key for exactly this.
func TestRead_ModelChangeMissesTheCache(t *testing.T) {
	synth := &fakeSynth{provider: "qwen", model: "qwen3-tts-flash", voice: "Cherry", available: true}
	att, cache := newFakeAtt(), newFakeCache()
	svc := newSvc(synth, att, cache)

	if _, err := svc.Read(context.Background(), "一句话", ""); err != nil {
		t.Fatalf("read: %v", err)
	}
	synth.provider, synth.model, synth.voice = "openai", "gpt-4o-mini-tts", "coral"
	res, err := svc.Read(context.Background(), "一句话", "")
	if err != nil {
		t.Fatalf("read after route change: %v", err)
	}
	if res.Cached || synth.calls != 2 {
		t.Fatalf("route change served stale audio (cached=%v calls=%d)", res.Cached, synth.calls)
	}
}

// TestRead_StaleCacheRowIsAMiss: a cache row whose attachment was deleted must re-synthesize
// rather than hand a dangling id to the player.
func TestRead_StaleCacheRowIsAMiss(t *testing.T) {
	synth := &fakeSynth{provider: "qwen", model: "m", voice: "Cherry", available: true}
	att, cache := newFakeAtt(), newFakeCache()
	svc := newSvc(synth, att, cache)

	first, err := svc.Read(context.Background(), "话", "")
	if err != nil {
		t.Fatalf("read: %v", err)
	}
	_ = att.Delete(context.Background(), first.Attachment.ID) // the artifact goes away

	res, err := svc.Read(context.Background(), "话", "")
	if err != nil {
		t.Fatalf("read after artifact removal: %v", err)
	}
	if res.Cached || synth.calls != 2 {
		t.Fatalf("a dangling cache row was served (cached=%v calls=%d)", res.Cached, synth.calls)
	}
	key := attachmentdomain.SpeechCacheKey("话", "Cherry", "qwen", "m")
	if len(cache.deleted) != 1 || cache.deleted[0] != key {
		t.Fatalf("stale cache deletes = %v, want [%s]", cache.deleted, key)
	}
	third, err := svc.Read(context.Background(), "话", "")
	if err != nil {
		t.Fatalf("read after stale-row repair: %v", err)
	}
	if !third.Cached || third.Attachment.ID != res.Attachment.ID || synth.calls != 2 {
		t.Fatalf("repaired cache did not converge: cached=%v attachment=%s calls=%d", third.Cached, third.Attachment.ID, synth.calls)
	}
}

// TestRead_AttachmentReadFailureKeepsTheCacheMapping ensures an unrelated storage failure is not
// mistaken for a proven dangling attachment and does not silently destroy the cache entry.
// TestRead_AttachmentReadFailureKeepsTheCacheMapping 确保无关存储故障不会被误判为附件悬空,也不会
// 静默删除缓存映射。
func TestRead_AttachmentReadFailureKeepsTheCacheMapping(t *testing.T) {
	synth := &fakeSynth{provider: "qwen", model: "m", voice: "Cherry", available: true}
	att, cache := newFakeAtt(), newFakeCache()
	svc := newSvc(synth, att, cache)
	first, err := svc.Read(context.Background(), "故障不等于丢失", "")
	if err != nil {
		t.Fatalf("first read: %v", err)
	}
	att.getErr = errors.New("blob index unavailable")
	key := attachmentdomain.SpeechCacheKey("故障不等于丢失", "Cherry", "qwen", "m")
	if _, err := svc.lookup(context.Background(), key); !errors.Is(err, att.getErr) {
		t.Fatalf("ordinary attachment storage error = %v, want %v", err, att.getErr)
	}
	if len(cache.deleted) != 0 {
		t.Fatalf("cache mappings deleted on ordinary storage failure: %v", cache.deleted)
	}
	att.getErr = nil
	res, err := svc.Read(context.Background(), "故障不等于丢失", "")
	if err != nil {
		t.Fatalf("read after storage recovery: %v", err)
	}
	if !res.Cached || res.Attachment.ID != first.Attachment.ID || synth.calls != 1 {
		t.Fatalf("cache did not survive storage failure: cached=%v attachment=%s calls=%d", res.Cached, res.Attachment.ID, synth.calls)
	}
}

// TestRead_EvictionRetiresTheArtifact: rows the cache evicts take their attachments with them,
// so the cache budget is a real byte budget rather than a row count with unbounded storage.
func TestRead_EvictionRetiresTheArtifact(t *testing.T) {
	synth := &fakeSynth{provider: "qwen", model: "m", voice: "Cherry", available: true}
	att, cache := newFakeAtt(), newFakeCache()
	cache.evicted = []string{"att_oldone"}
	att.rows["att_oldone"] = &attachmentdomain.Attachment{ID: "att_oldone"}

	if _, err := newSvc(synth, att, cache).Read(context.Background(), "话", ""); err != nil {
		t.Fatalf("read: %v", err)
	}
	if len(att.deleted) != 1 || att.deleted[0] != "att_oldone" {
		t.Fatalf("evicted artifacts = %v, want the evicted row's attachment retired", att.deleted)
	}
}

// TestRead_CacheWriteFailureKeepsTheAudio: the user is waiting for sound. A failed cache write
// costs a future re-synthesis, never the audio that was already produced and paid for.
func TestRead_CacheWriteFailureKeepsTheAudio(t *testing.T) {
	synth := &fakeSynth{provider: "qwen", model: "m", voice: "Cherry", available: true}
	cache := newFakeCache()
	cache.putErr = errors.New("disk full")
	res, err := newSvc(synth, newFakeAtt(), cache).Read(context.Background(), "话", "")
	if err != nil {
		t.Fatalf("a cache write failure must not fail the read: %v", err)
	}
	if res.Attachment == nil || res.Attachment.ID == "" {
		t.Fatal("audio lost on a cache write failure")
	}
}

// TestRead_ValidationAndAvailability: empty/oversized text is refused before any spend, and
// availability mirrors the route's own honest-absence answer.
func TestRead_ValidationAndAvailability(t *testing.T) {
	synth := &fakeSynth{provider: "qwen", model: "m", voice: "Cherry"}
	svc := newSvc(synth, newFakeAtt(), newFakeCache())

	if svc.Available(context.Background()) {
		t.Fatal("no speech route, yet read-aloud reports itself available")
	}
	synth.available = true
	if !svc.Available(context.Background()) {
		t.Fatal("a speech route exists, yet read-aloud reports itself unavailable")
	}

	if _, err := svc.Read(context.Background(), "   ", ""); !errors.Is(err, ErrTextRequired) {
		t.Fatalf("blank text err = %v, want ErrTextRequired", err)
	}
	if _, err := svc.Read(context.Background(), strings.Repeat("字", maxReadChars+1), ""); !errors.Is(err, ErrTextTooLong) {
		t.Fatalf("oversized text err = %v, want ErrTextTooLong", err)
	}
	if synth.calls != 0 {
		t.Fatalf("upstream called %d times for input that never should have left the door", synth.calls)
	}
}
