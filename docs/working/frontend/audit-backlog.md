---
id: WRK-063
type: working
status: active
owner: @weilin
created: 2026-07-09
reviewed: 2026-07-09
review-due: 2026-10-07
audience: [human, ai]
landed-into:
---

# 全前端完整排查 —— 修复 Backlog

> **出身**:route ⑥ 遗留清账下,用户拍板发起「全前端完整排查」。14 区 finder(shell/设计系统/编辑器/运行时/chat 核心/工具卡/entities/documents/settings/notifications + 4 横切:i18n 硬编码·字重token违规·跨模块漂移·死码卫生)只读扫描 → 每条候选发现一个**对抗性 skeptic 读码证伪** → 合成。**64 条全 CONFIRMED**(原始 69,证伪剔除 5),84 agent、~480 万 token。方法论沿用 WRK-059(对抗验证防「可行性谎言」)。
>
> **总览**:类别 bug 16 · 跨模块漂移 15 · 风格不一致 11 · 资源泄漏 8 · i18n 7 · 设计 3 · 死码 2 · a11y 1 · perf 1;严重度(对抗校正后)**high 1 · med 9 · low 54**。最集中的系统性主题=**「同一语义值/工具函数在 N 处各写各的」**(见 §4,最值得成批修)。

---

## §1 P0 — 必修 bug

| # | 是什么 | 位置 | 严重度 | 状态 |
|---|---|---|---|---|
| 1 | 成功重启渲成 danger「重启失败」(不读 payload['ok'] → toast/OS 假失败) | `notifications/ui/notification_copy.dart:87` | **high** | ✅ 已修(5a375647) |
| 2 | trigger settle 正则 `tg_` 但真实 id `trg_` → 恒 null,R-16 settle 块从不渲 | `chat/ui/stages/trigger_stage.dart:123` | med | ✅ 已修(5a375647,顺修 fixture) |
| 3 | 支撑 kind(control/approval/trigger)揭示死掉的 run 终端(空钮 no-op) | `app/app_shell.dart:94` | med | ✅ 已修(5a375647,延用 executable 门控) |
| 4 | handler 首方法默认选中丢失(detail 后到不补 → 空 method 点 Run 报错) | `entities/ui/run/run_input_form.dart:52` | med | ✅ 已修(5a375647,build ref.listen) |
| 5 | 「重置本地偏好」点了看似无效(resetAll 不 invalidate provider → 直到重启) | `settings/ui/panels/storage_panel.dart:131` | med | ⏳ 待定行为(relaunch vs 就地失效各 provider) |
| 6 | restart_handler 报错但错因不可见(resultFailed 只 auto-expand、无 body 渲 error) | `chat/ui/tool_card_catalog.dart:832` | med | ⏳ 待修(需改回执/加 body) |
| 7 | @ 提及异步竞态(清空/选中不 bump seq → 陈旧搜索复活 picker) | `core/editor/an_editor.dart:293` | med | ✅ 已修(5a375647) |
| 8 | 编辑器 composer/document 永不 dispose(Editor.dispose 不级联 → 每次挂卸泄漏) | `core/editor/an_editor.dart:210` | med(leak) | ✅ 已修(5a375647) |

## §2 P1 — 一致性 / 设计 / i18n(违铁律或跨模块不一致)

| # | 是什么 | 位置 | 状态 |
|---|---|---|---|
| 12 | 4 份分叉字节格式化(缺 GB 档、与权威 `formatBytes` 不一致:2GB→「2048.0 MB」) | `chat/ui/tool_card_search.dart:151` +`tool_card_fs_search.dart:160`+`stages/exhibit_stage.dart:163`+`stages/document_stage.dart:165` | ⏳ |
| 13 | core/ui 原语硬编码英文 a11y `semanticLabel:'Remove'`(违自设 DIP) | `core/ui/an_attachment_chip.dart:78` | ⏳ |
| 14 | skill 页 tags 幻影编辑(渲出输入口但 onMetaChanged 忽略 tags 不落库) | `documents/ui/an_document_editor.dart:190` | ⏳ |
| 15 | head「生成中」蓝点非活源(订 notifications 流,回合走 messages 流 → 不亮/滞留) | `chat/ui/chat_head.dart:109` | ⏳ |
| 16 | settings 直接 import chat feature(followModeProvider),违「features 互不依赖」 | `settings/ui/panels/chat_panel.dart:17` | ⏳ |
| 17 | notifications 借 entities 命名空间取 errorTitle/retry | `notifications/ui/notification_feed.dart:84` | ⏳ |
| 18 | WindowZoom 手搓 SharedPreferences 绕过中央 SettingsPrefs(键成幽灵声明) | `core/platform/window_zoom.dart:26` | ⏳ |
| 19 | _SkillForm 快照 config → 外部 edit_skill 改动下次保存被 clobber | `documents/ui/documents_inspector.dart:313` | ⏳ |
| 20 | auto-title 打字机迟播(reveal id 永不过期,别海洋落地时迟迟播) | `chat/state/title_reveals.dart:26` | ⏳ |
| 21 | 散落 i18n 硬编码(wire 状态词/archived/cursor/source/yes-no/中文 lorem 5+ 处) | `handler_stage.dart:155`·`tool_card_catalog.dart:886`·`tool_card_memory_web.dart:120`·`workflow_editor_inspector.dart:353`·`an_editor.dart:456` | ⏳ |
| 22 | form 错误提示两套 idiom(models_keys meta+s12 / 其余 5 表 label+s8 / entities Callout) | `settings/ui/panels/models_keys_panel.dart:460` | ⏳ |
| 23 | api_client.postForId 裸 cast `id as String` 无 null 守卫(畸形 202 抛非 typed 错) | `core/net/api_client.dart:176` | ⏳ |

