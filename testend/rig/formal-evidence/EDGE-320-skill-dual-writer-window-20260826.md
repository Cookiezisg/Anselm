# EDGE-320 · skill 双写者竞态

## L1 focused evidence

- `frontend/test/features/library/library_test.dart` 通过：skill CONFIG 全量 PUT 保留 body/description，autosave 窗口内编辑在 unmount 时 flush，不丢数据。
- 同文件通过：source body 更新替换 native editor 内容但不 remount 页面壳，中心编辑器与 inspector 之间的归账边界稳定。

## 判定

L1=`F1`：双写者窗口的持久化真相仍是完整 frontmatter/body，已知 600ms 取舍不被伪装成无竞态。L2-L5 本批未启动真实 App，记 `na`。
