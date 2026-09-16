// Package crypto defines the at-rest encryption contract. Implementations
// live in infra/crypto.
//
// Package crypto 定义持久化加密契约；实现在 infra/crypto。
package crypto

import (
	"context"

	errorspkg "github.com/sunweilin/anselm/backend/internal/pkg/errors"
)

// ErrDecrypt is wrapped into every Decrypt failure whose cause is the key, not the format: the
// ciphertext is well-formed but was sealed under a different master key (the keychain was
// unavailable for one launch, a dev build shared the data directory). Callers that own a
// re-creatable secret match on it to regenerate instead of failing.
// 密文格式正确、但封在另一把主密钥下(某次启动钥匙串不可用、开发版共用数据目录)时,每个 Decrypt 失败
// 都包上 ErrDecrypt。持有可重建秘密的调用方据此重建,而不是失败。
var ErrDecrypt = errorspkg.New(errorspkg.KindInternal, "CRYPTO_DECRYPT_FAILED", "ciphertext does not open under the current master key")

// Encryptor encrypts/decrypts byte slices, content-agnostic. Ciphertext
// carries a 'v1:' version tag making the format self-describing; Decrypt
// rejects any non-v1 ciphertext.
//
// Encryptor 加密/解密任意字节切片，与内容无关。密文带 'v1:' 版本标签使格式
// 自描述；Decrypt 拒绝任何非 v1 密文。
type Encryptor interface {
	// Encrypt seals plaintext into versioned ASCII-safe ciphertext.
	// Encrypt 封装明文为带版本的 ASCII 安全密文。
	Encrypt(ctx context.Context, plaintext []byte) ([]byte, error)

	// Decrypt reverses Encrypt. Rejects unsupported versions / malformed
	// ciphertext with non-nil error — never returns (nil, nil).
	// Decrypt 是 Encrypt 的逆操作。不支持版本或畸形密文返非 nil 错误，
	// 绝不返 (nil, nil)。
	Decrypt(ctx context.Context, ciphertext []byte) ([]byte, error)
}
