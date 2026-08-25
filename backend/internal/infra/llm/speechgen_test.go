package llm

import (
	"bytes"
	"encoding/binary"
	"strings"
	"testing"
	"unicode/utf8"
)

// The chunk-and-concat pipeline is the whole reason speech has an intermediate format at all, and
// it is pure logic — so it is pinned here, away from any network. A seam bug in this code sounds
// like a stutter in the middle of a sentence, which is the kind of defect nobody files as a bug.
//
// 切块再拼是语音之所以需要中间格式的全部理由,且它是纯逻辑——故在此钉死、不碰网络。这段代码里的
// 接缝错误听起来像句子中间打了个磕巴,而这种缺陷没人会当 bug 报上来。

func silentPCM(n int) []byte { return make([]byte, n*2) } // n 16-bit samples

// TestBuildParseWAVRoundTrip: a header we write is a header we can read back, byte-exact.
func TestBuildParseWAVRoundTrip(t *testing.T) {
	pcm := silentPCM(1000)
	w := BuildWAV(pcm, speechSampleRate, speechChannels, speechBits)
	if len(w) != 44+len(pcm) {
		t.Fatalf("wav length = %d, want 44+%d", len(w), len(pcm))
	}
	if string(w[0:4]) != "RIFF" || string(w[8:12]) != "WAVE" {
		t.Fatalf("not a RIFF/WAVE stream: %q", w[:12])
	}
	got, sr, ch, bits, err := ParseWAV(w)
	if err != nil {
		t.Fatalf("parse: %v", err)
	}
	if sr != speechSampleRate || ch != speechChannels || bits != speechBits {
		t.Fatalf("format = %d/%d/%d, want 24000/1/16", sr, ch, bits)
	}
	if !bytes.Equal(got, pcm) {
		t.Fatalf("pcm round-trip differs (%d vs %d bytes)", len(got), len(pcm))
	}
}

// TestParseWAVWalksChunks: a file with a LIST chunk between fmt and data must still yield the
// SAMPLES, not the metadata. A fixed-44-byte reader would hand the LIST bytes to the player as
// audio — noise that sounds like a broken encoder rather than a broken parser.
//
// fmt 与 data 之间夹了 LIST chunk 的文件仍须取出**样本**而非元数据。按固定 44 字节读会把 LIST 的
// 字节当音频交给播放器——那听起来像编码器坏了,而不是解析器坏了。
func TestParseWAVWalksChunks(t *testing.T) {
	pcm := silentPCM(10)
	base := BuildWAV(pcm, speechSampleRate, speechChannels, speechBits)
	var w bytes.Buffer
	w.Write(base[:36]) // through the fmt chunk
	w.WriteString("LIST")
	_ = binary.Write(&w, binary.LittleEndian, uint32(4))
	w.WriteString("INFO")
	w.Write(base[36:]) // data chunk
	// RIFF size is now stale; ParseWAV must not depend on it.
	got, _, _, _, err := ParseWAV(w.Bytes())
	if err != nil {
		t.Fatalf("parse with LIST chunk: %v", err)
	}
	if !bytes.Equal(got, pcm) {
		t.Fatalf("walked to the wrong chunk: got %d bytes, want the %d-byte data payload", len(got), len(pcm))
	}
}

func TestParseWAVWalksFactChunk(t *testing.T) {
	pcm := silentPCM(12)
	base := BuildWAV(pcm, speechSampleRate, speechChannels, speechBits)
	var w bytes.Buffer
	w.Write(base[:36])
	w.WriteString("fact")
	_ = binary.Write(&w, binary.LittleEndian, uint32(4))
	w.WriteString("TEST")
	w.Write(base[36:])

	got, _, _, _, err := ParseWAV(w.Bytes())
	if err != nil {
		t.Fatalf("parse with fact chunk: %v", err)
	}
	if !bytes.Equal(got, pcm) {
		t.Fatalf("fact metadata was treated as samples: got %d bytes, want %d", len(got), len(pcm))
	}
}

