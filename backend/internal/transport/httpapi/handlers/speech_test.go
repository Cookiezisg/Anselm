package handlers

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"
	"go.uber.org/zap"

	speechapp "github.com/sunweilin/anselm/backend/internal/app/speech"
	apikeydomain "github.com/sunweilin/anselm/backend/internal/domain/apikey"
	deviceproofinfra "github.com/sunweilin/anselm/backend/internal/infra/deviceproof"
)

type speechTestKeys struct {
	rows  []*apikeydomain.APIKey
	creds apikeydomain.Credentials
}

func (f speechTestKeys) List(context.Context, apikeydomain.ListFilter) ([]*apikeydomain.APIKey, string, error) {
	return f.rows, "", nil
}

func (f speechTestKeys) ResolveCredentialsByID(context.Context, string) (apikeydomain.Credentials, error) {
	return f.creds, nil
}

type fakeProofHeaders struct {
	gotURL     string
	gotInstall string
}

func (f *fakeProofHeaders) ProofHeaders(_ context.Context, method, rawURL, kid string, _ []byte, refresh bool) (http.Header, error) {
	f.gotURL, f.gotInstall = rawURL, kid
	h := make(http.Header)
	h.Set(deviceproofinfra.HeaderInstallID, kid)
	h.Set("X-Test-Proof-Method", method)
	if refresh {
		h.Set("X-Test-Refresh", "true")
	}
	return h, nil
}

func TestSpeechHandlerProxiesClientFramesToManagedGateway(t *testing.T) {
	events := make(chan string, 3)
	upgrader := websocket.Upgrader{}
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/v1/speech/asr" || r.URL.Query().Get("language") != "zh" {
			t.Errorf("upstream target = %s?%s", r.URL.Path, r.URL.RawQuery)
		}
		if got := r.Header.Get(deviceproofinfra.HeaderInstallID); got != "ins_1" {
			t.Errorf("install header = %q", got)
		}
		c, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			t.Errorf("upgrade upstream: %v", err)
			return
		}
		defer func() { _ = c.Close() }()
		for i := 0; i < 2; i++ {
			mt, payload, err := c.ReadMessage()
			if err != nil {
				t.Errorf("read upstream: %v", err)
				return
			}
			if mt == websocket.BinaryMessage {
				events <- "binary:" + string(payload)
				_ = c.WriteJSON(map[string]string{"type": "conversation.item.input_audio_transcription.delta", "text": "你"})
			} else {
				var evt struct {
					Type string `json:"type"`
				}
				_ = json.Unmarshal(payload, &evt)
				events <- "text:" + evt.Type
				_ = c.WriteJSON(map[string]string{"type": "session.finished"})
			}
		}
	}))
	defer upstream.Close()

	proof := &fakeProofHeaders{}
	svc := speechapp.New(speechTestKeys{
		rows: []*apikeydomain.APIKey{{ID: "aki_1", Provider: "anselm"}},
		creds: apikeydomain.Credentials{
			Provider: "anselm",
			Key:      "ins_1",
			BaseURL:  upstream.URL + "/v1",
		},
	})
	h := NewSpeechHandler(svc, proof, zap.NewNop())
	downstream := httptest.NewServer(http.HandlerFunc(h.ASR))
	defer downstream.Close()

	conn, _, err := websocket.DefaultDialer.Dial(strings.Replace(downstream.URL, "http://", "ws://", 1)+"/?language=zh", nil)
	if err != nil {
		t.Fatalf("dial downstream: %v", err)
	}
	defer func() { _ = conn.Close() }()

	if err := conn.WriteMessage(websocket.BinaryMessage, []byte("pcm")); err != nil {
		t.Fatal(err)
	}
	_, payload, err := conn.ReadMessage()
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(payload), "input_audio_transcription.delta") {
		t.Fatalf("missing delta relay: %s", payload)
	}
	if err := conn.WriteJSON(map[string]string{"type": "finish"}); err != nil {
		t.Fatal(err)
	}
	_, payload, err = conn.ReadMessage()
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(payload), "session.finished") {
		t.Fatalf("missing finished relay: %s", payload)
	}
	if got := <-events; got != "binary:pcm" {
		t.Fatalf("first upstream event = %q", got)
	}
	if got := <-events; got != "text:finish" {
		t.Fatalf("second upstream event = %q", got)
	}
	if proof.gotInstall != "ins_1" || !strings.Contains(proof.gotURL, "/v1/speech/asr?language=zh") {
		t.Fatalf("proof got install=%q url=%q", proof.gotInstall, proof.gotURL)
	}
}

func TestSpeechHandlerHeartbeatsBothWebSocketLegs(t *testing.T) {
	upstreamPing := make(chan struct{}, 1)
	downstreamPing := make(chan struct{}, 1)
	upgrader := websocket.Upgrader{}
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		c, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			t.Errorf("upgrade upstream: %v", err)
			return
		}
		defer func() { _ = c.Close() }()
		c.SetPingHandler(func(appData string) error {
			select {
			case upstreamPing <- struct{}{}:
			default:
			}
			return c.WriteControl(websocket.PongMessage, []byte(appData), time.Now().Add(time.Second))
		})
		for {
			if _, _, err := c.ReadMessage(); err != nil {
				return
			}
		}
	}))
	defer upstream.Close()

	svc := speechapp.New(speechTestKeys{
		rows: []*apikeydomain.APIKey{{ID: "aki_1", Provider: "anselm"}},
		creds: apikeydomain.Credentials{
			Provider: "anselm",
			Key:      "ins_1",
			BaseURL:  upstream.URL + "/v1",
		},
	})
	h := NewSpeechHandler(svc, &fakeProofHeaders{}, zap.NewNop())
	h.pingEvery = 10 * time.Millisecond
	h.pongWait = 200 * time.Millisecond
	downstream := httptest.NewServer(http.HandlerFunc(h.ASR))
	defer downstream.Close()

	conn, _, err := websocket.DefaultDialer.Dial(strings.Replace(downstream.URL, "http://", "ws://", 1), nil)
	if err != nil {
		t.Fatalf("dial downstream: %v", err)
	}
	defer func() { _ = conn.Close() }()
	conn.SetPingHandler(func(appData string) error {
		select {
		case downstreamPing <- struct{}{}:
		default:
		}
		return conn.WriteControl(websocket.PongMessage, []byte(appData), time.Now().Add(time.Second))
	})
	go func() {
		for {
			if _, _, err := conn.ReadMessage(); err != nil {
				return
			}
		}
	}()

	for name, ch := range map[string]<-chan struct{}{
		"upstream":   upstreamPing,
		"downstream": downstreamPing,
	} {
		select {
		case <-ch:
		case <-time.After(time.Second):
			t.Fatalf("missing %s heartbeat ping", name)
		}
	}
}

func TestValidSpeechControl_AllowsKnownControlsOnly(t *testing.T) {
	for _, typ := range []string{"finish", "commit", "cancel"} {
		if !validSpeechControl([]byte(`{"type":"` + typ + `"}`)) {
			t.Fatalf("control %q should be valid", typ)
		}
	}
	for _, raw := range [][]byte{
		[]byte(`{"type":"pause"}`),
		[]byte(`{"kind":"finish"}`),
		[]byte(`not-json`),
	} {
		if validSpeechControl(raw) {
			t.Fatalf("control %s should be rejected", raw)
		}
	}
}
