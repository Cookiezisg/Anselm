import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// The icon registry — ALL icons are Lucide (project mandate: one open-source icon family,
/// the same set the demo vendors). Features and primitives reference SEMANTIC keys here
/// (`AnIcons.function`), never `LucideIcons.*` directly: changing an icon happens in one
/// place, and the domain vocabulary stays stable even if a glyph is swapped. Mirrors the
/// demo's `icons.js` alias map.
///
/// 图标注册表——全部用 Lucide(项目铁律:统一一套开源图标,与 demo vendored 同款)。feature/原语引用
/// 这里的语义 key(`AnIcons.function`),绝不直接用 `LucideIcons.*`:换图标只动一处,领域词汇稳定。
/// 对齐 demo 的 icons.js 别名映射。
abstract final class AnIcons {
  // ── Entities / graph nodes / mounts 实体 / 图节点 / 挂载 ──
  static const IconData function = LucideIcons.squareFunction;
  static const IconData handler = LucideIcons.box;
  static const IconData agent = LucideIcons.bot;
  static const IconData workflow = LucideIcons.workflow;
  static const IconData trigger = LucideIcons.zap;
  static const IconData control = LucideIcons.gitBranch;
  static const IconData approval = LucideIcons.shieldCheck;
  static const IconData mcp = LucideIcons.plug;
  static const IconData skill = LucideIcons.bookOpen;
  static const IconData document = LucideIcons.fileText;

  // ── Navigation / sections 导航 / 分区 ──
  static const IconData entities = LucideIcons.layoutGrid;
  static const IconData chat = LucideIcons.messageSquare;
  static const IconData scheduler = LucideIcons.clock;
  static const IconData search = LucideIcons.search;
  static const IconData settings = LucideIcons.settings;
  static const IconData notifications = LucideIcons.bell;

  // ── Conversation / block semantics 对话 / 块语义 ──
  static const IconData reasoning = LucideIcons.brain;
  static const IconData tool = LucideIcons.wrench;
  static const IconData subagent = LucideIcons.gitFork;
  static const IconData turnEnd = LucideIcons.flag;
  static const IconData terminal = LucideIcons.squareTerminal;

  // ── Action verbs 执行 / 动作 ──
  static const IconData run = LucideIcons.play;
  static const IconData stop = LucideIcons.square;
  static const IconData enter = LucideIcons.cornerDownLeft;
  static const IconData spin = LucideIcons.loaderCircle;
  static const IconData forge = LucideIcons.hammer; // rebuild env (≠ AI iterate) 重建环境
  static const IconData edit = LucideIcons.squarePen;
  static const IconData trash = LucideIcons.trash2;
  static const IconData web = LucideIcons.globe;
  static const IconData iterate = LucideIcons.sparkles; // AI edit AI 编辑
  static const IconData history = LucideIcons.history;
  static const IconData diff = LucideIcons.gitCompare;
  static const IconData add = LucideIcons.plus;
  static const IconData check = LucideIcons.check;

  // ── Chrome 框架 ──
  static const IconData chevronRight = LucideIcons.chevronRight;
  static const IconData chevronDown = LucideIcons.chevronDown;
  static const IconData more = LucideIcons.ellipsis;
  static const IconData grip = LucideIcons.gripVertical;
  static const IconData close = LucideIcons.x;
  static const IconData sliders = LucideIcons.slidersHorizontal;
  static const IconData expand = LucideIcons.maximize2;
  static const IconData collapseLeft = LucideIcons.panelLeft;
  static const IconData collapseRight = LucideIcons.panelRight;

  // ── State placeholders / feedback 态占位 / 反馈 ──
  static const IconData empty = LucideIcons.inbox;
  static const IconData info = LucideIcons.info;
  static const IconData success = LucideIcons.circleCheck;
  static const IconData error = LucideIcons.triangleAlert;
  static const IconData unknown = LucideIcons.circleHelp; // fallback 兜底
}
