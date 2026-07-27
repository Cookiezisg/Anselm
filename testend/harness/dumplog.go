// dumplog.go — the model's-eye view of the wire, captured. Shared VERBATIM by the two things that
// can hold it: LLMMock (the scripted fake) and Recorder (the transparent proxy in front of a real
// upstream). Both answer the same question — "what did the model actually receive?" — so both must
// answer it with the same words, or a scenario ported from fake to real money silently changes
// meaning while still compiling.
//
// dumplog.go —— 模型视角的线缆,捕获下来。由能持有它的两者**逐字共用**:LLMMock(脚本化假件)与
// Recorder(真上游前面的透明代理)。两者回答的是同一个问题——**模型到底收到了什么**——故必须用同一套
// 词回答;否则一个从假件搬到真钱上的场景,会在照常编译的同时悄悄改变含义。
package harness

import (
	"encoding/json"
	"strings"
	"sync"
	"testing"
	"time"
)

// dumpLog is the append-only capture log. Embedded (not owned) so both holders expose the same
// three accessors with the same names — that is the whole point.
//
// dumpLog 是只追加的捕获账本。**内嵌**(而非各自持有),使两个持有者暴露同名的同三个访问器——这正是要点。
type dumpLog struct {
	dmu   sync.Mutex
	dumps []PromptDump
}

func (d *dumpLog) add(p PromptDump) {
	d.dmu.Lock()
	d.dumps = append(d.dumps, p)
	d.dmu.Unlock()
}

// Dumps returns a copy of every captured request so far.
//
// Dumps 返回至今捕获的全部请求副本。
func (d *dumpLog) Dumps() []PromptDump {
	d.dmu.Lock()
	defer d.dmu.Unlock()
	out := make([]PromptDump, len(d.dumps))
	copy(out, d.dumps)
	return out
}

// DumpsFor returns the captured requests addressed to one model id.
//
// DumpsFor 返回发给某 model id 的捕获请求。
func (d *dumpLog) DumpsFor(model string) []PromptDump {
	var out []PromptDump
	for _, x := range d.Dumps() {
		if x.Model == model {
			out = append(out, x)
		}
	}
	return out
}

// WaitDumps polls until at least n requests hit the given model id.
//
// WaitDumps 轮询直到某 model id 至少收到 n 个请求。
func (d *dumpLog) WaitDumps(t *testing.T, model string, n, timeoutMS int) []PromptDump {
	t.Helper()
	deadline := time.Now().Add(time.Duration(timeoutMS) * time.Millisecond)
	for time.Now().Before(deadline) {
		if ds := d.DumpsFor(model); len(ds) >= n {
			return ds
		}
		time.Sleep(50 * time.Millisecond)
	}
	t.Fatalf("harness: model %s never received %d requests (got %d)", model, n, len(d.DumpsFor(model)))
	return nil
}

// parsePromptDump turns one raw OpenAI-shaped chat request into the model's-eye view. Content that
// is NOT a plain string (a multimodal parts array) is kept as raw JSON text rather than flattened:
// that array IS the evidence in every media scenario, and flattening it would erase the one thing
// worth asserting on.
//
// parsePromptDump 把一个原始 OpenAI 形聊天请求变成模型视角。**非**纯字符串的 content(多模态 parts
// 数组)保留为原始 JSON 文本、不拍平:在每个媒体场景里**那个数组就是证据**,拍平会抹掉唯一值得断言的东西。
func parsePromptDump(raw json.RawMessage) PromptDump {
	var req struct {
		Model    string          `json:"model"`
		Messages json.RawMessage `json:"messages"`
		Tools    []struct {
			Function struct {
				Name string `json:"name"`
			} `json:"function"`
		} `json:"tools"`
	}
	_ = json.Unmarshal(raw, &req)

	dump := PromptDump{Model: req.Model, Raw: raw}
	for _, t := range req.Tools {
		dump.Tools = append(dump.Tools, t.Function.Name)
	}
	var msgs []struct {
		Role       string          `json:"role"`
		Content    json.RawMessage `json:"content"`
		ToolCallID string          `json:"tool_call_id"`
		ToolCalls  []struct {
			Function struct {
				Name string `json:"name"`
			} `json:"function"`
		} `json:"tool_calls"`
	}
	_ = json.Unmarshal(req.Messages, &msgs)
	for _, mm := range msgs {
		dm := DumpMsg{Role: mm.Role, ToolCallID: mm.ToolCallID}
		var s string
		if json.Unmarshal(mm.Content, &s) == nil {
			dm.Content = s
		} else {
			dm.Content = string(mm.Content)
		}
		for _, tc := range mm.ToolCalls {
			dm.ToolNames = append(dm.ToolNames, tc.Function.Name)
		}
		if mm.Role == "system" && dump.System == "" {
			dump.System = dm.Content
			continue
		}
		dump.Messages = append(dump.Messages, dm)
	}
	return dump
}

// HasImagePart reports whether any captured message carried a native image part whose bytes match
// the given base64 payload. This is THE media assertion: a pipeline can be green end to end while
// the model saw nothing but the sentence "upstream gave you a picture".
//
// HasImagePart 报告是否有任一捕获消息带着**原生** image part 且其字节等于给定 base64。这是**那条**
// 媒体断言:整条流水线可以端到端全绿,而模型看到的只是一句「上游给了你一张图」。
func (d *PromptDump) HasImagePart(b64 string) bool {
	raw := string(d.Raw)
	return strings.Contains(raw, "image_url") && strings.Contains(raw, b64)
}