// TestConcatAudioJoinsAtPCMLevel: two chunks become ONE stream with ONE header. A byte-level
// append would leave a second RIFF header stranded mid-stream, where most players simply stop —
// so the length assertion (not just "no error") is the real content of this test.
//
// 两块合成**一条**流、只有**一个**头。按字节追加会在流中间留下第二个 RIFF 头,多数播放器就停在
// 那儿——故长度断言(而非「没报错」)才是这个测试的真正内容。
func TestConcatAudioJoinsAtPCMLevel(t *testing.T) {
	a := GeneratedAudio{Bytes: BuildWAV(silentPCM(100), speechSampleRate, speechChannels, speechBits), Mime: "audio/wav"}
	b := GeneratedAudio{Bytes: BuildWAV(silentPCM(150), speechSampleRate, speechChannels, speechBits), Mime: "audio/wav"}
	joined, err := ConcatAudio([]GeneratedAudio{a, b})
	if err != nil {
		t.Fatalf("concat: %v", err)
	}
	if want := 44 + (100+150)*2; len(joined.Bytes) != want {
		t.Fatalf("joined length = %d, want %d (one header, both payloads)", len(joined.Bytes), want)
	}
	pcm, sr, _, _, err := ParseWAV(joined.Bytes)
	if err != nil || sr != speechSampleRate || len(pcm) != (100+150)*2 {
		t.Fatalf("joined stream unreadable: sr=%d pcm=%d err=%v", sr, len(pcm), err)
	}
	if bytes.Count(joined.Bytes, []byte("RIFF")) != 1 {
		t.Fatal("joined stream carries more than one RIFF header")
	}
}

// TestConcatAudioSinglePartPassesThrough: the common case (short text, one chunk) must not be
// re-encoded — it is returned untouched.
func TestConcatAudioSinglePartPassesThrough(t *testing.T) {
	one := GeneratedAudio{Bytes: []byte("not even wav"), Mime: "audio/mpeg"}
	got, err := ConcatAudio([]GeneratedAudio{one})
	if err != nil || !bytes.Equal(got.Bytes, one.Bytes) || got.Mime != one.Mime {
		t.Fatalf("single part must pass through untouched: %+v %v", got, err)
	}
}

// TestConcatAudioRefusesMixedFormats: joining differing sample rates without resampling would
// play one half at the wrong pitch. Refusing loudly beats shipping chipmunk audio.
//
// 不重采样就拼不同采样率,会让其中一半变调。大声拒绝胜过交付一段花栗鼠声音。
func TestConcatAudioRefusesMixedFormats(t *testing.T) {
	a := GeneratedAudio{Bytes: BuildWAV(silentPCM(10), 24000, 1, 16)}
	b := GeneratedAudio{Bytes: BuildWAV(silentPCM(10), 16000, 1, 16)}
	if _, err := ConcatAudio([]GeneratedAudio{a, b}); err == nil {
		t.Fatal("mixed sample rates must be refused, not silently joined")
	}
}

// TestSplitSpeechTextPrefersSentenceBoundaries: every chunk is within the cap, the pieces rejoin
// to the original content, and a seam lands after punctuation rather than mid-clause.
//
// 每块都在上限内、拼回来内容不丢、接缝落在标点之后而非句子中间。
func TestSplitSpeechTextPrefersSentenceBoundaries(t *testing.T) {
	sentence := "这是一句中文。"
	text := strings.Repeat(sentence, 30) // 210 runes
	chunks := SplitSpeechText(text, 50)
	if len(chunks) < 4 {
		t.Fatalf("expected several chunks, got %d", len(chunks))
	}
	for i, c := range chunks {
		if n := utf8.RuneCountInString(c); n > 50 {
			t.Fatalf("chunk %d has %d runes, over the 50 cap", i, n)
		}
		if i < len(chunks)-1 && !strings.HasSuffix(c, "。") {
			t.Fatalf("chunk %d ends mid-clause: %q", i, c)
		}
	}
	if strings.Join(chunks, "") != text {
		t.Fatal("rejoined chunks differ from the original text")
	}
}

