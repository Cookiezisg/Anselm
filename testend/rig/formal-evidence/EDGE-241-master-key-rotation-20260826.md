# EDGE-241 · 换 master key 种子

## L1 focused evidence

- `backend/internal/infra/crypto/aesgcm_test.go:TestAESGCMEncryptor_DifferentKeyFailsDecryption` 证明旧密文在换用不同 master key 后不会被错误解开；round-trip 与 tamper/version guards 同批通过。
- `frontend/test/core/process/master_key_test.dart` 锁住 keychain 解析/注入边界，现有装机缺 key 不硬铸新钥。

## 判定

L1=`F5`：换钥后必须重新录入密文秘密，不能伪装成可恢复。L2-L5 本轮未做真实旧库重启 App 五通道 session，记 `na`。
