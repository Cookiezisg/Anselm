package proxycore

import (
	"bufio"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
)

func TestHandlerWitnessesResponseBodyAfterStreaming(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, _ = io.WriteString(w, "first")
		if f, ok := w.(http.Flusher); ok {
			f.Flush()
		}
		_, _ = io.WriteString(w, " second")
	}))
	defer upstream.Close()
	u, err := url.Parse(upstream.URL)
	if err != nil {
		t.Fatal(err)
	}
	var witnessed []byte
	proxy := httptest.NewServer(HandlerWithResponseBody(u, nil, nil, func(_ *http.Response, body []byte) {
		witnessed = body
	}))
	defer proxy.Close()

	resp, err := http.Get(proxy.URL)
	if err != nil {
		t.Fatal(err)
	}
	got, err := io.ReadAll(resp.Body)
	_ = resp.Body.Close()
	if err != nil {
		t.Fatal(err)
	}
	if string(got) != "first second" || string(witnessed) != string(got) {
		t.Fatalf("downstream=%q witnessed=%q", got, witnessed)
	}
}

func TestHandlerForwardsProtocolUpgrade(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		conn, rw, err := http.NewResponseController(w).Hijack()
		if err != nil {
			t.Errorf("upstream hijack: %v", err)
			return
		}
		defer conn.Close()
		_, _ = rw.WriteString("HTTP/1.1 101 Switching Protocols\r\nConnection: Upgrade\r\nUpgrade: anselm-test\r\n\r\nhello\n")
		_ = rw.Flush()
	}))
	defer upstream.Close()
	u, err := url.Parse(upstream.URL)
	if err != nil {
		t.Fatal(err)
	}
	proxy := httptest.NewServer(Handler(u, nil, nil))
	defer proxy.Close()

	addr := strings.TrimPrefix(proxy.URL, "http://")
	conn, err := net.Dial("tcp", addr)
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()
	_, _ = fmt.Fprintf(conn, "GET /speech/asr HTTP/1.1\r\nHost: %s\r\nConnection: Upgrade\r\nUpgrade: anselm-test\r\n\r\n", addr)
	resp, err := http.ReadResponse(bufio.NewReader(conn), nil)
	if err != nil {
		t.Fatal(err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusSwitchingProtocols {
		t.Fatalf("status = %d, want 101", resp.StatusCode)
	}
}
