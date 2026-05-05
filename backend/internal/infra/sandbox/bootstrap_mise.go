// bootstrap_mise.go — D1-6 scaffold for the v2 PluginSandbox bootstrap.
// Design pinned here; binaries fetched + embedded by D2 once cmd/resources
// is rewritten to download mise per-platform.
//
// Plan (per documents/version-1.2/service-design-documents/sandbox.md §3 +
// §17, and the 2026-05-05 conversation decisions):
//
//   - Bundle a single mise binary per supported platform via go:embed.
//     Layout under this package:
//
//         mise/darwin-arm64/mise
//         mise/darwin-amd64/mise
//         mise/linux-amd64/mise
//         mise/linux-arm64/mise
//         mise/windows-amd64/mise.exe
//
//   - One *_<goos>_<goarch>.go file per platform declares
//
//         //go:embed mise/<goos>-<goarch>/mise[.exe]
//         var miseBinary []byte
//
//     so only the current build's binary is linked in. Other 4 stay on
//     disk in cmd/resources output and never bloat the binary.
//
//   - extractMise writes miseBinary to <dataDir>/sandbox/bin/mise, sets
//     0755, and on darwin runs ad-hoc codesign (--sign -) via the existing
//     macCodesign helper in preflight.go to defang Gatekeeper without an
//     Apple Developer ID. When the Developer ID arrives, swap the ad-hoc
//     hack for proper notarization in cmd/resources or release pipeline.
//
//   - Bootstrap idempotency: extractMise records a hash of the embedded
//     binary in <dataDir>/sandbox/.mise.hash; subsequent boots skip when
//     the hash is unchanged.
//
//   - Failure path: if no embed exists for the current GOOS/GOARCH (e.g.
//     freebsd, or a future platform we haven't built), extractMise must
//     return ErrPlatformUnsupported (not yet a sentinel — see D2 task list)
//     so the Service.Bootstrap caller can flip the Degraded Mode banner.
//
// D2 fills in:
//
//   1. cmd/resources rewrite to download mise binaries (with checksum +
//      retries) into the package's mise/<goos>-<goarch>/ directory.
//   2. The 5 per-platform _<goos>_<goarch>.go files with the embed directive.
//   3. extractMise body + hash idempotency.
//   4. Wiring into Service.Bootstrap (currently no Service exists; it lands
//      in D2 as well).
//
// bootstrap_mise.go ——D1-6 v2 PluginSandbox bootstrap 的骨架文件。
// 设计固化于此；二进制下载与 embed 留待 D2（cmd/resources 重写为按平台拉
// mise 后填进来）。
//
// 方案（依 sandbox.md §3 + §17 + 2026-05-05 对话决策）：
//
//   - 用 go:embed 按平台单独捆 mise 二进制，目录布局见英文段。
//   - 每平台一份 _<goos>_<goarch>.go 声明 `//go:embed ...` + miseBinary，
//     当前 build 只链入当前平台的二进制；另 4 份留在 cmd/resources 输出
//     目录，不污染 binary 体积。
//   - extractMise 把 miseBinary 写到 <dataDir>/sandbox/bin/mise + 0755；
//     darwin 上调 preflight.go 的 macCodesign（ad-hoc `--sign -`）在没有
//     Apple Developer ID 时绕开 Gatekeeper。等 Developer ID 到位换正式
//     notarization（cmd/resources 或 release pipeline 改）。
//   - 幂等：extractMise 把 embedded 二进制 hash 写到
//     <dataDir>/sandbox/.mise.hash；重启时 hash 没变跳过。
//   - 失败路径：当前 GOOS/GOARCH 无 embed 时（如 freebsd），extractMise
//     返 ErrPlatformUnsupported（待 D2 加 sentinel）让 Service.Bootstrap
//     翻 Degraded Mode 横幅。
//
// D2 实施：
//   1. cmd/resources 重写为 mise per-platform 下载器（checksum + 重试）。
//   2. 5 份 per-platform _<goos>_<goarch>.go embed 文件。
//   3. extractMise 函数体 + hash 幂等。
//   4. 接进 Service.Bootstrap（Service 本身也在 D2 落地）。

package sandbox

// extractMisePlaceholder is a build-time anchor for D1-6 — its sole purpose
// is to make the new bootstrap_mise.go file participate in compilation so
// the design notes above are not silently dropped from the package.
//
// D2 deletes this and replaces with extractMise(dataDir string) error.
//
// extractMisePlaceholder 是 D1-6 的编译期占位符——唯一作用是让本骨架文件
// 进入编译，避免上面的设计注释被无声丢弃。D2 删除并替换为
// extractMise(dataDir string) error。
//
//lint:ignore U1000 D1-6 scaffold; D2 replaces with the real extractMise.
func extractMisePlaceholder() {}
