# EDGE-338 · testend 网关指向关闭端口

## L1 focused evidence

- `testend/harness/server.go` 默认将测试 `ANSELM_GATEWAY_URL` 指向关闭回环端口；workspace 创建的异步免费档开通会快速失败，不触碰真实网关 install。
- 本轮完整 `make -C backend testend` 通过；真实 managed gateway 不属于该隔离 fixture，未产生 install 或配额副作用。

## 判定

L1=`F4`：测试场景对“真实网关线缆”与本地确定性 test fixture 做了明确隔离，避免无意登记/花费。L2-L5 本批未启动真实 App，记 `na`。
