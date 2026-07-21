package deviceproof

import (
	"bytes"
	"context"
	"os"
	"path/filepath"
	"testing"
)

type testEncryptor struct{}

func (testEncryptor) Encrypt(_ context.Context, p []byte) ([]byte, error) {
	out := append([]byte("sealed:"), p...)
	for i := len("sealed:"); i < len(out); i++ {
		out[i] ^= 0xa5
	}
	return out, nil
}

func (testEncryptor) Decrypt(_ context.Context, p []byte) ([]byte, error) {
	out := append([]byte(nil), p[len("sealed:"):]...)
	for i := range out {
		out[i] ^= 0xa5
	}
	return out, nil
}

func TestLoadOrCreatePersistsOneEncryptedIdentity(t *testing.T) {
	dir := t.TempDir()
	a, err := LoadOrCreate(context.Background(), dir, testEncryptor{})
	if err != nil {
		t.Fatal(err)
	}
	b, err := LoadOrCreate(context.Background(), dir, testEncryptor{})
	if err != nil {
		t.Fatal(err)
	}
	if a.PublicKey() != b.PublicKey() || a.Thumbprint() != b.Thumbprint() {
		t.Fatal("reloading changed the device identity")
	}
	info, err := os.Stat(filepath.Join(dir, keyFile))
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0o600 {
		t.Fatalf("key mode = %o, want 600", info.Mode().Perm())
	}
	stored, err := os.ReadFile(filepath.Join(dir, keyFile))
	if err != nil {
		t.Fatal(err)
	}
	if bytes.Contains(stored, a.private.Seed()) {
		t.Fatal("key file contains the plaintext Ed25519 seed")
	}
}

func TestLoadRepairsExistingKeyPermissions(t *testing.T) {
	dir := t.TempDir()
	if _, err := LoadOrCreate(context.Background(), dir, testEncryptor{}); err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(dir, keyFile)
	if err := os.Chmod(path, 0o644); err != nil {
		t.Fatal(err)
	}
	if _, err := LoadOrCreate(context.Background(), dir, testEncryptor{}); err != nil {
		t.Fatal(err)
	}
	info, err := os.Stat(path)
	if err != nil {
		t.Fatal(err)
	}
	if info.Mode().Perm() != 0o600 {
		t.Fatalf("repaired key mode = %o, want 600", info.Mode().Perm())
	}
}
