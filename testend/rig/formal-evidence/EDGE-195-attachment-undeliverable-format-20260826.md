# EDGE-195 attachment undeliverable format

- 结论：`pass`（L1 focused managed-media boundary）；L2-L5 按当前独立台架边界记 `na`。
- 目标：受管路由遇到 HEIC/AVIF 等 staging 闭集之外的图片时，在上传到网关之前给出点名文件和 MIME
  的诚实占位，不调用 uploader，不让一次不可交付附件摧毁整轮回答。

## focused regression

```text
cd backend && mise exec -- go test ./internal/app/attachment \\
  -run '^TestToContentParts_ManagedUndeliverableFormatDegradesInsteadOfStoppingTurn$' \\
  -count=1 -race -v
PASS
ok  github.com/sunweilin/anselm/backend/internal/app/attachment 1.694s
```

真实 application service 上传 `IMG_0001.HEIC`，注入受管 `RemoteMedia`，然后投影到模型输入。测试
确认返回单个文字占位，包含文件名 `IMG_0001.HEIC` 与 `image/heic`；uploader 调用数为零，证明
不可交付格式在网关上传前被拦下。

## 判定边界

```text
L2 na: 本格未在独立正式 rig session 中完成受管 HEIC/AVIF App 五通道录制
L3 na: 没有本格独立的格式提示、等待与重新附加建议 Computer Use 时序测量
L4 na: 没有本格独立的不可交付图片卡片、MIME 文案与布局视觉 craft 比对
L5 na: 没有本格独立的新用户发现并理解手机照片格式限制及解决路径的 discoverability session
```
