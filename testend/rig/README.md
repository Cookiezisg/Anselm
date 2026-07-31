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
| ① 帧 | Computer Use 截图 + `screencapture -v` 录屏 → ffmpeg 抽帧 | 会话目录 PNG/MOV(不入 git) |
| ② 后端 | conductor 亲启的 sidecar,stdout 全量捕获 | `backend.log` |
| ③ SSE | `cmd/ssetap` 独立订三条流(不经前端 demux) | `sse.jsonl` |
| ④ 前端 | `flutter run` console(接 app 时) | `frontend.log` |
| ⑤ LLM 线缆 | `cmd/llmtap` 透明代理在受管网关前 | `llm.jsonl` + 逐调用请求体文件 |

所有会话落 `~/.anselm-rig/sessions/<时间戳>/`,`~/.anselm-rig/current` 软链指认活会话,
`manifest.json` 是其余脚本唯一读的连接事实。

## 起 / 检 / 停

```bash
testend/rig/rig-up.sh      # 建二进制→起 llmtap→起后端(经 tap)→seed→接线闸→起 ssetap→manifest
testend/rig/rig-check.sh   # 五通道自检:权限/D1 归属/健康/tap 活性/接线/journal 非空
testend/rig/rig-down.sh    # 后端优雅关停→双 tap 收尾,journal 全保留
```

环境旋钮(都有默认值):`RIG_PORT`(默认 8742;dev 后端占着就换)· `RIG_DATA`(数据目录)·
`RIG_SEED=0` 跳过播种 · `RIG_LLMTAP=0` 关线缆见证(后端直连网关)· `RIG_HOME`(全套家目录)。

**接 app**:`ANSELM_BACKEND_URL=http://127.0.0.1:<RIG_PORT> make -C frontend app`,
console 输出重定向进会话目录作 `frontend.log`(通道④)。

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
cd testend && go run ./cmd/measure <子命令>
  diff A.png B.png        # 相邻帧变化占比+包围盒(每通道容差 8 吸收编码噪声)——跳变/闪
  regions IMG.png RRGGBB  # 目标色连通域矩形——高亮「等高吗、有缝吗」用像素回答
  contrast IMG.png x y x2 y2   # WCAG 2.x 对比度
  latency 帧目录 动作帧号      # 动作帧→首个越阈变化帧→ms
```

录屏抽帧:`ffmpeg -i in.mov -vf fps=30 frames/f%04d.png`。

## 裁决与记账(标绿是脚本动作,不是文本编辑)

```bash
python3 testend/rig/judge.py "<清册行名>" --family TOOL|EP|SURF|EDGE --level 1..5 \
  --verdict pass|fail|na --law <CODEX 法条 id 或 measure:...> --evidence <盘上文件>
```

- pass/fail 必须引**存在于 CODEX.md** 的法条(或测量值);证据必须是盘上真实非空文件。
- `na` 用 `--evidence 'note:<为何不适用>'`。
- L2(数据真相)pass 还须 `--session <会话目录>` 且五通道 journal 齐。
- 每次裁决盖时戳追加 `~/.anselm-rig/judgments.jsonl`——只经脚本、不手写。
- 法不够用 → **先立法再判**:按 CODEX.md 末的立法协议加新法条(只收紧、带回灌横扫),再引用它。

## 警报(漂移检测,gate 强制联动)

```bash
python3 testend/rig/alarms.py check              # 三曲线:间隔中位数<25s / 速率暴冲≥3× / fail 占比<5%
python3 testend/rig/alarms.py ack <id> --note "<销账依据:重审结果>"
```

**警报未销期间 judge.py 拒收一切新 pass**(物理拒收,非约定)。销账后若数据未被新的真实裁决
稀释,`check` 会再次开单——这是设计:销账不改写历史。

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
