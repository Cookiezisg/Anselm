package response

import (
	"encoding/json"
	"strings"
	"testing"

	streamdomain "github.com/sunweilin/foryx/backend/internal/domain/stream"
)

func wireOf(t *testing.T, frame streamdomain.Frame, seq int64) map[string]any {
	t.Helper()
	raw, err := MarshalStreamEnvelope(streamdomain.Envelope{
		Seq: seq,
		Event: streamdomain.Event{
			Scope: streamdomain.Scope{Kind: streamdomain.KindConversation, ID: "c1"},
			ID:    "n1",
			Frame: frame,
		},
	})
	if err != nil {
		t.Fatal(err)
	}
	var m map[string]any
	if err := json.Unmarshal(raw, &m); err != nil {
		t.Fatal(err)
	}
	return m
}

func TestMarshalStreamEnvelopeOpen(t *testing.T) {
	m := wireOf(t, streamdomain.Open{ParentID: "p1", Node: streamdomain.Node{Type: "text"}}, 5)
	if m["seq"].(float64) != 5 || m["id"] != "n1" {
		t.Errorf("envelope top = %+v", m)
	}
	scope := m["scope"].(map[string]any)
	if scope["kind"] != "conversation" || scope["id"] != "c1" {
		t.Errorf("scope = %+v", scope)
	}
	frame := m["frame"].(map[string]any)
	if frame["kind"] != "open" || frame["parentId"] != "p1" {
		t.Errorf("frame = %+v", frame)
	}
	if node := frame["node"].(map[string]any); node["type"] != "text" {
		t.Errorf("node = %+v", node)
	}
}

func TestMarshalStreamEnvelopeDelta(t *testing.T) {
	frame := wireOf(t, streamdomain.Delta{Chunk: "hi"}, 6)["frame"].(map[string]any)
	if frame["kind"] != "delta" || frame["chunk"] != "hi" {
		t.Errorf("delta frame = %+v", frame)
	}
}

func TestMarshalStreamEnvelopeClose(t *testing.T) {
	frame := wireOf(t, streamdomain.Close{Status: "completed", Result: &streamdomain.Node{Type: "text"}}, 7)["frame"].(map[string]any)
	if frame["kind"] != "close" || frame["status"] != "completed" {
		t.Errorf("close frame = %+v", frame)
	}
	if result := frame["result"].(map[string]any); result["type"] != "text" {
		t.Errorf("close result = %+v", result)
	}
}

func TestMarshalStreamEnvelopeSignal(t *testing.T) {
	frame := wireOf(t, streamdomain.Signal{Node: streamdomain.Node{Type: "entity_changed"}}, 8)["frame"].(map[string]any)
	if frame["kind"] != "signal" {
		t.Errorf("signal frame = %+v", frame)
	}
	if node := frame["node"].(map[string]any); node["type"] != "entity_changed" {
		t.Errorf("signal node = %+v", node)
	}
}

func TestWriteStreamEnvelopeIDLine(t *testing.T) {
	// Durable (seq>0) carries an id: line for resume; ephemeral (seq 0) omits it.
	var sb strings.Builder
	_ = WriteStreamEnvelope(&sb, streamdomain.Envelope{Seq: 5, Event: streamdomain.Event{
		Scope: streamdomain.Scope{Kind: streamdomain.KindConversation, ID: "c1"}, ID: "n1",
		Frame: streamdomain.Open{Node: streamdomain.Node{Type: "text"}},
	}})
	if !strings.Contains(sb.String(), "\nid: 5\n") {
		t.Errorf("durable frame missing id line: %q", sb.String())
	}

	sb.Reset()
	_ = WriteStreamEnvelope(&sb, streamdomain.Envelope{Seq: 0, Event: streamdomain.Event{
		Scope: streamdomain.Scope{Kind: streamdomain.KindConversation, ID: "c1"}, ID: "n1",
		Frame: streamdomain.Delta{Chunk: "x"},
	}})
	if strings.Contains(sb.String(), "id:") {
		t.Errorf("ephemeral frame must not carry an id line: %q", sb.String())
	}
}
