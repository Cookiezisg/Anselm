// Package deviceproof owns the desktop installation's non-exported Ed25519 key
// and the HTTP proof transport used by the built-in Anselm gateway provider.
package deviceproof

import (
	"context"
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"fmt"
	"os"
	"path/filepath"

	cryptodomain "github.com/sunweilin/anselm/backend/internal/domain/crypto"
)

const keyFile = "device-proof.key"

var b64 = base64.RawURLEncoding

// Signer is one installation identity. Only the encrypted seed is persisted.
type Signer struct{ private ed25519.PrivateKey }

// LoadOrCreate loads the encrypted seed or creates it atomically. An empty data
// dir intentionally creates an ephemeral identity for in-memory tests.
func LoadOrCreate(ctx context.Context, dataDir string, enc cryptodomain.Encryptor) (*Signer, error) {
	if enc == nil {
		return nil, fmt.Errorf("deviceproof: encryptor is nil")
	}
	if dataDir == "" {
		return generate()
	}
	path := filepath.Join(dataDir, keyFile)
	ciphertext, err := os.ReadFile(path)
	if err == nil {
		if err := os.Chmod(path, 0o600); err != nil {
			return nil, fmt.Errorf("deviceproof: protect existing key: %w", err)
		}
		seed, err := enc.Decrypt(ctx, ciphertext)
		if err != nil {
			return nil, fmt.Errorf("deviceproof: decrypt key: %w", err)
		}
		return fromSeed(seed)
	}
	if !os.IsNotExist(err) {
		return nil, fmt.Errorf("deviceproof: read key: %w", err)
	}
	s, err := generate()
	if err != nil {
		return nil, err
	}
	sealed, err := enc.Encrypt(ctx, s.private.Seed())
	if err != nil {
		return nil, fmt.Errorf("deviceproof: encrypt key: %w", err)
	}
	if err := os.MkdirAll(dataDir, 0o700); err != nil {
		return nil, fmt.Errorf("deviceproof: create data directory: %w", err)
	}
	tmp, err := os.CreateTemp(dataDir, ".device-proof-*")
	if err != nil {
		return nil, fmt.Errorf("deviceproof: create temporary key: %w", err)
	}
	tmpName := tmp.Name()
	defer os.Remove(tmpName)
	if err := tmp.Chmod(0o600); err != nil {
		_ = tmp.Close()
		return nil, fmt.Errorf("deviceproof: protect key: %w", err)
	}
	if _, err := tmp.Write(sealed); err != nil {
		_ = tmp.Close()
		return nil, fmt.Errorf("deviceproof: write key: %w", err)
	}
	if err := tmp.Sync(); err != nil {
		_ = tmp.Close()
		return nil, fmt.Errorf("deviceproof: sync key: %w", err)
	}
	if err := tmp.Close(); err != nil {
		return nil, fmt.Errorf("deviceproof: close key: %w", err)
	}
	if err := os.Rename(tmpName, path); err != nil {
		return nil, fmt.Errorf("deviceproof: install key: %w", err)
	}
	return s, nil
}

func generate() (*Signer, error) {
	_, private, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		return nil, fmt.Errorf("deviceproof: generate key: %w", err)
	}
	return &Signer{private: private}, nil
}

func fromSeed(seed []byte) (*Signer, error) {
	if len(seed) != ed25519.SeedSize {
		return nil, fmt.Errorf("deviceproof: invalid seed length %d", len(seed))
	}
	return &Signer{private: ed25519.NewKeyFromSeed(seed)}, nil
}

// PublicKey returns the RFC 8032 public key in base64url form.
func (s *Signer) PublicKey() string {
	return b64.EncodeToString(s.private.Public().(ed25519.PublicKey))
}

// Thumbprint is the stable key id used during registration.
func (s *Signer) Thumbprint() string {
	sum := sha256.Sum256(s.private.Public().(ed25519.PublicKey))
	return b64.EncodeToString(sum[:])
}
