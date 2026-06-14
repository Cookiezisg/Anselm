// Package crypto defines the at-rest encryption contract. Implementations
// live in infra/crypto.
//
// Package crypto 定义持久化加密契约；实现在 infra/crypto。
package crypto

import "context"

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
