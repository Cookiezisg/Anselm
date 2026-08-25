# EDGE-180 embedder 孤儿回收

- 结论：`pass`（L1 engine orphan-reap contract）；L2-L5 按当前独立台架边界记 `na`。
- 预期：上次非优雅退出留下 `runtimes/llamasrv/embedder.pid` 时，下一次 builtin embedder 启动必须 best-effort
  杀掉该 pid；缺失文件、垃圾内容和已死亡 pid 必须安全 no-op，不能把无关进程当成 Anselm 子进程。

## focused regression

```text
cd backend && mise exec -- go test ./internal/infra/search/engine \
  -run '^TestReapStalePID_KillsSurvivor$' -count=1 -race -v
PASS
ok  github.com/sunweilin/anselm/backend/internal/infra/search/engine 1.342s
```

Unix focused fixture 启动一个 `sleep` 进程作为遗留 embedder，写入其 pid 到 `embedder.pid`，调用
`reapStalePID` 后确认该进程被杀；随后以不存在路径和 `not-a-number` 内容验证异常记录不 panic、
安全无操作。测试使用临时目录与 deferred kill，不污染真实运行时目录。

## 判定边界

```text
L2 na: 本格未在独立正式 rig session 中执行真实 kill -9 后端再启动与五通道 App 录制
L3 na: 没有本格独立残留进程收容的 Computer Use 时序测量
L4 na: 没有本格独立启动收容提示的视觉成品与 craft 比对
L5 na: 没有本格独立新用户发现并理解孤儿回收状态的 discoverability session
```
