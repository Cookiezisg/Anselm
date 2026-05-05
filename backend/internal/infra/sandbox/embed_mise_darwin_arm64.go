//go:build darwin && arm64

package sandbox

import _ "embed"

// miseBinary holds the mise executable for darwin-arm64. Populated at
// compile time by go:embed; ExtractMiseBinary writes it to disk + chmods +
// codesigns on first boot.
//
// miseBinary 在编译时通过 go:embed 装入 darwin-arm64 mise 可执行文件；
// ExtractMiseBinary 首次启动时落盘 + chmod + codesign。
//
//go:embed mise/darwin-arm64/mise
var miseBinary []byte
