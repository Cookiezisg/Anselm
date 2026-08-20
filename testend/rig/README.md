# 验收台架操作手册(testend/rig)

> **本手册自足**:任何 AI agent(或人)只读这一页即可操作整套台架——不依赖任何对话记忆。
> 战役宪法(判据金字塔 / 拍板台账 / 控制系统语义)在
> [`docs/working/acceptance-loop/README.md`](../../docs/working/acceptance-loop/README.md)(WRK-087);
> 裁决引用的法典在 [`CODEX.md`](../../docs/working/acceptance-loop/CODEX.md)(WRK-088);
> 记账的对象是 [`COVERAGE.md`](../../docs/working/acceptance-loop/COVERAGE.md)(WRK-089)。

## 台架是什么

五条观测通道,全部落盘 journal,使「产品对不对」永远以证据回答、不以印象回答:

| 通道 | 载体 | journal |
|---|---|---|
| ① 帧 | Computer Use 操作/稳定态截图 + conductor 绑定 Anselm 主窗口几何区域的 `screencapture -v -R` 连续录屏 → ffmpeg 抽帧 | `screen.mov` + 抽帧目录(不入 git) |
| ② 后端 | conductor 亲启的 sidecar,stdout 全量捕获 | `backend.log` |
| ③ SSE | `cmd/ssetap` 动态发现全部 workspace 并独立订三条流(不经前端 demux) | `sse.jsonl` |
| ④ 前端 | conductor 亲启的真实 `flutter run` App 与 console | `frontend.log` |
| ⑤ LLM 线缆 | `cmd/llmtap` 透明代理在受管网关前 | `llm.jsonl` + 逐调用请求体/响应体文件；启动先落 `event=ready`，无模型调用的旅程仍能证明线缆在线 |

所有会话落 `$RIG_HOME/sessions/<时间戳>/`；conductor 初始化 `evidence/` 与各 channel journal，
截图等证据可以直接写入该目录。`$RIG_HOME/current` 软链指认活会话，`manifest.json` 是其余脚本唯一读的连接事实。
启用录屏时，manifest 同时指向 `recording-lifecycle.json`；该文件记录 `screencapture` 进程的
`spawnRequestedAt` 与 `spawnReturnedAt`（UTC 微秒）及 PID。任何把 MOV PTS 与后端/SSE 时戳对齐的
延迟量测都必须使用这段高精度起点证据，不能再用录屏完成后写入、且只有秒精度的 `startedAt`。

Computer Use 的 macOS AX 树读取只在稳定态做；流式期间由连续 `screen.mov` 负责逐帧证据。原因是 Flutter
debug engine 在 AX 树正被替换时可能输出 `accessibility_bridge.cc ... Failed to update ui::AXTree`，这是观察器/引擎
交互噪声，但仍属于未审阅前端红线：`rig-check` 会拒绝它，证据必须另行说明「流中不读 AX、静置不增长、无
FlutterError/DartError/RenderFlex」后才可把它从产品缺陷中分流，不能用 grep 静默抹掉。菜单/锚定浮层另有
产品代码守卫：触发器树必须保留常驻的显式语义边界；若开合后 AX 红线仍持续增长，先修代码，不得直接归类为观察噪声。

审阅不是全局开关。若本 session 只出现 Flutter 固定格式的「旧 AX node 不在树中」行，须在该 session 的
`evidence/frontend-ax-review.md` 写入 `classification: tooling-ax-tree` 与 `status: reviewed`，并说明观察时机、
静置不增长、没有 Dart/Flutter/布局异常；`rig-check` 只按这两个精确字段放行。任何未知 AX 文字或应用级异常仍
硬失败，不能靠删日志或环境变量消音。

## 起 / 检 / 停

```bash
testend/rig/rig-up.sh      # 建二进制→起 llmtap/后端/ssetap/真实 App/窗口录像→manifest
testend/rig/rig-check.sh   # 五通道自检:权限/进程与端口归属/三流连接/受管接线/journal
testend/rig/rig-down.sh    # 先封口录像,再停 App→后端→双 tap;ffprobe MOV,journal 全保留
testend/rig/rig-rebind-app.sh # 产品内重启后显式重绑新 App PID/窗口,不自动收养外部进程
```

