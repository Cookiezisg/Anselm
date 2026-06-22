import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Semantic icon registry — the ONE place a domain meaning binds to a concrete glyph. Mirrors the
/// demo's `core/icons.js` (ALIAS) + `config/entity-kinds.js`: features/widgets reference a semantic
/// name, never a raw Lucide identifier, so re-skinning an icon is a one-line edit here. The glyph
/// set is Lucide (the maintained package — same set the demo vendors). [byKey]/[tool]/[node] resolve
/// data-driven strings (a backend status, a tool name, a graph node kind) and fall back to
/// [fallback] so an unknown key degrades to a visible "?" instead of crashing.
///
/// 语义图标单源——领域含义 → 具体字形的唯一绑定处(镜像 demo icons.js + entity-kinds.js)。消费方只引
/// 语义名、绝不引裸 Lucide 名,改图标只动这一行。字形集=Lucide(成熟包,与 demo 同源)。byKey/tool/node
/// 解析数据驱动字串、未知回退 fallback(降级成可见的"?"而非崩)。
abstract final class AnIcons {
  // ── chrome ──
  static const IconData chevronRight = LucideIcons.chevronRight;
  static const IconData chevronDown = LucideIcons.chevronDown;
  static const IconData more = LucideIcons.ellipsis;
  static const IconData grip = LucideIcons.gripVertical;
  static const IconData close = LucideIcons.x;
  static const IconData sliders = LucideIcons.slidersHorizontal;
  static const IconData wrap = LucideIcons.wrapText;
  static const IconData expand = LucideIcons.maximize2;
  static const IconData search = LucideIcons.search;

  // ── entities / graph nodes / mounts ──
  static const IconData function = LucideIcons.squareFunction;
  static const IconData handler = LucideIcons.box;
  static const IconData agent = LucideIcons.bot;
  static const IconData workflow = LucideIcons.workflow;
  static const IconData trigger = LucideIcons.zap;
  static const IconData control = LucideIcons.gitBranch;
  static const IconData action = LucideIcons.play;
  static const IconData approval = LucideIcons.shieldCheck;
  static const IconData mcp = LucideIcons.plug;
  static const IconData skill = LucideIcons.bookOpen;
  static const IconData doc = LucideIcons.fileText;
  static const IconData entities = LucideIcons.layoutGrid;
  static const IconData chat = LucideIcons.messageSquare;
  static const IconData scheduler = LucideIcons.clock;
  static const IconData gear = LucideIcons.settings;

  // ── block / conversation semantics ──
  static const IconData reasoning = LucideIcons.brain;
  static const IconData tool = LucideIcons.wrench;
  static const IconData subagent = LucideIcons.gitFork;
  static const IconData turnEnd = LucideIcons.flag;
  static const IconData terminal = LucideIcons.squareTerminal;

  // ── execution verbs / actions ──
  static const IconData run = LucideIcons.play;
  static const IconData enter = LucideIcons.cornerDownLeft;
  static const IconData stop = LucideIcons.square;
  static const IconData spin = LucideIcons.loaderCircle;
  static const IconData forge = LucideIcons.hammer;
  static const IconData edit = LucideIcons.squarePen;
  static const IconData trash = LucideIcons.trash2;
  static const IconData web = LucideIcons.globe;
  static const IconData iterate = LucideIcons.sparkles; // AI edit (≠ forge: rebuild env) AI 编辑
  static const IconData history = LucideIcons.history;
  static const IconData diff = LucideIcons.gitCompare;

  // ── state placeholders ──
  static const IconData empty = LucideIcons.inbox;
  static const IconData error = LucideIcons.triangleAlert;

  /// Unknown-key sink — a visible "?" so a missing binding is obvious, never a crash.
  /// 未知键兜底——可见的"?",缺绑定一眼可见、绝不崩。
  static const IconData fallback = LucideIcons.circleQuestionMark;

  /// Semantic key → glyph, for data-driven resolution (a backend node kind, a derived tool icon).
  /// Prefer the named fields above at call sites; this map is for strings only.
  /// 语义键 → 字形,供数据驱动解析(后端节点 kind、派生的工具图标)。调用处优先用上面的具名字段。
  static const Map<String, IconData> _byKey = {
    'chevr': chevronRight, 'chevd': chevronDown, 'more': more, 'grip': grip,
    'close': close, 'sliders': sliders, 'wrap': wrap, 'expand': expand, 'search': search,
    'function': function, 'handler': handler, 'agent': agent, 'workflow': workflow,
    'trigger': trigger, 'control': control, 'action': action, 'approval': approval,
    'mcp': mcp, 'skill': skill, 'doc': doc, 'entities': entities,
    'chat': chat, 'conversation': chat, 'scheduler': scheduler, 'gear': gear,
    'reasoning': reasoning, 'tool': tool, 'subagent': subagent, 'turnend': turnEnd, 'terminal': terminal,
    'run': run, 'enter': enter, 'stop': stop, 'spin': spin, 'forge': forge,
    'edit': edit, 'trash': trash, 'web': web, 'iterate': iterate, 'history': history, 'diff': diff,
    'empty': empty, 'error': error,
  };

  /// Resolve a semantic key string to a glyph (unknown → [fallback]).
  /// 语义键字串 → 字形(未知 → fallback)。
  static IconData byKey(String key) => _byKey[key] ?? fallback;

  /// Exact tool-name → icon overrides (the rest are inferred by [tool]).
  /// 工具名精确映射(其余由 tool 推断)。
  static const Map<String, IconData> _toolExact = {
    'run_function': action, 'call_handler': handler, 'invoke_agent': agent, 'trigger_workflow': workflow,
    'run_shell': tool, 'read_file': doc, 'write_file': edit, 'edit_file': edit,
    'web_search': web, 'web_fetch': web, 'search_blocks': search,
  };

  /// Tool name → icon. Exact match first, then keyword inference (mirrors demo `toolIcon`); the
  /// block-tree shows a per-tool glyph so a `read_file` call reads differently from a `web_fetch`.
  /// 工具名 → 图标:先精确、后关键字推断(镜像 demo toolIcon);block-tree 据此让每种 tool_call 显不同图标。
  static IconData toolIcon(String name) {
    final n = name.toLowerCase();
    final exact = _toolExact[n];
    if (exact != null) return exact;
    if (RegExp(r'shell|bash|exec').hasMatch(n)) return AnIcons.tool;
    if (n.contains('search')) return search;
    if (RegExp(r'file|read|write|doc').hasMatch(n)) return doc;
    if (RegExp(r'web|fetch|http|url').hasMatch(n)) return web;
    if (n.contains('function')) return function;
    if (n.contains('handler')) return handler;
    if (n.contains('agent')) return agent;
    if (RegExp(r'workflow|trigger').hasMatch(n)) return workflow;
    if (RegExp(r'create|edit|build|forge').hasMatch(n)) return forge;
    if (n.startsWith('mcp')) return mcp;
    return AnIcons.tool;
  }

  /// Graph node kind → icon (the 5 closed kinds; unknown → [fallback]).
  /// 图节点 kind → 图标(5 个封闭 kind;未知 → fallback)。
  static IconData node(String kind) => const {
        'trigger': trigger, 'action': action, 'agent': agent, 'control': control, 'approval': approval,
      }[kind] ?? fallback;
}
