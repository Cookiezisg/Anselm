package logtail

import (
	"fmt"
	"strings"
	"sync"
	"testing"
)

func TestBuffer_UnderCapVerbatim(t *testing.T) {
	b := New(100)
	for i := range 5 {
		fmt.Fprintf(b, "line %d\n", i)
	}
	got := b.String()
	want := "line 0\nline 1\nline 2\nline 3\nline 4\n"
	if got != want {
		t.Fatalf("under-cap output mutated:\n got %q\nwant %q", got, want)
	}
	if b.Empty() {
		t.Fatal("Empty() true after writes")
	}
}

func TestBuffer_OverCapKeepsHeadAndTail(t *testing.T) {
	b := New(20) // head 10 + tail 10
	b.Write([]byte("HEADHEADHE"))
	b.Write([]byte(strings.Repeat("x", 500)))
	b.Write([]byte("TAILTAILTA"))
	got := b.String()
	if !strings.HasPrefix(got, "HEADHEADHE") {
		t.Fatalf("head lost: %q", got)
	}
	if !strings.HasSuffix(got, "TAILTAILTA") {
		t.Fatalf("tail lost: %q", got)
	}
	if !strings.Contains(got, "truncated: 500 middle bytes dropped of 520 total") {
		t.Fatalf("missing/wrong truncation marker: %q", got)
	}
}

func TestBuffer_NilAndEmptySafe(t *testing.T) {
	var b *Buffer
	if n, err := b.Write([]byte("x")); n != 1 || err != nil {
		t.Fatalf("nil Write = (%d, %v)", n, err)
	}
	if b.String() != "" || !b.Empty() {
		t.Fatal("nil buffer not inert")
	}
	nb := New(10)
	if nb.String() != "" || !nb.Empty() {
		t.Fatal("fresh buffer not empty")
	}
}

func TestBuffer_ConcurrentWriters(t *testing.T) {
	b := New(1024)
	var wg sync.WaitGroup
	for range 8 {
		wg.Go(func() {
			for range 100 {
				b.Write([]byte("0123456789"))
			}
		})
	}
	wg.Wait()
	if b.Empty() {
		t.Fatal("no data after concurrent writes")
	}
	if got := b.String(); !strings.Contains(got, "8000 total") {
		t.Fatalf("total miscounted: %q", got[len(got)-120:])
	}
}
