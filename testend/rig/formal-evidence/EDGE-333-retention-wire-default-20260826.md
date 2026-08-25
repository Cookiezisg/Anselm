# EDGE-333 · 保留面板无客户端默认

## L1 focused evidence

- `frontend/test/features/settings/s5_storage_limits_test.dart` 通过：后端 fixture 返回 30 天时面板显示 30 天而不是客户端硬编 90，选择 180 天立即 PATCH 并展示成功反馈。
- 同文件通过：永久保留写入 0，机器 scope badge 正确存在；设置面板不维护 modified/onReset 假状态。

## 判定

L1=`F1`：保留策略的展示与提交都服从服务端线缆，用户不会看到伪造默认值。L2-L5 本批未启动真实 App，记 `na`。
