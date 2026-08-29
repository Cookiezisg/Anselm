package harness

import (
	"os"
	"path/filepath"
	"testing"
)

func TestPrunePIDFilesKeepsRuntimeFilesOnly(t *testing.T) {
	dir := t.TempDir()
	for _, name := range []string{"embedder.pid", "bsh_123.pid", "python"} {
		if err := os.WriteFile(filepath.Join(dir, name), []byte("state"), 0o600); err != nil {
			t.Fatal(err)
		}
	}

	prunePIDFiles(dir)

	for _, name := range []string{"embedder.pid", "bsh_123.pid"} {
		if _, err := os.Stat(filepath.Join(dir, name)); !os.IsNotExist(err) {
			t.Fatalf("runtime cache retained pid file %s: %v", name, err)
		}
	}
	if _, err := os.Stat(filepath.Join(dir, "python")); err != nil {
		t.Fatalf("runtime file was pruned: %v", err)
	}
}
