# 设计规范(Design System)

> 本项目所有 UI 必须严格遵循本规范。风格关键词:**明亮、通透、轻盈、精致、有呼吸感**。
> 灵魂在三件事:**考究的字体排版 + 大留白 + 柔和的呼吸式动效**。
> **绝对不要任何渐变背景、不要深色模式、不要花哨装饰。**

---

## 一、整体气质

- 白色优先(light-first),干净通透,亲和而不冷。
- 参考气质:Stripe 的干净排版 + Gemini 的轻盈与柔和动效,但**去掉一切彩色渐变**。
- 把"美"押注在排版、留白、微交互上,而不是靠颜色或效果堆砌。
- 克制大于炫技。能用留白解决的,绝不加装饰。

---

## 二、配色(Color)

只用黑白灰 + **一个**克制的强调色。强调色仅用于重点元素(主按钮、链接、状态点),绝不大面积使用。

```css
:root {
  /* 背景 */
  --bg:            #FFFFFF;   /* 主背景,纯白 */
  --bg-subtle:     #FAFAFA;   /* 次级表面 / 区块背景 */

  /* 文字 */
  --text:          #1A1A1A;   /* 主文字,近黑 */
  --text-muted:    #6B7280;   /* 次要文字,中灰 */
  --text-faint:    #9CA3AF;   /* 提示 / 标注,浅灰 */

  /* 强调色:全局同时只渲染一个;用户在引导/设置里选哪一个(默认 claude 橙) */
  --accent:        #d97757;   /* claude 橙(默认);另有 蓝/墨/绿/紫 可选,见 tokens.css */

  /* 边框(极细、低透明度) */
  --border:        rgba(0,0,0,0.08);
  --border-strong: rgba(0,0,0,0.14);
}
```

规则:
- 背景永远是白或近白,**禁止渐变背景**。
- 一个页面里强调色出现的地方越少越好(理想是 2-3 处)。
- 边框用极细、低透明度的黑,而不是实色灰线。
- 不要彩色阴影、不要霓虹光、不要 glow。

---

## 三、字体排版(Typography)—— 重点

- 字体:无衬线,可读性与美感优先。优先 `Inter`,其次系统字体栈。
- **只用两种字重:400(常规)、500(中等加粗)。禁止 600/700**,太重会破坏轻盈感。
- 层级要清晰,标题大、字重对比明显;正文温和、行高舒展。
- 大标题收紧字间距(letter-spacing 负值),正文不收。
- **始终用 sentence case(句首大写),禁止 Title Case 和全大写。**

```css
--font: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;

/* 字号阶梯 */
h1   { font-size: 46px; font-weight: 500; line-height: 1.1;  letter-spacing: -0.025em; }
h2   { font-size: 30px; font-weight: 500; line-height: 1.2;  letter-spacing: -0.02em;  }
h3   { font-size: 20px; font-weight: 500; line-height: 1.3;  letter-spacing: -0.01em;  }
body { font-size: 16px; font-weight: 400; line-height: 1.6;  color: var(--text); }
small{ font-size: 13px; font-weight: 400; color: var(--text-muted); }
```

---

## 四、留白与布局(Spacing & Layout)

- 大留白,疏密有致(不是傻大空,而是有节奏)。
- 严格用 **8px 间距系统**:8 / 16 / 24 / 32 / 48 / 72。
- 区块(section)之间留白要充足,内容呼吸感拉满。
- 重要内容居中、克制,首屏一句大字号问候/标题,而不是堆功能。
- 内容最大宽度做约束(如正文 540-640px),避免一行太长。

---

## 五、形状与质感(Shape & Surface)

- 圆角统一、偏大、柔和:
  - 一般元素 `border-radius: 12px`
  - 卡片 / 面板 `16px`
  - 按钮、徽章、标签:**全圆角药丸形 `999px`**(呼应 Gemini 亲和气质)
