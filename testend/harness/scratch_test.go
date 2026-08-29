package harness

import (
	"os"
	"path/filepath"
	"strconv"
	"testing"
)

func TestReapStaleScratchUsesPIDLiveness(t *testing.T) {
	root := t.TempDir()
	dead := filepath.Join(root, "999999999")
	live := filepath.Join(root, "notes")
	current := filepath.Join(root, strconv.Itoa(os.Getpid()))
	for _, dir := range []string{dead, live, current} {
		if err := os.Mkdir(dir, 0o700); err != nil {
			t.Fatal(err)
		}
	}

	reapStaleScratch(root)

	if _, err := os.Stat(dead); !os.IsNotExist(err) {
		t.Fatalf("dead run scratch still exists: %v", err)
	}
	for _, dir := range []string{live, current} {
		if _, err := os.Stat(dir); err != nil {
			t.Fatalf("non-numeric or live scratch was removed: %s: %v", dir, err)
		}
	}
}
