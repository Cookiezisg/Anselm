# EDGE-141 handler generator 终值两写法

- 结论：`pass`（L1 handler 协议与真实黑盒行为）；L2-L5 按当前台架边界记 `na`。
- 预期：Handler method 用 `yield` 产生最终值时，最后一个非 progress yield 成为返回值；method 用 `return` 从 generator 返回时，driver 捕获 `StopIteration.value`，不能把结果吞掉。

## 证据一：真实生成 driver 子进程

命令：

```text
cd backend && mise exec -- go test ./internal/app/handler -run '^TestDriverScript_GeneratorFinals$' -count=1 -race -v
=== RUN   TestDriverScript_GeneratorFinals
--- PASS: TestDriverScript_GeneratorFinals (0.05s)
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/handler  1.709s
```

该测试把 `AssembleClass` 的输出和生产 `DriverScript` 写入临时目录，启动真实
`python3`，通过 stdio 行 JSON 协议发送两个 call。协议顺序为 `ready`、两次
`progress`、两次 `return`；`yield_final` 返回 `{"v":"yield-final"}`，
`return_final` 返回 `{"v":"return-final"}`。后者证明 `StopIteration.value` 已经越过 driver
边界成为最终结果。

## 证据二：包内与真实 HTTP 回归

```text
cd backend && mise exec -- go test ./internal/app/handler -run '^(TestAssembleClass|TestWriteBody_Dedent)$' -count=1 -race -v
--- PASS: TestWriteBody_Dedent
--- PASS: TestAssembleClass

cd testend && mise exec -- go test ./scenarios -run '^TestContractEntities_HandlerResidentSemantics$' -count=1 -v
--- PASS: TestContractEntities_HandlerResidentSemantics (7.51s)
ok  github.com/sunweilin/anselm/testend/scenarios  8.134s
```

黑盒场景真实创建 Handler，并分别通过 `POST /api/v1/handlers/{id}:call` 调用
`yield_final` 与 `return_final`；两次均返回 HTTP 200，响应值分别为
`yield-final` 和 `return-final`。同一场景还验证了 resident、meta edit、冷启动并发和
active schema 过滤，收台时 sandbox 无残留。

## 判定边界

这是 handler 协议/执行正确性边界，L1 的 focused + black-box 证据足够；当前证据没有为
本格单独捕获完整真实 App 的 Computer Use 五通道 session，也没有独立的视觉、时序测量或
discoverability 录屏。因此 L2-L5 不越级登记：

```text
L2 na: 当前仅有真实 stdio/HTTP/backend 证据，没有本格独立五通道 App session
L3 na: 没有本格独立的 Computer Use 逐帧/等待时序测量
L4 na: 没有本格独立的视觉成品与 craft 比对
L5 na: 没有本格独立的用户可发现性 session
```