`rig-up.sh`、`rig-check.sh` 和 `rig-down.sh` 都不接受位置参数；`-h/--help` 只打印用法并退出，未知参数直接拒绝。
不要用一个会把参数透传给启动器的探查命令代替 help，否则台架可能在未形成 manifest 前启动真实 App。

环境旋钮:`RIG_HOME`(必须显式绝对路径)· `RIG_PORT`(8742;被占就换)· `RIG_BACKEND_WAIT_SEC`(60;启动时等待后端健康探针的秒数)·
`RIG_LLMTAP_PORT`(8788)· `RIG_DATA`· `RIG_SEED=0` 跳过播种并走真实首次 onboarding。`RIG_LLMTAP=0`、`RIG_RECORD=0`、
`RIG_APP=0` 只用于诊断；缺任一通道的会话不能通过 `rig-check` 或 L2 gate。需要验收启动门的三态时，使用
`RIG_APP_FIRST=1 RIG_BACKEND_START_DELAY_SEC=5` 让真实 App 先由录屏捕获 `starting → ready`；使用
`RIG_BACKEND_START_DELAY_SEC=25` 可让前端健康等待先落 `crashed`，后端随后仍由 conductor 启动，点击真实 `Retry`
即可复验恢复。该旋钮默认关闭，不改变普通台架的 backend-first 顺序；`startup-gate.jsonl` 与 manifest 一起记录
App、录屏、后端健康和 SSE 的事件时序。
需要验收 workspace 名册解析中的中间 loading 面时，使用默认 backend-first 顺序加
`RIG_APP_PROXY=1 RIG_APP_PROXY_DELAY_MS=2500`；它只把真实 App 的精确 `GET /api/v1/workspaces`
请求延迟，其他请求透明转发，backend 端口仍由 conductor 直接持有，ssetap 也仍直连 backend。
要验收某个首载列表的**真实错误+重试**，在同一路径上再给
`RIG_APP_PROXY_FAIL_COUNT=2 RIG_APP_PROXY_FAIL_STATUS=503`；对话 rail 首载的两条并行列表 `GET` 返回 N1
`RIG_INJECTED_FAILURE`，之后恢复透明转发，故可在同一冷载中观察骨架→错误、点击一次真实 Retry→列表。
`appproxy.jsonl`、`appProxyPid`、`appBackendUrl` 和 delay/failure 配置会写进 manifest；该扰动默认关闭，
只服务台架构造，不能拿它代替真实后端故障或正式性能数字。失败次数是并发安全的一次性预算，不能跨 session
重置，也不会改动 backend 或 SSE witness 的真实端口。
`RIG_LLMTAP=0` 时后端不注入网关环境，适合只用本地 API 清理 fixture；该模式仍保留 D1 端口归属检查。

出厂重置等“App 必须删除自己数据目录”的路径使用 `RIG_APP_OWNS_BACKEND=1`。此模式强制 App-first，
conductor 把刚构建的 `server` 放到真实 bundle executable 旁，由 `BackendController` 自己启动并监督；
conductor 再从精确子进程的 loopback listener 发现端口，继续接入 `ssetap` 和健康门。因为 Flutter
进程负责接收 owned sidecar 的 stderr，channel-2 的 `backend.log` 是从同一 session 的
`frontend.log` 中按 `[backend]` 前缀投影出的 sidecar-only journal，不能与外接 backend 模式混写；
manifest 会记录 `appOwnsBackend=1` 与 `appSidecarPid`，D1 仍以端口 holder、PID 和命令身份三者相等为准。

`RIG_HOME` 是本次验收的账本根：`judgments.jsonl`、`alarms.json`、`anchor-check.json` 和 `current`
必须来自同一个显式绝对目录。正式 session 使用 `RIG_HOME=/private/tmp/anselm-rig-formal-...` 时，
先在 shell 中 `export RIG_HOME=/private/tmp/anselm-rig-formal-...`，再运行 `rig-up.sh`、`rig-check.sh`、
`rig-down.sh` 或 `judge.py`、`alarms.py`、`anchors.py`；所有台架入口在变量缺失、相对路径或 `~` 路径时都会
fail-closed，不会再静默回落到个人默认目录。只有 `--help` 这种只读用法不要求作用域。不能把未绑定作用域的
clean 结果当作当前 session 的门禁证据。

