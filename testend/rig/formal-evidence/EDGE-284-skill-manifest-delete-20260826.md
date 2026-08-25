# EDGE-284 · skill 清单拒删

## L1 focused evidence

- `backend/internal/app/skill/files_test.go:TestDeleteFile_ManifestRefused` 通过：删除 `SKILL.md` 返回 ErrFilePathInvalid。
- 同文件的 `TestWriteFile_ManifestRoutesThroughValidation` 证明清单写入走结构化校验，不会因 files 面而失去主文件约束。

## 判定

L1=`E1`：不可执行的删除动作被明确拒绝，用户仍可使用 skill 级 DELETE。L2-L5 本批未启动真实 App，记 `na`。
