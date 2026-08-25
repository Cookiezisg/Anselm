# EDGE-273 · workDir 三态 presence

## L1 focused evidence

- `backend/internal/app/conversation/workdir_group_test.go:TestList_WorkDirAndPinnedFilters` 通过三态 workDir/pin 过滤。
- 缺失 workDir、不带值的显式空值与具体 path 分别映射到不筛选、仅未挂、仅该驻地，服务端读取 query presence。

## 判定

L1=`F1`：过滤语义不被空字符串覆盖，rail 投影与请求真实意图一致。L2-L5 本批未启动真实 App，记 `na`。
