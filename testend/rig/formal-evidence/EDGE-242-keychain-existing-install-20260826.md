# EDGE-242 · keychain 铸钥只对全新安装

## L1 focused evidence

- `frontend/test/core/process/master_key_test.dart` 的 existing database/no key、existing keychain、fresh install mint/read-back、silent write failure、throwing keychain 六分支全部通过。
- 旧装机路径断言 `resolve()` 返回 null 且不写 keychain；keychain 故障降级而不阻塞启动。

## 判定

L1=`F5`：已有数据库绝不硬注新钥，keychain 异常不把产品启动打砖。L2-L5 本轮未重跑真实旧装机 App session，记 `na`。
