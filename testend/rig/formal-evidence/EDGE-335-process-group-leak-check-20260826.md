# EDGE-335 · testend 进程组泄漏自检

## L1 focused evidence

- `testend/harness/server.go` 的 cleanup 在优雅停止后执行整组 SIGKILL 兜底，并轮询进程组；超时会 `t.Errorf` 并列出幸存者，而不是让测试保持绿色。
- 本轮 `make -C backend testend` 通过，收台后进程审计无 `anselm-server`、`llama-server`、`testend-bin` 残留。

## 判定

L1=`F3`：测试绿不等于收容成功，进程组自检把泄漏提升为显式失败；本轮真实收台审计也为零。L2-L5 本批未启动真实 App，记 `na`。
