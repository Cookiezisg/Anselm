//go:build !((darwin && (arm64 || amd64)) || (linux && (amd64 || arm64)) || (windows && amd64))

package sandbox

// miseBinary is empty on unsupported (GOOS, GOARCH) tuples (e.g. freebsd,
// linux/386). ExtractMiseBinary detects len(miseBinary)==0 and returns a
// friendly error referencing the host platform — Service.Bootstrap then
// flips Degraded Mode rather than crashing.
//
// 不支持 (GOOS, GOARCH) 时 miseBinary 为空（如 freebsd、linux/386）。
// ExtractMiseBinary 检测 len==0 返友好错带主机平台——Service.Bootstrap 翻
// Degraded Mode 而非 crash。
var miseBinary []byte
