# SURF-093 i18n/coldStart — investigation and stop-and-fix record

## Red finding

With `RIG_SEED=0`, the real App correctly rendered the localized onboarding frame and `正在准备工作区…`, but the shell released after creation with four English Chat landing labels: `What should we dig into?`, `Auto`, `Mention an entity` and `Attach files`. The problem was found in native AX and the screenshot, not inferred from source. The red session was `/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-051818` and is explicitly excluded from green evidence.

## Fix

`frontend/lib/i18n/zh_CN.i18n.json` now contains natural Chinese for the full cold-start bundle and the four same-frame Chat labels. The generated slang files were regenerated, and `frontend/test/core/settings/locale_boot_test.dart` asserts the exact values. Existing workspace bootstrap/create-control tests remain in the targeted suite.

The chosen copy preserves product names and museum context while removing UI-language leakage: `Anselm · 首次使用预览`, `创建工作区`, `工作区名称`, `工作 №001`, `克里斯托费尔·比肖普 · 1862 · 荷兰国立博物馆`, `海姆斯科克与巴伦支规划第二次极北远征`, `自动`, `想从哪里开始？`, `提及实体`, `添加附件`.

## Green revalidation

Fresh repaired session=`/private/tmp/anselm-rig-formal-20260801-3/sessions/20260825-052124`, data=`/private/tmp/anselm-data-surf093-20260825-r2`. The real App re-ran empty-roster onboarding, create feedback and shell release. AX and the final frame agreed on every exposed label. The ASCII name `onboard093` was used for the mutation because the Computer Use CJK text injection path is an instrument limitation; it did not affect the Chinese copy/AX observation.

## Boundary

The duplicate-name state is proven by the exact API error mapping and focused widget test, but was not falsely labeled as a real duplicate mutation in this green session. The cold-start path also intentionally has no Chat completion: LLM wire readiness and managed routing were observed, while no user message was needed to judge onboarding.
