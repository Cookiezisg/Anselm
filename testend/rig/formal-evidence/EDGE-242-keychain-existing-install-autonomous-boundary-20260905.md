# EDGE-242 · keychain 铸钥只对全新安装：自动化边界记录

## 已完成的自动验证

在 `frontend` 目录执行：

```text
mise exec -- flutter test test/core/process/master_key_test.dart --reporter compact
00:01 +8: All tests passed!
exit=0
```

8 个分支均通过：已有 keychain 条目优先、全新安装铸钥并读回、已有数据库且无条目时不铸新钥、静默写失败、抛异常、读超时和写超时。测试同时证明自定义 `ANSELM_DATA_DIR` 的数据库探测不会误查默认 HOME。

## 未冒充的部分

本 edge 的产品断言需要在真实 App 冷启动时同时满足“磁盘已有旧数据库”和“真实登录 keychain 没有 `anselm.master-key`”。当前正式安装使用真实登录 keychain，不能通过删除或替换该条目来构造负向条件，因为这会破坏当前安装的密文归属；现有台架也没有独立、可安全销毁的 keychain profile。因而本轮没有把 focused Flutter test、旧的启动记录或其他 keychain 授权结果冒充为新的 L2-L5 真实 App 五通道证据。

## 调度结论

L1 的既有 `F5` focused 判定保持。L2-L5 不写 pass、na 或 provisional；该项保留在 `manual_queue`，并从当前 `forced_queue` 队首移到队尾。阻碍是可安全隔离的真实 macOS keychain profile/旧装机冷启动条件缺失，不是代码测试失败。已有实现仍由 `frontend/test/core/process/master_key_test.dart` 锁定：旧装机缺条目时返回 `null` 走 legacy fingerprint，keychain 异常或超时不会阻塞启动。
