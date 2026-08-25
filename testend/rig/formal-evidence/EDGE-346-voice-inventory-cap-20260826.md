# EDGE-346 音色库存两槽上限

- 判定对象：第三个音色登记时的库存闸。
- 证据：`backend/internal/app/voice` 与 `frontend/test/features/settings/voices_card_test.dart` 通过；前端测试覆盖满库存、剩余槽位和“删除一个腾位”文案。
- 产品判断：库存是明确的资源上限，不与金额或每日配额混淆；满态给出可执行的删除路径。
- 法条：E1。