`RIG_RECORD=1`(默认)时，`rig-up.sh` 会在构建后端、启动 observer、编译 Flutter 或启动真实 App **之前**
先用一次性 PNG 探测 Screen Recording 权限；探测失败立即退出并提示授权，不产生半启动的产品 session，也不把
缺少帧证据的后端日志误当成验收会话。该拒绝路径由 `test_screen_recording.py` 回归：模拟
`screencapture` 被系统拒绝时，不生成 server/ssetap/llmtap 二进制、不启动 observer、不创建 manifest。
`RIG_RECORD=0` 仅用于诊断：conductor 会把“跳过 Screen Recording TCC 探测”视为成功继续，避免
`set -e` 把刻意关闭录像的诊断态误报成权限失败；它仍会写明 `recording.disabled`，且不能通过正式
`rig-check` 或 L2 gate。正式验收始终必须使用 `RIG_RECORD=1`、真实窗口录像和可解析的封口 MOV。

所有进程经 `spawn.py` 建独立进程组，启动 shell 退出后仍受 manifest 所有；不要另外手起 App。真实
验收 App 由 conductor 先 `flutter build macos --debug`，再直接 spawn `.app/Contents/MacOS/anselm`，
故 `ANSELM_BACKEND_URL`、`ANSELM_DATA_DIR` 会进入**真实 App 进程**；这是刻意不用 `flutter run` 的地方，
因为 Flutter runner 交给 launch services 的子进程不会可靠继承 PTY runner 环境。`appLaunchPid` 与
`appPid` 必须相同且都活着；旧 session 若仍有 `runnerPid`，`rig-check` 仍兼容检查。台架启动前拒绝已有
Anselm App，启动后只接收新出现的精确 App 进程，并由录屏窗口反查 owner PID，不能把一个残留进程误判
为前端在线。产品内「重置本地偏好」或「出厂重置」会让 App 自己退出并启动新 PID；这不是外部进程，
但也不能由门禁猜测。重启后必须显式运行 `rig-rebind-app.sh`：旧 PID 已死、manifest 中的精确
`appBinary` 只有一个新候选、候选窗口 owner 是 Anselm 且几何与现有录屏区域完全一致，四项同时满足才更新
`appPid/appWindowId`，并把 `app_rebounded` 写入 `app-rebind.jsonl`。任一项不满足都拒绝，不能用
「看起来像同一个 App」放行；`rig-check` 会验证 rebind 账与当前五通道归属。`frontend-build.log` 保存
构建 console，`frontend.log` 保存真实 App stdout/stderr。正式验收还会向 App 注入 debug-only 的
`ANSELM_RELAUNCH_LOG`；出厂重置/本地偏好重启后的 replacement App 必须把 stdout/stderr 追加回同一
`frontend.log`，否则只能看到旧 PID，L2 不得放行。
若 replacement window 的几何发生变化，`rig-rebind-app.sh` 会先以 SIGINT 封口旧
`screen.mov`，再以新几何启动 `screen-rebind-<pid>.mov`；manifest 记录
`screenRecordingSegments` 和新的微秒 lifecycle，不会静默沿用 stale crop。需要单文件回放时，
收台后用同编码 segment 生成 `screen-final.mov`，并保留原段与重绑段供审计。
录像在
Flutter 窗口真正出现后按 CoreGraphics window ID 解析其几何区域，使用 `-R x,y,w,h` 录制该 App 区域；这样
同一窗口内的 OverlayPortal / 菜单浮层也进入连续帧，同时拒绝把全桌面录屏当作帧证据。manifest 同时保留
`appWindowId` 与 `appWindowBounds`，`rig-check` 对两者和 recorder 命令做归属复核。首次
注册场景用 `RIG_SEED=0`，ssetap 会在 onboarding 创建 workspace 后一秒内自动接管三条流。

`rig-check` 还会用 CoreGraphics 按前后层级扫描 Anselm 窗口上方的外部窗口；会话自己的 App 与 recorder PID
明确排除；Computer Use 自己的 `Software Cursor` 也作为仪器层明确列入白名单，任何其他与录制区域相交的
系统弹窗或其他应用都会硬失败。窗口区域录制不能证明“画面只属于产品”，所以不能用裁剪或“这只是权限弹窗”
放行；先清除外部遮挡，再重新录制整段 session。扫描器不调用 AppleScript / System Events，避免验收工具自己
触发新的 macOS 自动化授权弹窗。