- 卡片:白底 + 极细边框 + 大圆角,**不要重阴影**(必要时只用极轻阴影 `0 1px 3px rgba(0,0,0,0.04)`)。
- 分隔用极细线 `0.5px solid var(--border)`,而不是粗线或色块。

---

## 六、动效(Motion)—— 灵魂,重点

这是这套风格最关键的部分。动效要**柔和、缓慢、自然,像呼吸一样**,绝不生硬或花哨。

**1. 缓动曲线** 一律用带轻微弹性的 ease-out,绝不用 linear:
```css
--ease: cubic-bezier(0.22, 1, 0.36, 1);
```

**2. 元素入场:依次淡入 + 轻微上移**(stagger / 错峰)
```css
.reveal {
  opacity: 0;
  transform: translateY(10px);
  animation: rise 700ms var(--ease) forwards;
}
@keyframes rise { to { opacity: 1; transform: translateY(0); } }
/* 多个元素依次延迟 60ms / 160ms / 280ms / 400ms ... 制造错峰 */
```

**3. 呼吸动画:用于状态点 / 强调元素**(Gemini 那种"活着"的感觉,但极度克制)
```css
.breathe { animation: breathe 2.6s ease-in-out infinite; }
@keyframes breathe {
  0%, 100% { opacity: 1;    transform: scale(1);    }
  50%      { opacity: 0.45; transform: scale(0.82); }
}
```

**4. 交互反馈:** hover 轻微上浮或变色,过渡 200-300ms;active 轻微缩放 `scale(0.98)`。
```css
button { transition: transform 220ms var(--ease), opacity 220ms var(--ease); }
button:hover  { transform: translateY(-1px); }
button:active { transform: scale(0.98); }
```

动效红线:
- 过渡时长 **200-300ms** 区间,呼吸/入场可到 700ms-2.6s。
- **不要**快闪、不要弹跳过头、不要旋转炫技、不要一次性所有元素同时动(要错峰)。
- 尊重 `prefers-reduced-motion`,为该偏好的用户关闭非必要动画。

---

## 七、明确禁止(Never)

- ❌ 任何渐变背景(radial / linear / mesh 全部禁止)
- ❌ 深色模式 / 深色背景
- ❌ 重阴影、霓虹光、glow、模糊装饰
- ❌ 字重 600 / 700
- ❌ Title Case、全大写
- ❌ emoji 当图标(用线性图标库,如 Lucide / Tabler outline)
- ❌ 颜色超过"黑白灰 + 一个强调色"
- ❌ 一次性所有元素同时入场(必须错峰)
- ❌ 生硬的 linear 过渡
- ❌ 文案里的营销词、黑话、感叹号、卖萌语气(详见第八节)

---

## 八、文案调性(Voice & Tone)—— 和视觉同等重要

文案和视觉必须是同一个性格:**像一个冷静、笃定、惜字如金的人在说话**。
安静、自信、有用,绝不聒噪或卖力推销。视觉这么克制,文案就不能聒噪,否则调性破功。

原则:
- **极简**:能短不长,砍掉一切冗余修饰。
  "立即开启你的高效之旅" → "开始"
  "了解更多详情" → "了解更多"
- **不喊**:禁用感叹号(错误提示也尽量不用)、禁用营销词
  (超强 / 极致 / 颠覆 / 革命性 / 全新升级 / 业界领先)。陈述事实即可。
- **说人话**:禁用产品黑话——赋能、抓手、闭环、一站式、全方位、
  打造、助力、生态、护城河、深度整合。它们听起来很忙,其实什么都没说。
- **用户视角**:描述"你能做什么",而非"我们多厉害"。
  "我们提供业界领先的搜索引擎" → "快速找到任何东西"
- **克制 emoji**:UI 文案默认不用 emoji。视觉已经在传递情绪,文字不用卖萌。
- **状态 / 错误文案同样冷静**:有用、不卖萌、不甩锅。
  "哎呀,这里空空如也呢~" → "还没有内容"
  "出错啦,再试试呗!" → "出了点问题,请重试"

