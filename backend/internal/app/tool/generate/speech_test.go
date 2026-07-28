package generate

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	apikeydomain "github.com/sunweilin/anselm/backend/internal/domain/apikey"
	modeldomain "github.com/sunweilin/anselm/backend/internal/domain/model"
	llminfra "github.com/sunweilin/anselm/backend/internal/infra/llm"
)

// speechTool digs the speech member out of the family by name.
func speechTool(t *testing.T, router *Router, up Uploader) *GenerateSpeech {
	t.Helper()
	for _, tw := range GenerateTools(router, up, nil, nil) {
		if s, ok := tw.Tool.(*GenerateSpeech); ok {
			return s
		}
	}
	t.Fatal("generate_speech missing from the family")
	return nil
}

func wav(nSamples int) []byte {
	return llminfra.BuildWAV(make([]byte, nSamples*2), 24000, 1, 16)
}

// TestSpeech_EndToEndOpenAIForm drives the whole tool against a fake OpenAI-form upstream: raw
// wav body → uploaded attachment → receipt JSON. It also pins the two things the wire must carry
// on this dialect — an explicit wav request format and the route's own default voice.
//
// 对假 OpenAI 形上游全链驱动:裸 wav 体 → 落附件 → receipt。并钉死本方言线缆上必须带的两样:
// 显式 wav 格式、以及**该路由自己的**默认音色。
func TestSpeech_EndToEndOpenAIForm(t *testing.T) {
	var gotBody map[string]any
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/v1/audio/speech" {
			t.Errorf("path = %s", r.URL.Path)
		}
		_ = json.NewDecoder(r.Body).Decode(&gotBody)
		w.Header().Set("Content-Type", "audio/wav")
		_, _ = w.Write(wav(120))
	}))
	defer srv.Close()

	router := routerWith(
		fakePicker{err: modeldomain.ErrNotConfigured},
		fakeKeys{creds: map[string]apikeydomain.Credentials{"aki_o": {Provider: "openai", Key: "sk", BaseURL: srv.URL + "/v1"}}},
		fakeProbes{rows: []apikeydomain.ProbedKey{{ID: "aki_o", Provider: "openai", TestStatus: apikeydomain.TestStatusOK}}},
	)
	up := &fakeUploader{}
	out, err := speechTool(t, router, up).Execute(context.Background(), `{"text":"hello there"}`)
	if err != nil {
		t.Fatalf("execute: %v", err)
	}
	if gotBody["model"] != "gpt-4o-mini-tts" || gotBody["response_format"] != "wav" {
		t.Fatalf("wire = %v, want the default model and an explicit wav format", gotBody)
	}
	if gotBody["voice"] != "coral" {
		t.Fatalf("wire voice = %v, want OpenAI's own default (a DashScope voice name here is a 400)", gotBody["voice"])
	}
	var receipt map[string]any
	if err := json.Unmarshal([]byte(out), &receipt); err != nil {
		t.Fatalf("receipt not JSON: %v (%s)", err, out)
	}
	if receipt["attachmentId"] != "att_generated0001" || receipt["source"] != "generate_speech" {
		t.Fatalf("receipt = %v", receipt)
	}
	if receipt["provider"] != "openai" || receipt["characters"] != float64(11) {
		t.Fatalf("receipt provenance = %v", receipt)
	}
	// The artifact must land under a playable extension — a wav saved as .png cannot be opened
	// by double-clicking it. 产物必须落在可播放的扩展名下——存成 .png 的 wav 双击打不开。
	if !strings.HasSuffix(up.last.Filename, ".wav") {
		t.Fatalf("artifact filename = %q, want a .wav extension", up.last.Filename)
	}
}

