# EDGE-341 未验证供应商诚实标识真实 App 复验

真实 macOS Debug App + 受管网关台架进入 Settings → Models & keys → Add key。供应商目录真实显示
`0-100 of 213 items`；多个目录卡片同时显示供应商名、模型数量和 `未验证` 徽标，未把目录条目伪装成
已验证能力。Computer Use 打开 `302.AI` 的添加表单后只读检查名称、空密钥、Base URL 和取消入口，随后
取消返回 Models & keys；没有输入、上传或保存任何凭证，也没有产生 API key。

五通道收口：session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260827-210515`，录屏
`139.223333s`；`rig-check` 前后通过，backend=`201` 行、frontend=`3` 行、SSE=`9` 行、llmtap=`7` 行，
`rig-down` 正常封存且进程审计无残留。backend/frontend/SSE/LLM journals 无 panic/fatal/RenderFlex/
Unhandled/Exception 红线；llmtap wiring 通过，本次没有 completion。源码同时确认 `未验证` 徽标挂有
`unverifiedHint` tooltip，内容明确说明来源是 models.dev 且尚未由 Anselm 试过。

本轮真实观察没有独立 hover/tooltip 证据，也不是全新 onboarding，因此不把它冒充 L4/L5 新判决；既有
`L1:E4` 保持不变，正式账本与 50 格批次不变。
