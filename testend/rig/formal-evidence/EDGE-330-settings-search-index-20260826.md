# EDGE-330 · 设置项搜索索引漂移

## L1 focused evidence

- `frontend/test/features/settings/settings_search_test.dart` 通过：索引项全局唯一、都归属 catalog panel、双语言 label/hint 非空。
- 同文件通过 anchor-mount gate：逐面板实测 mounted anchors 与声明式 `settingsSearchIndex` 完全相等；搜索分组、跳转洗亮和空态均通过。

## 判定

L1=`F1`：设置搜索索引、面板 catalog 与实际挂载三方一致，新增或遗漏搜索行会被测试门禁直接暴露。L2-L5 本批未启动真实 App，记 `na`。
