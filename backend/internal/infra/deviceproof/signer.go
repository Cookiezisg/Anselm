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
	"time"

	cryptodomain "github.com/sunweilin/anselm/backend/internal/domain/crypto"
)

const keyFile = "device-proof.key"

var b64 = base64.RawURLEncoding

// Signer is one installation identity. Only the encrypted seed is persisted.
type Signer struct {
	private ed25519.PrivateKey
	retired string
}

// RetiredKeyFile is the path an undecryptable previous key was moved to when this
// identity had to be regenerated, or empty when the stored key loaded normally.
// 上一把解不开的钥匙被挪到的路径(本次身份因此重新生成);正常加载时为空。
func (s *Signer) RetiredKeyFile() string { return s.retired }

// LoadOrCreate loads the encrypted seed or creates it atomically. An empty data
// dir intentionally creates an ephemeral identity for in-memory tests.
//
// A stored key that no longer decrypts is set aside and a fresh identity is minted
// instead of refusing to boot: the master key can legitimately change under the
// file (keychain unavailable for one launch, a dev build sharing the data dir),
// and the device proof is only an install identity the gateway re-registers,
// never user data. The retired file is kept so nothing is destroyed silently.
// 存的钥匙解不开时挪开并铸新身份,而不是拒绝启动:主密钥可能在文件底下合法地变了
// (某次启动钥匙串不可用、开发版共用数据目录),而 device proof 只是网关可重新注册的
// 安装身份,不是用户数据。旧文件保留,不无声销毁任何东西。
func LoadOrCreate(ctx context.Context, dataDir string, enc cryptodomain.Encryptor) (*Signer, error) {
	if enc == nil {
		return nil, fmt.Errorf("deviceproof: encryptor is nil")
	}
	if dataDir == "" {
		return generate()
	}
	path := filepath.Join(dataDir, keyFile)
	retired := ""
	ciphertext, err := os.ReadFile(path)
	if err == nil {
		if err := os.Chmod(path, 0o600); err != nil {
			return nil, fmt.Errorf("deviceproof: protect existing key: %w", err)
		}
		if seed, err := enc.Decrypt(ctx, ciphertext); err == nil {
			if s, err := fromSeed(seed); err == nil {
				return s, nil
			}
		}
		retired = fmt.Sprintf("%s.undecryptable-%d", path, time.Now().Unix())
		if err := os.Rename(path, retired); err != nil {
			return nil, fmt.Errorf("deviceproof: retire undecryptable key: %w", err)
		}
	} else if !os.IsNotExist(err) {
		return nil, fmt.Errorf("deviceproof: read key: %w", err)
	}
	s, err := generate()
	if err != nil {
		return nil, err
	}
	s.retired = retired
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
