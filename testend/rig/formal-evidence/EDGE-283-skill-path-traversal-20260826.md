# EDGE-283 · skill 路径穿越

## L1 focused evidence

- `backend/internal/infra/fs/skill/filetruth_test.go:TestStore_Files_TraversalMatrix` 与 `TestStore_Files_SymlinkEscapeBlocked` 通过：相对穿越、绝对路径、反斜杠和 symlink 逃逸均被拒，skill 根目录外没有产物。
- `backend/internal/app/skill/files_test.go` 同时覆盖 files 面写入与清单路由校验；manifest 不作为普通文件绕过 frontmatter 验证。

## 判定

L1=`E4`：skill 文件写入保持在 skill 根目录内，危险路径不会被静默接受。L2-L5 本批未启动真实 App，记 `na`。
