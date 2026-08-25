package mcp

import (
	"context"
	"strings"
	"sync"
	"testing"

	mcpsdk "github.com/modelcontextprotocol/go-sdk/mcp"
)

func TestWithProgress_RoundTrip(t *testing.T) {
	if ProgressFrom(context.Background()) != nil {
		t.Fatal("no sink set → progressFrom must be nil")
	}
	got := ""
	ctx := WithProgress(context.Background(), func(s string) { got = s })
	if sink := ProgressFrom(ctx); sink == nil {
		t.Fatal("WithProgress sink not retrievable")
	} else {
		sink("x")
	}
	if got != "x" {
		t.Fatalf("sink not the one set: %q", got)
	}
	// nil sink is a no-op wrap.
	if ProgressFrom(WithProgress(context.Background(), nil)) != nil {
		t.Fatal("WithProgress(nil) must not set a sink")
	}
}

// TestOnProgress_RoutesByToken: a server progress notification reaches the CallTool that registered
// its token, and an unknown token is dropped (no panic).
//
// TestOnProgress_RoutesByToken：server 进度通知到达登记了该 token 的 CallTool，未知 token 丢弃（不 panic）。
func TestOnProgress_RoutesByToken(t *testing.T) {
	c := &client{}
	var got []string
	c.progress.Store("7", func(s string) { got = append(got, s) })

	c.onProgress(context.Background(), &mcpsdk.ProgressNotificationClientRequest{
		Params: &mcpsdk.ProgressNotificationParams{ProgressToken: "7", Message: "indexing", Progress: 3, Total: 10},
	})
	// unknown token → dropped, no panic.
	c.onProgress(context.Background(), &mcpsdk.ProgressNotificationClientRequest{
		Params: &mcpsdk.ProgressNotificationParams{ProgressToken: "999", Message: "stray"},
	})

	if len(got) != 1 || !strings.Contains(got[0], "indexing") || !strings.Contains(got[0], "3/10") {
		t.Fatalf("progress not routed/formatted to the registered sink: %v", got)
	}
}

func TestOnProgress_RoutesConcurrentCallsByToken(t *testing.T) {
	c := &client{}
	a := make(chan string, 2)
	b := make(chan string, 2)
	c.progress.Store("call-a", func(line string) { a <- line })
	c.progress.Store("call-b", func(line string) { b <- line })

	var wg sync.WaitGroup
	wg.Add(2)
	go func() {
		defer wg.Done()
		c.onProgress(context.Background(), &mcpsdk.ProgressNotificationClientRequest{
			Params: &mcpsdk.ProgressNotificationParams{ProgressToken: "call-a", Message: "alpha", Progress: 1, Total: 2},
		})
		c.onProgress(context.Background(), &mcpsdk.ProgressNotificationClientRequest{
			Params: &mcpsdk.ProgressNotificationParams{ProgressToken: "unknown", Message: "stray"},
		})
	}()
	go func() {
		defer wg.Done()
		c.onProgress(context.Background(), &mcpsdk.ProgressNotificationClientRequest{
			Params: &mcpsdk.ProgressNotificationParams{ProgressToken: "call-b", Message: "beta", Progress: 1, Total: 2},
		})
		c.onProgress(context.Background(), &mcpsdk.ProgressNotificationClientRequest{
			Params: &mcpsdk.ProgressNotificationParams{ProgressToken: "call-b", Message: "beta done"},
		})
	}()
	wg.Wait()
	close(a)
	close(b)

	var aLines, bLines []string
	for line := range a {
		aLines = append(aLines, line)
	}
	for line := range b {
		bLines = append(bLines, line)
	}
	if len(aLines) != 1 || !strings.Contains(aLines[0], "alpha") || strings.Contains(aLines[0], "beta") {
		t.Fatalf("call-a received cross-talk or wrong count: %v", aLines)
	}
	if len(bLines) != 2 || !strings.Contains(strings.Join(bLines, ""), "beta") || strings.Contains(strings.Join(bLines, ""), "alpha") {
		t.Fatalf("call-b received cross-talk or wrong count: %v", bLines)
	}
}