按钮文案参考:开始 / 继续 / 保存 / 了解更多 / 试用 / 联系我们
(动词开头,简短,不带语气词和 emoji)

写任何文案前自问:这句话一个惜字如金的人会这么说吗?
有没有可以删的词?有没有在卖力吆喝?有没有黑话?

---

## 九、给 AI 的一句话自检

> 生成任何 UI 前,先自问:背景是不是干净的白?是不是只有一个克制的强调色?字体层级是否清晰、字重只用 400/500?动效是不是柔和、错峰、像呼吸?有没有不小心加了渐变?文案是不是简短、不喊、没黑话、没 emoji?——全过再写代码。

---

## 十、问候语调性(Voice for Greetings)

欢迎页问候语是品牌触点,每次进首屏都见。调性原则:

- **语言:** 英文 only。中文与硅谷腔不搭。
- **腔调:** 硅谷腔 — 自信、克制、惜字如金。像一个有把握的工程师拍你肩说一句话。
- **禁:** 感叹号、表情、营销词("超级"/"极致"/"颠覆")、励志金句、咖啡 emoji。
- **可用:** 锻造/锤/铁/火/锚的隐喻;时间感(早 / 深夜);AI 自我引述("I'm all ears.");留 30% 中性/温柔避免硬核疲劳。
- **个性化:** 含 `{name}` 占位的句子用 displayName 替换;displayName 空时,池里 name-bearing 句不参与抽签。

参考池:`frontend/src/panes/dashboard/greetings.js`(380 句,15 类标签 A-O)。

新增/修改问候语规则:
- 添加前 grep 池子防重复:`grep -F "Your phrase" frontend/src/panes/dashboard/greetings.js`
- 加 tag 至少一个;含 `{name}` 必带 M tag
- ≤ 50 字符。超过容易在 input 框上方溢出。

---

## 十一、组件与交互约定(Component & Interaction)

§1–10 是"长什么样",这节是"怎么动 / 怎么搭"。以下规则都是 welcome + sidebar
改造里用 bug 换来的,违反任何一条都会被一眼看出来。

**1. 图标列对齐(rail icon column)**
可折叠导航栏里,所有图标(logo / nav / 工具 / 头像 / 齿轮)的中心都落在**同一条
竖线**上 —— 取收起态轨道的中心(64px 轨道 → x:32),**展开和收起两态都在这条线**。
结果:折叠只是纯水平收窄,图标一根都不动。

**2. 收起 / 展开 = 零位移(铁规)**
折叠动画只允许改宽度 + label 淡出。任何图标 / 头像**不得有横向或纵向位移**。要点:
- 图标用**固定左偏移**,不依赖动画过程中的容器宽度;
- 两态**行高必须相同**(收起态 nav 项也要 38px;高 2px × N 行 = 肉眼可见的纵向膨胀);
- 需要居中时,在**固定宽度**里居中(如 footer 固定 64px),**不要**在 Framer 正在
  动画的宽度里 `align-items:center`(否则随宽度收窄从右滑入);
- **同一个元素在两态复用**;别 expanded 用元素 A、collapsed 用元素 B(absolute vs
  flow 居中会有亚像素漂移)。

**3. 浮层 = 定位与动画分两层(关键)**
任何用 Floating UI(或类似)定位 + 带入场动画的浮层(菜单 / popover / tooltip),
**定位 transform 与动画 transform 绝不能在同一个元素上** —— 会互相覆盖,表现为
"先在左上角闪一下再跳到正确位置"。做法:外层只承载定位(`floatingStyles`),
内层承载入场动画(opacity + 自相对的 transform)。

**4. 列表项 / 菜单项复用药丸语言**
侧栏对话项、ActionMenu 项等,统一用导航项的药丸语言:999px 圆角、相同左右 margin、
`--bg-hover` / `--bg-active` 的 hover/active 底色。次级列表字号可小一档(13 vs 14)。

