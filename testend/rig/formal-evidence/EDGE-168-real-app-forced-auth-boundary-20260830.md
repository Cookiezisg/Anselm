# EDGE-168 每租户模板 URL：真实 App 强制授权边界

- session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260830-173148`
- 真实 App 从 MCP servers marketplace 打开 `com.glean/mcp` 的安装计划，表单显示必填 `GLEAN_MCP_URL`、租户 endpoint 示例和 `Connect & authorize`。
- 本轮停在授权按钮之前：没有猜测租户 URL，没有启动浏览器 OAuth，没有创建 OAuth grant，也没有持久化 MCP server。原因是该动作会建立持久访问凭证，必须在 action time 获得确认。
- 这不是产品格通过，也不是 `na`。COVERAGE 保持 `EDGE-168=✓~~~~`，L2-L5 继续开放；该行从历史 `manual_queue` 候选补入显式 `forced_queue`，避免顺序门要求代理静默创建授权。
- 本 session 只用于确认真实 App 的表单与安全边界，未作为 EDGE-168 L2-L5 的正式证据提交。收台时没有新增安装行或 OAuth credential。
