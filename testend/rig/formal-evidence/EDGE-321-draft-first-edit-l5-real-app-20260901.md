# EDGE-321 草稿文档首次编辑：L5 真实 App 可发现性证据

## User goal

普通用户目标是：在 Library 创建并保存一篇新页面，确认自己输入的内容没有丢失。用户不需要知道
“draft”“claim id”或首次编辑会触发 POST。

## Real App path

真实 session=`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-214332`。Library 空选区态
直接呈现 `Untitled`、`Add a description...`、`Add a tag` 和 `Start writing, or press / for commands`。
用户先离开再返回，空稿仍然没有偷偷出现在文档树；点击正文引导并输入后，左树出现单一 `Untitled`，
右侧立即给出 `Path /Untitled`、`Size 18 B` 和修改时间，明确反馈页面已创建并保存。继续输入后，
返回该页面仍显示正文和更新后的 `30 B` 大小。

## Judgment

入口、操作提示、创建反馈和结果验证均在真实 App 中可见；用户通过“Start writing”即可自然开始，
无需内部知识、命令或额外帮助。离开再返回后单一树项与 Inspector 信息提供了可理解的完成反馈，
没有把“空稿”误显示为已保存页面。L5=`G1`。

证据沿用清洁场 L4 的真实录像和五通道交叉记录，但本格只判用户入口、提示、反馈和目标完成，不把
内部日志或模型 wire 当作可发现性证据：`testend/rig/formal-evidence/EDGE-321-draft-first-edit-l4-fixed-real-app-20260901.md`。
