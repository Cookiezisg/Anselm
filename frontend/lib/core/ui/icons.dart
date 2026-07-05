import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Semantic icon registry — the ONE place a domain meaning binds to a concrete glyph. Mirrors the
/// demo's `core/icons.js` (ALIAS) + `config/entity-kinds.js`: features/widgets reference a semantic
/// name, never a raw Lucide identifier, so re-skinning an icon is a one-line edit here. The glyph
/// set is Lucide; we render the THIN weight family ([_family]) — the package ships static per-weight
/// faces (Lucide100–600) that SHARE codepoints, so re-pointing the family to a lighter stroke (≈ the
/// demo's stroke-width 1.7, vs the heavier default ~2) is a one-token change. [byKey]/[toolIcon]/
/// [node] resolve data-driven strings and fall back to [fallback] so an unknown key degrades to a
/// visible "?" instead of crashing.
///
/// 语义图标单源——领域含义 → 字形的唯一绑定处(镜像 icons.js + entity-kinds.js)。字形集=Lucide,渲染 THIN
/// 字重族(_family):包内各字重是共享码点的独立字体,改一处 _family 即换更细的笔画(≈demo 1.7,默认偏粗 ~2)。
abstract final class AnIcons {
  // Lighter Lucide weight face — codepoints are shared with the default 'Lucide', so we keep the
  // same glyph, thinner stroke. Lucide300 ≈ demo stroke 1.7. 更细字重族,码点共享、笔画更细。
  static const String _family = 'Lucide300';
  static const String _pkg = 'lucide_icons_flutter';
  static IconData _thin(IconData base) => IconData(base.codePoint, fontFamily: _family, fontPackage: _pkg);

  // ── chrome ──
  static final IconData chevronRight = _thin(LucideIcons.chevronRight);
  static final IconData chevronDown = _thin(LucideIcons.chevronDown);
  static final IconData more = _thin(LucideIcons.ellipsis);
  static final IconData grip = _thin(LucideIcons.gripVertical);
  static final IconData close = _thin(LucideIcons.x);
  static final IconData sliders = _thin(LucideIcons.slidersHorizontal);
  static final IconData wrap = _thin(LucideIcons.wrapText);
  static final IconData copy = _thin(LucideIcons.copy); // code-block / value copy-to-clipboard 复制
  static final IconData expand = _thin(LucideIcons.maximize2);
  static final IconData plus = _thin(LucideIcons.plus); // New / add (sidebar New row, row-add) 新建/添加
  static final IconData zoomIn = _thin(LucideIcons.zoomIn); // graph canvas zoom 图画布放大
  static final IconData zoomOut = _thin(LucideIcons.zoomOut); // graph canvas zoom 图画布缩小
  static final IconData search = _thin(LucideIcons.search);
  static final IconData check = _thin(LucideIcons.check);
  static final IconData panelLeft = _thin(LucideIcons.panelLeft); // collapse/reopen the left island 左岛收起/展开
  static final IconData panelRight = _thin(LucideIcons.panelRight); // toggle the right island 右岛切换

  // ── entities / graph nodes / mounts ──
  static final IconData function = _thin(LucideIcons.squareFunction);
  static final IconData handler = _thin(LucideIcons.box);
  static final IconData agent = _thin(LucideIcons.bot);
  static final IconData workflow = _thin(LucideIcons.workflow);
  static final IconData trigger = _thin(LucideIcons.zap);
  static final IconData control = _thin(LucideIcons.gitBranch);
  static final IconData action = _thin(LucideIcons.play);
  static final IconData approval = _thin(LucideIcons.shieldCheck);
  static final IconData mcp = _thin(LucideIcons.plug);
  static final IconData skill = _thin(LucideIcons.bookOpen);
  static final IconData doc = _thin(LucideIcons.fileText);
  static final IconData entities = _thin(LucideIcons.layoutGrid);
  static final IconData chat = _thin(LucideIcons.messageSquare);
  static final IconData scheduler = _thin(LucideIcons.clock);
  static final IconData gear = _thin(LucideIcons.settings);
  static final IconData bell = _thin(LucideIcons.bell); // notifications 通知
  static final IconData pin = _thin(LucideIcons.pin); // pinned conversations 置顶对话
  static final IconData archive = _thin(LucideIcons.archive); // archive a conversation 归档对话

