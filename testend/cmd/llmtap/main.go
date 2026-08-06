// llmtap is the acceptance rig's standing LLM-wire witness (WRK-087 channel 5): the standalone
// process form of harness.Recorder. It sits between the backend and one real upstream (typically
// the Anselm free-tier gateway), forwards every byte, and journals every crossing to JSONL —
// request bodies land as per-call files so a multi-MB base64 image doesn't turn the journal into
// one unreadable line. "The model really saw the pixels" and "the cache really didn't pay twice"
// are only provable here, never in the model's own words.
//
// llmtap 是验收台架常驻的 LLM 线缆见证者(WRK-087 通道五):harness.Recorder 的独立进程形。它站在
// 后端与一个真上游(通常是 Anselm 免费档网关)之间,逐字节转发,并把每次穿越落进 JSONL——请求体落
// 成逐调用文件,几 MB 的 base64 图不会把 journal 压成一行读不了的东西。「模型真的看见了像素」与
// 「缓存真的没付第二次钱」只在这里可证,永远不在模型自己的话里。
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/sunweilin/anselm/testend/harness/proxycore"
)

type record struct {
	TS           string `json:"ts"`
	Event        string `json:"event,omitempty"`
	Upstream     string `json:"upstream,omitempty"`
	Method       string `json:"method"`
	Path         string `json:"path"`
	Size         int    `json:"size"`
	BodyFile     string `json:"bodyFile,omitempty"`
	ResponseFile string `json:"responseFile,omitempty"`
	Status       int    `json:"status,omitempty"`
}

func main() {
	listen := flag.String("listen", "127.0.0.1:8788", "listen address")
	upstream := flag.String("upstream", "", "real upstream origin, e.g. https://api.anselm.website (required)")
	out := flag.String("out", "", "journal JSONL path (required)")
	flag.Parse()
	if *upstream == "" || *out == "" {
		fmt.Fprintln(os.Stderr, "llmtap: -upstream and -out are required")
		os.Exit(2)
	}
	u, err := url.Parse(strings.TrimRight(*upstream, "/"))
	if err != nil || u.Host == "" {
		fmt.Fprintf(os.Stderr, "llmtap: bad upstream %q\n", *upstream)
		os.Exit(2)
	}
	journal, err := os.OpenFile(*out, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0o644)
	if err != nil {
		fmt.Fprintf(os.Stderr, "llmtap: open journal: %v\n", err)
		os.Exit(1)
	}
	bodies := filepath.Join(filepath.Dir(*out), "llm-bodies")
	if err := os.MkdirAll(bodies, 0o755); err != nil {
		fmt.Fprintf(os.Stderr, "llmtap: mkdir bodies: %v\n", err)
		os.Exit(1)
	}
	responses := filepath.Join(filepath.Dir(*out), "llm-responses")
	if err := os.MkdirAll(responses, 0o755); err != nil {
		fmt.Fprintf(os.Stderr, "llmtap: mkdir responses: %v\n", err)
		os.Exit(1)
	}

	var mu sync.Mutex
	n, responseN := 0, 0
	writeRec := func(r record) {
		r.TS = time.Now().Format(time.RFC3339Nano)
		b, err := json.Marshal(r)
		if err != nil {
			return
		}
		mu.Lock()
		_, _ = journal.Write(append(b, '\n'))
		mu.Unlock()
	}
	// A deterministic journey may legitimately make no model request (for example an inline
	// metadata PATCH). Keep channel 5 observable without fabricating a request/response pair.
	// 纯确定性旅程可能合法地不调模型(如就地 PATCH 元数据);保留通道五可见,但不伪造请求/响应对。
	writeRec(record{Event: "ready", Upstream: u.String()})

	// Request and response are journaled as two lines sharing method+path order rather than one
	// merged record: ModifyResponse fires on a different goroutine schedule than the request hook,
	// and pretending to pair them would fabricate an ordering the wire does not guarantee.
	// 请求与响应各落一行(共 method+path 的先后序)而非并成一条:ModifyResponse 与请求钩子的调度
	// 不同,假装配对等于伪造一个线缆并不保证的顺序。
	handler := proxycore.HandlerWithResponseBody(u, func(r *http.Request, body []byte) {
		mu.Lock()
		n++
		seq := n
		mu.Unlock()
		bf := ""
		if len(body) > 0 {
			bf = filepath.Join(bodies, fmt.Sprintf("%05d%s.bin", seq, strings.ReplaceAll(r.URL.Path, "/", "_")))
			_ = os.WriteFile(bf, body, 0o644)
		}
		writeRec(record{Method: r.Method, Path: r.URL.Path, Size: len(body), BodyFile: bf})
	}, func(resp *http.Response) {
		writeRec(record{Method: resp.Request.Method, Path: resp.Request.URL.Path, Status: resp.StatusCode})
	}, func(resp *http.Response, body []byte) {
		mu.Lock()
		responseN++
		seq := responseN
		mu.Unlock()
		file := filepath.Join(responses, fmt.Sprintf("%05d%s.bin", seq, strings.ReplaceAll(resp.Request.URL.Path, "/", "_")))
		if err := os.WriteFile(file, body, 0o644); err != nil {
			return
		}
		writeRec(record{Method: resp.Request.Method, Path: resp.Request.URL.Path, Size: len(body), ResponseFile: file, Status: resp.StatusCode})
	})

	fmt.Printf("llmtap: %s → %s (journal %s)\n", *listen, u.String(), *out)
	if err := http.ListenAndServe(*listen, handler); err != nil {
		fmt.Fprintf(os.Stderr, "llmtap: %v\n", err)
		os.Exit(1)
	}
}