## 两条铁律(都以真事故立法,自检强制执行)

- **D1 journal 归属**:持有服务端口的 PID 必须 == 捕获 stdout 的 PID。抢端口失败的后端瞬间死掉、
  journal 却依然像样——0728 真发生过,故 rig-up 拒收外来进程、rig-check 持续复验。
  (细节坑:`lsof -ti` 必须带 `-sTCP:LISTEN`,否则 tap 的客户端连接会被算成端口持有者。)
- **通道五接线**:受管 key 的 base_url 在 provision 时**落库**(`freetier.go` 存
  `AnselmGatewayBase()`),换过接线的旧数据目录会永远抱着旧指针——静默形态是受管流量绕开 tap
  而 `llm.jsonl` 只是安静。rig-up 在启动 ssetap、Flutter 与录制器**之前**就对每个已有 workspace
  做 fail-closed 校验：无 workspace/无 managed key 才允许 onboarding pending；缺地址、坏响应或指向别的
  端口都拒绝启动。rig-check 持续用同一严格判定复验。
  (相关后端 env:`ANSELM_GATEWAY_URL` 指 tap;`ANSELM_PROOF_HOST` 让 device-proof 的 htu
  签**真实受众**——受管流量按 DPoP 式设计天生反代理,唯一正当例外是设备自己的录制代理。)
  `llm.jsonl` 的 `event=ready` 只证明 recorder 已启动并绑定目标上游，不代表产生了模型流量；模型请求/响应仍必须逐条看真实 wire 记录。

透明代理对 `101 Switching Protocols` 必须保持 duplex body 原样可写；只对有限 HTTP 响应做 body witness。
否则语音 ASR 的上游虽返回 101，ReverseProxy 会因“non-writable body”拒绝升级，产品端只会看到假性的握手失败。

## 测量(凡能成为数字的视觉判断必须成为数字)

```bash
cd testend
go run ./cmd/measure diff -dir <frames/> -roi x,y,w,h
go run ./cmd/measure regions -img <shot.png> -color '#RRGGBB'
go run ./cmd/measure contrast -fg '#RRGGBB' -bg '#RRGGBB'
go run ./cmd/measure latency -dir <frames/> -fps 30 -action <0-based帧号> -roi x,y,w,h
go run ./cmd/measure compare -source <source.png> -frame <first-frame.png>
```

`compare` 是 `animate_image` 的首帧硬证据:它先把源图确定性归一到视频首帧的栅格,再输出变化像素占比和包围盒;默认 `changedFrac <= 0.20` 才通过。它不是逐编码器像素相等,而是防止上游把图生视频静默降级成另一幅文生视频构图。

`rig-down.sh` 会先封口录像再停 App，确保 MOV 尾帧仍属于 Anselm 窗口；之后再抽帧：

```bash
SESSION=$RIG_HOME/sessions/<时间戳>
mkdir -p "$SESSION/frames"
ffmpeg -i "$SESSION/screen.mov" -vf fps=30 "$SESSION/frames/f%06d.png"
```

ROI 应只框目标控件，排除时钟、鼠标、呼吸动画等无关变化；不使用 ROI 的全屏延迟数字通常无意义。

## 开工校准(先于任何 pass)

```bash
export RIG_HOME=/private/tmp/anselm-rig-formal-<session>
python3 testend/rig/anchors.py quiz
# 逐题填写 $RIG_HOME/anchor-quiz.json 的 verdict / law / reason
python3 testend/rig/anchors.py check "$RIG_HOME/anchor-quiz.json"
```

校准凭证绑定冻结题集且只活四小时；缺失、过期或题集变化时 `judge.py` 物理拒绝所有新 pass。

## 裁决与记账(标绿是脚本动作,不是文本编辑)

```bash
python3 testend/rig/judge.py "<清册行名>" --family TOOL|EP|SURF|EDGE --level 1..5 \
  --verdict pass|fail|na --law <CODEX 法条 id 或 measure:...> --evidence <盘上文件>
```