## §3 P2 — 卫生 / 低优 / token nit(批量清理)

- **禁用透明度 0.45 魔数**(应 `AnOpacity.disabled`=0.4):`an_switch.dart:51`·`an_segmented.dart:57`·`an_setting_row.dart:65`。
- **旋钮/分段阴影硬编码 theme-blind 色**(`Color(0x33000000)`/`Color(0x14000000)`):`an_switch.dart:76`·`an_segmented.dart:82`。
- **编辑器浮层尺寸魔数**(slash 328 vs mention 320;宽 208/268/232/320/280 各拍;阅读列 720):`an_editor_slash_menu.dart:159/210`·`an_editor_mention.dart:103`·`an_editor_toolbar.dart:313`·`an_editor_stylesheet.dart:93`。
- **阅读列 720 vs 672**:`an_document_editor.dart:63` documents 正文比别处宽 ~48px。
- **地层透明度漂移** 0.55/0.4/0.5(同 R-5 概念):`workflow_stage.dart:60`·control/agent stage·`AnLayerDiff`。
- **裸 `width:1` 应 `AnSize.hairline`**:`function_stage.dart:138`·`handler_stage.dart:109`。
- **裸 `Curves.easeOutCubic` 应 `AnMotion.easeOut`**:`an_switch.dart:66`·`an_segmented.dart:73`。
- **未 dispose 资源**:`an_editor_toolbar.dart:321` build 内 FocusNode;`chat_thinking.dart:206/249` 每帧 TextPainter;`an_editor_syntax.dart:24` 语法缓存永不淘汰;`runtime.dart:52` backendController ValueNotifier+`_probe` Dio;`toast_dispatcher.dart:29` `_lastFired` map 永不清。
- **非 autoDispose 漂移**:`document_ocean.dart:24` documentMentionNamesProvider(键=整篇 content,会话内无界)。
- **重复时间格式化** `_fmtDate` ≡ `fmtStamp`:`documents_inspector.dart:463`·`memory_panel.dart:175`。
- **死码**:`en.i18n.json` 36 个零引用叶子键;`core/models/`(1 provider)与 `core/model/`(7 文件)近重名目录。
- **一致性 nit**:`ui.dart:84` 桶文件缺 8 个 An* export;`an_overlay.dart:14/242` toast cap 注释仍写 5(实 3);`an_segmented.dart:26` doc「2–4 段」实 2–6;`an_secret_field.dart:85` 缺 cursorColor/cursorWidth(光标渲 Material 蓝);`app_shell.dart:62` headOwners 漏 settings(离开设置海洋残留面包屑幽灵按钮);`about_panel.dart:114` launchUrl 绕过 `openExternalUrl` 闸;`mcp_panel.dart:210` 详情头 reconnect 无 try/catch;`limits_panel.dart:203` 只 Enter 提交、失焦丢值。
- **a11y**:`an_setting_row.dart:60` reset 钮仅 hover 揭示、无焦点路径。
- **perf**:`an_editor.dart:217` 每键在防抖前同步序列化整篇 markdown(单用户近可忽略)。

## §4 跨模块系统性主题(最值得成批修)

1. **「同一语义值各写各的」token 缺口**——禁用透明度(3)·阴影色(2)·地层透明度(3)·阅读列 720(3)·浮层尺寸(5+)·hairline/曲线。**修法**:补齐 `AnOpacity`/knob-shadow/stratum/popover-size/reading-measure 语义 token,一轮全库替换。
2. **重复实现权威工具函数**——字节格式化 4 份·时间格式化 2+。**修法**:强制 import 地基删副本。
3. **未 dispose 资源模式**——7 处。**修法**:成批补 dispose + 审查项。
4. **i18n 硬编码散落**——7 处(含 core/ui 违自设 DIP、中文 lorem)+ 36 死键。**修法**:core/ui 一律注入/slang + 全库字面量扫描。
5. **features 互不依赖被破坏**——settings→chat、notifications→entities。**修法**:跨 feature 共享态上提 core/shared。
6. **实时点/信号源不一致**——head 点非活·composer 热切换绑 disposed·markRead 误扣徽标。**修法**:统一「点/计数只信活 transcript 或权威 refetch」。

## §5 待真机/运行时确认(代码坐实、后果依赖罕见时序)

`chat_composer.dart:562`(热切换+mid-thread 流式冻结)· `chat_head.dart:109`(蓝点)· `an_editor.dart:293`(提及竞态需真 backend 延迟)· `title_reveals.dart:26`(迟播)· `entity_list_provider.dart:74`(搜索激活时他处新建泄漏行)· `tool_card_catalog.dart:832`(仅当后端 completed 却带 error)。**P0 已修的 #1/#3/#4 亦建议真机 E2E 复核**(通知假失败需真 handler 重启、右岛门控需选支撑 kind、handler run 需真 detail 时序)。

---

## 建造进展

- **P0 批 ✅(2026-07-09,5a375647)**:6 个 CONFIRMED bug(#1/#2/#3/#4/#7/#8)已修 + 回归测(notification tone 分流覆盖 ok:true 盲区 / stages_w3 fixture 前缀纠正),fe-verify 3312 全绿。剩 #5(行为待定)+ #6(待修)。
