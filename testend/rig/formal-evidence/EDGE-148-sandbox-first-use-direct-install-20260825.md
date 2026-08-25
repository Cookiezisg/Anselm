# EDGE-148 sandbox 首次使用直装

- 结论：`pass`（L1 sandbox direct-install 首次使用语义）；L2-L5 按当前台架边界记 `na`。
- 预期：清空 runtime 根目录后，首次使用必须直接从上游下载钉死资产，校验发布摘要，原子解压
  到正式目录并能执行；重复 Install 应命中已存在二进制而幂等短路。测试不得依赖开发机已有缓存。

## 真实上游 e2e

```text
cd backend && mise exec -- go test -tags e2e ./internal/infra/sandbox -run '^TestE2E_DirectInstall$' -count=1 -v -timeout 600s
=== RUN   TestE2E_DirectInstall
=== RUN   TestE2E_DirectInstall/uv
    install_e2e_test.go:43: uv installed → runtimes/uv/0.11.4 (.../uv)
    install_e2e_test.go:49: uv [--version] → uv 0.11.4 (3523c2349 2026-04-07 aarch64-apple-darwin)
=== RUN   TestE2E_DirectInstall/node
    install_e2e_test.go:43: node installed → runtimes/node/22 (.../bin/node)
    install_e2e_test.go:49: node [--version] → v22.22.3
=== RUN   TestE2E_DirectInstall/python
    install_e2e_test.go:43: python installed → runtimes/python/3.12 (.../bin/python3)
    install_e2e_test.go:49: python [--version] → Python 3.12.13
--- PASS: TestE2E_DirectInstall (14.62s)
PASS
ok  github.com/sunweilin/anselm/backend/internal/infra/sandbox 15.172s
```

测试在 `t.TempDir()` 中从零开始，真实走 download → checksum → extract → layout → exec；UV、
Node、Python 均执行成功，并逐个再次 `Install` 验证 binary-present 的幂等短路。默认不纳入
226MB 的 dotnet，代码路径仍由同一 direct installer 覆盖。

## 判定边界

本格没有单独捕获完整真实 App 的 Computer Use 五通道 session，也没有独立视觉、等待时序或
discoverability 证据。因此 L2-L5 不越级登记：

```text
L2 na: 当前为真实上游 sandbox e2e，没有本格独立五通道 App session
L3 na: 没有本格独立的 Computer Use 逐帧/等待时序测量
L4 na: 没有本格独立的视觉成品与 craft 比对
L5 na: 没有本格独立的用户可发现性 session
```