**5. 主操作 hover-only**
"新对话"这类主项**不要常驻底色**(看着像被点击 / 卡住),只 hover 变色 + 字重 500
即可。

**6. 弹窗样式统一(ActionMenu / popover)**
纯白底 `--bg-paper`、圆角 12、item 圆角 8、13px 字、16px 图标、padding 8·12、
分隔线两侧留白。**全局一套**,别每处各写。

**7. 状态点克制**
列表项默认不挂状态点;只有 streaming(accent 脉动)/ 待批准(warn)才显,idle 标题
齐平左对齐。

**8. 折叠按钮要可见**
展开态收起按钮要**常驻可见**(Gemini 那样右上角一个方块),别藏成 hover 才 morph 的
小 logo —— 用户找不到 = 等于没有。收起态窄轨放不下时,才让 logo 兼任(hover 变
展开图标)。

**9. 数据单一来源**
显示字段(用户名等)从**权威源**读(后端激活 User),不要复制进孤立的 localStorage
字段 —— 会和真源脱节(走完引导仍显示 "?")。

**10. CSS 收敛**
一个组件一套样式,**不留打架的重复定义**(如 `.action-menu button` 靠 specificity
盖住 `.action-menu-item`)。改样式前先 `grep` 有没有重复块,顺手删死代码。

> 交互自检:折叠/展开来回点几次,图标 / 头像有没有动一个像素?浮层点开有没有闪?
> 主项是不是只 hover 才变色?—— 全过再说做完。

---

## 十二、协作工作流 · Superpowers

这套 UI 是用 superpowers skills 做出来的。以后做**大块 UI / 改造 / 多步任务**照走;
小修小补可跳过仪式,但"先想清楚、先定根因、每步可验证"始终成立。

**1. 想清楚再动手 — `superpowers:brainstorming`**
"做个功能 / 改造 UI"先 brainstorm:探意图 → 一次问一个问题 → 提 2-3 方案 → 给设计 →
写 spec。**没对齐不写代码。**

**2. 视觉决策用 Visual Companion(默认动作)**
涉及布局 / 样式 / 取舍,用视觉伴侣在浏览器画 **2-3 版 HTML mockup**,让用户**点着选**,
定了再实现。"先 super power 脑洞个 html 给我看看" = 标准开场。**别凭空发明,别直接
改代码让用户在真 app 里猜。**

**3. spec → plan → 执行**
- spec 落 `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md`;
- `superpowers:writing-plans` 拆成**逐任务、TDD、含确切文件 + 代码**的计划,落
  `docs/superpowers/plans/`;
- `superpowers:subagent-driven-development` 每任务派**全新 subagent** 实现 + **两段
  review**(先 spec 合规、再代码质量)+ 最后整体 review。机械任务用便宜模型,
  重写 / 判断用强模型。
- (这些 spec/plan 是过程产物,合并后可像 user-identity-cleanup 那样 drop 掉。)

**4. 改 bug — `superpowers:systematic-debugging`(Iron Law)**
任何 bug **先定位根因再修**:没找到根因不准提修法。这轮所有 bug 都是先算清楚
(像素坐标、grid 与 motion 宽度冲突、transform 抢占、字段脱节),对比原始 commit /
读 git 历史 / 查后端,**再一刀修干净** —— 绝不猜、不打补丁遮症状。修法要"干净"
(收敛重复、零位移、像素精确)。

**5. 每步可验证 + 频繁提交**
每个改动:`cd frontend && npm run build` + `npm test` 全绿 → commit → push。
本仓库 trunk / feature 分支每 commit 即推、**无 AI 署名**。声称"修好了"前要有证据
(测试 / 构建绿,或让用户肉眼验);视觉改动尤其要用户在浏览器确认。

**6. 节奏**
用户报问题 → 定根因(必要时读 git / curl 后端 / 算坐标)→ 视觉的先 mockup、逻辑的
直接修 → 验证 → commit+push → 让用户检查。一次一个清晰闭环。
