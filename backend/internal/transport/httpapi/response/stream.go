package response

import (
	"encoding/json"
	"fmt"
	"io"

	streamdomain "github.com/sunweilin/forgify/backend/internal/domain/stream"
)

// streamWire is the on-wire JSON shape of a stream Envelope (see references/backend/events.md):
// {seq, scope, id, frame:{kind, ...}}. Built here, not in domain/stream, so the domain
// stays serialization-free; this is the single place the frame discriminant (kind) and
// node discriminant (type, via Node's own json tags) are injected onto the wire.
//
// streamWire 是 stream Envelope 的线上 JSON 形状（见 references/backend/events.md）。在此构造而非
// domain/stream，让 domain 不碰序列化；这是 frame 判别（kind）与 node 判别（type）注入线缆的唯一处。
type streamWire struct {
	Seq   int64              `json:"seq"`
	Scope streamdomain.Scope `json:"scope"`
	ID    string             `json:"id"`
	Frame frameWire          `json:"frame"`
}

type frameWire struct {
	Kind     string             `json:"kind"` // open | delta | close | signal
	ParentID string             `json:"parentId,omitempty"`
	Chunk    string             `json:"chunk,omitempty"`
	Status   string             `json:"status,omitempty"`
	Error    string             `json:"error,omitempty"`
	Node     *streamdomain.Node `json:"node,omitempty"`
	Result   *streamdomain.Node `json:"result,omitempty"`
}

func frameToWire(f streamdomain.Frame) frameWire {
	switch fr := f.(type) {
	case streamdomain.Open:
		return frameWire{Kind: "open", ParentID: fr.ParentID, Node: &fr.Node}
	case streamdomain.Delta:
		return frameWire{Kind: "delta", Chunk: fr.Chunk}
	case streamdomain.Close:
		return frameWire{Kind: "close", Status: fr.Status, Error: fr.Error, Result: fr.Result}
	case streamdomain.Signal:
		return frameWire{Kind: "signal", Node: &fr.Node}
	default:
		return frameWire{}
	}
}

// MarshalStreamEnvelope renders an Envelope to its wire JSON (the {seq,scope,id,frame} shape).
//
// MarshalStreamEnvelope 把 Envelope 渲染为线上 JSON（{seq,scope,id,frame} 形状）。
func MarshalStreamEnvelope(env streamdomain.Envelope) ([]byte, error) {
	return json.Marshal(streamWire{
		Seq:   env.Seq,
		Scope: env.Scope,
		ID:    env.ID,
		Frame: frameToWire(env.Frame),
	})
}

// WriteStreamEnvelope writes one Envelope as an SSE event. Durable frames carry an
// `id: <seq>` line (so a reconnect resumes via Last-Event-ID); ephemeral frames (Seq 0)
// omit it — they are live-only and never replayed. Use as the onEvent of StreamSSE.
//
// WriteStreamEnvelope 把一个 Envelope 写成 SSE 事件。durable 帧带 `id: <seq>` 行（断线经
// Last-Event-ID 续传）；ephemeral 帧（Seq 0）省略——实时不 replay。作 StreamSSE 的 onEvent。
func WriteStreamEnvelope(out io.Writer, env streamdomain.Envelope) error {
	data, err := MarshalStreamEnvelope(env)
	if err != nil {
		return err
	}
	if env.Seq == 0 {
		_, err = fmt.Fprintf(out, "event: stream\ndata: %s\n\n", data)
	} else {
		_, err = fmt.Fprintf(out, "event: stream\nid: %d\ndata: %s\n\n", env.Seq, data)
	}
	return err
}
