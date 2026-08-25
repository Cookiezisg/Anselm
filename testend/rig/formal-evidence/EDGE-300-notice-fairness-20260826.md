# EDGE-300 · 顶带公平调度

## L1 focused evidence

- `frontend/test/core/notice/notice_center_test.dart` 通过：`continuous priority yields one waiting normal after every three`，普通事件不会被 priority 长期饿死。
- 同文件 priority/normal ordering 测试通过：当前播放不被抢占，排队优先级只影响后继调度。

## 判定

L1=`A5`：高优先级反馈与普通事件之间有可验证的公平调度。L2-L5 本批未启动真实 App，记 `na`。
