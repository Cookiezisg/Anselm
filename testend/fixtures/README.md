---
id: DOC-082
type: reference
status: active
owner: @weilin
created: 2026-07-24
reviewed: 2026-07-24
review-due: 2026-10-24
audience: [human, ai]
---

# 多模态金标素材

`manifest.json` 是 C0 基线与后续 M/V 阶段共用的固定测试集合。仓库只保存配方、语义断言和每份产物
SHA-256，不保存大二进制。本地生成物的 hash 也受单测保护，确保相同代码得到相同证据。运行：

```bash
go run ./fixtures/cmd/materialize -out .cache/multimodal-fixtures
```

生成器会：

- 确定性生成文字截图、长图、PDF、DOCX 和合成音乐；
- 从阿里官方文档 CDN 下载照片、真实语音和短视频，下载后先验 SHA-256；
- 若本机有 `ffmpeg`，把已验真的短视频无转码循环为 `long.mp4`；没有时明确报错，不伪造成功。

`.cache/` 不进 Git。远程 URL 失效或内容漂移会让 materialize 失败；更新样本必须同时 review 新内容、
更新 hash、语义问题和基线报告。`mixed-media` 是同一次请求中的组合 case，不生成第四份重复原件。

这些素材的目标不是追逐逐字模型输出，而是冻结可机器判断的证据：文字/数字 sentinel、时间戳、模态
分离、不确定性与“不把互不相关的音画编成同一事件”。模型/provider 迁移必须重跑相同 manifest。
