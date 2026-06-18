package fsnotify

import (
	"testing"

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
