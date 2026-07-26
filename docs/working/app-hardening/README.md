---
id: WRK-083
type: working
status: active
owner: "@weilin"
created: 2026-07-26
reviewed: 2026-07-26
review-due: 2026-10-24
audience: [human, ai]
landed-into:
---

# WRK-083 · 真机全面验收与缺陷清零

> **本册的存在理由**:两仓门禁全绿 ≠ 产品可用。WRK-078 收口当晚,门禁全绿之后真机上仍当场
> 抓到**五条**缺陷(网关内联、install 死结、`Hijacker` 缺转发致所有 WebSocket 裸 500……)。
> 本册把「真机点点点」变成**有信号源、有覆盖矩阵、不重不漏**的一轮扫查,并要求**发现即修**。
>
> **前置于 [WRK-082](../multimodal-output/README.md)**:先一身干净,再上大工单(用户 0726 决定
> WRK-082 暂缓,今天只保产品质量)。
>
> **本轮无产品决策**——已建成的功能只有「对不对」,没有「要不要」。发现分歧按既定 working
> 文档执行;真需要拍板的单独提出,不夹带在缺陷里。
>
---

## §0 三条铁律(违反 = 本轮未完成,与编译失败同级)

### 铁律一 · 全修,零例外

**本轮结束时 §4 台账必须清零。** 没有「已知问题」、没有「下个版本再说」、没有「可接受」。
本项目未上线、无用户、无兼容包袱(设计原则 #7)——**留 bug 的唯一理由是懒,不是权衡。**

**下列话术一律不成立,写进台账即视为未完成**:

| 逃逸话术 | 为什么不成立 |
|---|---|
| 「这个是小问题 / 不影响使用」 | 严重性决定**修的顺序**,不决定**修不修**。 |
| 「这是设计如此」 | 只有 working 文档里**白纸黑字写过**才叫设计如此;临时想出来的解释不算。找不到出处 = 是 bug。 |
| 「概率很低 / 只有窄窗才有」 | B5 正是「只有窄窗才有」,而用户天天在窄窗用。触发条件窄 ≠ 危害小。 |
| 「上游/框架的问题」 | 那也要在我们这侧 workaround 并留注释说明上游 issue 号。用户不关心是谁的错。 |
| 「测不了所以算了」 | 物理测不了(§2.8 三类)→ 转 C4 **由用户验**,不是消失。转出去要有落点。 |
| 「改动风险大」 | 未上线的项目没有这种风险。真的复杂就拆批,不是不修。 |

**唯一合法的不修**:确认它**不存在**(复现失败 + 说明原报告为何误判)。这要写证据,不是写结论。

### 铁律二 · 修在根上,不修在症状上

**判据三条,三条全过才算根修**:

1. **同类还会不会再犯?** 若答案是「换个调用方还会」,那修的是症状。
2. **修改点在哪一层?** 业务层反复出现的样板,**病在地基**——原则 #8 明写「业务层手搓的样板本应
   由地基提供时**强化地基**、非模块内重抄」。
3. **守卫能不能覆盖整个类?** 只钉住这一个实例的测试,是把症状固化下来。

**本轮三条已确诊缺陷的「根」分别在哪**(施工时照此,不许就地打补丁):

| # | 症状层的修法(**禁止**) | 根在哪 |
|---|---|---|
| **B2** | 给驻地菜单那一项加个 `Flexible` | 根在 `an_menu.dart` 的 **`AnMenuItem` 原语**:它的 `meta` 对**任何调用方**都会溢出。修原语 = 全 app 所有菜单一起好。守卫应是「**所有** `AnMenuItem` 形态在窄宽下渲染无异常」,不是「驻地菜单不溢出」 |
| **B5** | 窄窗时特判一下 | 根在**右岛宽度有两个事实源**:`_takenOf` 用静息 `widget.rightWidth`,实际布局用 `_w.clamp(min, rightCeiling)`。修法是**让它只有一个**。守卫应断言「冻结用的海洋宽 == 实际布局出来的海洋宽」这条**不变量**,而非某个具体像素 |
| **B1** | 在 `set()` 里补一行 `invalidate(列表)` | 根在**失效责任散落在各个变更点**:`addWorktree` 已经自己手写了一句 `invalidate(conversationHeaderProvider)`,`set()` 走的又是另一条 patch 路径,而**两条都忘了列表**。下一个改 `work_dir` 的入口还会再忘。修法是让「对话行变了」有**唯一的失效编排点**,所有变更路径经它 |

### 铁律三 · 不自欺

1. **每格结论要有证据。** ✅ 必须能说出「点了什么、看到什么」。**没点过就写「未扫」**——
   「应该没问题」不是一个合法结论。
2. **每个缺陷必须回答「门禁为什么没抓到」。** 二选一:①**没有测覆盖**→本轮补上;
   ②**有测但断言错了**→那个测试**自己也是 bug**,一并修。这一栏空着 = 没修完,因为
   下次它会原样再来一遍。
3. **「测试绿了」≠「bug 修好了」。** 先证明测试**在修复前是红的**(反证)。写完测试直接绿,
   优先假设它测错了地方——这在 WRK-078 的 CR-1b 上真实发生过三次:连写三版回归测试都是
   空绿,最后靠「把修复回滚、看测试是否变红」才发现它根本没测到那条路径。
4. **修完要在真机上复看。** 单测绿不代表用户看到的东西变了(B5 尤其:像素断言抓不到重挂,
   帧率与体感要真机验)。

---

## §1 用户报告的缺陷(2026-07-26)

> 五条均已读码定位,**三条找到确切病灶**。「定位」列是诊断,施工时以实测复现为准。

| # | 现象 | 定位 | 判定 |
|---|---|---|---|
| **B1** | 工作目录修改后**左岛没有立即刷新** | `work_dir.dart` `set()` 只 patch 了 `conversationHeaderProvider` 与驻地投影,**没有失效左岛列表 provider**(rail 的 📁 驻地组按 `workDir` 分组,数据源是 `conversationListProvider`)。改完驻地,行的分组归属变了而列表还是旧的 | **确认** |
| **B2** | 工作目录菜单最近目录项**溢出 23px** | `an_menu.dart:203` `AnMenuItem` 的 `meta` 是**裸 `Text`、无 `Flexible`**;`label` 有 `Expanded` 而 `meta` 没有,长路径按 intrinsic 宽度索要空间 → `RenderFlex` 溢出。最近目录项恰好 `meta = 完整路径`,必然撞上 | **确认** |
| **B3** | 驻地按钮**尺寸不对**,应对齐选模型按钮 | 两者都是 `AnButtonSize.sm`,但驻地未挂载时是**纯图标方块**、模型按钮是**图标+标签**,视觉重量不等。B4 落地后两个都变纯图标,故真正诉求 = **纯图标按钮盒子要与带标签按钮等高/等视觉重量** | 与 B4 合并 |
| **B4** | Fork 与驻地**不必在面包屑显示具体名字**,展开时再显示 | 驻地按钮当前 `label: mounted ? _basename(storedPath) : null`(`chat_work_dir_button.dart:107`)→ 改为恒 `null`;完整路径已在菜单身份头。Fork 侧同理 | 信息架构,**先于 B3** |
| **B5** | 小窗口下右岛开合**仍跳变** | `an_shell.dart:150` `_takenOf` 用 `widget.rightWidth`(静息宽)算冻结目标,但右岛实际按 `w = _w.clamp(min, rightCeiling)` 布局;**窄窗下 `rightCeiling` 会夹小它**。海洋被冻结在比实际窄的宽度上,释放时 snap。左岛无上限夹取故丝滑——这解释了「只在小窗口复现」 | **确认**,RI/S11 遗漏格 |

**施工序**:B4 → B3(同族:先定形状再定尺寸)· B2 · B1 · B5 各自独立。
**守卫要求**:B2/B5 断言布局不变量而非截图;B1 断言 provider 失效链;
**B5 必须在窄窗下验**——宽窗下冻结闸根本不上膛,会宣布已修而它没被碰过。

---

## §2 信号源(七只眼,不止两只)

### 2.0 ⚠️ 结构性发现:`make app` 的终端只有一半

`frontend/test/dev/run_app.sh` 把 `make -C backend run` 扔到**后台并重定向**
(`>/tmp/anselm-dev-server.log 2>&1 &`),然后才 `flutter run`。**故被盯的那个终端只有 Flutter
一侧,后端整条日志流不可见。** 本轮必须同时盯下列 2.2/2.3。

### 2.1 眼睛① · Flutter 终端(`make -C frontend app`)

`RenderFlex overflowed` / assertion / 未捕获异常 / provider 错误。**它们都不会让 app 崩**,
所以只看界面永远发现不了 —— B2 就是活证据:那条 23px 溢出只在 debug build 画成黄黑条,
发布构建里它静默消失,**但布局仍然是错的**。

**纪律**:每完成一个功能面就回扫终端新增输出;任何 `overflow`/`assertion`/`Exception`/`Error`
一律记入 §4,不许当噪音跳过。

### 2.2 眼睛② · 后端结构化日志(**本轮最大增量**)

`/tmp/anselm-dev/logs/anselm.log` —— zap JSON,轮转,**每个 HTTP 请求一行带 `status`**。
机械扫一遍即得完整异常时间线:

```bash
python3 -c "
import json
for line in open('/tmp/anselm-dev/logs/anselm.log'):
    try: d=json.loads(line)
    except: continue
    st=d.get('status')
    if (isinstance(st,int) and st>=400) or d.get('level') in ('warn','error','dpanic','panic','fatal'):
        print(d.get('time','')[:19], st or d['level'], d.get('method',''), d.get('path','') or d.get('msg',''))
"
```

**判读律**:任何 `500` = bug;任何**非预期** 4xx = bug(预期的要能说出为什么)。

### 2.3 眼睛③ · 后端控制台 `/tmp/anselm-dev-server.log`

panic 栈、启动期错误、go run 编译错误落在这里(结构化日志之外的东西)。

### 2.4 眼睛④ · SQLite 直查(**验盘上的真相,不是屏幕上的样子**)

操作后直接查 `/tmp/anselm-dev/anselm.db`。屏幕对了不代表盘上对了,而**这一类错日后会变成
数据丢失**:分叉的 seq 重排 / 嵌套 remap / summary 水位重定基 · `:retry` 的 `superseded_by`
是指针而非软删(行仍在盘上)· `marker` 块真的落了 · touchpoint 台账有记 ·
`flowrun_nodes` 的 record-once 唯一键 · 软删是 `deleted_at` 而非物理删(D1)。

### 2.5 眼睛⑤ · SSE 三流抓帧(E 系列宪法的**运行时**验证)

curl 挂着 `messages`/`entities`/`notifications` 录全程,验:`seq` 单调无洞 ·
ephemeral(delta/tick)恒 `seq=0` 且不入 buffer · close 帧带快照 · `parentBlockId` 嵌套正确。
**目前这些只有单测守,从没在真运行时验过。**

### 2.6 眼睛⑥ · profile 帧率(客观数字取代「感觉不丝滑」)

`test/dev/shot_perf.sh` 的基础设施已就位。B5 那类跳变**应该有掉帧数字**(>16.7ms),
不靠体感判定。岛屿开合 / 长 transcript 滚动 / 流式渲染三处必测。

### 2.7 眼睛⑦ · 进程与文件系统卫生

退出后 `ps aux | grep anselm` 查残留 sidecar(验 stdin 死人开关真开火)· 数据目录有无遗留
临时文件 · WAL 是否 checkpoint · sandbox/handlers 目录有无垃圾。

### 2.8 我物理上做不到的三类(**必须留给用户,绝不冒充**)

已用 Finder 对照实验证实:**computer use 的合成滚轮与拖拽事件在本机对任何 app 均无效**
(非 Anselm 缺陷)。故:①滚轮/触控板滚动手感与惯性 ②拖拽类(音频 seek、岛宽拖拽、分割线)
③划选复制手感 —— 全部转 `multimodal-agent/ACCEPTANCE-GUIDE.md` C4 由用户验。

---

## §3 覆盖矩阵

> **「没扫」与「扫了没问题」是两种状态,不许混同。** 每格结论三选一:✅通过 / ❌缺陷(→§4) /
> 🚫物理测不了(→C4)。

### 3.A 维度乘子(同一批操作要跑几遍)

| 轴 | 取值 | 为什么 |
|---|---|---|
| 窗宽 | **窄(<768)** / 中 / 宽 / 窗口最小尺寸 | 冻结闸、reflow floor、右岛上限**只在窄窗上膛**;B5 就藏在这一格 |
| 缩放 | 100% / Cmd+ 放大 / Cmd− 缩小 | `scaled_app` 整体缩放,易撞固定尺寸假设 |
| 主题 | 亮 / 暗 | 令牌覆盖是否完整 |
| 语言 | 中 / **英** | 「严禁硬编码中英文」——切英文,漏的 key 与写死的中文当场现形 |
| 字体轴 | 默认 / 改 UI 轴 / 改内容轴 / 改代码轴 | 三轴改动不得破坏布局 |

**优先级**:全矩阵跑「窄窗 + 亮 + 中文」;**关键路径**(chat 全流程、settings、右岛)另跑
「英文」与「暗色」与「缩放」各一遍。

### 3.B chat 海洋 —— **已扫**(2026-07-26,真机,窄窗+亮+中文)

| # | 格 | 结论 | 证据 |
|---|---|---|---|
| C01 | rail 四段结构 | ✅ | 新对话·搜索·置顶 1·📁×2·最近 12,分段与计数一致 |
| C02 | 组头 ⋯ 三动作 | ✅ | 归档全部对话 / 删除全部对话(danger)/ 在访达中显示;**两个破坏性动作都明写 conversations,无「目录」字样** |
| C03 | 搜索替换结构 | ✅ | 输入 `Hello` → 分段消失、扁平 2 命中,**且够到折叠组内的对话** |
| C04 | 行动作 | ✅ | ⋯ 菜单五项;执行置顶 → 计数 1→2、行移入置顶段、离开最近,零刷新 |
| C05 | transcript 跳转 | 🟡 | TOC 跳转重锚 ✅;**滚动/center 锚 🚫 物理测不了**(合成滚轮无效)→ C4 |
| C06 | 消息动作排 · 复制 | ✅ | 剪贴板含**懒列表没建过**的开头段 → 证明取自 model 而非选区 |
| C07 | 显隐律 | ✅ | 末轮恒显 / 生成中不显 / 「Stopped」终态仍显 |
| C08 | send↔stop | ✅ | 三态(mic→send→stop)正确;停止 → 「Stopped」+ 动作排 |
| C09 | @ 提及 | ✅ | 8 候选跨五类带图标与描述;输入 `cat_action` 收敛;回车插入蓝色药丸 |
| C10 | 附件入口 | 🟡 | 选择器 ✅(缩略图 + ✕);**拖入 🚫 物理测不了** → C4;粘贴未测 |
| C11 | 生成中入队 | 🟡 | chip 行 `1 waiting to send` + ✕ ✅、管道空闲逐条排出 ✅;**「按停止不清队列」未隔离**(队列排空太快,两次都是自然排空) |
| C12 | 自动命名双落 | ✅ | 新对话首发 → 头部与 rail 同时变「幂等性的一句话解释」 |
| C13 | 驻地按钮三态 | 🟡 | laptop / folder ✅;**folder-x(目录已不存在)未在真机见到**,仅单测覆盖 |
| C14 | 驻地菜单三段 | ✅ | 身份头(完整路径)/ 访达 / 终端 / 切换 / 退出 / 最近 / Git 段齐全 |
| C15 | git 段 | ✅ | `Branch main` · `✓ No uncommitted changes` · `+ New branch…` · `为此对话开 worktree…`(**键盘翻页**才够得到——菜单超 `menuMaxHeight` 需滚动;不实际执行以免动用户仓库) |
| C16 | **越界写人闸** | ✅ | **明确指示「不要问我,直接写」仍强制走闸**;`Dangerous` + 路径与内容摊开 + 三选项;点拒绝后**文件根本没被创建**;模型如实报告被拦 |
| C17 | subagent 继承驻地 | ⬜ | 未扫 |
| C18 | 工具卡谱系 | ✅ | 默认收起 ✅ / **失败一次自动展开**并显节点级错误 ✅ / **人闸自动展开** ✅ |
| C19 | 右岛侧幕 | ✅ | 自动开岛→登台→活更新(Tasks 3/4→4/4、Ran ×4→×8)→ 时间分组(Just now / Earlier today / Earlier) |
| C20 | 侧幕五铁律 | ✅ | 全程无重复卡、无幽灵 Live、行内交互不冻流水线 |
| C21 | 语音输入 | 🟡 | 空态圆钮=麦克风 ✅、`Record audio attachment` 入口在 ✅;**权限流与录音**上一战役已验(A5) |
| C22 | 媒体渲染 | ✅ | 图片全尺寸渲染;**完整多模态链路真跑通** —— 答案逐字正确(蓝方块左上/橙方块右下) |

**本域扫查产出的缺陷**:L4(`AnRow` 带状态点仍溢出 5.8px,B2 的回归)——已修。
**三个日志源全程**:后端结构化日志 0 异常(唯一一条 WARN 是 agent 自己的工具调用失败并自行修复,可解释)、后端控制台无新增、Flutter 终端除 L4 那条外零异常。

### 3.C entities 海洋

| # | 格 |
|---|---|
| E01 | 列表 rail(四实体类型切换 · 分页 loadMore · 搜索) |
| E02 | 详情海洋(各类型字段渲染 · 空表破折号) |
| E03 | 右岛调试台:JSON 编辑器 · 示例生成器 · 来源 chip · 最近执行台账「用这份输入」装回 |
| E04 | 真执行:`:run` / `:call` / `:invoke` / `:trigger` 各一次,验结果与错误态 |
| E05 | Overview 关系图:焦点星图 · BFS 衰减 · 四力布局 · 点击换焦点 |
| E06 | 创建 / 编辑 / 删除 各实体,验列表与关系图同步 |

### 3.D library 海洋

| # | 格 |
|---|---|
| L01 | 页面树(建 / 拖动 / 嵌套 / 删除) |
| L02 | 编辑器:slash 命令 · @ 药丸 · markdown 即打即转 |
| L03 | 嵌入式代码块 · 行内代码 paint-beneath · 可编辑表格 |
| L04 | codec 三保真(存→读→再存不失真) |
| L05 | 一头三组右岛:大纲 / 属性 / 反链 |
| L06 | skill 侧:创建 · `allowed-tools` 预授权真的免确认 |

### 3.E scheduler 海洋

| # | 格 |
|---|---|
| S01 | Overview 主页 |
| S02 | 运行矩阵(状态色 · 分页) |
| S03 | 运行卷宗 / 节点检查器双脸右岛 |
| S04 | 真跑一个 workflow:节点推进 tick · 失败 · **`:replay` 幂等重走** |
| S05 | trigger:cron / 手动 fire · schedule 投影 `truncated` 诚实报告 |

### 3.F 平台横切

| # | 格 |
|---|---|
| P01 | notifications:铃托盘时间分组 · 滑动折叠 · 未读徽标**靠权威 refetch 而非据帧 +1** |
| P02 | 顶带即时消息舞台:恒定居中 · 最多两候场 · `+N→✕` 快照清场 |
| P03 | OS 原生通知真的弹出 |
| P04 | settings 13 面板逐个开 · 设置项级搜索 · 三相等门禁 |
| P05 | 机器/工作区两持久化轴(改完重启仍在) |
| P06 | 字体三轴切换 · 全局快捷键改绑 · 出厂重置 · 更新检查 |
| P07 | 窗口:缩放 / 窄窗 / 岛屿开合 / 最小尺寸 / 全屏 |
| P08 | 启动门控(冷启动 · 后端未就绪时的界面) |
| P09 | 退出卫生:⌘Q 优雅停 · **kill -9 app 后无残留 sidecar** |
| P10 | 多 workspace 切换(401 清选区重选) |

### 3.G 韧性与边界(**过去从未在真机验过**)

| # | 格 | 做法 / 结论 |
|---|---|---|
| R01 | 生成中 `kill -9` 后端 | ✅ **已扫**:发送失败态诚实且可恢复——`⚠ Couldn't send` + **Retry / Discard**,消息保住、不静默丢弃;后端拉回后点 Retry **重发成功**、SSE 三流自动重连、流式恢复。SSE 重连约 4s 退避(合理,只是日志吵)。**注意 dev-attach 模式下 app 不拥有 sidecar,故「监督者自动重启」那条路径未被覆盖**——它是生产专有路径 |
| R02 | 生成中 `kill -9` app | ✅ **已扫,两半都验**(dev-attach 只覆盖前一半,后一半单独造场)。**(a) durable 恢复**:流式到第 2 段时 `kill -9` app 进程 → 后端**独立跑完**(被杀那刻可见 `灯塔顶端的`,最终多出 **489 字**、`completed`/`end_turn`),**自动命名也在零客户端下完成**(`潮汐与灯塔`),`isGenerating=False` 无卡死;重启 app 开该对话:四段全文完整、无重复、composer 回正常发送态;三源扫查零异常。**(b) 死人开关**(WRK-070 T2 崩溃路径,`ANSELM_PARENT_WATCH`,**此前从未真机验过**):写替身父进程(`scratchpad/hardening/deadman_parent.py`,独立数据目录 + 独立端口,stdin/stderr 皆管道——production 契约逐条复刻)→ 触发语义搜索拉起真 `llama-server` 子进程 → `kill -9` **父进程** → sidecar **未孤儿化**、`llama-server` **随之而去**、文件日志留下完整有序关停两行(**证明 `signal.Ignore(SIGPIPE)` 那道防线成立**——注释记载的失败模式正是「日志零关停行」)。**机制订正**:带走 llama 的**不是**沙箱 kill-set(日志 `all handles killed count:0`——embedder 不归沙箱管),而是 `search/engine.Close()→killProcess()` 的优雅分支,由 `embedder.pid` **被删除**坐实(只有该分支删记录,R2) |
| R03 | 断网 | ✅ **已扫**(**上游失联**式,非物理拔网——拔网会同时切断本会话到 API 的连接;改法更精确:建一把真 deepseek BYOK 键、跑通基线,再把它的 `baseUrl` 指到拒连端口,即「用着用着网没了」的真实形状)。**拔网发消息**:快速失败、不挂死,红字诚实到位(`LLM_STREAM_ERROR` + 上游原文 `dial tcp 127.0.0.1:1: connect: connection refused`),用户消息保住、重试钮在;**行上落盘**——`status=error` / `stopReason=error` / **`errorCode` + `errorMessage` 都在 message 行上**(先怀疑「原因只活在 SSE 帧里」,重启复验推翻了这个怀疑)。**拔网切页**:切海洋、切对话、翻历史全部正常(本地 sidecar 不受上游影响)。**恢复自愈**:改回真 baseUrl → 点重试 → 当场成功。**扫查副产物**:眼睛② 扫不到这类失败(送出是 202、失败经 SSE,HTTP 日志里无 4xx/5xx,结构化日志零行)——这类失败的账在 **messages 行**上,不在日志里;**这不是缺陷、是扫查方法的边界**,记此以免下次误判「无异常」。**本格逼出 L6**(见下) |
| R04 | SSE 断线续传 | ✅ **已扫**(**逼出 L7**,见下)。**①真机·冻结客户端**:`SIGSTOP` app → 灌 900 条 durable 帧 → `SIGCONT`,app **完整追上**(rail 顶部即被灌帧那条、标题是最后一次的值),无卡死无丢帧。**注意它没能复现 410**:bus 只在订阅者通道(256+256)塞满时才主动断开慢客户端(R5),而 `conversation.*` 是**仅帧回声**、payload 极小(与我灌的 4KB 标题无关——rail 自己回读行),900 帧被内核 socket 缓冲轻松吃下。**这条限制本身值得记档**:「冻住客户端」在本系统里造不出 410。**②后端半边·确定性**:真 HTTP 客户端带陈旧游标订阅 → `Last-Event-ID: 1` 与 `5` 皆 **410**、无游标 **200**,契约成立。**③客户端半边**:`sse_connection_test` 已钉住「410 → 发 resync + 丢游标 + 下次连接不带 Last-Event-ID」。**④消费方半边**——本格的真发现:resync **发出来了却没人接**,见 L7 |
| R05 | 五电池灌输入 | 🟡 **①空**:空框回车 + 纯空格回车皆**不发送、不建对话**,空格被 trim ✅。**④极值**:一条含 emoji / ZWJ 家庭序列 / 区域指示符国旗 / 阿拉伯语 + 希伯来语 RTL / 零宽空格 + 零宽连字 / 组合字符 / RLO-PDF 覆写 / 制表符 / emoji 夹汉字 / BMP 外代理对 的消息,**端到端无损**:agent 自建函数逐码点比对,121 码点输入输出**完全一致**(无截断/无乱码/无损坏),渲染侧 RTL 与覆写字符都正确成形、未逃逸出方括号 ✅。**逼出 L9**(见下)。**②超长 ③海量 ⑤注入 未做** |
| R06 | 极长路径 / 极长实体名 | 驻地按钮截断 · 列表截断 |
| R07 | 并发 | 两窗口?同对话快速连发?快速切海洋 |

---

## §4 缺陷台账(边扫边填)

> **每条五栏缺一不可**,任一栏空着 = 该条未完成(§0 铁律二/三):

| 栏 | 要求 |
|---|---|
| 现象 | 复现步骤,精确到能被别人照做 |
| **根因层** | 病在哪一层(不是「哪一行」)——照铁律二三条判据 |
| 修复 | commit hash |
| **守卫** | 覆盖**整类**的机械测试;且须记录它**修复前是红的** |
| **门禁为何没抓到** | ①无覆盖 → 已补 ②有测但断言错 → 那个测试也修了 |

| # | 现象 | 根因层 | 修复 | 守卫 | 门禁为何没抓到 | 状态 |
|---|---|---|---|---|---|---|
| B1 | 改驻地后左岛不刷新 | **契约漂移,不是「忘了 invalidate」**(§0 的原判据被实证推翻,见下「B1 根因订正」):后端自 WRK-077 WD1 起发 `conversation.work_dir`,而前端 `conversation_signal.dart` 的动词表**从未学会它** → 落进 `_ => unknown` → rail 的 `_onSignal` 直接 `return` | `8c4f670f` | **双守卫**:① 机械——`cmd/docs` 新增 `driftSignalVocabulary`,把 events.md 登记的 `conversation.{…}` 族与 Dart switch 逐动词 diff(先证红 ✓,报「events.md registers \`conversation.work_dir\` but conversation_signal.dart never maps that verb」);② 行为——`conversation_list_provider_test` 新增「a work_dir frame off the **WIRE**」,从真信封投影后喂给 notifier(先证红 ✓) | **有测但两条都测在缝的两侧**:① `conversation_signal_test` 的「action vocab collapses correctly」**手工列举**词表、漏了新动词(它自己也是 bug,已补);② rail 的重分组由「leaving a residency…」直接调 `applyUpdate` 测过。**线缆动词→枚举那道缝从没人测**——一整个子系统全绿,功能却是死的 | ✅ 已修 |
| B2 | 菜单项溢出(真机复现为 **148px**,截图那次 23px——溢出量随路径长度变,不是固定值) | **不是那一处调用点,是整个行族的 `meta` 契约**:`AnMenuItem` 与 `AnRow` 都把 meta 作为**裸 `Text`** 放进 `Row`,而非弹性 child 拿到的是**无界**主轴约束 → `TextOverflow.ellipsis` 从不生效。守卫证明 `AnRow` 同病(同一输入溢出 **776px**),只是没人报过——rail 的 meta 都是时间戳与计数 | `55707ffc` | `test/guards/row_family_meta_overflow_guard_test.dart`:**两个原语 × 四种宿主宽度**灌荒唐 meta,断言 `takeException()` 为空(先证红:三格分别溢出 668/776/856px ✓) | **无覆盖**——从没有测试在窄宿主里渲过行族原语;既有测试都喂正常长度的 meta,于是那条无界约束永远不发作 | ✅ 已修 |
| B3 | 驻地按钮尺寸不对齐模型选择器 | 面包屑控件的**档位**无人约束:驻地/分叉写死 `sm`(24pt/icon12)、模型菜单用默认 `md`(28pt/icon16) | `08b8f215` | `chat_head_test` **B3**:对 `ChatHead` 下**每一个** `AnButton` 全称断言 `size == md`(先证红 ✓) | **无覆盖**——从没有测试看过头部控件的尺寸;像素断言也抓不到,因为两种尺寸都能正常渲染 | ✅ 已修 |
| B4 | 面包屑不该显具体名字 | 同上:面包屑**是否携带数据派生文本**无人约束 | `08b8f215` | `chat_head_test` **B4**:断言收起态的头部不含目录 basename / 全路径 / 分叉源标题,但保留线程**自己**的标题(先证红 ✓) | **无覆盖**——旧测试反而**要求**显示名字(`mounted: the basename labels the button` 等 5 条),它们已**反转**而非删除,反转留在案上 | ✅ 已修 |
| B5 | 窄窗右岛跳变 | **右岛宽度双事实源**(§0 判据成立):`_takenOf` 读**静息** `rightWidth`(320),右岛实际按 `rightWidth.clamp(rightIslandMin, rightCeiling)` 布局。1100pt 窗口下 ceiling = `(1084−328−480−8).clamp(280,640)` = **280** → 闸把海洋冻在比落定值窄 40pt 处,冻结一解除即 snap。**第二层同病**:`targetOceanW` 上那个 `.clamp(oceanMin, …)` 也在撒谎——窗口窄到无法两全时 `rightIslandMin` 压过海洋保底,海洋**真的**会渲到 468 < `oceanMin` 480 | `5ca651c8` | `an_shell_test` **「NARROW window, OPENING」**:断言**不变量**(滑动每一帧的宽度 == 落定宽度),不钉具体像素(钉死的数字会在令牌变动那天过期)。先证红 ✓(冻在 480、落定 468) | **有测但只测了安全方向**:既有「NARROW window: an island slide…」用的**正是同一个 1100pt 窗口**(夹取已经在发生!),但它只测**关闭**——终态没有右岛,右岛宽度从不进入算式,闸不可能算错。**打开**才是两个事实源相遇的方向,而那个方向没人测 | ✅ 已修 |
| **L1** | 选中对话后切 workspace,同一瞬间一簇针对旧对话的请求(首轮 3×404;编舞修后仍 4 条:`interactions`/`touchpoints`/`todos` 200 + `messages` 404——不 404 只因**仅 `ListMessages` 校验存在性**) | **两层,一根**。层①编舞帧序:「先离开」只是语句顺序不是时间顺序——`go('/')` 同步更新 router,但 widget 下一帧才卸、provider 重建又在下一帧**之前** flush,翻转瞬间仍被监听者带旧 id 重跑。层②(残留主体):右岛 `_InspectorStack` 的**私有** `_lastChat` 让 StagePanel(旧对话) 常驻折叠(海洋看一眼侧幕不卸,设计本意),但记忆**随 widget 活而不随 workspace 死**——它监听的 ledger→touchpoints、pending→interactions、rundown→todos 直接重取,director 的 build 更经 `ref.read` 把**已死**的 conversationStreamProvider **复活**再 hydrate=`/messages` 404。四条线一根 | `1fb327f2`(层①:轴翻转移 post-frame)+ `1b4abb22`(层②:记忆上提 `core/shell/inspector_memory.dart` 的 `lastChatThreadProvider`,watch activeWorkspace 换世界即弃 + 编舞第①拍与 `go('/')` **同瞬显式 clear**) | **三层,皆先证红**:①线缆——`hot_switch_test`「nothing asks about the old conversation」(带对照组;三次自我纠错:URL 断言空绿 / 夹具自造缺陷 / stub 网关空绿,详见 git);②线缆·保活维——同文件「KEPT-ALIVE right island」:替身**与路由并排**、经真记忆 provider 持 provider(红:2 条,且**记忆已被自愈复位仍红**——实证只靠 watch 自愈晚一个 flush,清除必须在编舞第①拍);③结构——`workspace_switcher_test`「unbinds the kept-alive sidestage」:真 `AppShell` + `StagePanel` **skipOffstage:false**(缺陷恰住在 offstage 里;对修前代码红) | **无覆盖**:没有任何测试问过「切换之后还有谁在发请求」;守卫①的替身又随路由卸载,没建模「记忆让 provider 活过选区」的保活右岛——守卫绿、真机红,直到守卫②补上那一维 | ✅ 已修(真机:前置断言先行→切 ws **0 条**旧请求[修前 4]、0 条 4xx/5xx;回程重开五端点各**恰一次**全 200,重绑无损) |
| **L3** | 左岛底栏的 workspace 菜单**只列当前那一个**——有两个 workspace 的用户从壳里根本切不过去(服务端 `/workspaces` 返两个,菜单列一个) | 菜单那一行是**写死**的 `AnMenuItem(label: wsName, checked: true, onTap: () {})`:它复述着打开它的那颗按钮上已经印着的名字,且不可点。架构文档一直把这个菜单描述为「切换/新建/工作区设置」——**「切换」那三分之一从来没接上线** | `1fb327f2` | `test/app/workspace_switcher_test.dart`:喂三个 workspace,断言**每一个**都在菜单里、且点非当前项真的切过去。守的是**数目**不是字符串(断言「Personal 与演示工作台都在列」对一个把这两个名字写死的菜单同样会通过)。先证红 ✓ | **无覆盖**——从没有测试把菜单的行数与 `/workspaces` 对过。界面上它毫无破绽:菜单打得开、看着也对、当前项旁边还有个勾 | ✅ 已修 |
| **L4** | `AnRow` 尾端带**状态点**时仍溢出 **5.8px**——真机扫查(眼睛①)在一次真实对话生成中抓到 | **B2 修复自己引入的回归**:那次修复给**整个 trail** 设了界(`Flexible`+`Align`),却让 trail **内层** Row 的孩子留在自然尺寸。「有界的 trail 装着无界的 row」照样溢出——只是溢得少 | `dcfa4a26` | 守卫加一格:**带 `trailingDot` + 长 meta**(先证红 ✓,917px)。这正是**对话 rail 行的真实形状**(时间戳挨着生成中/未读点) | **B2 的守卫覆盖不足**——它测过「长 meta」也测过「hover 动作」,却从未把**状态点与长 meta render 在一起**。对真实形状而言,「从未一起测过」就是「从未测过」 | ✅ 已修 |
| **L5** | 发送失败行 `⚠ Couldn't send / Retry / Discard` 溢出 **17px**——**韧性扫查 R01 中抓到**:后端 `kill -9` 后这一行出现,而当时右岛开着、海洋窄 | **与 B2/L4 同一类,第三例**:一个 Row 混着**本地化句子**与**固定 affordance**(图标 + 两颗按钮),而全部 child 都非弹性。`mainAxisSize: min` 帮不上——它只是「贴内容」,内容超出父宽照样溢 | `e12c958a` | 抽出 `FailedSendRow` 组件(**内联 Row 测试渲不出来**,不立起整个 transcript 就够不着)+ 守卫一格:窄宿主下无异常 **且两颗按钮都还在**——靠截肢掉一个动作换来的「装得下」不叫修好。先证红 ✓(133px) | **两个触发条件只在崩溃时同时成立**:这一行只在后端宕机时存在,而溢出还需要海洋窄(右岛开着)。此前每一轮扫查都碰不到这个交集——**是韧性域把它逼出来的** | ✅ 已修 |
| **L6** | 重试之后,被取代的那一版**作为多出来的一轮**留在屏上——同一个问题答两遍、且没有版本翻页;**只有重启(走 REST)才折叠**成 `‹ 2/2 ›`。R03 断网演练里逼出来的:失败一轮 → 重试成功 → 屏上同时挂着红字失败轮与新答案 | **close 快照不自足**。`retryOf` 只搭了 `message_start`,而 **E2 规定 Close 是 durable 帧、其快照即 replay 真相**,客户端从该快照**整体覆写** content(此律在 `conversation_transcript.dart` 里已被写死过一次——本地 mentions 就是因它才要「每个 durable 帧后补写」)。于是回合一结束,开场送来的指针被抹掉,版本链断在**终点**。**同一种形状后端自己已经栽过一次并立了法**:`chat.md` 白纸黑字记着 `WriteFinalize` **整体重写** Attrs、故 `retryOf` 必须在收尾时**重新种**,连后果都写对了——「那个失败的版本会渲成**多出来的一轮**而不是版本翻页里的一页」。库那一半补了,线缆这一半没有。同文件内 **user 回声的 close 快照带 `RetryOf`**(编辑重发用)、assistant 的不带,是遗漏而非设计 | `<本次提交>` | **两层,皆先证红**:①`retry_test.go` 的 `TestRetry_CloseSnapshotCarriesTheVersionPointer`——断言**穿过真 JSON**(一个永不被序列化的字段蒙混不过去),红:`retryOf=""`;②testend `TestChatRetry_VersionChainWalksOnTheWire` 补 SSE 半——**仅凭 close 帧**重建整条向后链,拉真二进制真 SSE,红:两步各差一个指针。修后两层全绿,`make -C backend verify` + testend retry 全族绿 | **既有覆盖全在 REST**:testend 那条场景名字就叫「WalksOnTheWire」,但它走的是 `GET /messages` 投影——链在那儿**一直是对的**。没有任何测试问过「**只拿 close 帧**能不能重建这条链」,而那正是 replay / 中途连上的第二个窗口 / 每一次重连所处的位置 | ✅ 已修(真机:修复版上重试**当场**折成 `‹ 4/4 ›`;**首次复验作废重做**——那次的 8742 上跑的是 12:06 的旧进程,我的重启因工作目录不对静默失败,是核对进程启动时间才发现,详见下「L6 复验作废」) |
| **L7** | notifications 流一旦 410,**chat rail / 对话头 / 实体列表 / 实体详情 / library 页树与 skill 列表** 六处全部静默停止跟踪各自的生命周期变更(改名·归档·置顶·驻地·自动命名·增删),且**一直陈旧到会话结束**——它们住在保活栈里,导航不会重建它们 | **信号与 resync 走的不是同一条流**。四个仓都从 notifications 流派生 `lifecycleSignals`,而 410 的语义是「丢游标 → 通知消费方重取 → 从新 head 重连」:缺口里的信号**永远**没了,只听信号的消费方无从得知。six 处里没有一处订阅 notifications 的 resync;chat rail 甚至**有**一条 resync 订阅——挂在 `transcriptResync()` 即 **messages** 流上,那条流载着它的活态点、不载它的生命周期,**于是它为漏不掉的那一半重翻了整列,却在会漏的那一半上保持陈旧**。这个错在别的任何方面都看不出来:订阅编译得过、流也是对的、正常会话完美,只有离开够久的客户端静默偏离 | `<本次提交>` | **两层,皆先证红**:①**源码类守卫** `lifecycle_resync_guard_test`——凡订阅 `lifecycleSignals(` 的文件必须也订阅 `lifecycleResync(`(先证红,一次点名**全部 5 个文件**;守的是**下一个**照抄既有订阅接上来的 provider,而照抄正是它蔓延到四域的方式);②**行为守卫** `conversation_list_provider_test` 新增「a notifications-stream 410 re-reads the rail」——在客户端「聋掉」期间**不发信号地**改掉夹具的行,只有真去重读才看得见(撤掉修法即红:`OLD TITLE`) | **无覆盖**:`sse_connection_test` 把 410 的**连接层**钉得很死(resync 发了、游标丢了、下次不带 Last-Event-ID),而**没有任何测试问过「谁在听 resync」**。连接层完美地履行了契约,信号发进了空气里 | ✅ 已修(六处消费方各自补取;`make -C frontend verify` 5040 测全绿) |
| **L8** | `make -C frontend verify` **在 main 上本就是红的**(与本轮改动无关——`git stash` 后同样红):`skill_tool_picker_test` 的「adds a builtin by name」失败于 `Bad state: No element` | 测试**点在了视口外**:内置工具组比面板长,`Read` 落在折叠线以下,而 `tester.tap` 对视口外的目标**只给警告、不报错**,于是回调从未触发、`picks` 为空。同一个测试给下面的 `sync_inventory` **写了** `ensureVisible`,给 `Read` 没写——它一直是脆的,只是候选列表长到某一天把 `Read` 挤下去才发作 | `<本次提交>` | 补 `ensureVisible`(与该测试对 `sync_inventory` 的既有做法一致);修后单跑与全量皆绿 | **门禁自己红着**——本轮之前的会话在内环只跑 `quick`(按纪律 quick 只跑 diff 涉及的测试,library 未被碰过就不跑),而全量 verify 是 pre-push 档。**这正是分层门禁的已知代价**,不是纪律被违反;记此以说明「推送前必须全量」为何不是形式 | ✅ 已修 |
| **L9** | 创建卡**报错名字**:agent 建了个叫 `echo_unicode` 的函数,转录里写的是「Created function **codepoints**」——而 `codepoints` 是这个函数**输出字段**的名字。顶带通知与右岛(不走这个取法)都叫对了 | **身份用了「任意深度同名键」取法**。`liveStringNamed` 匹配任意深度的**末段**键名、且**倒扫** events——这对它被文档化的职责(跟住此刻正在生长的 `code`/`body`,不论嵌多深)完全正确,对**身份**完全错误:ops 形状里 `ops[0].name`(set_meta=实体名)后面还跟着 `ops[2].outputs[*].name`,最后一个赢。**不限于函数、不限于 Unicode**:凡 ops 形状且输入/输出带名字的构建工具全中招;`install_mcp_server` 的 `env` 是**自由键 map**,一个字面叫 `name` 的环境变量同样会盖过服务器名 | `<本次提交>` | `tool_card_builds_test` 新增「a create card names the entity, not a nested output field」——用**真机那次的原样 payload**(先证红,且红得一字不差:`codepoints`)+ 扩到**整类**:MCP 自由键 map 那格、以及「名字仍在打字时活性未丢」那格 | **无覆盖**:既有构建族测试全用**扁平**或**只含 set_code** 的 ops 夹具,从没有一个夹具**同时**有 `set_meta.name` 与带名字的 `outputs`——而那恰恰是任何真实函数的形状 | ✅ 已修(身份取法下沉 `toolCardCreatedName`/`toolCardTopLevelName`,按**精确路径**读 + 在途尾值走同一路径保活性;**8 处**身份点全部改用它,含 skins 里 RunStatBar 的 label;真机复看运行卡显示 `echo_unicode`) |
| **L10** | 工具失败的**结构化日志**丢掉了原因:`tool execute failed … invalid workflow ops`,而后端**已经算出**「哪个 op 错了」 | `zap.Error(err)` 渲染 `Error()`,而 `Error()` 按构造丢 `Details`。同一份错误**给 LLM 的那一份**经 `Surface` 带着 Details(F7 教训:不透明错误让 agent 盲猜),**给运维的那一份**没有——不对称是反的:模型还能重试,凌晨读日志的人不能。**这条是我自己读日志时被绊到才发现的** | `<本次提交>` | `tools_llmerr_test` 新增 `TestToolFailureLog_CarriesTheReason`——用 zap observer 抓那一行、断言含 `ops[3]`(先证红:只有 `invalid workflow ops`) | **无覆盖**:既有 `TestLLMErrText` 把**模型那一侧**钉得很死,日志侧从没测过——而日志只有在你**真去读**时才看得出它缺了什么 | ✅ 已修(两个工具日志点改走 `llmErrText`,键名不变、值更富) |
| **L2** | 冷启动与热重启**必现**的 riverpod 断言 `setState() called during build` | **懒刷新的脏跨过了 build 边界**:`WorkspaceBootstrap` 先 `read(apiClientProvider)` 把 dio+apiClient 挂起来,随后在 await 之后 set `activeWorkspaceProvider`——而 dio **watch** 着它(那个 watch 就是热切换脉搏)。dio 就此变脏,riverpod 懒刷新,于是这份脏一直搁到某个 **widget** 的 build 走下那条链(rail → `chatRepositoryProvider` → `apiClientProvider`),刷新在 build 里跑、apiClient 自我失效、调度 refresh = 对 scope 的 `setState`。**在 build 中途** | `c76740f7` | **双守卫,都先证红**:① 行为——`provider_settle_guard_test` 用 40 行复现同一条断言(build 外 set → 后续 build 首次 watch);② **源码级**——`workspace_write_guard_test` 扫 `lib/**`,任何绕过 `setActiveWorkspace` 直接调 `.notifier).set(` 的文件即红(行为测试对**新增的绕行调用点**一无所知,而绕行正是最容易犯的错:它编译得过、id 也设对了,损害落在别处) | **没有任何测试覆盖 provider 图的时序**。既有测试要么 `overrideWithValue(apiClient)` 绕开真链(`workspace_bootstrap_test`),要么只在 `ProviderContainer` 里跑、根本没有 widget build 阶段(`hot_switch_test`)。**「脏是否跨过 build 边界」这件事,之前一个字都没测过** | ✅ 已修 |

### B1 复现(2026-07-26 02:16,真机,意外但完整)

热重载时驻地菜单仍开着,一次本意打在别处的点击落到了「Leave working directory」上。四个信号源交叉印证,
故事完整,**顺带把 B1 钉死了**:

| 信号源 | 说的话 |
|---|---|
| **④ SQLite** `marker` 块 | `{"from":"…/ShopeeFileFolder","to":""}` @ `18:16:02 UTC` = **本地 02:16:02**,与那次点击同秒 |
| **④ SQLite** `conversations` | 全库仅 **1** 条带 `work_dir`(且是另一条对话) |
| 服务端 `GET /conversations/workdir-groups` | 只报 **1** 个驻地组 |
| **① 界面** | rail 仍显示 **2** 个组,被清空的 `ShopeeFileFolder` 组还在,里面还挂着那条对话 |

**判读**:退出驻地这个动作本身完全正确(库、投影、面包屑字形三处都对),**唯独左岛没跟上**——正是 B1 报的
那件事,只不过用户报的是「修改后」,这里是「退出后」,同一个失效缺口的两个入口。这进一步坐实 §0 铁律二对
B1 根因的判断:**失效责任散落在各个变更点**,补一行 `invalidate` 只会修好其中一个入口。

### L1 残留(已根治,`1b4abb22`;定位史如实留档)

编舞修复(`1fb327f2`)把三条 404 砍到一条后,第二轮真机复现(前置条件先坐实——此前一次「0 异常」是
**空的**,因为对话根本没打开)看清了残留的确切形状:切换后仍有**四条**针对旧对话的请求
(`interactions` / `touchpoints` / `todos` 200 + `messages` **404**)。那三条不 404,只是因为**只有
`ListMessages` 校验存在性**——同样是不该发出的请求,后端对它们更宽容而已。

**两条试过并被自己证伪的假设,均已撤销**(留一个注释里写着假因果的改动,比不改更糟):
1. `dio.close(force: true)`——猜「跨越切换的在飞请求在发送时才读 header」。真机结果不变。
2. `_hydrate` 先让出一个微任务再查 `ref.mounted`——真机结果不变;**再加一帧(共两帧)也一字不差**,
   帧数不是杠杆。

**当晚的定位(保活栈留住 transcript 族)方向对、主体错**——读码到底后:transcript 随 landing 换台
**正常死**(`ChatOcean` 无记忆,选区一空就渲 landing);活过切换的是右岛 `_InspectorStack` 的私有
`_lastChat`——它刻意让 `StagePanel(旧对话)` 常驻折叠(去别的海洋看一眼、侧幕不卸,设计本意),但记忆
**随 widget 活而不随 workspace 死**。它监听的四个对话域 provider 与真机四条请求**一一对号**:
`touchpointLedger`→touchpoints、`pendingInteractions`→interactions、`rundown`→todos 直接重取;
`stageDirector` 的 build 更经 `ref.read(conversationStreamProvider(旧).notifier)` 把**已经死掉**的
消息流 provider **复活**、重新 hydrate=`/messages` 404。这也解释了 header/workDir 为何按时死——
它们不在任何记忆之下。

**修法**(`1b4abb22`):记忆上提为 `core/shell/inspector_memory.dart` 的 `lastChatThreadProvider`
(壳级,同 `rightPanelCollapsedProvider` 一族):AppShell 进对话上闩(深链冷启 post-frame 补闩)、
`_InspectorStack` 改吃 provider(私有态删除),`WorkspaceSwitch` 第①拍与 `go('/')` **同瞬显式
clear**——面板在轴翻转**前一帧**卸载,翻转时对话域 provider 已零监听,级联不再急重建它们。provider 自身
watch activeWorkspace(换世界即弃闩)只是局部不变量、不是修法:守卫「KEPT-ALIVE right island」在
「有自愈、无编舞清除」的中间态下**记忆已复位、线上仍 2 条旧请求**——自愈晚一个 flush,实证清除必须在
第①拍。

**真机收口**(热重启装新码,前置断言先行):开 `cv_b6f7c8825b3dc77e`、`/messages` 200 坐实 → 切
演示工作台 → 水位后**0 条**旧对话请求、0 条 4xx/5xx(修前同操作 4 条)→ 切回重开,五端点
(messages/interactions/todos/touchpoints/workdir)各**恰好一次**全 200——卸载不伤重绑;Flutter 终端
全窗口零输出。

### L6 复验作废(第四次同类陷阱,记档以钉住教训)

L6 修复后的**第一次**真机复验显示「仍然分裂」,几乎被我读成「修法无效」。核对进程启动时间才发现:8742 上跑的是
**12:06 启动的旧后端**——我那条重启命令的工作目录是仓库根、`go run ./cmd/server` 在那里根本不存在,命令静默失
败,而随后的 `health=200` 来自**没死的旧进程**。也就是说那次复验是**打在带病版上的**,它什么都没证明。

**教训不是「小心工作目录」,而是**:真机复验前必须先坐实**被验的是哪一个二进制**。健康检查回 200 只证明「有人
在监听」,不证明「监听的是你刚改的那份」。此后所有后端复验一律先核 `ps -o lstart`(或等价的身份证据)。

这是本战役第四次同类陷阱(前三次:URL 断言空绿 / 夹具自造缺陷 / 未开对话就宣布 0 异常),四次的共同形状是
**「验证对象没有被真正置于被验状态」**。

### B1 根因订正(§0 的原判据被实证推翻,记档而非默默改口)

§0 铁律二里我判 B1 的根是「失效责任散落在各个变更点」,证据是 `addWorktree` 自己手写了一句
`invalidate` 而 `set()` 走另一条 patch 路径、两条都忘了列表。**那个判断是错的。**

读码到底后事实是:rail 的重分组机器**早就建好了**——`applyUpdate` 按 `_axisOf` 重新归段、并向服务端
重问组计数,注释里连「刚离开驻地的线程带着空 workDir 到达、而它的组从未展开过所以我们从没持有过那一行」
这种边角都推演过。它不是没建,是**从没被触发过**:后端发的 `conversation.work_dir` 在前端动词表里不存在,
落进 `_ => unknown`,`_onSignal` 直接 `return`。

**订正的意义不在于我判错了,而在于两种根因导出完全不同的修法**:按原判会去补 `invalidate` 调用——那会
在**已经正确**的机器旁边再搭一台,而真正的缺口(动词表)原封不动,下一个动词照样静默。真机验证:挂上驻地
的瞬间新组出现、`Recents` 13→12,零刷新。

**B3/B4 施工中主动扩大的两处**(如实记档,非工单点名):
1. **`AnIcons.folderMissing`(新增语义图标)**。按钮改纯字形后,「目录已不存在」失去了全部可见通道——旧注释声称警示「落在标签自己的字形」,但代码里标签只是 `_basename()`,**那句注释本就与代码不符**。AnButton 没有 `warn` 变体可着色(只有 ghost/primary/danger/icon),故警报改骑**字形**(`folder` → `folder-x`)。字形也胜过着色:暗色与色盲下都还成立。
2. **`_ForkLineage` 从「带标签的钮」变成「纯字形 + 菜单」**。单纯摘掉标签会造成一个更糟的交互:点击即导航,而字形本身什么都没说——**你无法在不跳过去的前提下知道它通向哪**。故点击改为**展开**,名字就是它展开出来的东西。这同时让面包屑两个字形说同一套文法(字形 → 菜单 → 身份在菜单头)。

**已解释、不再追的历史异常**(同次考古所得,记此以免重复调查):
`/speech/asr` 500 ×6(`Hijacker` 缺转发,已修,23:23 后转 400)·
`/freetier/quota` 401 ×11(install 死结,已修)· `media: derivative processing failed`(HEIC,预期)·
`autoTitle 401`(同 install 死结)·
**`ConcurrentModificationError`(0726 13:0x 扫查所见,framework 内部,记档不吞)**:栈全在 Flutter 的
`MultiSelectableSelectionContainerDelegate.handleClearSelection`(`selectable_region.dart`,
`didChangeSelectables` 排的任务边遍历 selectables 边被改)——发生在**两次热重启之间**的窗口
(dev 工具链批量拆 selectable),我方代码零帧;L1 收口验证窗口(重启后)Flutter 终端零输出,全部真实
用户流程扫查中从未出现。若某天在真实流程(如选中文字时切对话)复现,按新缺陷立项;在那之前不冒充可修。

---

## §5 完成定义(逐条勾,任一未过 = 本轮未完成)

1. ☐ §3 矩阵**每一格**有明确结论(✅ / ❌ / 🚫)。**空格 = 未完成**;「应该没问题」不是结论。
2. ☐ §4 台账**清零**——无「待修」、无「待查」、无「已知问题」。§0 铁律一的六种逃逸话术
   一条都没用上。
3. ☐ 每条缺陷的**五栏全满**,尤其:根因层不是「哪一行」而是「哪一层」;守卫覆盖**整类**;
   「门禁为何没抓到」有答案。
4. ☐ 每个守卫都**验过它在修复前是红的**(铁律三·3)。
5. ☐ 修完在**真机复看**过,不是只看单测绿(铁律三·4)。
6. ☐ 一轮完整操作后:Flutter 终端零 overflow / 零 assertion / 零未处理异常;
   后端结构化日志**零 500**、4xx **每一条都能说出为什么**。
7. ☐ 物理测不了的三类如实转入 `ACCEPTANCE-GUIDE` C4 并有落点,不冒充已验。
8. ☐ 本轮新增守卫全部进 `make verify`——**下一轮不必重扫同一格**;两仓门禁全绿。

> **只有 1–8 全勾,才轮到 [WRK-082](../multimodal-output/README.md)。** 这是用户 0726 定的
> 顺序:先一身干净,再上大工单。
