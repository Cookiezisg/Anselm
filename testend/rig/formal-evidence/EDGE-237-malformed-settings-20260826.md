# EDGE-237 · 坏 settings.json

## L1 focused evidence

- `backend/internal/app/settings/settings_test.go:TestLoad_MalformedFileFails` 与 `TestRetention_MalformedFileFailsBoot` 写入坏 JSON，断言 Load/Boot 大声失败；通过。
- `TestLoad_AbsentFileIsDefaults` 同时锁住缺文件是纯默认而不是坏启动；通过。

## 判定

L1=`E1`：坏配置不被静默当作默认值，缺文件与损坏文件语义分开。L2-L5 本轮未做真实磁盘破坏后的 App session，记 `na`。
