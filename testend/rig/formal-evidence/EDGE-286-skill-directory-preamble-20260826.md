# EDGE-286 · skill 目录前导兜底

## L1 focused evidence

- `backend/internal/app/skill/files_test.go:TestActivate_PreambleOnlyWhenBundledFilesExist` 通过：单文件 skill 不加前导，带捆绑文件且无占位符时加目录前导。
- `TestActivate_SkillDirPlaceholderSubstituted` 通过：已有目录占位符时替换为真实 skill 路径且不重复添加前导。

## 判定

L1=`H1`：激活文本的目录锚点完整且不重复，避免模型看到无法访问的相对引用。L2-L5 本批未启动真实 App，记 `na`。
