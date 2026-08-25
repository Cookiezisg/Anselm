package fsnotify

import (
	"testing"
	"time"

	notifyfsnotify "github.com/fsnotify/fsnotify"
)

// TestConfigEventKind — regression for the round-2 iteration finding: the delivered eventKind must
// use the same lowercase config vocabulary (create|modify|delete|rename|chmod) the create_trigger
// description advertises, NOT fsnotify's raw UPPERCASE Op.String() (CREATE/WRITE/REMOVE…), so a
// downstream CEL filter against the documented enum matches. Combined ops join their tokens with "|".
func TestConfigEventKind(t *testing.T) {
	cases := []struct {
		op   notifyfsnotify.Op
		want string
	}{
		{notifyfsnotify.Create, "create"},
		{notifyfsnotify.Write, "modify"},
		{notifyfsnotify.Remove, "delete"},
		{notifyfsnotify.Rename, "rename"},
		{notifyfsnotify.Chmod, "chmod"},
		{notifyfsnotify.Create | notifyfsnotify.Write, "create|modify"},
	}
	for _, c := range cases {
		if got := configEventKind(c.op); got != c.want {
			t.Errorf("configEventKind(%v) = %q, want %q", c.op, got, c.want)
		}
	}
}

func TestDedupKey_UsesPathOperationAndSecondBucket(t *testing.T) {
	base := time.Date(2026, time.August, 25, 11, 22, 33, 100_000_000, time.UTC)
	if got, want := dedupKey("/tmp/report.txt", "modify", base), dedupKey("/tmp/report.txt", "modify", base.Add(800*time.Millisecond)); got != want {
		t.Fatalf("events in one UTC second must share a dedup key: %q != %q", got, want)
	}
	if got, same := dedupKey("/tmp/report.txt", "modify", base.Add(time.Second)), dedupKey("/tmp/report.txt", "modify", base); got == same {
		t.Fatalf("the next second must produce a new dedup key: %q", got)
	}
	if got, same := dedupKey("/tmp/report.txt", "delete", base), dedupKey("/tmp/report.txt", "modify", base); got == same {
		t.Fatalf("different operations must not share a dedup key: %q", got)
	}
	if got, same := dedupKey("/tmp/other.txt", "modify", base), dedupKey("/tmp/report.txt", "modify", base); got == same {
		t.Fatalf("different paths must not share a dedup key: %q", got)
	}
}