  // ── block / conversation semantics ──
  static final IconData reasoning = _thin(LucideIcons.brain);
  static final IconData tool = _thin(LucideIcons.wrench);
  static final IconData subagent = _thin(LucideIcons.gitFork);
  static final IconData turnEnd = _thin(LucideIcons.flag);
  static final IconData terminal = _thin(LucideIcons.squareTerminal);

  // ── tool-call verb glyphs (the collapsed-row identity per tool family, WRK-053 §3) ──
  // 工具卡收起行族字形:builds/get 用实体形、lifecycle 用动作形、run-logs 用 history、humanloop/memory/mcp 专属。
  static final IconData folder = _thin(LucideIcons.folder); // LS / directory listing 目录
  static final IconData refresh = _thin(LucideIcons.refreshCw); // restart_handler / reconnect_mcp 重启/重连
  static final IconData move = _thin(LucideIcons.move); // move_document 移动
  static final IconData download = _thin(LucideIcons.download); // WebFetch / install_mcp_server 抓取/安装
  static final IconData layers = _thin(LucideIcons.layers); // stage_workflow 暂存版本
  static final IconData pause = _thin(LucideIcons.circlePause); // deactivate_workflow 停用
  static final IconData ban = _thin(LucideIcons.ban); // kill_workflow / KillShell 强杀
  static final IconData store = _thin(LucideIcons.store); // list_mcp_marketplace 市场
  static final IconData unplug = _thin(LucideIcons.unplug); // uninstall_mcp_server 卸载
  static final IconData model = _thin(LucideIcons.cpu); // get_model_config 模型配置
  static final IconData capability = _thin(LucideIcons.badgeCheck); // capability_check_workflow 能力体检
  static final IconData relations = _thin(LucideIcons.share2); // get_relations 依赖关系
  static final IconData memory = _thin(LucideIcons.bookMarked); // write/read_memory 记忆
  static final IconData ask = _thin(LucideIcons.messageCircleQuestion); // ask_user 提问
  static final IconData gavel = _thin(LucideIcons.gavel); // decide_approval 裁决
  static final IconData inbox = _thin(LucideIcons.inbox); // list_approval_inbox 审批收件箱

  // ── editor / slash block menu (AnDocEditor `/`) 编辑器斜杠块菜单 ──
  static final IconData paragraph = _thin(LucideIcons.type); // Text block 段落
  static final IconData heading1 = _thin(LucideIcons.heading1);
  static final IconData heading2 = _thin(LucideIcons.heading2);
  static final IconData heading3 = _thin(LucideIcons.heading3);
  static final IconData listBulleted = _thin(LucideIcons.list);
  static final IconData listNumbered = _thin(LucideIcons.listOrdered);
  static final IconData quote = _thin(LucideIcons.textQuote);
  static final IconData codeBlock = _thin(LucideIcons.code); // fenced code block 代码块
  static final IconData divider = _thin(LucideIcons.minus); // horizontal rule 分隔线
  static final IconData todo = _thin(LucideIcons.listTodo); // task checkbox block 待办

  // ── composer (chat input) ──
  static final IconData mention = _thin(LucideIcons.atSign); // @ mention trigger @提及
  static final IconData attach = _thin(LucideIcons.paperclip); // 📎 attach a file 附件
  static final IconData send = _thin(LucideIcons.arrowUp); // ↑ send the message (stop reuses `stop`) 发送

  // ── execution verbs / actions ──
  static final IconData run = _thin(LucideIcons.play);
  static final IconData enter = _thin(LucideIcons.cornerDownLeft);
  static final IconData stop = _thin(LucideIcons.square);
  static final IconData spin = _thin(LucideIcons.loaderCircle);
  static final IconData forge = _thin(LucideIcons.hammer);
  static final IconData edit = _thin(LucideIcons.squarePen);
  static final IconData trash = _thin(LucideIcons.trash2);
  static final IconData web = _thin(LucideIcons.globe);
  static final IconData iterate = _thin(LucideIcons.sparkles); // AI edit (≠ forge: rebuild env) AI 编辑
  static final IconData history = _thin(LucideIcons.history);
  static final IconData diff = _thin(LucideIcons.gitCompare);

  // ── state placeholders ──
  static final IconData empty = _thin(LucideIcons.inbox);
  static final IconData error = _thin(LucideIcons.triangleAlert);
  static final IconData image = _thin(LucideIcons.image); // markdown image placeholder chip 图片占位
  static final IconData taskOpen = _thin(LucideIcons.square); // md task list, unchecked 任务未勾
  static final IconData taskDone = _thin(LucideIcons.squareCheck); // md task list, checked 任务已勾

