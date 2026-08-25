# EDGE-285 · 大小写不敏感 FS 上的 skill.md

## L1 focused evidence

- `backend/internal/app/skill/files_test.go:TestWriteFile_ManifestRoutesThroughValidation` 通过小写 `skill.md` 写入并回读结构化 frontmatter。
- skill 文件存储实现对 manifest 采用 `SameFile` 语义处理大小写不敏感文件系统，避免清理时误删目标文件。

## 判定

L1=`F1`：manifest 的物理文件名差异不改变 skill 的结构化真相。L2-L5 本批未启动真实 App，记 `na`。
