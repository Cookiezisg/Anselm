package llm

import (
	"context"
	"testing"
)

func TestMockClientFIFO(t *testing.T) {
	m := NewMockClient()
	m.PushScript(MockScript{Events: []StreamEvent{{Type: EventText, Delta: "a"}}})
	m.PushScript(MockScript{Events: []StreamEvent{{Type: EventText, Delta: "b"}}})

	e1 := collect(m.Stream(context.Background(), Request{}))
	e2 := collect(m.Stream(context.Background(), Request{}))
	if len(e1) == 0 || len(e2) == 0 || e1[0].Delta != "a" || e2[0].Delta != "b" {
		t.Errorf("FIFO order broken: %+v / %+v", e1, e2)
	}
	if m.CallCount() != 2 {
		t.Errorf("CallCount = %d, want 2", m.CallCount())
	}
	if m.QueueDepth() != 0 {
		t.Errorf("QueueDepth = %d, want 0", m.QueueDepth())
	}
}

func TestMockClientQueueEmptyYieldsError(t *testing.T) {
	m := NewMockClient()
	events := collect(m.Stream(context.Background(), Request{}))
	if len(events) != 1 || events[0].Type != EventError || events[0].Err == nil {
		t.Errorf("empty queue should yield one EventError: %+v", events)
	}
}

func TestMockClientErrAfter(t *testing.T) {
	m := NewMockClient()
	m.PushScript(MockScript{ErrAfter: ErrProviderError})
	events := collect(m.Stream(context.Background(), Request{}))
	if len(events) != 1 || events[0].Type != EventError {
		t.Errorf("ErrAfter should yield one EventError: %+v", events)
	}
}
