# EDGE-290 · skill 未知 frontmatter 键保真

## L1 focused evidence

- `backend/internal/app/skill/files_test.go:TestReplaceRaw_UpdatesAndResyncsEquipEdges` 通过：未知的 `license` 键在 raw replace 后仍可读，allowed-tools 变化同步 equip edges。
- `backend/internal/app/skill/install_test.go:TestInstall_LandsWithProvenanceAndDerivedSource` 通过：安装不会把 provenance 写回原始 frontmatter，typed 投影与物理正文保持分离。

## 判定

L1=`F1`：typed 编辑不会吞掉扩展字段或污染原始文档，关系投影与正文同步。L2-L5 本批未启动真实 App，记 `na`。
