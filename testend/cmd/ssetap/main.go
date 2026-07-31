// ssetap is the acceptance rig's independent SSE witness (WRK-087 channel 3): it subscribes
// to the three streams exactly like the frontend does, but journals every wire frame to JSONL
// with a receive timestamp — bypassing the app's demux entirely, so what the UI claims can be
// checked against what the wire actually carried. Durable frames (seq > 0) advance a resume
// cursor; on disconnect the tap journals the gap and reconnects with ?fromSeq=<cursor>, so a
// long scenario's journal is honest about every hole in it.
//
// ssetap 是验收台架的独立 SSE 见证者（WRK-087 通道三）：像前端一样订阅三条流，但把每一帧
// 连同接收时戳落进 JSONL——完全绕开 app 的 demux，故「UI 声称的」可以对照「线缆真发的」。
// durable 帧（seq > 0）推进续传游标；断线时把缺口本身记进 journal 并以 ?fromSeq=<游标> 重连，
// 长场景的 journal 对自己的每一个洞都诚实。
package main

import (
	"bufio"
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"sync"
	"syscall"
	"time"
)

type record struct {
	TS     string          `json:"ts"`
	Stream string          `json:"stream"`
	Tap    string          `json:"tap,omitempty"` // connect / disconnect / stop — 台架自身事件,与线缆帧分开可辨
	Event  string          `json:"event,omitempty"`
	Seq    int64           `json:"seq,omitempty"`
	Data   json.RawMessage `json:"data,omitempty"`
	Err    string          `json:"err,omitempty"`
}

type journal struct {
	mu sync.Mutex
	w  *os.File
}

// write appends one JSONL line and fsyncs nothing: the OS page cache is fine for a rig
// journal, but the line itself must be whole — hence a single Write per record.
//
// write 追加一行 JSONL；不 fsync（台架 journal 走页缓存足够），但一行必须原子成行——
// 故每条记录恰一次 Write。
func (j *journal) write(r record) {
	r.TS = time.Now().Format(time.RFC3339Nano)
	b, err := json.Marshal(r)
	if err != nil {
		return
	}
	j.mu.Lock()
	defer j.mu.Unlock()
	_, _ = j.w.Write(append(b, '\n'))
}

func main() {
	base := flag.String("base", "http://127.0.0.1:8742", "backend base URL")
	ws := flag.String("ws", "", "workspace id (required)")
	token := flag.String("token", "", "bearer token (ANSELM_AUTH_TOKEN; empty = auth off)")
	out := flag.String("out", "", "journal path (default stdout)")
	streams := flag.String("streams", "messages,entities,notifications", "streams to tap")
	flag.Parse()
	if *ws == "" {
		fmt.Fprintln(os.Stderr, "ssetap: -ws is required")
		os.Exit(2)
	}

	w := os.Stdout
	if *out != "" {
		f, err := os.OpenFile(*out, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o644)
		if err != nil {
			fmt.Fprintf(os.Stderr, "ssetap: open journal: %v\n", err)
			os.Exit(1)
		}
		defer f.Close()
		w = f
	}
	j := &journal{w: w}

	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	var wg sync.WaitGroup
	for s := range strings.SplitSeq(*streams, ",") {
		s = strings.TrimSpace(s)
		if s == "" {
			continue
		}
		wg.Add(1)
		go func(stream string) {
			defer wg.Done()
			tap(ctx, j, *base, *ws, *token, stream)
		}(s)
	}
	wg.Wait()
	j.write(record{Tap: "stop"})
}

// tap runs one stream's connect→read→journal loop until ctx ends. The resume cursor only
// moves on durable frames — replaying ephemerals is not a thing the backend offers, and
// pretending otherwise would fabricate wire history.
//
// tap 跑一条流的 连接→读→落账 循环直到 ctx 结束。续传游标只随 durable 帧移动——后端本就
// 不重放 ephemeral，装作能重放等于伪造线缆历史。
func tap(ctx context.Context, j *journal, base, ws, token, stream string) {
	cursor := int64(-1)
	for ctx.Err() == nil {
		err := connectOnce(ctx, j, base, ws, token, stream, &cursor)
		if ctx.Err() != nil {
			return
		}
		j.write(record{Stream: stream, Tap: "disconnect", Err: errString(err)})
		select {
		case <-time.After(1 * time.Second):
		case <-ctx.Done():
			return
		}
	}
}

func connectOnce(ctx context.Context, j *journal, base, ws, token, stream string, cursor *int64) error {
	url := base + "/api/v1/" + stream + "/stream"
	if *cursor >= 0 {
		url += fmt.Sprintf("?fromSeq=%d", *cursor)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return err
	}
	req.Header.Set("X-Anselm-Workspace-ID", ws)
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("stream status %d", resp.StatusCode)
	}
	j.write(record{Stream: stream, Tap: "connect"})

	sc := bufio.NewScanner(resp.Body)
	sc.Buffer(make([]byte, 64*1024), 4*1024*1024)
	var event string
	var data json.RawMessage
	for sc.Scan() {
		line := sc.Text()
		switch {
		case strings.HasPrefix(line, "event:"):
			event = strings.TrimSpace(strings.TrimPrefix(line, "event:"))
		case strings.HasPrefix(line, "data:"):
			data = json.RawMessage(strings.TrimSpace(strings.TrimPrefix(line, "data:")))
		case line == "" && (event != "" || len(data) > 0):
			seq := extractSeq(data)
			if seq > *cursor {
				*cursor = seq
			}
			j.write(record{Stream: stream, Event: event, Seq: seq, Data: data})
			event, data = "", nil
		}
	}
	return sc.Err()
}

func extractSeq(data json.RawMessage) int64 {
	var env struct {
		Seq int64 `json:"seq"`
	}
	if json.Unmarshal(data, &env) != nil {
		return 0
	}
	return env.Seq
}

func errString(err error) string {
	if err == nil {
		return "eof"
	}
	return err.Error()
}
