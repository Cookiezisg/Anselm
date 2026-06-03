# Round 0011 — crypto 切片（波次 0 · M0.3）

类型 / 目标：迁移 crypto 垂直切片 —— domain port + infra adapter，全部原样保留。

依赖扫描：
- `domain/crypto`：仅 import `context`（纯抽象）。
- `infra/crypto`：`crypto/aes·cipher·rand·sha256` + `os/exec` + `runtime`（全 stdlib），**生产代码不 import domain/crypto**（Go 隐式接口）。
- 下游：`app/apikey`（用 Encryptor 接口）、`response/errmap`（crypto error→HTTP）、`main`（构造 + 注入）。

它是什么：
- `domain/crypto.Encryptor`：加解密 port（版本化密文，多算法可共存）。
- `infra/crypto/aesgcm.go`：AES-256-GCM，线格式 `v1:base64(nonce‖ct‖tag)`，每次随机 nonce（IND-CPA），`DeriveKey(fingerprint)`→32B。
- `infra/crypto/fingerprint.go`：跨平台机器指纹（darwin ioreg / win reg / linux machine-id），无 fallback。

架构范本（首个 port+adapter 切片）：domain 出 port（零外部依赖）、infra 出 adapter（隐式满足、**生产代码零 import port**）、app 用 port、main 接线。DIP 正确方向：禁 `domain→infra`，许 `infra→domain 抽象`。测试用 `var _ Encryptor = (*AESGCMEncryptor)(nil)` 做编译期断言防实现漂移（测试依赖，非生产依赖）。

判定：全部保留原样（干净、安全、目标架构必需）。无 user_id/gorm/Phase 叙述。`v1:` 版本化是加密工程正确实践（非 over-engineer）。

删除 / 移出：无。

契约变更：无对外契约。

新测试：aesgcm 10（往返/v1 前缀/非确定 nonce/错 key 失败/不支持版本/缺前缀/短密文/篡改拒绝/key size 校验/DeriveKey 确定性）+ fingerprint 3（非空/确定/无 fallback，sandbox 无 ioreg 时 skip）。

验证：`gofmt` 净 / `go build ./...` OK / `go vet` OK / `go test ./internal/infra/crypto` 绿。

是否更干净：本就干净，原样保留。确立 **port-adapter 范本**（domain 港口 + infra 适配器，依赖只从外向内）。

覆盖状态：crypto 切片 cleaned。**M0.3 完成**（logger R0010 + crypto R0011）。

衔接（M7）：main 用 `DeriveKey(MachineFingerprint())` 现场派生 vs 之前见的 `~/.forgify/encryption-key` 文件 → 登记 deps-todo。

下一步：M0.4 `domain/errors` + `domain/eventlog` + `domain/notifications`（横切契约）。
