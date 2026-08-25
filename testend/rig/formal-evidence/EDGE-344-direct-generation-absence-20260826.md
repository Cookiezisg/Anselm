# EDGE-344 直连生成整体退场

- 判定对象：仅有 BYOK、没有受管 install 时的生成能力目录。
- 证据：`TestGenerateImage_HonestAbsence`、`TestGenerateVideo_HonestAbsenceWithoutAKey` 通过；`TestSpeech_HonestAbsence` 通过。
- 产品判断：无路由时入口不注入，而不是让用户点进必失败的工具；有路由时能力按场景独立出现。
- 法条：E4。

