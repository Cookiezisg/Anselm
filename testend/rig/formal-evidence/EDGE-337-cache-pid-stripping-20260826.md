# EDGE-337 · testend 缓存剥 pid

## L1 focused evidence

- `testend/harness/server.go` 的 runtime cache save-back 在回存前剥离 `*.pid` 运行态记录；embedder pid 只服务当前轮启动/收台，不进入共享缓存。
- backend/testend 全量通过，最终进程审计无 embedder 残留。
- 2026-08-27 补充 `testend/harness/server_test.go` 的
  `TestPrunePIDFilesKeepsRuntimeFilesOnly`，并与 scratch 活性测试一起通过 `go test ./harness -count=1`；
  两个 pid 文件被移除，普通 runtime 文件保留。

## 判定

L1=`F3`：缓存不携带可能被未来 OS 复用的陈旧 pid，回收器不会误杀无关进程。L2-L5 本批未启动真实 App，记 `na`。
