# EDGE-297 · 触点目录穷尽性 · L2-L5 适用性边界

## 断言

EDGE-297 检查的是 bootstrap 组装出的工具名称全集是否逐项在 touchpoint catalog 中有
明确 extraction 或 no-touch 表态。它的产品对象是发布构建的完整性，而不是用户在 App
中执行某个动作后得到的状态。

## L2 · 五通道事实

L2 的“真实 App 状态”要求在场景中有可观察的产品结果。该门禁没有独立场景结果：缺项时
启动构建失败，缺项本身不会通过用户入口成为一条触点记录；全集通过时也不产生独立的
用户可见状态、SSE 业务事件、LLM 请求或后端业务行。因此 L2 对本断言不适用。完整性事实
由 `backend/internal/bootstrap/touchpoint_gate_test.go:TestTouchpointCatalog_CoversEveryTool`
和 `backend/internal/app/touchpoint/catalog_test.go:TestCovers` 直接承担。

## L3 · 顺滑

该门禁没有用户输入、异步等待、动画或可持续交互反馈，因而不存在可测的响应时序或位移
对象；L3 不适用。

## L4 · 视觉 craft

该门禁没有用户界面、错误卡、列表、徽标或其它视觉成品。它不能合理援引 C1-C5 评价
几何、颜色、层级或对齐；L4 不适用。

## L5 · 可发现性

该门禁没有用户入口、命名 affordance 或可学习的操作。它不是一个用户需要从零发现的
能力；L5 不适用。

## 约束

本边界不是缺少现场证据的 waiver。任何未来把该门禁暴露为用户可见的诊断页、启动错误
修复入口或触点审计 UI 的改动，都必须删除这些 `na` 裁决，并按新的产品表面重新走五级
验收。L1 仍由现有 focused 装配门禁负责。