// TestSplitSpeechTextHardCutsWhenNoBoundary: unpunctuated text still gets spoken — a hard cut
// beats refusing, and every chunk still respects the cap.
func TestSplitSpeechTextHardCutsWhenNoBoundary(t *testing.T) {
	text := strings.Repeat("字", 130)
	chunks := SplitSpeechText(text, 50)
	if len(chunks) != 3 {
		t.Fatalf("chunks = %d, want 3", len(chunks))
	}
	for i, c := range chunks {
		if n := utf8.RuneCountInString(c); n > 50 {
			t.Fatalf("chunk %d has %d runes", i, n)
		}
	}
	if strings.Join(chunks, "") != text {
		t.Fatal("hard-cut chunks lost content")
	}
}

// TestSplitSpeechTextShortTextIsOneChunk: the common case pays no splitting at all.
func TestSplitSpeechTextShortTextIsOneChunk(t *testing.T) {
	if got := SplitSpeechText("  hello there  ", 480); len(got) != 1 || got[0] != "hello there" {
		t.Fatalf("split = %v, want one trimmed chunk", got)
	}
	if got := SplitSpeechText("   ", 480); got != nil {
		t.Fatalf("blank text must yield nothing, got %v", got)
	}
}

// TestSpeechChunkLimitCoversEveryRoutedProvider: each provider the router can pick has an explicit
// limit, and the unknown-provider fallback is the SMALLEST of them. A generous default would send
// 3000 characters to an upstream that caps at 500 and fail the whole utterance at chunk one.
//
// 路由能选到的每一家都有显式上限,且未知 provider 的兜底取其中**最小**。慷慨的默认值会把 3000 字
// 发给一个 500 封顶的上游,在第一块就让整段话失败。
func TestSpeechChunkLimitCoversEveryRoutedProvider(t *testing.T) {
	smallest := SpeechChunkLimit("unknown-provider")
	for _, p := range []string{"anselm", "openai", "google", "qwen", "zhipu"} {
		n := SpeechChunkLimit(p)
		if n <= 0 {
			t.Fatalf("provider %s has no chunk limit", p)
		}
		if n < smallest {
			t.Fatalf("fallback %d is larger than %s's real limit %d", smallest, p, n)
		}
	}
}

// TestAudioDurationMs_MeasuresOrSaysNothing pins both halves of the contract: an exact number when
// the bytes are a readable WAV, and ZERO — never a guess — when they are not.
//
// A receipt that invents a length is worse than one that omits it, because the caller cannot tell
// an invention from a measurement (WRK-082 H6).
//
// TestAudioDurationMs_MeasuresOrSaysNothing 钉住契约的两半:字节是可读 WAV 时给**精确**数,不是时给
// **零**、而不是猜。
//
// 一份**编**长度的 receipt 比一份干脆不写的更糟,因为调用方分不出编造与测量(H6)。
func TestAudioDurationMs_MeasuresOrSaysNothing(t *testing.T) {
	// 24kHz / 16-bit / mono — the shape every synthesis in this package produces. Half a second of
	// PCM is 24000 bytes.
	// 24kHz/16bit/mono——本包每次合成产出的规格。半秒 PCM 是 24000 字节。
	wav := BuildWAV(make([]byte, 24000), 24000, 1, 16)
	if got := AudioDurationMs(wav); got != 500 {
		t.Fatalf("AudioDurationMs = %dms, want 500ms for half a second of 24kHz mono PCM", got)
	}
	for name, b := range map[string][]byte{
		"empty":       nil,
		"not a riff":  []byte("ID3 this is an mp3"),
		"truncated":   wav[:8],
		"header only": BuildWAV(nil, 24000, 1, 16),
	} {
		if got := AudioDurationMs(b); got != 0 {
			t.Fatalf("%s: AudioDurationMs = %d, want 0 (never guess)", name, got)
		}
	}
}
