# SURF-110 stage/agent investigation

## Scope

验收 Agent 舞台的四个配置槽与版本编辑：`prompt`、`tools`、`knowledge`、`modelOverride`。产品目标是用户可以从自然语言完成创建，并在只改 prompt 的编辑后仍看见真实、完整、可读的挂载配置；live 阶段显示未触碰槽的旧真相，settled 阶段显示当前版本并允许 prompt 在有界视口内滚动。

## Static contract

- `frontend/lib/features/chat/ui/stages/agent_stage.dart` 同时消费四个字段；prompt live 取末尾有界行，settled 使用有界代码视口，tools/knowledge/model 在 live 阶段保留旧槽的低墨层，落定后回全墨。
- `create_agent` 的 `knowledge` 是文档 ID 数组；`tools` 是带 `ref` 的对象数组；`modelOverride` 是同时包含 `apiKeyId` 与 `modelId` 的对象。
- `edit_agent` 是局部合并；只提交 `prompt` 时，tools、knowledge、modelOverride、metadata 应保持不变并生成新版本。

## Real run

- session: `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-100206`
- workspace: `ws_54e12e38cccbb4b2`
- conversation: `cv_4ee51ebc9d84275b`
- app window: `2104`; backend `14232`; ssetap `14287`; llmtap `14208`; recorder `14787`
- recording: `screen.mov`, finalized `572.313333s`, `2784x1808`
- agent: `ag_5f61179bfce0af74`, `surf110-planner`

### Negative paths retained

1. 首次 `create_agent` 把 `knowledge` 发成 JSON 字符串，后端明确返回 `json: cannot unmarshal string into Go struct field .configArgs.knowledge of type []string`；App 显示“草稿未保存 · 尚未创建实体”，没有实体副作用。
2. 第二次使用正确的 knowledge 数组和真实 ID，但 `modelOverride` 缺少 `apiKeyId`；后端明确返回 `invalid modelOverride (apiKeyId and modelId both required)`，App 仍显示未创建实体，没有 v1。
3. 停止一次重复推理时出现 `incremental block persistence failed; finalize will retry ... context canceled`；这是取消路径的已知收尾 WARN，原样保留，不作为成功路径错误隐藏。

### Positive path

1. 最终创建调用只创建一个 Agent v1：`knowledge=["doc_cb76412ca8fc8183"]`，`tools=[{"ref":"fn_a62ac98dd28924cd"}]`，`modelOverride={"apiKeyId":"aki_fa6cda7c029fecb7","modelId":"anselm-auto"}`，并保留名称、描述、标签和 prompt。
2. REST `GET /api/v1/agents/ag_5f61179bfce0af74` 返回 active v1，四个配置槽均为上述真实值。
3. 第二次真实编辑只提交 `prompt`，生成 v2 并追加 `Always state which knowledge document informed the answer.`；tools、knowledge、modelOverride、description、tags 均保持不变。
4. REST active v2、SSE close、主内容和右侧舞台均显示同一 v2；历史失败卡仍在活动区，但没有被误报为成功实体。

## Product observations

- 最终画面 `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-100206/evidence/SURF-110-stage-agent-settled.png` 显示 v2 prompt、`greet`、`上手指南`、`anselm-auto`、tags、description 和版本；字段没有被字符串化内容污染。
- 录屏抽查的 `430s/455s/470s/500s` 帧均保持同一 settled 版式，无 clipping、overlap、RenderFlex、持续跳变或错误重排。
- 观察器的 AX `set_value` 与可视编辑器不同步，以及输入桥丢失中文/下划线，是测试仪器边界；该事实保留并不计为产品成功证据。正向结论来自真实 gateway mutation、REST、SSE、录屏和 UI settled truth 的交叉核验。

## Product verdict

创建→查看→只改 prompt→重新查看的用户目的达成。四个配置槽完整落地，局部编辑不丢挂载，不产生重复实体；错误参数大声失败且没有半成品污染。该格可进入五级账本。
