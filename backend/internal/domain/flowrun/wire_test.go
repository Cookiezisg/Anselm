package flowrun

// wire_test.go locks the FlowRun wire contract for run provenance (scheduler 工单①): camelCase
// names (N3), omitempty on NULL — a pre-provenance row sends NEITHER key (the client's "unknown"
// fallback keys off absence, never an empty string), and the origin vocabulary mirrors the DB CHECK.
//
// wire_test.go 锁 FlowRun 溯源的线缆契约（scheduler 工单①）：camelCase（N3）、NULL omitempty——
// 溯源前旧行两键都**不发**（客户端 unknown 兜底认缺席、不认空串），origin 词表与 DB CHECK 一致。

import (
	"encoding/json"
	"strings"
	"testing"
)

func TestWire_ProvenanceOmittedWhenNull(t *testing.T) {
	b, err := json.Marshal(&FlowRun{ID: "fr_1", WorkflowID: "wf_1", Status: StatusRunning})
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	s := string(b)
	if strings.Contains(s, "origin") || strings.Contains(s, "conversationId") {
		t.Fatalf("NULL provenance must be omitted from the wire, got %s", s)
	}
}

func TestWire_ProvenanceCamelCaseWhenStamped(t *testing.T) {
	origin, conv := OriginChat, "cv_1"
	b, err := json.Marshal(&FlowRun{ID: "fr_1", Origin: &origin, ConversationID: &conv})
	if err != nil {
		t.Fatalf("marshal: %v", err)
	}
	s := string(b)
	if !strings.Contains(s, `"origin":"chat"`) || !strings.Contains(s, `"conversationId":"cv_1"`) {
		t.Fatalf("stamped provenance must ride camelCase keys, got %s", s)
	}
}

func TestWire_OriginVocabularyClosed(t *testing.T) {
	want := []string{"manual", "chat", "cron", "webhook", "fsnotify", "sensor"}
	if len(RunOrigins) != len(want) {
		t.Fatalf("RunOrigins = %v, want %v", RunOrigins, want)
	}
	for i, w := range want {
		if RunOrigins[i] != w {
			t.Fatalf("RunOrigins[%d] = %q, want %q", i, RunOrigins[i], w)
		}
	}
}