// TestSpeech_LongTextChunksAndRejoins: text past the provider's per-request cap is split, each
// chunk synthesized, and the audio rejoined into ONE stream. Without this the managed free tier
// (500 characters per request) could not read a normal chat message aloud at all.
//
// 超过该家单请求上限的文本被切块、逐块合成、音频接回**一条**流。没有这条,受管免费档(单请求 500
// 字符)根本读不完一条正常的聊天消息。
func TestSpeech_LongTextChunksAndRejoins(t *testing.T) {
	calls := 0
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		var body map[string]any
		_ = json.NewDecoder(r.Body).Decode(&body)
		if n := len([]rune(body["input"].(string))); n > llminfra.SpeechChunkLimit("zhipu") {
			t.Errorf("chunk %d carries %d runes, over the provider cap", calls, n)
		}
		w.Header().Set("Content-Type", "audio/wav")
		_, _ = w.Write(wav(100))
	}))
	defer srv.Close()

	router := routerWith(
		fakePicker{err: modeldomain.ErrNotConfigured},
		fakeKeys{creds: map[string]apikeydomain.Credentials{"aki_z": {Provider: "zhipu", Key: "sk", BaseURL: srv.URL + "/v4"}}},
		fakeProbes{rows: []apikeydomain.ProbedKey{{ID: "aki_z", Provider: "zhipu", TestStatus: apikeydomain.TestStatusOK}}},
	)
	up := &fakeUploader{}
	text := strings.Repeat("这是一句话。", 400) // 2400 runes > zhipu's 1000 cap
	if _, err := speechTool(t, router, up).Execute(context.Background(), `{"text":"`+text+`"}`); err != nil {
		t.Fatalf("execute: %v", err)
	}
	if calls < 3 {
		t.Fatalf("upstream calls = %d, want the text split into several chunks", calls)
	}
	// ONE stream out: a single RIFF header and every chunk's samples.
	pcm, sr, _, _, err := llminfra.ParseWAV(up.Data)
	if err != nil {
		t.Fatalf("joined artifact unreadable: %v", err)
	}
	if sr != 24000 || len(pcm) != calls*100*2 {
		t.Fatalf("joined pcm = %d bytes at %d Hz, want %d bytes from %d chunks", len(pcm), sr, calls*100*2, calls)
	}
}

// TestSpeech_HonestAbsenceAndValidation: a workspace with no speech-capable key never offers the
// tool, and the tool refuses empty or oversized text before spending anything.
func TestSpeech_HonestAbsenceAndValidation(t *testing.T) {
	none := routerWith(
		fakePicker{err: modeldomain.ErrNotConfigured},
		fakeKeys{creds: map[string]apikeydomain.Credentials{}},
		fakeProbes{},
	)
	if none.SpeechAvailable(context.Background()) {
		t.Fatal("no key can speak, yet the tool reports itself available")
	}
	if _, err := speechTool(t, none, &fakeUploader{}).Execute(context.Background(), `{"text":"hi"}`); err == nil {
		t.Fatal("execute without a route must fail loudly")
	}

	tool := speechTool(t, none, &fakeUploader{})
	if err := tool.ValidateInput(json.RawMessage(`{"text":"   "}`)); err == nil {
		t.Fatal("blank text must be refused")
	}
	long := strings.Repeat("字", maxSpeechChars+1)
	if err := tool.ValidateInput(json.RawMessage(`{"text":"` + long + `"}`)); err == nil {
		t.Fatal("oversized text must be refused before any upstream call")
	}
	if err := tool.ValidateInput(json.RawMessage(`{"text":"ok"}`)); err != nil {
		t.Fatalf("valid input refused: %v", err)
	}
}

// TestSpeech_DefaultVoiceIsPerRoute: voice names are not portable across providers, so an unset
// voice must resolve from the ROUTE. One global default would 400 on three of the four dialects.
//
// 音色名不跨家通用,故未设音色必须由**路由**解析。一个全局默认会在四个方言里的三个上打出 400。
func TestSpeech_DefaultVoiceIsPerRoute(t *testing.T) {
	seen := map[string]string{}
	for provider, want := range map[string]string{"openai": "coral", "zhipu": "tongtong"} {
		srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			var body map[string]any
			_ = json.NewDecoder(r.Body).Decode(&body)
			seen[provider], _ = body["voice"].(string)
			w.Header().Set("Content-Type", "audio/wav")
			_, _ = w.Write(wav(10))
		}))
		router := routerWith(
			fakePicker{err: modeldomain.ErrNotConfigured},
			fakeKeys{creds: map[string]apikeydomain.Credentials{"k": {Provider: provider, Key: "sk", BaseURL: srv.URL}}},
			fakeProbes{rows: []apikeydomain.ProbedKey{{ID: "k", Provider: provider, TestStatus: apikeydomain.TestStatusOK}}},
		)
		if _, err := speechTool(t, router, &fakeUploader{}).Execute(context.Background(), `{"text":"hi"}`); err != nil {
			t.Fatalf("%s execute: %v", provider, err)
		}
		srv.Close()
		if seen[provider] != want {
			t.Fatalf("%s default voice = %q, want %q", provider, seen[provider], want)
		}
	}
}
