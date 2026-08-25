# EDGE-146 handler 产物目录 chdir 恢复

- 结论：`pass`（L1 Handler driver/产物目录生命周期语义）；L2-L5 按当前台架边界记 `na`。
- 预期：一次带 `out` 的调用即使异常退出，driver 也必须在 `finally` 中恢复 cwd 并清除
  `ANSELM_OUT`。调用方随后可能删除本次产物目录；驻留进程仍应能继续服务下一次带产物调用，
  之后的无产物调用也不能继承旧目录。

## focused stdio driver

```text
cd backend && mise exec -- go test ./internal/app/handler -run '^TestDriverScript_(GeneratorFinals|ArtifactDirRestoresAfterFailure)$' -count=1 -race -v
=== RUN   TestDriverScript_GeneratorFinals
--- PASS: TestDriverScript_GeneratorFinals (0.04s)
=== RUN   TestDriverScript_ArtifactDirRestoresAfterFailure
--- PASS: TestDriverScript_ArtifactDirRestoresAfterFailure (0.04s)
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/handler 2.003s
```

`TestDriverScript_ArtifactDirRestoresAfterFailure` 运行真实生成的 `DriverScript` 与
`AssembleClass`：第一调用在 `out-first` 中抛异常，测试随后删除该目录；驻留进程接着在
`out-second` 中成功执行 `where`，最后再执行无 `out` 的 `where`。断言同时检查：第二次 cwd
为真实解析后的 `out-second`、`ANSELM_OUT` 仍是该调用的原始传值，最后 cwd 回到 driver
启动目录且 `ANSELM_OUT` 为空。该回归覆盖了异常响应后的真实后续调用，而不是只查源码中的
`finally`。

## 真实 HTTP 黑盒

```text
cd testend && mise exec -- go test ./scenarios -run '^TestHandler_ArtifactPerCallProduct$' -count=1 -v
--- PASS: TestHandler_ArtifactPerCallProduct (4.46s)
PASS
ok  github.com/sunweilin/anselm/testend/scenarios 5.118s
```

现有真实 HTTP 场景通过驻留 Handler 的正常 `:call` 面验证两次调用各自产生独立产物目录、
独立附件 receipt，并成功读取两份 PNG 内容。它与 focused driver 回归共同覆盖 driver 的
恢复语义和应用层的产物交付语义。

## 判定边界

本格没有单独捕获完整真实 App 的 Computer Use 五通道 session，也没有独立视觉、等待时序或
discoverability 证据。因此 L2-L5 不越级登记：

```text
L2 na: 当前为 focused driver + 真实 HTTP/附件证据，没有本格独立五通道 App session
L3 na: 没有本格独立的 Computer Use 逐帧/等待时序测量
L4 na: 没有本格独立的视觉成品与 craft 比对
L5 na: 没有本格独立的用户可发现性 session
```