  // ── attachments (backend kind wire: image|document|text|audio|video|other) 附件(后端 kind 线缆) ──
  static final IconData audio = _thin(LucideIcons.music);
  static final IconData video = _thin(LucideIcons.film);
  static final IconData file = _thin(LucideIcons.file); // kind=other 通用文件
  static final IconData fileCode = _thin(LucideIcons.fileCode); // kind=text(代码/纯文本)
  static final IconData fileMissing = _thin(LucideIcons.fileX); // tombstone: deleted/404 墓碑

  // ── feedback severities (callout / state) ──
  static final IconData info = _thin(LucideIcons.info);
  static final IconData success = _thin(LucideIcons.circleCheck);
  static final IconData warning = _thin(LucideIcons.triangleAlert);
  static final IconData danger = _thin(LucideIcons.octagonAlert);

  /// Unknown-key sink — a visible "?" so a missing binding is obvious, never a crash.
  /// 未知键兜底——可见的"?",缺绑定一眼可见、绝不崩。
  static final IconData fallback = _thin(LucideIcons.circleQuestionMark);

  /// Semantic key → glyph, for data-driven resolution (a backend node kind, a derived tool icon).
  /// Prefer the named fields above at call sites; this map is for strings only.
  /// 语义键 → 字形,供数据驱动解析。调用处优先用上面的具名字段。
  static final Map<String, IconData> _byKey = {
    'chevr': chevronRight, 'chevd': chevronDown, 'more': more, 'grip': grip,
    'close': close, 'sliders': sliders, 'wrap': wrap, 'expand': expand, 'search': search, 'check': check,
    'function': function, 'handler': handler, 'agent': agent, 'workflow': workflow,
    'trigger': trigger, 'control': control, 'action': action, 'approval': approval,
    'mcp': mcp, 'skill': skill, 'doc': doc, 'document': doc, 'entities': entities, // 'document' = backend EntityKind wire 后端实体 kind 线缆值
    'chat': chat, 'conversation': chat, 'scheduler': scheduler, 'gear': gear,
    'reasoning': reasoning, 'tool': tool, 'subagent': subagent, 'turnend': turnEnd, 'terminal': terminal,
    // editor slash block menu 斜杠块菜单
    'paragraph': paragraph, 'heading1': heading1, 'heading2': heading2, 'heading3': heading3,
    'listBulleted': listBulleted, 'listNumbered': listNumbered, 'quote': quote,
    'codeBlock': codeBlock, 'divider': divider, 'todo': todo,
    'run': run, 'enter': enter, 'stop': stop, 'spin': spin, 'forge': forge,
    'edit': edit, 'trash': trash, 'web': web, 'iterate': iterate, 'history': history, 'diff': diff,
    'empty': empty, 'error': error,
  };

  /// Resolve a semantic key string to a glyph (unknown → [fallback]). 语义键字串 → 字形。
  static IconData byKey(String key) => _byKey[key] ?? fallback;

