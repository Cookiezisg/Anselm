# EDGE-323 进全屏白带：L5 真实 App 可发现性证据

## User goal

普通用户希望把 Anselm 放大到全屏工作，并能用 macOS 熟悉的全屏入口退出；不需要知道
toolbar、`willEnterFullScreen` 或窗口管理实现。

## Real App path

正式 session=`/private/tmp/anselm-rig-formal-20260831-11/sessions/20260901-215951`。
窗口化启动后的 macOS 标准窗口 AX 树明确暴露全屏按钮；通过该真实入口进入全屏，稳定
后再用 macOS 标准 `super+ctrl+f` 退出。进入与退出后均回到可继续操作的 Settings 页面，
没有要求用户寻找内部设置或输入命令。

## Judgment

全屏入口沿用系统窗口语义，位于用户熟悉的 macOS window controls 中；退出使用系统标准
快捷键，产品没有制造第二套隐蔽的全屏概念。进入后内容连续铺满，退出后恢复窗口态，
所以用户能完成目标且不会因顶部白带或空白残影误以为应用卡住。

Computer Use 全屏截图中的彩色顶部伪影已在 L4 证据中原样记录并与 WindowServer、绑定
窗口录屏交叉核对；它不改变真实 App 的可发现性结论，但会作为后续台架升级的明确仪器
缺陷保留，不能从证据中静默抹掉。

L5=`G1`：入口与退出路径不依赖项目文档，且稳定画面不引入误导性白带。
