# EDGE-336 · testend 超时/被杀由下一轮收

## L1 focused evidence

- `testend/harness/scratch.go` 的 stale-run 清扫按 `$TMPDIR/anselm-testend/<pid>/` pid 活性识别死亡轮次，先按进程存活状态收割，再删除 scratch 目录。
- 完整 testend 通过，收台后的进程审计为零；当前轮不会把前一轮未收尸误算成下一轮的正常缓存。

## 判定

L1=`F5`：测试二进制超时或被 SIGKILL 后，下一轮仍能从持久 scratch/进程事实收敛，不遗留隐形执行体。L2-L5 本批未启动真实 App，记 `na`。
