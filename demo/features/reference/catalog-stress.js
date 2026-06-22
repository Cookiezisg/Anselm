/* 压力与边界态 specimen —— 五电池(空/超长/海量/极值注入)+登记缺口变体。
   与 catalog.js(happy-path 展柜)分列：本件是组件健壮性压力床——每件在任意数据填充下不破。
   why: 画廊是 web 建设事实源，既要典型态也要边界态，二者分层不混；这些态由 Playwright demo-test 自动断言。 */
(function () {
  if (!window.REF_CATALOG) return;
  window.REF_CATALOG.push(
    {
      cat: "压力·控件 Atoms",
      icon: "blocks",
      items: [
        {
          name: "状态点 status-dot",
          tag: "an-status-dot",
          blurb: "压力态 — 非法 state 落默认灰点（不崩）",
          specimens: [
            { label: "极值:非法 state（落默认灰点）", tag: "an-status-dot", center: true, attrs: { state: "exploded" } },
            { label: "极值:空 state（=idle）", tag: "an-status-dot", center: true, attrs: { state: "" } },
            { label: "注入:state 含 <>&（属性转义、非枚举落默认）", tag: "an-status-dot", center: true, attrs: { state: "<img src=x onerror=alert(1)>" } },
            { label: "极值:数字 state=0（非枚举落默认）", tag: "an-status-dot", center: true, attrs: { state: 0 } }
          ]
        },
        {
          name: "状态徽 badge",
          tag: "an-badge",
          blurb: "压力态 — 超长 label 截断、非法 tone/dot 落默认",
          specimens: [
            { label: "超长截断（max-width+ellipsis）", tag: "an-badge", attrs: { tone: "ok", dot: "done" }, text: "release-notes-agent-nightly-replay-from-parked-node-with-a-very-long-status-label-0123456789abcdef" },
            { label: "极值:非法 tone（落 neutral）", tag: "an-badge", attrs: { tone: "radioactive" }, text: "未知 tone" },
            { label: "极值:非法 dot（status-dot 落默认）", tag: "an-badge", attrs: { tone: "accent", dot: "kaboom" }, text: "非法 dot" },
            { label: "注入(转义):slot 含 <>&", tag: "an-badge", attrs: { tone: "danger" }, text: "<b>danger</b> & <script>alert(1)</script>" },
            { label: "极值:emoji+CJK", tag: "an-badge", attrs: { tone: "warn" }, text: "⚠️ 已驻留 · parked 🅿️" },
            { label: "空:label 缺失（空药丸）", tag: "an-badge", attrs: { tone: "ok", dot: "done" } }
          ]
        },
        {
          name: "按钮 button",
          tag: "an-button",
          blurb: "压力态 — 超长 label nowrap、disabled、登记缺口 outline 变体",
          specimens: [
            { label: "超长 label（nowrap 不换行）", tag: "an-button", attrs: { variant: "primary", icon: "play" }, text: "Trigger nightly-etl workflow and replay every parked flowrun from its last memoized node 0123456789" },
            { label: "登记:outline（danger 红边删除钮）", tag: "an-button", center: true, attrs: { variant: "danger", outline: true, icon: "trash" }, text: "删除实体" },
            { label: "登记:outline（primary 描边）", tag: "an-button", center: true, attrs: { variant: "primary", outline: true }, text: "outline CTA" },
            { label: "disabled（键盘+鼠标双挡）", tag: "an-button", center: true, attrs: { variant: "primary", disabled: true, icon: "play" }, text: "Run（禁用）" },
            { label: "disabled + outline + danger", tag: "an-button", center: true, attrs: { variant: "danger", outline: true, disabled: true }, text: "禁用删除" },
            { label: "极值:非法 variant（落 ghost 默认皮）", tag: "an-button", center: true, attrs: { variant: "nuclear" }, text: "未知 variant" },
            { label: "注入(转义):slot 含 <>&", tag: "an-button", center: true, text: "<i>save</i> & <script>x</script>" },
            { label: "极值:emoji+CJK label", tag: "an-button", center: true, attrs: { variant: "primary", icon: "play" }, text: "运行工作流 🚀 立即" }
          ]
        },
        {
          name: "输入框 input",
          tag: "an-input",
          blurb: "压力态 — 超长 value、multiline 海量文本、注入转义",
          specimens: [
            { label: "超长 value（单行横向裁切）", tag: "an-input", attrs: { full: true, mono: true, value: "request.method == \"POST\" && request.headers[\"x-anselm-signature\"] != \"\" && payload.pull_request.draft == false && payload.action == \"opened\"" } },
            { label: "海量:multiline 多行文本", tag: "an-input", span: true, attrs: { full: true, multiline: true, mono: true, value: "line 01: spawn venv\nline 02: pip install -r requirements.txt\nline 03: python ingest.py --workspace ws_4a2f --limit 50\nline 04: stdout: fetched 1820 SKUs\nline 05: stdout: upserted 1820 rows\nline 06: stdout: done in 842ms\nline 07: exit 0" } },
            { label: "注入(转义):value 含 <>&\"'", tag: "an-input", attrs: { full: true, value: "<script>alert('xss')</script> & \"quoted\" 'apos'" } },
            { label: "空:value 与 placeholder 皆空", tag: "an-input", attrs: { full: true, value: "", placeholder: "" } },
            { label: "极值:emoji+CJK value", tag: "an-input", attrs: { full: true, value: "搜索实体… 🔍 nightly_etl 工作流 ✦" } },
            { label: "超长 placeholder（占位裁切）", tag: "an-input", attrs: { full: true, placeholder: "搜索 function / handler / agent / workflow / trigger，按名称、ID 或标签过滤，支持 mono 等宽 cron 表达式 0 */6 * * *" } }
          ]
        },
        {
          name: "键值大行 field",
          tag: "an-field",
          blurb: "压力态 — 超长 value（默认裁切 vs wrap 换行）、空值占位、超长 label/hint",
          specimens: [
            { label: "超长 value（默认 nowrap 右裁）", tag: "an-field", span: true, attrs: { label: "命令", value: "python ingest.py --workspace ws_4a2f1c9b3e7d0a85 --warehouse SG-01 --limit 50 --replay-from-parked --dry-run false 0123456789" } },
            { label: "超长 value + wrap（多行左对齐 anywhere 断行）", tag: "an-field", span: true, attrs: { label: "stdout", wrap: true, value: "Traceback (most recent call last): File \"main.py\", line 42, in transform raise ValueError(\"empty rows after upstream node fetch_orders returned 0 records for warehouse SG-01\")" } },
            { label: "空:value 空串（占位 —）", tag: "an-field", span: true, attrs: { label: "上次错误", value: "", editable: true } },
            { label: "空:label 也缺", tag: "an-field", span: true, attrs: { value: "" } },
            { label: "超长 label + hint（label 省略号 · hint anywhere 换行）", tag: "an-field", span: true, attrs: { label: "一个极其冗长的字段名称用于验证标签区不会撑破布局0123456789abcdef", value: "30s", hint: "节点级硬超时，超时即标记 flowrun 失败并 park 至断点，等待人工 resume 或 replay，不会重复展开已记忆化的上游节点结果。" } },
            { label: "注入(转义):value 含 <>&", tag: "an-field", span: true, attrs: { label: "filter", wrap: true, value: "payload.action == \"opened\" && <b>draft</b> == false & <script>alert(1)</script>" } },
            { label: "极值:emoji+CJK value", tag: "an-field", span: true, attrs: { label: "状态", value: "🅿️ 已驻留 parked · 等待审批 ⏳ 中文混排" } }
          ]
        },
        {
          name: "定义列表 kv",
          tag: "an-kv",
          blurb: "压力态 — 空 rows、海量 30 行滚动、超长 value（裁切 vs wrap）",
          specimens: [
            { label: "空:rows=[]（空列表无行）", tag: "an-kv", span: true, props: { rows: [] } },
            { label: "空:rows=null（兜底空）", tag: "an-kv", span: true, props: { rows: null } },
            { label: "空:值全空（每行占位 —）", tag: "an-kv", span: true, props: { rows: [["上次错误", ""], ["park 原因", null], ["下次触发", ""]] } },
            {
              label: "海量:30 行（纵向铺满 · 滚动验证）",
              tag: "an-kv",
              span: true,
              attrs: { mono: true },
              props: { rows: Array.from({ length: 30 }, function (_, i) { return ["node_" + String(i).padStart(2, "0"), "fnn_" + (i * 9876543210 + 1234567).toString(16).padStart(16, "0").slice(0, 16)]; }) }
            },
            { label: "超长 value（默认 nowrap 右裁）", tag: "an-kv", span: true, props: { rows: [["命令", "python ingest.py --workspace ws_4a2f1c9b3e7d0a85 --warehouse SG-01 --limit 50 --replay-from-parked --dry-run false 0123456789abcdef"], ["错误码", "FN_RUNTIME_PANIC"]] } },
            { label: "超长 value + wrap（多行 anywhere 断长串）", tag: "an-kv", span: true, attrs: { wrap: true }, props: { rows: [["stdout", "Traceback (most recent call last): File \"main.py\", line 42, in transform raise ValueError(\"empty rows after upstream fetch returned zero records\")"], ["url", "https://hooks.anselm.local/api/v1/triggers/trg_0c5e6a11/fire?token=whsec_abcdefghijklmnopqrstuvwxyz0123456789&replay=true"]] } },
            { label: "超长 key（key 省略号裁切）", tag: "an-kv", span: true, props: { rows: [["一个极其冗长的键名用于验证 key 列不会撑破布局且正确省略0123456789abcdef", "v"]] } },
            { label: "注入(转义):key/value 含 <>&", tag: "an-kv", span: true, props: { rows: [["<b>key</b>", "<script>alert('xss')</script> & \"q\" 'a'"], ["&amp; raw", "<img src=x onerror=alert(1)>"]] } },
            { label: "极值:emoji+CJK", tag: "an-kv", span: true, props: { rows: [["状态 🅿️", "已驻留 parked ⏳"], ["触发 🔔", "cron · 每 6 小时 ⏰"]] } }
          ]
        },
        {
          name: "分组小标题 group-label",
          tag: "an-group-label",
          blurb: "压力态 — 超长文本（uppercase + 自然换行）、注入转义",
          specimens: [
            { label: "超长（uppercase 大写 · 多词换行）", tag: "an-group-label", span: true, text: "Flowrun nodes memoized record-once durable execution interpreter idempotent replay from parked node" },
            { label: "注入(转义):含 <>&", tag: "an-group-label", text: "Entities & <triggers> \"durable\"" },
            { label: "极值:emoji+CJK（uppercase 对 CJK 无效）", tag: "an-group-label", text: "执行块 blocks ✦ 节点记忆化 🅿️" },
            { label: "空:无文本（空标题块）", tag: "an-group-label", text: "" }
          ]
        }
      ]
    },
    {
      cat: "压力·容器 Containers",
      icon: "section",
      items: [
        {
          name: "段 section",
          tag: "an-section",
          blurb: "压力/边界态：空 body、仅 actions 无 label、超长 label 截断、grid 海量、注入转义",
          specimens: [
            { label: "空（无 label·空 body，整段塌成空）", tag: "an-section", span: true },
            { label: "仅 actions 无 label（head 仍渲、动作不消失）", tag: "an-section", span: true, children: [
              { tag: "an-action-group", attrs: { slot: "actions", end: true }, children: [
                { tag: "an-button", attrs: { variant: "icon", icon: "edit" } },
                { tag: "an-button", attrs: { icon: "function" }, text: "添加" }
              ] }
            ] },
            { label: "超长 label（100+ 字符·大写小标签截断不撑破）", tag: "an-section", span: true,
              attrs: { label: "ENVIRONMENT VARIABLES AND SANDBOX RUNTIME CONFIGURATION FOR THE DURABLE WORKFLOW EXECUTOR ACROSS ALL NODES PLUS RETRY POLICY" },
              children: [ { tag: "an-row", attrs: { icon: "gear", label: "PATH", meta: "/usr/bin" } } ] },
            { label: "海量 grid（48 块·自动 2 列塌 1 列）", tag: "an-section", span: true,
              attrs: { label: "环境变量", grid: true },
              children: Array.from({ length: 48 }, function (_, i) {
                return { tag: "an-info-card", attrs: { title: "KEY_" + i, icon: "gear", meta: "env" }, children: [
                  { tag: "an-row", attrs: { icon: "doc", label: "value_" + i, meta: String(i) } }
                ] };
              }) },
            { label: "注入(转义)·plain variant", tag: "an-section", span: true,
              attrs: { variant: "plain", label: "<img src=x onerror=alert(1)> & <b>标题注入</b> 海洋页 \"引号\"" },
              children: [ { tag: "an-row", attrs: { label: "正文行" } } ] }
          ]
        },
        {
          name: "行 row",
          tag: "an-row",
          blurb: "压力/边界态：超长 label+meta、空 meta、emphatic 强调选中、mono 等宽、注入转义、深缩进",
          specimens: [
            { label: "超长 label + 超长 meta（label 单行省略·meta 不换行）", tag: "an-row", span: true,
              attrs: {
                icon: "workflow",
                label: "release-gate-发布闸门-工作流-在合并前跑全套-lint-typecheck-单元测试-集成测试-安全扫描-然后等待人工审批节点放行到生产环境",
                meta: "上次运行 2026-06-22 09:41:33 UTC · 842ms · flowrun fne_5e1a2b3c4d · 12 节点全绿"
              } },
            { label: "空 meta（meta=\"\" 整个尾槽抑制）", tag: "an-row", span: true,
              attrs: { icon: "function", label: "fetch_pr", meta: "" } },
            { label: "缺字段（仅 label·无 icon/dot/meta）", tag: "an-row", span: true,
              attrs: { label: "只有标签的裸行" } },
            { label: "登记:emphatic（accent 软底 + 左 inset 条·须配 selected）", tag: "an-row", span: true,
              attrs: { emphatic: true, selected: true, dot: "run", label: "fne_5e1a · 运行中", meta: "12s" } },
            { label: "登记:emphatic 未选中（无强调·回退常态）", tag: "an-row", span: true,
              attrs: { emphatic: true, dot: "idle", label: "fne_3b9c · 未选中 emphatic", meta: "—" } },
            { label: "登记:mono（label 等宽·run id/hash）", tag: "an-row", span: true,
              attrs: { mono: true, icon: "run", label: "fne_5e1a2b3c4d6f8a90", meta: "sha:9f8e7d6c" } },
            { label: "注入(转义)·label+meta 含 < > & 实体回显", tag: "an-row", span: true,
              attrs: { dot: "err", label: "<script>alert('xss')</script> & <b>node</b>", meta: "<i>0</i> & \"err\"" } },
            { label: "极值 depth=8 深缩进 + hint 多行", tag: "an-row", span: true,
              attrs: { depth: 8, collapsible: true, open: true, icon: "subagent",
                label: "深层子代理节点", hint: "缩进到第 8 层仍对齐·hint 长说明文本可换行承载机制描述而不被截断挤压成单行省略号永远" } }
          ]
        },
        {
          name: "信息卡 info-card",
          tag: "an-info-card",
          blurb: "压力/边界态：超长 title 截断、超长 meta 缩并截断、空 body、注入转义、海量内嵌行",
          specimens: [
            { label: "超长 title（100+ 字符·小标签不撑破 head）", tag: "an-info-card", span: true,
              attrs: { icon: "scheduler",
                title: "调度计划与重试策略以及在节点失败时的指数退避窗口和最大重试次数还有死信队列处置方式的完整配置说明文档标题超长测试", meta: "UTC" },
              children: [ { tag: "an-row", attrs: { icon: "trigger", label: "cron · 0 9 * * 1", meta: "每周一" } } ] },
            { label: "超长 meta（flex 缩并省略·不挤标题）", tag: "an-info-card", span: true,
              attrs: { icon: "run", title: "入参",
                meta: "application/json; charset=utf-8; schema=v3; very-long-content-type-value-that-must-truncate" },
              children: [ { tag: "an-row", attrs: { label: "prNumber", meta: "428" } } ] },
            { label: "空 body（仅 head·无内容·actions 行塌掉）", tag: "an-info-card", span: true,
              attrs: { icon: "doc", title: "空卡", meta: "0 项" } },
            { label: "全缺（无 title/icon/meta·head 不渲·仅裸 body）", tag: "an-info-card", span: true,
              children: [ "只有正文、没有头部的信息卡" ] },
            { label: "注入(转义)·title+meta 含 HTML 串", tag: "an-info-card", span: true,
              attrs: { icon: "gear", title: "<b>注入</b> & <script>x</script>", meta: "<i>&meta</i>" },
              children: [ { tag: "an-row", attrs: { label: "正文不受影响" } } ] },
            { label: "海量内嵌（40 行·卡内自然堆叠）", tag: "an-info-card", span: true,
              attrs: { icon: "history", title: "最近 firing", meta: "40 条" },
              children: Array.from({ length: 40 }, function (_, i) {
                return { tag: "an-row", attrs: { dot: i % 3 === 0 ? "err" : "done",
                  label: "trf_" + i.toString(16).padStart(4, "0") + " · " + (i % 3 === 0 ? "去重丢弃" : "已激活"),
                  meta: (100 + i * 7) + "ms" } };
              }) }
          ]
        },
        {
          name: "卡片 card",
          tag: "an-card",
          blurb: "压力/边界态：超长内容换行、selectable/selected、海量内嵌、注入转义、空卡",
          specimens: [
            { label: "超长内容（无 chrome·纯文本须换行不溢出）", tag: "an-card", span: true,
              children: [ "这是一段超长的卡片正文内容用于验证 an-card 在没有任何内部结构组件直接承载长文本时能否正常换行而不撑破容器边界或产生横向溢出滚动条这段文字故意写得非常非常长超过一百个字符以触发多行换行布局测试" ] },
            { label: "selectable + selected（accent 选中边）", tag: "an-card", span: true,
              attrs: { selectable: "", selected: "" },
              children: [ { tag: "an-row", attrs: { icon: "agent", label: "可选且已选中的卡", meta: "选中" } } ] },
            { label: "selectable 未选（hover 出 line-strong 边）", tag: "an-card", span: true,
              attrs: { selectable: "" },
              children: [ { tag: "an-row", attrs: { icon: "agent", label: "可点选卡·hover 试", meta: "点我" } } ] },
            { label: "row 横向 + 海量子项（溢出测试）", tag: "an-card", span: true, attrs: { row: "" },
              children: Array.from({ length: 12 }, function (_, i) {
                return { tag: "an-badge", attrs: { tone: ["neutral", "ok", "warn", "danger", "accent"][i % 5] }, text: "tag" + i };
              }) },
            { label: "注入(转义)·正文 HTML 串作纯文本", tag: "an-card", span: true,
              children: [ "<img src=x onerror=alert(1)> & <b>注入</b> \"引号\" 应原样可见" ] },
            { label: "空卡（无 slot 内容·pad=tight）", tag: "an-card", span: true, attrs: { pad: "tight" } }
          ]
        },
        {
          name: "海洋页头 ocean-header",
          tag: "an-ocean-header",
          blurb: "压力/边界态：超长 crumb 多级、超长 title 换行、注入转义、空 crumb、纯 actions",
          specimens: [
            { label: "超长 crumb（多级 nowrap 省略）+ 超长 title 换行", tag: "an-ocean-header", span: true,
              attrs: {
                crumb: "Entities|Workflow|生产环境|发布流水线|合并前闸门|安全扫描子流程|人工审批节点|深层嵌套面包屑超长溢出测试层级",
                title: "release-gate-发布闸门-在合并到主分支之前自动运行完整的-lint-与类型检查与单元集成测试再等待人工审批放行生产环境的工作流标题超长换行测试"
              } },
            { label: "editable 超长 title（就地改名·长标题盒不偏移）", tag: "an-ocean-header", span: true,
              attrs: { crumb: "Entities|Function",
                title: "fetch_pull_request_with_a_very_long_function_name_for_truncation_test_0123456789", editable: true } },
            { label: "空 crumb（无面包屑·仅 title）", tag: "an-ocean-header", span: true,
              attrs: { title: "无面包屑的页头" } },
            { label: "注入(转义)·crumb+title 含 HTML 串", tag: "an-ocean-header", span: true,
              attrs: { crumb: "<b>A</b>|<script>x</script> & B|<i>C</i>",
                title: "<img src=x onerror=alert(1)> & <b>标题注入</b>" } },
            { label: "crumb 含管道空段（'|||' 过滤空层级）+ meta + actions", tag: "an-ocean-header", span: true,
              attrs: { crumb: "Entities|||Agent||triage", title: "triage 诊断智能体", editable: true },
              children: [
                { tag: "an-badge", attrs: { slot: "meta", dot: "done", tone: "ok" }, text: "ready" },
                { tag: "an-badge", attrs: { slot: "meta", tone: "neutral" }, text: "v0.2 · 28 工具 · 双模型 fallback · 长 meta 徽超长内容测试" },
                { tag: "an-action-group", attrs: { slot: "actions", end: true }, children: [
                  { tag: "an-button", attrs: { variant: "primary", icon: "agent" }, text: "Invoke" },
                  { tag: "an-button", attrs: { variant: "icon", icon: "more" } }
                ] }
              ] }
          ]
        },
        {
          name: "右岛 right-island",
          tag: "an-right-island",
          blurb: "压力/边界态：登记 headless（自绘头）、超长 title 截断、空 body、海量卡堆叠滚动",
          specimens: [
            { label: "登记:headless（不画 .head·slot 自绘头）", tag: "an-right-island", span: true,
              attrs: { headless: "" },
              children: [
                { tag: "an-row", attrs: { icon: "entities", label: "工作台自绘头 · 真名 + 选择器", passive: "" } },
                { tag: "an-info-card", attrs: { title: "facet", icon: "doc" },
                  children: [ { tag: "an-row", attrs: { label: "headless 下 body 顶无内距" } } ] }
              ] },
            { label: "超长 title（head 单行省略不撑破）", tag: "an-right-island", span: true,
              attrs: { icon: "run", title: "试运行结果详情面板标题超长测试用于验证右岛头部标题在内容过长时正确截断省略而不破坏布局结构稳定" },
              children: [ { tag: "an-info-card", attrs: { title: "出参", icon: "doc", meta: "json" },
                children: [ { tag: "an-row", attrs: { label: "ok", meta: "true" } } ] } ] },
            { label: "空 body（仅 head·无卡·正文空白）", tag: "an-right-island", span: true,
              attrs: { icon: "trigger", title: "触发器 · 无 firing" } },
            { label: "全缺（无 title/icon·空 head 空 body）", tag: "an-right-island", span: true },
            { label: "海量卡堆叠（30 卡·body 滚动不显滚轮）", tag: "an-right-island", span: true,
              attrs: { icon: "history", title: "运行历史 · 30 条" },
              children: Array.from({ length: 30 }, function (_, i) {
                return { tag: "an-info-card", attrs: { title: "run #" + i, icon: "run", meta: (50 + i) + "ms" },
                  children: [ { tag: "an-row", attrs: { dot: i % 4 === 0 ? "err" : "done",
                    label: "fne_" + i.toString(16).padStart(4, "0"), meta: i % 4 === 0 ? "failed" : "ok" } } ] };
              }) }
          ]
        },
        {
          name: "标签页 tabs",
          tag: "an-tabs",
          blurb: "压力/边界态：空 items、海量 tab、超长 tab label、count 极值/注入、value 指向不存在 key",
          specimens: [
            { label: "空 items（空数组·strip 空·无 pane）", span: true, tag: "an-tabs", props: { items: [] } },
            { label: "海量 tab（40 个·横向溢出测试）", span: true, tag: "an-tabs",
              props: { items: Array.from({ length: 40 }, function (_, i) {
                return { key: "t" + i, label: "标签" + i, count: i % 3 === 0 ? i * 10 : undefined,
                  render: function (p) { p.textContent = "pane " + i; } };
              }) } },
            { label: "超长 tab label（单 tab 标签 100+ 字符 nowrap）", span: true, tag: "an-tabs",
              props: { items: [
                { key: "a", label: "这是一个非常非常长的标签页名称用来测试单个-tab-在标签文本超长时是否会正确保持-nowrap-不换行并影响下划线滑块的宽度计算与定位逻辑" },
                { key: "b", label: "短", count: 3 }
              ] } },
            { label: "极值/注入·count=0/负/超大 + label 含 HTML 串", span: true, tag: "an-tabs",
              props: { items: [
                { key: "zero", label: "零计数", count: 0 },
                { key: "neg", label: "负数", count: -5 },
                { key: "big", label: "超大", count: 9876543210 },
                { key: "inj", label: "<b>注入</b> & <script>x</script>", count: "<i>!</i>" }
              ] } },
            { label: "value 指向不存在 key（回退首项·不崩）", span: true, tag: "an-tabs",
              props: { value: "nonexistent_key", items: [
                { key: "one", label: "一" }, { key: "two", label: "二" }
              ] } }
          ]
        },
        {
          name: "动作组 action-group",
          tag: "an-action-group",
          blurb: "压力/边界态：登记 footer 变体、海量按钮溢出、超长按钮文本、空组、注入 label",
          specimens: [
            { label: "登记:footer（内容底独立动作区·上拉间距占满宽）", tag: "an-action-group", span: true,
              attrs: { footer: "", end: true },
              children: [
                { tag: "an-button", text: "取消" },
                { tag: "an-button", attrs: { variant: "primary", icon: "iterate" }, text: ":iterate" }
              ] },
            { label: "登记:footer + stack（底部纵向占满）", tag: "an-action-group", span: true,
              attrs: { footer: "", stack: true },
              children: [
                { tag: "an-button", attrs: { block: true, variant: "primary", icon: "run" }, text: "Resume flowrun" },
                { tag: "an-button", attrs: { block: true, variant: "danger", icon: "trash" }, text: "Delete failed nodes" }
              ] },
            { label: "海量按钮（24 个·间距均匀溢出测试）", tag: "an-action-group", span: true,
              attrs: { compact: true },
              children: Array.from({ length: 24 }, function (_, i) {
                return { tag: "an-button", attrs: { "data-action": "a" + i }, text: "动作" + i };
              }) },
            { label: "超长按钮文本（block + stack 不撑破）", tag: "an-action-group", span: true,
              attrs: { stack: true, block: true },
              children: [
                { tag: "an-button", attrs: { block: true, icon: "history" },
                  text: "从指定节点重放整个工作流并清除所有失败节点行让幂等解释器重新走一遍以恢复确定性执行超长按钮文本测试" }
              ] },
            { label: "空组（无子按钮·组塌成空）", tag: "an-action-group", span: true },
            { label: "注入(转义)·aria label 含 HTML 串", tag: "an-action-group", span: true,
              attrs: { end: true, label: "<script>x</script> & \"组\"" },
              children: [ { tag: "an-button", attrs: { "data-action": "ok" }, text: "确定" } ] }
          ]
        }
      ]
    },
    {
      cat: "压力·数据 Data",
      icon: "data",
      items: [
        {
          name: "瘦表 thin-table",
          tag: "an-thin-table",
          blurb: "压力态：空行表、海量 50 行（验证滚动/不撑高）、非首列超长值（验证 minmax(0,auto) 压缩截断）",
          specimens: [
            {
              label: "空（columns 有、rows=[]）",
              span: true,
              tag: "an-thin-table",
              props: {
                columns: [
                  { key: "node", label: "节点" },
                  { key: "state", label: "状态", align: "center" },
                  { key: "ms", label: "耗时", align: "right" }
                ],
                rows: []
              }
            },
            {
              label: "空（columns 也空 → 只剩表头壳）",
              span: true,
              tag: "an-thin-table",
              props: { columns: [], rows: [] }
            },
            {
              label: "超长截断（非首列超长值不撑破）",
              span: true,
              tag: "an-thin-table",
              props: {
                columns: [
                  { key: "node", label: "节点" },
                  { key: "detail", label: "明细" },
                  { key: "ms", label: "耗时", align: "right" }
                ],
                rows: [
                  {
                    node: "fetch_rows",
                    detail: "此处节点输出值故意塞超长内容以验证非首列在 minmax(0,auto) 轨道下能够压缩并以省略号截断而不会撑破整张表格的列对齐 abcdefghij 0123456789 末尾",
                    ms: "120ms"
                  },
                  {
                    node: "transform",
                    detail: "short",
                    ms: "318ms"
                  },
                  {
                    node: "post_slack_notification_handler_with_a_long_first_column_value_too_to_verify_1fr_track",
                    detail: "首列也超长但吃 minmax(0,1fr) 吸富余仍截断",
                    ms: "404ms"
                  }
                ]
              }
            },
            {
              label: "海量50行（滚动/不撑高）",
              span: true,
              tag: "an-thin-table",
              props: {
                columns: [
                  { key: "iter", label: "iteration", align: "center" },
                  { key: "node", label: "节点" },
                  { key: "kind", label: "kind" },
                  { key: "state", label: "状态", align: "center" },
                  { key: "ms", label: "耗时", align: "right" }
                ],
                rows: Array.from({ length: 50 }, (_, i) => ({
                  iter: String(i % 3),
                  node: "node_" + String(i).padStart(2, "0") + "_step",
                  kind: ["function", "handler", "agent", "control", "approval"][i % 5],
                  state: ["done", "running", "replay", "parked", "fail"][i % 5],
                  ms: (i * 37 % 900) + "ms"
                }))
              }
            },
            {
              label: "极值/注入(转义)（0/负/超大数 + <b> 转义 + emoji/CJK）",
              span: true,
              tag: "an-thin-table",
              props: {
                columns: [
                  { key: "node", label: "节点 <b>注入</b>" },
                  { key: "n", label: "值", align: "right" }
                ],
                rows: [
                  { node: "<script>alert(1)</script>", n: 0 },
                  { node: "负耗时(脏数据)", n: -42 },
                  { node: "超大计数 🚀 节点名包含 CJK 与 emoji", n: 9007199254740991 },
                  { node: "a & b < c > d \"quoted\"", n: 3.14159 }
                ]
              }
            }
          ]
        },
        {
          name: "JSON 树 json-tree",
          tag: "an-json-tree",
          blurb: "压力态：空 {}、海量/深嵌套、超长字符串值（>MAX_VAL 截断）、注入串（转义）、循环引用（props.data 自含 → [Circular]）",
          specimens: [
            {
              label: "空（{} 空对象）",
              span: true,
              tag: "an-json-tree",
              props: { data: {} }
            },
            {
              label: "空（[] 空数组）",
              span: true,
              tag: "an-json-tree",
              attrs: { label: "nodes" },
              props: { data: [] }
            },
            {
              label: "空(缺字段/null/空串值)",
              span: true,
              tag: "an-json-tree",
              props: {
                data: {
                  id: "flr_91c3e2a7",
                  cursor: null,
                  note: "",
                  tags: [],
                  meta: {}
                }
              }
            },
            {
              label: "海量(60 节点数组 · 截断/滚动)",
              span: true,
              tag: "an-json-tree",
              attrs: { label: "flowrun", "open-depth": "2" },
              props: {
                data: {
                  flowrunId: "flr_dead_beef_cafe",
                  nodes: Array.from({ length: 60 }, (_, i) => ({
                    id: "n_" + String(i).padStart(2, "0"),
                    state: ["done", "running", "replay", "parked", "fail"][i % 5],
                    ms: i * 13
                  }))
                }
              }
            },
            {
              label: "深嵌套（12 层 + open-depth=99 全展开）",
              span: true,
              tag: "an-json-tree",
              attrs: { "open-depth": "99" },
              props: {
                data: (() => {
                  let node = { leaf: "bottom 🪂", n: 42 };
                  for (let i = 12; i >= 1; i--) node = { ["level_" + i]: node };
                  return node;
                })()
              }
            },
            {
              label: "超长截断（字符串值 >MAX_VAL=500「…」）",
              span: true,
              tag: "an-json-tree",
              attrs: { label: "trace" },
              props: {
                data: {
                  traceback: "Traceback (most recent call last):\n".repeat(40) + "ValueError: this string is well over five hundred characters so the json-tree internal MAX_VAL cap must slice it and append an ellipsis to avoid a giant text node",
                  short: "ok"
                }
              }
            },
            {
              label: "注入(转义)（< > & + emoji/CJK key/value）",
              span: true,
              tag: "an-json-tree",
              props: {
                data: {
                  "<script>": "<img src=x onerror=alert(1)>",
                  "键 & 值": "a < b && c > d",
                  "状态 🚀": "已 parked",
                  "quote": "he said \"durable\" & <b>bold</b>"
                }
              }
            },
            {
              label: "循环引用(走 props.data 自含 → [Circular])",
              span: true,
              tag: "an-json-tree",
              attrs: { label: "graph" },
              props: {
                data: (() => {
                  const root = { id: "wf_cycle", name: "self-iterating", child: { kind: "control" } };
                  root.child.parent = root;
                  root.self = root;
                  return root;
                })()
              }
            },
            {
              label: "极值（数字 0/负/超大 + bool + null 各类型上色）",
              span: true,
              tag: "an-json-tree",
              props: {
                data: {
                  zero: 0,
                  negative: -273,
                  huge: 9007199254740991,
                  float: -3.141592653589793,
                  enabled: true,
                  disabled: false,
                  missing: null,
                  empty: ""
                }
              }
            },
            {
              label: "极值(非法 JSON 串 → invalid 兜底)",
              span: true,
              tag: "an-json-tree",
              attrs: { json: "{ status: parked, nodes: [,,] }" }
            }
          ]
        },
        {
          name: "实体提及药丸 ref-pill",
          tag: "an-ref-pill",
          blurb: "压力态：超长 label（max-width:--w-block + ellipsis 截断）、未登记 kind 兜底图标、注入串 label、空 label",
          specimens: [
            {
              label: "超长截断（label 截断不撑破行）",
              tag: "an-ref-pill",
              attrs: {
                kind: "function",
                id: "fn_5e1a9c4d",
                label: "normalize_and_dispatch_github_webhook_payload_to_downstream_handlers_with_retry_and_dedup_then_park_99"
              }
            },
            {
              label: "超长截断（CJK label）",
              tag: "an-ref-pill",
              attrs: {
                kind: "workflow",
                id: "wf_a04f8b12",
                label: "每夜定时同步上游订单到数据仓库并生成对账报表再推送到飞书群与邮件通知值班同学的超长工作流名称用于验证截断行为"
              }
            },
            {
              label: "注入(转义)（label 含 < > &）",
              tag: "an-ref-pill",
              attrs: {
                kind: "handler",
                id: "hd_2f7b1a30",
                label: "<script>alert('xss')</script> & <b>x</b>"
              }
            },
            {
              label: "极值(未登记 kind → kind 当 icon key 兜底)",
              tag: "an-ref-pill",
              attrs: {
                kind: "search",
                id: "doc_0a1b2c3d",
                label: "纯提及（doc/search 等非实体 kind）"
              }
            },
            {
              label: "极值(非法 kind → 图标缺失兜底)",
              tag: "an-ref-pill",
              attrs: {
                kind: "not_a_real_kind_zzz",
                id: "x_123",
                label: "非法 kind 仍渲染文案"
              }
            },
            {
              label: "空（空 label + 空 id · 不可点）",
              tag: "an-ref-pill",
              attrs: { kind: "agent" }
            },
            {
              label: "极值(emoji label)",
              tag: "an-ref-pill",
              attrs: { kind: "skill", id: "skill_pdf", label: "pdf 🪂 解析 · CJK 混排" }
            }
          ]
        },
        {
          name: "标签集 tags",
          tag: "an-tags",
          blurb: "压力态：超长单标签（max-width:--w-block 截断）、海量 40 标签（flex-wrap 多行）、注入/emoji 标签、空集",
          specimens: [
            {
              label: "空（— 无 — + add 入口）",
              tag: "an-tags",
              props: { items: [] }
            },
            {
              label: "超长截断（单标签截断不撑破）",
              tag: "an-tags",
              props: {
                items: [
                  "durable",
                  "this_is_an_absurdly_long_tag_name_that_should_truncate_with_ellipsis_inside_the_pill_not_overflow_the_row_123456",
                  "ok"
                ]
              }
            },
            {
              label: "海量(40 标签 · flex-wrap 多行)",
              span: true,
              tag: "an-tags",
              props: {
                items: Array.from({ length: 40 }, (_, i) =>
                  i % 7 === 0 ? { label: "tag_" + i, health: i % 14 === 0 ? "ok" : "bad" } : "tag_" + i
                )
              }
            },
            {
              label: "注入(转义)（< > & + emoji/CJK）",
              tag: "an-tags",
              props: {
                items: [
                  "<script>alert(1)</script>",
                  "a & b < c",
                  "🚀 emoji",
                  "中文标签",
                  { label: "<b>health ok</b>", health: "ok" }
                ]
              }
            },
            {
              label: "极值(非法 health → idle 兜底点)",
              tag: "an-tags",
              props: {
                items: [
                  { label: "github", health: "ok" },
                  { label: "postgres", health: "DOWN" },
                  { label: "redis", health: "" }
                ]
              }
            },
            {
              label: "极值(脏数据 null/缺 label → 空 pill)",
              tag: "an-tags",
              props: {
                items: [
                  "normal",
                  { health: "ok" },
                  {},
                  ""
                ]
              }
            }
          ]
        },
        {
          name: "节点图例 kind-legend",
          tag: "an-kind-legend",
          blurb: "5 类图节点只读色图例（自 AnGraph 取数·零属性）；登记缺口：divided（脚位变体 · 顶分隔线 + 留白）",
          specimens: [
            {
              label: "default（自 AnGraph.KIND_ORDER 取 5 类）",
              span: true,
              tag: "an-kind-legend"
            },
            {
              label: "登记:divided（脚位 · 顶分隔线 + padding）",
              span: true,
              tag: "an-kind-legend",
              attrs: { divided: true }
            }
          ]
        },
        {
          name: "侧栏列表 sidebar-list",
          tag: "an-sidebar-list",
          blurb: "压力态：空 model（无 groups → 只剩 New/过滤头）、海量行（单类型 50 行 · 验证滚动）、超长 label 行、注入串行",
          specimens: [
            {
              label: "空（model undefined → New + 过滤头壳）",
              span: true,
              tag: "an-sidebar-list"
            },
            {
              label: "空（groups=[] · 仅 New/filter 头）",
              span: true,
              tag: "an-sidebar-list",
              props: {
                model: {
                  newLabel: "New workflow",
                  filterPlaceholder: "搜索工作流…",
                  groups: []
                }
              }
            },
            {
              label: "海量50行（单 headless 类型 · 滚动）",
              span: true,
              tag: "an-sidebar-list",
              props: {
                model: {
                  newLabel: "New",
                  filterPlaceholder: "filter…",
                  groups: [
                    {
                      types: [
                        {
                          rows: Array.from({ length: 50 }, (_, i) => ({
                            id: "wf_" + String(i).padStart(3, "0"),
                            label: "workflow_" + String(i).padStart(2, "0"),
                            dot: ["done", "running", "err", "idle", "warn"][i % 5],
                            meta: (i * 7 % 90) + "r"
                          }))
                        }
                      ]
                    }
                  ]
                }
              }
            },
            {
              label: "超长截断（label/meta/标题超长不撑破）",
              span: true,
              tag: "an-sidebar-list",
              props: {
                model: {
                  newLabel: "新建一个名字非常非常长的实体用于验证 New 行 label 的省略号截断行为不会撑破侧栏宽度",
                  filterPlaceholder: "在此输入一段超长占位提示文字以验证 input placeholder 在窄侧栏内的表现",
                  groups: [
                    {
                      label: "分组标题也写得相当长用于验证大组头在折叠计数与 chevron 之间的截断",
                      types: [
                        {
                          icon: "workflow",
                          label: "Workflows 类型头标题很长很长很长",
                          count: 3,
                          open: true,
                          rows: [
                            {
                              id: "wf_long",
                              icon: "workflow",
                              label: "nightly_sync_orders_to_warehouse_and_generate_reconciliation_report_then_notify_99",
                              meta: "1234567890r"
                            },
                            { id: "wf_short", icon: "workflow", label: "短名", meta: "2r" }
                          ]
                        }
                      ]
                    }
                  ]
                }
              }
            },
            {
              label: "注入(转义)（< > & + emoji/CJK 行）",
              span: true,
              tag: "an-sidebar-list",
              props: {
                model: {
                  newLabel: "New <b>x</b>",
                  filterPlaceholder: "a & b < c",
                  groups: [
                    {
                      types: [
                        {
                          icon: "agent",
                          label: "Agents <script>",
                          open: true,
                          rows: [
                            { id: "ag_1", dot: "running", label: "<script>alert(1)</script>", meta: "<b>3</b>" },
                            { id: "ag_2", dot: "done", label: "🚀 中文 agent & 符号", meta: "0r" }
                          ]
                        }
                      ]
                    }
                  ]
                }
              }
            },
            {
              label: "海量/深嵌套（children 递归 4 层树）",
              span: true,
              tag: "an-sidebar-list",
              props: {
                model: {
                  newLabel: "New doc",
                  filterPlaceholder: "filter docs…",
                  groups: [
                    {
                      types: [
                        {
                          rows: [
                            {
                              id: "d_root",
                              icon: "folder",
                              label: "root",
                              open: true,
                              children: [
                                {
                                  id: "d_a",
                                  icon: "folder",
                                  label: "level-1",
                                  open: true,
                                  children: [
                                    {
                                      id: "d_b",
                                      icon: "folder",
                                      label: "level-2",
                                      open: true,
                                      children: [
                                        { id: "d_c", icon: "doc", label: "level-3-leaf.md", meta: "v4" }
                                      ]
                                    }
                                  ]
                                }
                              ]
                            }
                          ]
                        }
                      ]
                    }
                  ]
                }
              }
            }
          ]
        },
        {
          name: "警示条 callout",
          tag: "an-callout",
          blurb: "压力态：各 tone（warn/danger/info/ok）、非法 tone（归一回 warn）、超长富文本体（换行图标顶对齐不撑破）、注入/emoji",
          specimens: [
            {
              label: "tone=warn（默认 · 含 <b>）",
              span: true,
              tag: "an-callout",
              html: "此 workflow 含 <b>dangerous</b> 工具调用，replay 时将逐次内存阻塞确认。"
            },
            {
              label: "tone=danger",
              span: true,
              tag: "an-callout",
              attrs: { tone: "danger" },
              html: "flowrun <b>fnr_4a8c…</b> 在 node <b>fetch_orders</b> 处崩溃；游标已 parked，可从断点 replay。"
            },
            {
              label: "tone=info",
              span: true,
              tag: "an-callout",
              attrs: { tone: "info" },
              html: "节点结果已记忆化（<b>record-once</b>）：解释器幂等重走只补未完成节点。"
            },
            {
              label: "tone=ok",
              span: true,
              tag: "an-callout",
              attrs: { tone: "ok" },
              html: "全部节点 <b>done</b>，flowrun 已确定性完成，842ms。"
            },
            {
              label: "极值(非法 tone zzz → 归一回 warn 不裸条)",
              span: true,
              tag: "an-callout",
              attrs: { tone: "zzz_not_a_tone" },
              html: "非法 tone 被组件归一回写成 warn，CSS 命中软底描边而非裸条。"
            },
            {
              label: "超长截断（换行 · 图标顶对齐不撑破）",
              span: true,
              tag: "an-callout",
              attrs: { tone: "danger" },
              html: "此 workflow 含多个标注为 <b>dangerous</b> 的工具调用，replay 时解释器会对每一次危险调用逐次内存阻塞确认；这段文案故意写得很长以验证 callout 富文本体在换行时仍保持左图标顶对齐、不撑破容器、行高遵循 lh-prose 排版规则 0123456789 abcdefghij"
            },
            {
              label: "注入(转义 · 纯文本经 text 不解析)",
              span: true,
              tag: "an-callout",
              attrs: { tone: "warn" },
              text: "<script>alert('xss')</script> 应作为纯文本展示 · a & b < c > d · 🚀 中文混排"
            },
            {
              label: "icon 覆盖默认（tone=info + 自定 icon）",
              span: true,
              tag: "an-callout",
              attrs: { tone: "info", icon: "trigger" },
              html: "webhook 触发已去重（<b>idx_trf_dedup</b>），同一 firing 不重复展开。"
            },
            {
              label: "空（slot 无内容 → 仅图标条）",
              span: true,
              tag: "an-callout",
              attrs: { tone: "warn" }
            }
          ]
        }
      ]
    },
    {
      cat: "压力·执行 Exec",
      icon: "run",
      items: [
        {
          name: "block-tree an-block-tree",
          tag: "an-block-tree",
          blurb: "压力/边界态：空块流、海量 todo、超长/注入文本、未知块型",
          specimens: [
            { label: "空（blocks=[]）", tag: "an-block-tree", span: 2, props: { blocks: [] } },
            { label: "空 todo（items=[] 显空态行）", tag: "an-block-tree", span: 2, props: { blocks: [ { type: "todo", open: true, items: [] } ] } },
            { label: "海量 todo（50 项 · 验滚动/截断）", tag: "an-block-tree", span: 2, props: { blocks: [ { type: "todo", open: true, items: Array.from({ length: 50 }, (_, i) => ({ content: "任务 #" + (i + 1) + " — 处理批次数据并校验幂等 record-once 落盘", status: i < 24 ? "completed" : (i === 24 ? "in_progress" : "pending"), activeForm: i === 24 ? "正在处理批次数据…" : undefined })) } ] } },
            { label: "超长文本块（120+ 字符 · 验通栏换行不撑破）", tag: "an-block-tree", span: 2, props: { blocks: [ { type: "text", text: "这是一段非常非常长的助手正文用于验证超长文本在通栏块内的换行行为：当文本持续延伸超过一百二十个字符且不含任何手动断点时仍应优雅折行而绝不撑破容器边界abcdefghijklmnopqrstuvwxyz0123456789" }, { type: "text", role: "user", text: "超长无空格串验证 overflow-wrap:anywhere → https://example.com/very/long/path/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa?token=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" } ] } },
            { label: "注入文本块（含 <b>/<script> · 验转义）", tag: "an-block-tree", span: 2, props: { blocks: [ { type: "text", text: "注入探针 <script>alert('xss')</script> 与 <img src=x onerror=alert(1)> 以及 & < > 实体应原样转义显示，**加粗** 与 `行内码` 仍按白名单 md 放行" }, { type: "reasoning", open: true, label: "推理（注入）", text: "思考块内 <b>不应</b> 解析 HTML：<iframe src=javascript:alert(2)></iframe> & raw <>" } ] } },
            { label: "注入到 tool_call（name/args/result 全转义）", tag: "an-block-tree", span: 2, props: { blocks: [ { type: "tool_call", open: true, summary: "危险注入 <script>", items: [ { verb: "run_function", name: "<svg/onload=alert(3)>", danger: "dangerous", args: { payload: "<script>alert('args')</script>", note: "a & b < c > d" }, result: { data: { stdout: "<img src=x onerror=alert(4)>", ok: false } } } ] } ] } },
            { label: "未知块型（协议开放 · 不静默吞）", tag: "an-block-tree", span: 2, props: { blocks: [ { type: "telemetry_burst", foo: 1 }, { type: null }, { type: "<script>evil</script>" }, { text: "缺 type 字段的块" } ] } },
            { label: "极值/混排（emoji/CJK · turnEnd 非法 stopReason 兜底）", tag: "an-block-tree", span: 2, props: { blocks: [ { type: "text", text: "emoji + CJK 混排：🚀🔥✅ 中文长句标点，；。！？ — éàü 𝕌𝕟𝕚𝕔𝕠𝕕𝕖 𠮷野家" }, { type: "todo", open: true, items: [ { content: "🔥 emoji 任务", status: "completed" }, { content: "进行中 🚀", status: "in_progress" } ] }, { type: "turnEnd", stopReason: "__nonexistent_reason__" } ] } },
            { label: "海量混合块流（45 块 · 验流滚动）", tag: "an-block-tree", span: 2, props: { blocks: Array.from({ length: 45 }, (_, i) => i % 3 === 0 ? { type: "text", text: "第 " + (i + 1) + " 块：助手正文段落，验证长块流的纵向节奏与滚动。" } : i % 3 === 1 ? { type: "text", role: "user", text: "用户第 " + (i + 1) + " 条提问气泡" } : { type: "tool_call", summary: "工具组 #" + (i + 1), items: [ { verb: "search", name: "q" + i, result: { list: [ { title: "命中 " + i, meta: "score 0." + i, hint: "摘要片段" } ] } } ] }) } }
          ]
        },
        {
          name: "run-board an-run-board",
          tag: "an-run-board",
          blurb: "压力态：零运行空态、海量运行列表",
          specimens: [
            { label: "空（runs=[] → 内嵌空态）", tag: "an-run-board", span: 2, props: { runs: [] } },
            { label: "单运行（基线 · 含甘特）", tag: "an-run-board", span: 2, props: { runs: [ { id: "flr_a1b2c3d4e5f60718", status: "completed", when: "2 分钟前", trigger: "webhook", gantt: [ { id: "n1", kind: "function", label: "fetch", status: "done", atPct: 0, wPct: 30 }, { id: "n2", kind: "agent", label: "triage", status: "done", atPct: 30, wPct: 50 } ] } ] } },
            { label: "超长 run id / trigger（验 mono 行截断）", tag: "an-run-board", span: 2, props: { runs: [ { id: "flr_超长运行标识符0123456789abcdef0123456789abcdef0123456789abcdefABCDEF", status: "failed", when: "刚刚", trigger: "超长触发源名称-cron-every-fifteen-minutes-with-a-very-verbose-descriptive-suffix", replay: 7 } ] } },
            { label: "海量运行（48 次 · 验左列滚动）", tag: "an-run-board", span: 2, props: { runs: Array.from({ length: 48 }, (_, i) => ({ id: "flr_" + String(i).padStart(16, "0"), status: ["running", "completed", "failed", "parked", "cancelled"][i % 5], when: i + " 分钟前", trigger: ["webhook", "cron", "manual", "event"][i % 4], replay: i % 6 === 0 ? (i % 6) + 1 : undefined, selected: i === 0, gantt: [ { id: "g" + i, kind: "action", label: "node " + i, status: "done", atPct: 0, wPct: 40 + (i % 30) } ] })) } },
            { label: "非法 status 枚举（DOT 兜底 idle）", tag: "an-run-board", span: 2, props: { runs: [ { id: "flr_badstatus000000", status: "__invalid__", when: "未知", trigger: "manual" }, { id: "flr_nullstatus00000", when: "—" } ] } }
          ]
        },
        {
          name: "node-gantt an-node-gantt",
          tag: "an-node-gantt",
          blurb: "压力态：海量节点、越界 atPct、零节点",
          specimens: [
            { label: "空（nodes=[] · 验空白不崩）", tag: "an-node-gantt", span: 2, props: { nodes: [] } },
            { label: "基线（done/err/parked/future/×N 多态）", tag: "an-node-gantt", span: 2, props: { nodes: [ { id: "n1", kind: "function", label: "fetch", status: "done", atPct: 0, wPct: 25 }, { id: "n2", kind: "agent", label: "loop", status: "done", iters: [ { atPct: 25, wPct: 10 }, { atPct: 36, wPct: 10 }, { atPct: 48, wPct: 12 } ] }, { id: "n3", kind: "handler", label: "approve", parked: true, atPct: 62, wPct: 5 }, { id: "n4", kind: "workflow", label: "failed-step", status: "failed", atPct: 70, wPct: 18 }, { id: "n5", kind: "action", label: "not-yet", status: "future", atPct: 0, wPct: 0 } ] } },
            { label: "越界极值（atPct>100/负/超大 wPct · 验 pct 钳 [0,100]）", tag: "an-node-gantt", span: 2, props: { nodes: [ { id: "x1", kind: "action", label: "atPct=250 越界", status: "done", atPct: 250, wPct: 40 }, { id: "x2", kind: "action", label: "atPct=-50 负", status: "done", atPct: -50, wPct: 30 }, { id: "x3", kind: "action", label: "wPct=9999 超大", status: "failed", atPct: 10, wPct: 9999 }, { id: "x4", kind: "action", label: "全 0", status: "done", atPct: 0, wPct: 0 }, { id: "x5", kind: "action", label: "NaN 脏值", status: "done", atPct: "abc", wPct: "xyz" } ] } },
            { label: "海量节点（45 行 · 验封顶自滚）", tag: "an-node-gantt", span: 2, props: { nodes: Array.from({ length: 45 }, (_, i) => ({ id: "node_" + i, kind: ["function", "agent", "handler", "workflow", "action"][i % 5], label: "node-" + i + " 长标签验证省略号截断处理逻辑abcdefgh", status: ["done", "failed", "future"][i % 3], atPct: (i * 2) % 100, wPct: 8 + (i % 20), iters: i % 7 === 0 ? [ { atPct: (i * 2) % 100, wPct: 5 }, { atPct: ((i * 2) % 100) + 6, wPct: 5 } ] : undefined })) } },
            { label: "注入 label/id（验转义）+ 非法 kind/status 兜底", tag: "an-node-gantt", span: 2, props: { nodes: [ { id: "<script>alert(1)</script>", kind: "__bad_kind__", label: "<img src=x onerror=alert(2)> & <b>raw</b>", status: "__bad_status__", atPct: 10, wPct: 40 } ] } }
          ]
        },
        {
          name: "skeleton an-skeleton",
          tag: "an-skeleton",
          blurb: "压力态：count 海量验 clamp（封顶 60）",
          specimens: [
            { label: "基线 row（count=3）", tag: "an-skeleton", attrs: { variant: "row", count: "3" }, span: 2 },
            { label: "海量 count=999（验 clamp 至 60）", tag: "an-skeleton", attrs: { variant: "row", count: "999" }, span: 2 },
            { label: "海量 text count=200（验 clamp）", tag: "an-skeleton", attrs: { variant: "text", count: "200" }, span: 2 },
            { label: "海量 lines count=120（验 clamp）", tag: "an-skeleton", attrs: { variant: "lines", count: "120" }, span: 2 },
            { label: "海量 card count=80（验 clamp）", tag: "an-skeleton", attrs: { variant: "card", count: "80" }, span: 2 },
            { label: "极值 count=0（验 0 条不崩）", tag: "an-skeleton", attrs: { variant: "row", count: "0" }, span: 2 },
            { label: "极值 count=-5 负（num 兜底）", tag: "an-skeleton", attrs: { variant: "text", count: "-5" }, span: 2 },
            { label: "非法 variant（兜底 row）", tag: "an-skeleton", attrs: { variant: "__nope__", count: "2" }, span: 2 }
          ]
        },
        {
          name: "state an-state",
          tag: "an-state",
          blurb: "压力态：empty/loading/error 三态 + 边界文案",
          specimens: [
            { label: "empty（缺省图标 inbox）", tag: "an-state", attrs: { variant: "empty", title: "尚无数据", hint: "创建第一个实体后这里会列出" }, span: 2, center: true },
            { label: "loading（spin + shimmer 井）", tag: "an-state", attrs: { variant: "loading", title: "加载中", hint: "正在拉取运行记录…" }, span: 2, center: true },
            { label: "error（danger 调性）", tag: "an-state", attrs: { variant: "error", title: "加载失败", hint: "网络错误，请重试" }, span: 2, center: true },
            { label: "空（无 title/无 hint · 验 copy 塌掉）", tag: "an-state", attrs: { variant: "empty" }, span: 2, center: true },
            { label: "超长 title/hint（验居中换行不撑破）", tag: "an-state", attrs: { variant: "empty", title: "这是一个非常非常长的空态标题用于验证标题在受限宽度下的居中换行行为是否优雅", hint: "这是一段同样很长的说明文字用于验证 hint 在 max-width:w-block 约束下的多行换行节奏与可读性当文案超过两行时仍应保持居中对齐与舒适行距abcdefghij" }, span: 2, center: true },
            { label: "注入 title/hint（含 <script> · 验转义）", tag: "an-state", attrs: { variant: "error", title: "错误 <script>alert(1)</script>", hint: "详情 <img src=x onerror=alert(2)> & raw <b>not bold</b>" }, span: 2, center: true },
            { label: "非法 variant（兜底 empty + inbox 图标）", tag: "an-state", attrs: { variant: "__weird__", title: "未知 variant", hint: "应兜底为 empty 中性态" }, span: 2, center: true },
            { label: "emoji/CJK 文案", tag: "an-state", attrs: { variant: "empty", icon: "rocket", title: "🚀 空空如也", hint: "✅ 中文文案 éàü 🔥 混排" }, span: 2, center: true }
          ]
        },
        {
          name: "version-diff an-version-diff",
          tag: "an-version-diff",
          blurb: "压力态：超长行、海量增删、注入、最早版本",
          specimens: [
            { label: "基线 diff（+N/−N 计数）", tag: "an-version-diff", span: 2, attrs: { lang: "js", range: "v3 → v4", note: "重构 fetch 逻辑" }, props: { before: "function fetch(url) {\n  return get(url);\n}", after: "async function fetch(url, opts) {\n  const r = await get(url, opts);\n  return r.json();\n}" } },
            { label: "最早版本（before 空 → 整段 ctx 不染增删）", tag: "an-version-diff", span: 2, attrs: { lang: "js", range: "v1（初版）" }, props: { before: "", after: "const x = 1;\nconst y = 2;\nconsole.log(x + y);" } },
            { label: "超长行（200+ 字符无断点 · 验横向滚动）", tag: "an-version-diff", span: 2, attrs: { lang: "js", range: "v4 → v5", note: "超长行测试" }, props: { before: "const cfg = { a: 1 };", after: "const cfg = { a: 1, b: 2, c: 3, longKey: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' };" } },
            { label: "海量增删（60 行全替换 · 验主体滚动）", tag: "an-version-diff", span: 2, attrs: { lang: "js", range: "v5 → v6", note: "大改" }, props: { before: Array.from({ length: 30 }, (_, i) => "const old_" + i + " = " + i + ";").join("\n"), after: Array.from({ length: 30 }, (_, i) => "const new_" + i + " = " + (i * 2) + ";").join("\n") } },
            { label: "注入行（含 <script>/HTML 实体 · 验转义高亮）", tag: "an-version-diff", span: 2, attrs: { lang: "html", range: "v6 → v7" }, props: { before: "<div>a & b</div>\n<span>old</span>", after: "<div>a & b < c > d</div>\n<script>alert('xss')</script>\n<img src=x onerror=alert(1)>" } },
            { label: "emoji/CJK diff", tag: "an-version-diff", span: 2, attrs: { range: "v7 → v8", note: "国际化" }, props: { before: "label = '提交'\nicon = '✅'", after: "label = '提交 🚀'\nicon = '🔥'\nhint = 'éàü 中文注释'" } },
            { label: "无变更（before===after · 全 ctx 无 +/−）", tag: "an-version-diff", span: 2, attrs: { lang: "js", range: "v8（无改动）" }, props: { before: "const same = true;", after: "const same = true;" } },
            { label: "bare 内联（隐顶栏）", tag: "an-version-diff", span: 2, attrs: { lang: "js", bare: true }, props: { before: "let n = 1;", after: "let n = 2;\nlet m = 3;" } }
          ]
        }
      ]
    }
  );
})();