  /// Exact tool-name → glyph, keyed lowercase. Covers every IRREGULAR tool (whose glyph isn't
  /// derivable from a create/edit/get/delete/revert × entity pattern) — the regular entity-CRUD
  /// families are resolved by rule in [toolIcon]. Real backend tool names (WRK-057 census §6),
  /// not the old demo aliases. 精确表:钉死一切不规则工具;规整 entity-CRUD 由 [toolIcon] 规则解析。
  static final Map<String, IconData> _toolExact = {
    // F1 fs-ops:读=文档 / 写=笔 / 改=diff(编辑即呈现变化)
    'read': doc, 'write': edit, 'edit': diff,
    // F2 fs-search:pattern 检索=search / LS=目录
    'glob': search, 'grep': search, 'ls': folder,
    // F3 shell:终端 / 后台输出=终端 / 杀=禁
    'bash': terminal, 'bashoutput': terminal, 'killshell': ban,
    // F8 exec:执行动词(标的实体形,replay=history)
    'run_function': run, 'call_handler': handler, 'invoke_agent': agent,
    'trigger_workflow': workflow, 'fire_trigger': trigger, 'replay_flowrun': history,
    // workflow 生命周期:暂存=层 / 激活=运行 / 停用=暂停 / 杀=禁 / 能力体检=徽
    'stage_workflow': layers, 'activate_workflow': run, 'deactivate_workflow': pause,
    'kill_workflow': ban, 'capability_check_workflow': capability,
    // lifecycle 杂项:重启=刷新 / 激活技能=运行 / 移动文档=移动
    'restart_handler': refresh, 'activate_skill': run, 'move_document': move,
    // F6 内容读取:文档=文档形 / 附件=文件形
    'read_document': doc, 'read_attachment': file,
    // F10 web:搜网=地球 / 抓取=下载
    'websearch': web, 'webfetch': download,
    // F11 memory-todo:记/忆=书签 / 忘=删 / 待办=清单
    'write_memory': memory, 'read_memory': memory, 'forget_memory': trash,
    'todo_write': todo, 'todo_read': todo,
    // F12 introspection:依赖=关系 / 找工具=search / 模型配置=芯片
    'get_relations': relations, 'search_tools': search, 'get_model_config': model,
    // F13 mcp-mgmt:市场=店 / 装=下载 / 卸=拔插 / 重连=刷新
    'list_mcp_marketplace': store, 'install_mcp_server': download,
    'uninstall_mcp_server': unplug, 'reconnect_mcp': refresh,
    // F15 subagent:派遣=分叉 / 看轨迹=history
    'subagent': subagent, 'get_subagent_trace': history,
    // F16 humanloop:提问=气泡 / 裁决=法槌 / 收件箱=收件箱
    'ask_user': ask, 'decide_approval': gavel, 'list_approval_inbox': inbox,
    // F17 conversation + misc:管理/列对话=对话 / 块检索=search / 列附件·文档
    'manage_conversation': chat, 'list_conversations': chat,
    'search_blocks': search, 'list_attachments': file, 'list_documents': doc,
  };

  /// The entity noun a regular tool name ends with → its glyph (null = not an entity-CRUD tool).
  /// 规整工具名的尾实体名词 → 字形(null=非 entity-CRUD)。
  static IconData? _entityGlyph(String n) {
    if (n.endsWith('_function')) return function;
    if (n.endsWith('_handler')) return handler;
    if (n.endsWith('_agent')) return agent;
    if (n.endsWith('_workflow')) return workflow;
    if (n.endsWith('_control')) return control;
    if (n.endsWith('_approval')) return approval;
    if (n.endsWith('_trigger') || n.endsWith('_triggers')) return trigger;
    if (n.endsWith('_document') || n.endsWith('_documents')) return doc;
    if (n.endsWith('_skill')) return skill;
    return null;
  }

  /// Tool name → glyph. Exact table first (irregulars), then structured rules for the regular
  /// entity-CRUD families: build/get show the ENTITY, delete/revert/search show the ACTION, and
  /// run-log archives (executions / calls / flowruns / firings / activations) read as history.
  /// Every registered tool lands an intentional glyph — the wrench default is only for genuinely
  /// unknown names. 工具名 → 字形:精确表打头(不规则),其余按规则(建/看=实体、删/回滚/搜=动作、
  /// 执行档案=history);每个注册工具都有意图字形,扳手兜底只留给真未知名。
  static IconData toolIcon(String name) {
    final n = name.toLowerCase();
    final exact = _toolExact[n];
    if (exact != null) return exact;
    if (n.startsWith('mcp__')) return mcp; // dynamic MCP tool 动态 MCP 工具
    // Run-log archives read as history — checked BEFORE the entity rule so `get_function_execution`
    // isn't captured by the `_function` suffix. 执行档案先判,免被实体后缀截胡。
    if (RegExp(r'execution|_call|flowrun|firing|activation').hasMatch(n)) return history;
    final ent = _entityGlyph(n);
    if (ent != null) {
      if (n.startsWith('delete_')) return trash;
      if (n.startsWith('revert_')) return history;
      if (n.startsWith('search_') || n.startsWith('list_')) return search;
      if (n.startsWith('update_')) return edit;
      return ent; // create_ / edit_ / get_ 建/改/看 → 实体形
    }
    // Unknown tool fallbacks (MCP dynamic already handled above). 未知兜底。
    if (n.contains('search') || n.contains('list')) return search;
    if (RegExp(r'create|edit|build|forge|update').hasMatch(n)) return edit;
    return tool;
  }

  /// Graph node kind → icon (the 5 closed kinds; unknown → [fallback]). 图节点 kind → 图标。
  static final Map<String, IconData> _nodeKind = {
    'trigger': trigger, 'action': action, 'agent': agent, 'control': control, 'approval': approval,
  };

  static IconData node(String kind) => _nodeKind[kind] ?? fallback;
}
