# EDGE-145 handler 纯 meta edit 不重启

- 结论：`pass`（L1 Handler resident/version/meta 语义）；L2-L5 按当前台架边界记 `na`。
- 预期：纯 `set_meta` edit 只改 Handler 行，不铸新版本、不重启 resident；共享内存态必须继续
  存活，避免一次无关重命名抹掉用户状态。

## focused service

```text
cd backend && mise exec -- go test ./internal/app/handler -run '^TestEdit_MetaOnlyNoVersionNoRestart$' -count=1 -race -v
=== RUN   TestEdit_MetaOnlyNoVersionNoRestart
--- PASS: TestEdit_MetaOnlyNoVersionNoRestart (0.07s)
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/handler 1.920s
```

focused 测试先 warm resident，再执行纯 `set_meta` edit；spawn 计数保持 1，随后调用继续
使用原内存态，版本集合不增加。

## 真实 HTTP 黑盒

```text
cd testend && mise exec -- go test ./scenarios -run '^TestContractEntities_HandlerResidentSemantics$' -count=1 -v
--- PASS: TestContractEntities_HandlerResidentSemantics (6.74s)
PASS
ok  github.com/sunweilin/anselm/testend/scenarios 7.054s
```

真实场景中计数 Handler 两次 `:call` 后为 2；PATCH 改名后下一次为 3；全 `set_meta` edit 改
描述后下一次为 4。随后 GET 仍只有一个 version，名称/描述已更新，证明 meta 行变更与 resident
class/version 生命周期分离。该真实场景同时完成了后续并发 spawn、schema 过滤和 generator 回归，
收台无 sandbox 残留。

## 判定边界

本格覆盖真实 HTTP、版本列表、meta 行与 resident memory truth；当前没有为本格单独捕获完整
真实 App 的 Computer Use 五通道 session，也没有独立视觉、时序或 discoverability 证据。因此
L2-L5 不越级登记：

```text
L2 na: 当前为 focused service + 真实 HTTP/version/resident 证据，没有本格独立五通道 App session
L3 na: 没有本格独立的 Computer Use 逐帧/等待时序测量
L4 na: 没有本格独立的视觉成品与 craft 比对
L5 na: 没有本格独立的用户可发现性 session
```
