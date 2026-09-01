# EDGE-184 短词 LIKE 回退 · L5

- 结论：`pass`
- 法条：`G1`（新用户不读内部文档即可走到目标入口）
- 正式 session：`/private/tmp/anselm-rig-formal-20260801-7/sessions/20260830-225024`

从普通 Chat 入口，用户只表达产品目标：找出一个包含精确短 token 的文档、展示匹配
文本，然后筛出同时满足两个 token 的文档。用户不需要知道 trigram、LIKE、FTS 或
search settings。模型自行发现 `search_documents` 与 `read_document`，先完成 `qx`
短词查找，再完成 `forecast + qx` 合取并解释排除原因；最终结果与数据库真实内容一致。

该路径验证的是用户目的达成和能力可发现性，不要求用户寻找内部搜索设置。中文 `天气`
的输入桥接实验单独披露为 Computer Use 输入限制，未把缺失的 CJK 字符当作本格产品
通过证据；本格的 L5 只依据成功完成的 ASCII 两字母短 token 产品旅程。