- pass/fail 必须引**存在于 CODEX.md** 的法条(或测量值);证据必须是盘上真实非空文件。
- `na` 用 `--evidence 'note:<为何不适用>'`。
- L2(数据真相)的 pass/fail 都须 `--session <会话目录>`；必须先 `rig-down`，六件证据非空、MOV 可读且
  SSE witness 曾连接三条流。`judge.py` 还会 fail-closed 检查：`manifest.json` 的绝对 `session` 身份必须
  与 `--session` 一致，`--session` 必须属于当前 `$RIG_HOME/sessions/`，`--evidence` 的真实解析路径必须在
  该 session 内；不能把另一个台架的证据拼进当前正式账本。
- 每次裁决盖时戳追加 `$RIG_HOME/judgments.jsonl`——只经脚本、不手写；未设置或错误设置 `RIG_HOME` 时
  直接拒绝，不产生个人默认账本。
- `judge.py` 用 `$RIG_HOME/judge.lock` 跨进程串行保护去重判断、COVERAGE 更新和 journal 追加；同一
  `(family,item,level,verdict,law,evidence)` 命令重跑是幂等 no-op，不重复写 journal 或 COVERAGE 证据指针。
  若进程在两份持久记录之间半步退出，重跑同一命令会按已有 journal 重放清册格和证据指针；所以不能只数
  `judgments.jsonl`，必须同时运行 `gen_coverage.py --check` 并检查目标行五格。
- `ledger-sequence.json` 是仓内版本控制的正式前线顺序策略（不接受 `RIG_SEQUENCE` 等调用方环境变量替换），当前模式为
  `first_unsettled`：judge 在锁内按 COVERAGE 的真实行序找到第一条含 `·/✗` 的行，只允许该行继续落新裁决，任何后行都拒绝；
  第一行五格均为 `✓/~` 后，前线自动推进到下一条。策略版本/模式非法或 COVERAGE 无法解析时 fail-closed，不靠工作记录口头约定越序。
  重复同一已存在裁决仍先按幂等规则重放，不被顺序策略误伤。若改变顺序机制，必须修改策略文件、测试并同步 working 记录。
- 并发回归可用 `python3 -m unittest testend/rig/test_judge.py -v`；更换证据或裁决仍会留下新的审计行。
- 法不够用 → **先立法再判**:按 CODEX.md 末的立法协议加新法条(只收紧、带回灌横扫),再引用它。

## 警报(漂移检测,gate 强制联动)

```bash
python3 testend/rig/alarms.py check              # 三曲线:间隔中位数<25s / 速率暴冲≥3× / fail 占比<5%
python3 testend/rig/alarms.py ack <id> --note "<销账依据:重审结果>"
```

**警报未销期间 judge.py 拒收一切新 pass**(物理拒收,非约定)。ack 绑定当前最后一条裁决水位，
同一批历史不会原地复活；出现新裁决后重新计算，异常仍在才重新开单。

## 清册刷新(代码合并后)

```bash
# ① 重校四份提取物 testend/rig/extracts/{tools,endpoints,surfaces,edges}.md
#    (机械法:tools=活后端 GET /tools + 代码枚举 CapabilityTools;endpoints=transport 路由真 diff;
#     surfaces=frontend/lib 文件级 diff + i18n 键组;edges=提交考古,每行带构造配方)
# ② 重生成(merge-aware:行键=项名,已判列逐字携带、新行未判、消失行进墓碑):
python3 testend/rig/gen_coverage.py
```

`check_journeys.py` 核验旅程对清册的认领覆盖(二期启用,基线自证过)。

`TOOL-123` 进入真实 App 前，先对 llmtap 保存的 `/models` 响应运行
`python3 testend/rig/check_i2v_contract.py <models-response.bin>`；它支持原始 JSON 和 gzip，只有
`video_generation.available=true` 与 `image_to_video=true` 同时存在时才返回 0。缺失时返回 2，不能
把 T2V-only 网关误当成 I2V 继续烧一轮实机额度。

## 快速自证(怀疑台架先于怀疑产品)

任何异常先跑 `rig-check.sh`;它红了,一切产品裁决冻结——哑掉的通道读起来与干净的产品一模一样,
这正是台架自检存在的理由(「先查夹具再报缺陷」)。
清册生成器默认才会写盘；恢复上下文或做门禁前先用只读的
`python3 testend/rig/gen_coverage.py --check`，它会验证当前 `COVERAGE.md` 是否与四份提取物一致。
`--help` 也必须保持只读；不要把探查命令当作刷新命令执行。
