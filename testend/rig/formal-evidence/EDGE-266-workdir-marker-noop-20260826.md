# EDGE-266 · 空线程/重复 PATCH 不落 marker

## L1 focused evidence

- `backend/internal/app/conversation/workdir_test.go:TestUpdate_WorkDirNoopsAndAbsentKey` 通过。
- 空线程首挂与同路径重复 PATCH 均无“之前”可记录，动作保持 no-op，不污染消息历史。

## 判定

L1=`F5`：marker 只描述真实状态迁移，重启/刷新不会出现伪造的驻地历史。L2-L5 本批未启动真实 App，记 `na`。
