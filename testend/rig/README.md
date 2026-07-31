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
| ① 帧 | Computer Use 操作/截图 + conductor 的 `screencapture -v` 连续录屏 → ffmpeg 抽帧 | `screen.mov` + 抽帧目录(不入 git) |
| ② 后端 | conductor 亲启的 sidecar,stdout 全量捕获 | `backend.log` |
| ③ SSE | `cmd/ssetap` 动态发现全部 workspace 并独立订三条流(不经前端 demux) | `sse.jsonl` |
| ④ 前端 | conductor 亲启的真实 `flutter run` App 与 console | `frontend.log` |
| ⑤ LLM 线缆 | `cmd/llmtap` 透明代理在受管网关前 | `llm.jsonl` + 逐调用请求体/响应体文件 |

所有会话落 `~/.anselm-rig/sessions/<时间戳>/`,`~/.anselm-rig/current` 软链指认活会话,
`manifest.json` 是其余脚本唯一读的连接事实。

## 起 / 检 / 停

```bash
testend/rig/rig-up.sh      # 建二进制→起 llmtap/后端/ssetap/录像/真实 App→manifest
testend/rig/rig-check.sh   # 五通道自检:权限/进程与端口归属/三流连接/受管接线/journal
testend/rig/rig-down.sh    # App→后端→双 tap→录像;封口并 ffprobe MOV,journal 全保留
```

环境旋钮(都有默认值):`RIG_PORT`(8742;被占就换)· `RIG_LLMTAP_PORT`(8788)· `RIG_DATA`·
`RIG_HOME`· `RIG_SEED=0` 跳过播种并走真实首次 onboarding。`RIG_LLMTAP=0`、`RIG_RECORD=0`、
`RIG_APP=0` 只用于诊断；缺任一通道的会话不能通过 `rig-check` 或 L2 gate。

所有进程经 `spawn.py` 建独立进程组，启动 shell 退出后仍受 manifest 所有；不要另外手起 App。首次
注册场景用 `RIG_SEED=0`，ssetap 会在 onboarding 创建 workspace 后一秒内自动接管三条流。

## 两条铁律(都以真事故立法,自检强制执行)

- **D1 journal 归属**:持有服务端口的 PID 必须 == 捕获 stdout 的 PID。抢端口失败的后端瞬间死掉、
  journal 却依然像样——0728 真发生过,故 rig-up 拒收外来进程、rig-check 持续复验。
  (细节坑:`lsof -ti` 必须带 `-sTCP:LISTEN`,否则 tap 的客户端连接会被算成端口持有者。)
- **通道五接线**:受管 key 的 base_url 在 provision 时**落库**(`freetier.go` 存
  `AnselmGatewayBase()`),换过接线的旧数据目录会永远抱着旧指针——静默形态是受管流量绕开 tap
  而 `llm.jsonl` 只是安静。rig-up 对错指针直接拒绝;rig-check 持续断言。
  (相关后端 env:`ANSELM_GATEWAY_URL` 指 tap;`ANSELM_PROOF_HOST` 让 device-proof 的 htu
  签**真实受众**——受管流量按 DPoP 式设计天生反代理,唯一正当例外是设备自己的录制代理。)

## 测量(凡能成为数字的视觉判断必须成为数字)

```bash
cd testend
go run ./cmd/measure diff -dir <frames/> -roi x,y,w,h
go run ./cmd/measure regions -img <shot.png> -color '#RRGGBB'
go run ./cmd/measure contrast -fg '#RRGGBB' -bg '#RRGGBB'
go run ./cmd/measure latency -dir <frames/> -fps 30 -action <0-based帧号> -roi x,y,w,h
```

先 `rig-down.sh` 封口录像，再抽帧：

```bash
SESSION=~/.anselm-rig/sessions/<时间戳>
mkdir -p "$SESSION/frames"
ffmpeg -i "$SESSION/screen.mov" -vf fps=30 "$SESSION/frames/f%06d.png"
```

ROI 应只框目标控件，排除时钟、鼠标、呼吸动画等无关变化；不使用 ROI 的全屏延迟数字通常无意义。

## 开工校准(先于任何 pass)

```bash
python3 testend/rig/anchors.py quiz
# 逐题填写 ~/.anselm-rig/anchor-quiz.json 的 verdict / law / reason
python3 testend/rig/anchors.py check ~/.anselm-rig/anchor-quiz.json
```

校准凭证绑定冻结题集且只活四小时；缺失、过期或题集变化时 `judge.py` 物理拒绝所有新 pass。

## 裁决与记账(标绿是脚本动作,不是文本编辑)

```bash
python3 testend/rig/judge.py "<清册行名>" --family TOOL|EP|SURF|EDGE --level 1..5 \
  --verdict pass|fail|na --law <CODEX 法条 id 或 measure:...> --evidence <盘上文件>
```

- pass/fail 必须引**存在于 CODEX.md** 的法条(或测量值);证据必须是盘上真实非空文件。
- `na` 用 `--evidence 'note:<为何不适用>'`。
- L2(数据真相)pass 还须 `--session <会话目录>`；必须先 `rig-down`，六件证据非空、MOV 可读且
  SSE witness 曾连接三条流。
- 每次裁决盖时戳追加 `~/.anselm-rig/judgments.jsonl`——只经脚本、不手写。
- 同一 `(family,item,level,verdict,law,evidence)` 命令重跑是幂等 no-op，不重复写 journal 或 COVERAGE 证据指针；更换证据或裁决则会留下新的审计行。
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

## 快速自证(怀疑台架先于怀疑产品)

任何异常先跑 `rig-check.sh`;它红了,一切产品裁决冻结——哑掉的通道读起来与干净的产品一模一样,
这正是台架自检存在的理由(「先查夹具再报缺陷」)。
