import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/contract/api_error.dart';
import '../../../core/contract/entities/document.dart';
import '../../../core/contract/entities/skill.dart';
import '../../../core/model/byte_format.dart';
import '../../../core/model/status_state.dart';
import '../../../core/model/time_format.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/overlay/an_overlay.dart';
import '../../../core/notice/notice_center.dart';
import '../../../core/perf/debouncer.dart';
import '../../../core/shell/right_panel.dart';
import '../../../core/router/panel_registry.dart';
import '../../../core/ui/an_card.dart';
import '../../../core/ui/an_dialog.dart';
import '../../../core/ui/an_dropdown.dart';
import '../../../core/ui/an_expand_reveal.dart';
import '../../../core/ui/an_form_field.dart';
import '../../../core/ui/an_input.dart';
import '../../../core/ui/an_kv.dart';
import '../../../core/ui/an_menu.dart';
import '../../../core/ui/an_panel_head.dart';
import '../../../core/ui/an_button.dart';
import '../../../core/ui/an_chip.dart';
import '../../../core/ui/an_row.dart';
import '../../../core/ui/an_scroll_behavior.dart';
import '../../../core/ui/an_last_good.dart';
import '../../../core/ui/an_skeleton.dart';
import '../../../core/ui/an_state.dart';
import '../../../core/ui/an_tags.dart';
import '../../../core/ui/icons.dart';
import '../../../i18n/strings.g.dart';
import '../data/library_repository.dart';
import '../state/doc_group_collapse.dart';
import '../state/library_state.dart';
import 'skill_file_preview.dart';
import 'skill_tool_picker.dart';

/// The Documents ocean's right-island inspector — the three-segment grammar (三段式文法 §1–§3, batch 2, 用户
/// 0719): ONE identity head ([AnPanelHead]: doc/skill glyph · name · ⋯ · ✕) over a quiet §2 GLANCE strip
/// (`N 字 · M 反链 · 昨天编辑`, signal-only) over §3 collapsible GROUPS (Outline / Properties / Backlinks,
/// each an [AnRow] group head + a folded body) — retiring the three orphan mini-titles (Outline / Properties
/// / Backlinks each an [AnGroupLabel] over a flat block). The group INTERNALS are untouched (the outline
/// tree / KV meta rows / backlinks list / skill form — 动骨不动髓); only the chrome converged.
///
/// A page shows metadata (name / description / tags edit in the CENTER; this island shows read-only
/// path·size·modified) via partial PATCH; a skill shows its frontmatter (config fields) via PUT full-replace
/// (the backend has no partial skill update, so a write re-sends the whole frontmatter AND the untouched
/// body). Fold state persists per-group ([docGroupCollapseProvider]); no selection → an inset empty state.
///
/// 文档海洋右岛检查器——三段式文法(§1 身份头 [AnPanelHead] + §2 速览带 + §3 可折叠三组),退役三孤儿小标题;
/// 组内实现原样保留(动骨不动髓)。页=元数据(名/描述/标签归中心,本岛只读 path·size·modified)走分部 PATCH;
/// skill=frontmatter 走 PUT 全覆盖;折叠态按组持久化;无选=空态。
class LibraryInspector extends ConsumerWidget {
  const LibraryInspector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sel = ref.watch(selectedDocProvider);
    if (sel == null) {
      // No selection → the head names the panel, no ⋯ (nothing to fold), no glance. 无选:头命名面板、无 ⋯ 无速览。
      return _InspectorShell(
        icon: AnIcons.doc,
        title: context.t.library.props.title,
        body: AnState(
          kind: AnStateKind.empty,
          size: AnStateSize.inset,
          title: context.t.library.props.empty,
          hint: context.t.library.props.emptyHint,
        ),
      );
    }
    return sel.isSkill
        ? _SkillProperties(key: ValueKey('skill:${sel.id}'), name: sel.id)
        : _DocProperties(key: ValueKey(sel.id), id: sel.id);
  }
}

/// The shared inspector chrome (三段式文法 §1) — the [AnPanelHead] (icon · [title] · ⋯ · ✕) with the §2 glance
/// [sub] band, over a scrolling body. [menuEntries] empty → no ⋯ (the empty state). Horizontal pad is ZERO
/// (the island's 12px is the sole inset — the group heads land flush like the left island's rail rows).
/// 共享外壳:身份头 + 速览带 + 滚动 body;menuEntries 空→无 ⋯;水平 0(岛 12 唯一内距,组头洗底)。
class _InspectorShell extends ConsumerWidget {
  const _InspectorShell({
    required this.icon,
    required this.title,
    required this.body,
    this.sub,
    this.menuEntries = const <AnMenuEntry>[],
  });

  final IconData icon;
  final String title;
  final Widget body;
  final Widget? sub;
  final List<AnMenuEntry> menuEntries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnPanelHead(
          icon: icon,
          title: title,
          menuEntries: menuEntries,
          menuSemanticLabel: context.t.a11y.moreActions,
          sub: sub,
          onClose: () =>
              ref.read(rightPanelCollapsedProvider.notifier).set(true),
          closeSemantics: context.t.shell.togglePanel,
        ),
        Expanded(
          child: ScrollConfiguration(
            behavior: const AnScrollBehavior(),
            // No horizontal pad — the [AnIsland]'s 12px is the sole island inset (single-source law).
            // 水平 0:岛壳 12 即唯一岛级内距。
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: AnSpace.s8),
              child: body,
            ),
          ),
        ),
      ],
    );
  }
}

/// The head ⋯ overflow (三段式文法 §1 — the panel action the collapsible-groups structure introduces):
/// «展开全部» / «收起全部» over [docGroupCollapseProvider]. 头 ⋯:全展/全收。
List<AnMenuEntry> _menuEntries(BuildContext context, WidgetRef ref) {
  final p = context.t.library.props;
  return [
    AnMenuItem(
      label: p.expandAll,
      icon: AnIcons.unfold,
      onTap: () => ref.read(docGroupCollapseProvider.notifier).expandAll(),
    ),
    AnMenuItem(
      label: p.collapseAll,
      icon: AnIcons.fold,
      onTap: () => ref.read(docGroupCollapseProvider.notifier).collapseAll(),
    ),
  ];
}

/// The skill panel's ⋯ — the doc entries plus the manifest source-mode toggle and «new file»
/// (panel-level actions per the三段式 law: group heads stay ⋯-free). skill 面板 ⋯:通用两项 +
/// 清单源码切换 + 新建文件(面板级动作归 ⋯,组头无 ⋯)。
List<AnMenuEntry> _skillMenuEntries(BuildContext context, WidgetRef ref) {
  final t = context.t;
  final sourceMode = ref.watch(skillManifestSourceModeProvider);
  return [
    AnMenuItem(
      label: t.library.skillManifestSource,
      icon: AnIcons.fileCode,
      checked: sourceMode,
      onTap: () => ref.read(skillManifestSourceModeProvider.notifier).toggle(),
    ),
    AnMenuItem(
      label: t.library.skillNewFile,
      icon: AnIcons.plus,
      onTap: () => _promptNewSkillFile(context, ref),
    ),
    ..._menuEntries(context, ref),
  ];
}

/// The «new file» prompt: a relative path in, an empty file lands through the guarded write,
/// the tree refreshes and the center opens it. 新建文件:输相对路径→守卫写空文件→树刷新+打开。
void _promptNewSkillFile(BuildContext context, WidgetRef ref) {
  final sel = ref.read(selectedDocProvider);
  if (sel == null || !sel.isSkill) return;
  final name = sel.id;
  final nav = Navigator.of(context, rootNavigator: true);
  nav.push(
    anPanelRoute<void>(
      scrim: context.colors.scrim,
      reduced: AnMotionPref.reduced(context),
      barrierLabel: context.t.feedback.dialogBarrier,
      builder: (dialogCtx) => _NewSkillFilePanel(name: name),
    ),
  );
}

class _NewSkillFilePanel extends ConsumerStatefulWidget {
  const _NewSkillFilePanel({required this.name});

  final String name;

  @override
  ConsumerState<_NewSkillFilePanel> createState() => _NewSkillFilePanelState();
}

class _NewSkillFilePanelState extends ConsumerState<_NewSkillFilePanel> {
  final _ctl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final rel = _ctl.text.trim();
    if (rel.isEmpty) return;
    try {
      await ref
          .read(libraryRepositoryProvider)
          .writeSkillFile(widget.name, rel, const []);
      ref.invalidate(skillFilesProvider(widget.name));
      if (!mounted) return;
      Navigator.of(context).maybePop();
      context.go(skillFileLocation(widget.name, rel));
    } catch (e) {
      final m = e.toString();
      final i = m.lastIndexOf(': ');
      setState(
        () => _error = i >= 0 && i + 2 < m.length ? m.substring(i + 2) : m,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final c = context.colors;
    return Center(
      child: SizedBox(
        width: 420,
        child: AnCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t.library.skillNewFile, style: AnText.h3),
              const SizedBox(height: AnSpace.s12),
              AnInput(
                controller: _ctl,
                placeholder: t.library.skillNewFileHint,
                onSubmitted: (_) => _create(),
              ),
              if (_error != null) ...[
                const SizedBox(height: AnSpace.s6),
                Text(_error!, style: AnText.meta.copyWith(color: c.danger)),
              ],
              const SizedBox(height: AnSpace.s12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AnButton(
                    label: t.action.cancel,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: AnSpace.s8),
                  AnButton(
                    label: t.library.skillNewFile,
                    variant: AnButtonVariant.primary,
                    onPressed: _create,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The skill glance: «N 文件 · M 绑定 · rel 编辑» — zero-speech law per segment (files>1,
/// bindings>0; edited always). skill 速览带:每段有真信号才在。
Widget? _skillGlance(
  BuildContext context, {
  required int files,
  required int bindings,
  required DateTime updatedAt,
}) {
  final t = context.t;
  final p = t.library.props;
  final rel = fmtRelativeDay(
    updatedAt,
    DateTime.now(),
    today: p.time.today,
    yesterday: p.time.yesterday,
    daysAgo: (n) => p.time.daysAgo(n: n),
  );
  final segs = <String>[
    if (files > 1) t.library.glanceFiles(n: files),
    if (bindings > 0) t.library.glanceBindings(n: bindings),
    p.glanceEdited(rel: rel),
  ];
  return Text(
    segs.join(' · '),
    style: AnText.meta.copyWith(color: context.colors.inkFaint),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
  );
}

// ── §2 glance strip ──

/// The number of NON-WHITESPACE code points in [content] — a coarse «字数» for the glance (raw markdown
/// characters; a size proxy, not a linguistic word count). 非空白码点数(粗粒度字数,含 markdown 语法字符)。
int _charCount(String content) =>
    content.replaceAll(RegExp(r'\s+'), '').runes.length;

/// A compact count: `840` / `2.4k` / `12k` (trailing `.0` stripped). 紧凑计数。
String _compactCount(int n) {
  if (n < 1000) return '$n';
  final s = (n / 1000).toStringAsFixed(1);
  return '${s.endsWith('.0') ? s.substring(0, s.length - 2) : s}k';
}

/// The §2 GLANCE strip — one quiet [AnText.meta] line of `N 字 · M 反链 · <rel>编辑`, each segment present
/// ONLY when it carries signal (零人话律: chars/backlinks omitted at 0; «edited» always meaningful from
/// updatedAt). Returns null when nothing has a value → [AnPanelHead] draws no band. 速览带:有信号才在段,全空→null。
Widget? _glance(
  BuildContext context, {
  required int chars,
  required int backlinks,
  required DateTime updatedAt,
}) {
  final c = context.colors;
  final p = context.t.library.props;
  final rel = fmtRelativeDay(
    updatedAt,
    DateTime.now(),
    today: p.time.today,
    yesterday: p.time.yesterday,
    daysAgo: (n) => p.time.daysAgo(n: n),
  );
  final segs = <String>[
    if (chars > 0) p.glanceChars(count: _compactCount(chars)),
    if (backlinks > 0) p.glanceBacklinks(n: backlinks),
    p.glanceEdited(rel: rel),
  ];
  if (segs.isEmpty) return null;
  return Text(
    segs.join(' · '),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: AnText.meta.copyWith(color: c.inkFaint),
  );
}

// ── §3 collapsible group ──

/// One collapsible right-island GROUP (三段式文法 §3) — an [AnRow] group head (type icon that hover-swaps to
/// the disclosure chevron + count meta, no ⋯ — the SAME AnRow language as the left island's rows) over its
/// [child] body. Fold state lives in [docGroupCollapseProvider] keyed by [groupKey], persisted per-group
/// (survives restart). Every group reveals through the kit's ONE [AnExpandReveal]; [keepMounted] only picks
/// whether the collapsed subtree stays mounted (the skill form's debounced autosave + edit buffers must
/// survive a fold) — the disclosure MOTION is identical either way.
///
/// 可折叠组:AnRow 组头(类型图标 hover 换披露箭头 + 计数、无 ⋯,同左岛行)+ 体;折叠态按 groupKey 持久化。
/// 所有组走套件唯一的 AnExpandReveal;keepMounted 只决定收起后子树是否仍挂载(skill 表单的在途保存须活过折叠)
/// ——**展开动效两者一致**。
class _GroupSection extends ConsumerWidget {
  const _GroupSection({
    required this.groupKey,
    required this.icon,
    required this.label,
    required this.count,
    required this.child,
    this.keepMounted = false,
  });

  final String groupKey;

  /// The group's type icon — shown at rest, hover-swaps to the disclosure chevron (AnRow's
  /// collapsible+icon behaviour, same as the left island's rows). An icon-LESS head would degrade to
  /// a bare permanent chevron (the notification tray's deliberate look, wrong for a titled group).
  /// 组类型图标——静息显示、hover 换披露箭头(AnRow collapsible+icon 行为,同左岛);无图标会退化成裸常驻箭头。
  final IconData icon;
  final String label;
  final int count;
  final Widget child;
  final bool keepMounted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = !ref.watch(docGroupCollapseProvider).contains(groupKey);
    void toggle() =>
        ref.read(docGroupCollapseProvider.notifier).toggle(groupKey);
    // The body breathes below the head; the next group head is the separator (no dividers). 体在头下透气,组头即分隔。
    final body = Padding(
      padding: const EdgeInsets.only(top: AnSpace.s2, bottom: AnSpace.s12),
      child: child,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnRow(
          collapsible: true,
          open: open,
          icon: icon,
          label: label,
          meta: '$count',
          onSelect: toggle,
          onToggle: toggle,
        ),
        AnExpandReveal(open: open, keepMounted: keepMounted, child: body),
      ],
    );
  }
}

/// The open document/skill's OUTLINE group (三段式文法 §3) — its headings as an indented, tappable table of
/// contents (fed live by the editor; a tap scrolls the editor to that heading; the entry the viewport is
/// READING highlights live via [docOutlineActiveProvider]). Quietly ABSENT (no group) when there are no
/// headings. 大纲组:标题作可点目录(编辑器活喂;点击滚到该标题;视口正读项实时高亮);无标题时整组静默缺席。
class _OutlineGroup extends ConsumerWidget {
  const _OutlineGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outline = ref.watch(docOutlineProvider);
    if (outline.isEmpty) return const SizedBox.shrink();
    final active = ref.watch(docOutlineActiveProvider);
    // Indent RELATIVE to the shallowest heading present — a document whose sections start at h2 reads
    // flush-left, not pre-indented one step. 缩进按最浅层级归一。
    var minLevel = 6;
    for (final e in outline) {
      if (e.level < minLevel) minLevel = e.level;
    }
    return _GroupSection(
      groupKey: kDocGroupOutline,
      icon: AnIcons.listBulleted,
      label: context.t.library.props.outline,
      count: outline.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < outline.length; i++)
            AnRow(
              depth: outline[i].level - minLevel,
              label: outline[i].text,
              leadless:
                  true, // a TOC has no icons — the reserved slot reads as mystery indent 目录无图标
              selected: active == i,
              onSelect: () => ref.read(outlineJumpProvider.notifier).jump(i),
            ),
        ],
      ),
    );
  }
}

/// A labelled field with the standard inter-field bottom gap. 字段块(标准字段间距)。
class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child, this.desc});

  final String label;
  final String? desc;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AnSpace.s16),
    child: AnFormField(label: label, desc: desc, child: child),
  );
}

// ── document properties ──

class _DocProperties extends ConsumerWidget {
  const _DocProperties({required this.id, super.key});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final doc = ref.watch(openDocumentProvider(id));
    final loaded = doc.value;
    final name = loaded?.name.trim() ?? '';
    // The glance rides the LOADED doc + the (separately-async) backlink count; null while loading. 速览带走已载 doc + 反链数。
    Widget? sub;
    if (loaded != null) {
      final backlinks = ref.watch(backlinksProvider(id)).value ?? const [];
      sub = _glance(
        context,
        chars: _charCount(loaded.content),
        backlinks: backlinks.length,
        updatedAt: loaded.updatedAt,
      );
    }
    return _InspectorShell(
      icon: AnIcons.doc,
      // The head IS the open page's name (falls back while loading / for the unnamed). 头=页名。
      title: name.isEmpty ? t.library.untitled : name,
      menuEntries: _menuEntries(context, ref),
      sub: sub,
      body: AnLastGood(
        value: doc,
        resetKey:
            id, // switching pages hard-resets; same-page refreshes hold 换页硬换代,同页刷新顶住
        placeholder: const AnSkeleton.lines(5),
        errorBuilder: (_, _, _) => AnState(
          kind: AnStateKind.error,
          size: AnStateSize.inset,
          title: t.library.loadFailed,
        ),
        // The island is "about this page" only: outline (live focus) / file meta / backlinks. The page's
        // OWN properties (name/description/tags) edit in the CENTER under the big title. 右岛只谈「这一页」。
        builder: (context, doc) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _OutlineGroup(),
            _DocMetaGroup(doc: doc),
            _BacklinksGroup(id: doc.id),
          ],
        ),
      ),
    );
  }
}

/// The page's PROPERTIES group (三段式文法 §3) — the read-only file meta (path · size · modified) as a family
/// KV list (the page's editable name/description/tags live in the center header). 页属性组:只读文件 meta 键值列。
class _DocMetaGroup extends StatelessWidget {
  const _DocMetaGroup({required this.doc});

  final DocumentNode doc;

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    // The family KV list (批6 A-082): path wraps (a flush-right ellipsis would cut its most useful tail).
    // 族键值列(path 换行,贴右省略会砍最有用的尾段)。
    final rows = [
      AnKvRow(t.library.props.path, doc.path, mono: true, wrap: true),
      AnKvRow(t.library.props.size, formatBytes(doc.sizeBytes)),
      AnKvRow(t.library.props.modified, fmtDateTime(doc.updatedAt)),
    ];
    return _GroupSection(
      groupKey: kDocGroupProps,
      icon: AnIcons.sliders,
      label: t.library.props.title,
      count: rows.length,
      child: AnKv(dense: true, rows: rows),
    );
  }
}

/// The document's BACKLINKS group (三段式文法 §3) — pages whose bodies `[[id]]`-wikilink this one (incoming
/// `link` edges, names hydrated server-side). A document row navigates to the linker; non-document linkers
/// (a conversation, a workflow) render inert — their oceans own their navigation. Always present for a page
/// (the empty body states «no pages link here yet»). 反链组:入向 link 边;文档行点击导航,非文档惰性;空态陈述。
class _BacklinksGroup extends ConsumerWidget {
  const _BacklinksGroup({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final c = context.colors;
    return AnLastGood(
      value: ref.watch(backlinksProvider(id)),
      resetKey: id,
      placeholder: _GroupSection(
        groupKey: kDocGroupBacklinks,
        icon: AnIcons.link,
        label: t.library.props.backlinks,
        count: 0,
        child: const AnSkeleton.lines(2),
      ),
      errorBuilder: (_, _, _) =>
          const SizedBox.shrink(), // quiet: backlinks are auxiliary 反链是辅助信息,静默降级
      builder: (context, links) => _GroupSection(
        groupKey: kDocGroupBacklinks,
        icon: AnIcons.link,
        label: t.library.props.backlinks,
        count: links.length,
        child: links.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: AnSpace.s8),
                child: Text(
                  t.library.props.noBacklinks,
                  style: AnText.meta.copyWith(color: c.inkFaint),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final link in links)
                    AnRow(
                      icon: AnIcons.byKey(link.fromKind),
                      label: link.fromName.isEmpty
                          ? link.fromId
                          : link.fromName,
                      onSelect: link.fromKind == 'document'
                          ? () => context.go(documentLocation(link.fromId))
                          : null,
                    ),
                ],
              ),
      ),
    );
  }
}

// ── skill frontmatter properties ──

class _SkillProperties extends ConsumerWidget {
  const _SkillProperties({required this.name, super.key});

  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final skill = ref.watch(openSkillProvider(name));
    final loaded = skill.value;
    // A skill has no backlinks (the backend only parses `[[id]]` on documents) → the 反链 segment is omitted
    // by 零人话律 (backlinks: 0). Glance = «N 字 · <rel>编辑». skill 无反链→段被 0 律省;速览带=字+编辑。
    Widget? sub;
    final fileCount = ref.watch(skillFilesProvider(name)).value?.length ?? 0;
    final bindingCount =
        ref.watch(skillBindingsProvider(name)).value?.length ?? 0;
    if (loaded != null) {
      sub = _skillGlance(
        context,
        files: fileCount,
        bindings: bindingCount,
        updatedAt: loaded.updatedAt,
      );
    }
    return _InspectorShell(
      icon: AnIcons.skill,
      // The slug IS the identity — the head shows it directly. slug 即身份,头直显。
      title: name,
      menuEntries: _skillMenuEntries(context, ref),
      sub: sub,
      body: AnLastGood(
        value: skill,
        resetKey: name, // switching skills hard-resets 换 skill 硬换代
        placeholder: const AnSkeleton.lines(6),
        errorBuilder: (_, _, _) => AnState(
          kind: AnStateKind.error,
          size: AnStateSize.inset,
          title: t.library.loadFailed,
        ),
        builder: (context, skill) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SkillFilesGroup(name: skill.name),
            _SkillPropsGroup(skill: skill),
            if (skill.source == kSkillSourceInstalled)
              _SkillProvenanceGroup(skill: skill),
            // Outline LAST — it tracks the OPEN FILE (the tree can switch the center to any bundled
            // file), so above the stable groups it made every file-switch reflow-push the config /
            // files / provenance below it. Pinned to the bottom, its height changes disturb nothing.
            // 大纲置末:它跟随「当前打开的文件」,置顶时切文件会把下方稳定组整体下推(跳);钉底则高度变化不扰动任何组。
            const _OutlineGroup(),
          ],
        ),
      ),
    );
  }
}

/// The skill's PROPERTIES group (三段式文法 §3) — its frontmatter CONFIG form. [keepMounted] (Offstage, not
/// tree-removed): the form holds a debounced autosave + edit buffers, and the open provider is deliberately
/// never refetched mid-edit (cursor), so unmounting on collapse would drop a pending save and stale-remount.
/// 技能属性组:frontmatter 配置表单;keepMounted(保态,收起不卸载,免丢在途保存/陈旧重挂)。
class _SkillPropsGroup extends StatelessWidget {
  const _SkillPropsGroup({required this.skill});

  final Skill skill;

  @override
  Widget build(BuildContext context) {
    final f = skill.frontmatter;
    // The visible config fields: context, tools, arguments, model-invoke, user-invoke (+ agent iff fork).
    // 可见配置字段数(fork 才有 agent)。
    final count = 5 + (f.context == kSkillContextFork ? 1 : 0);
    return _GroupSection(
      groupKey: kDocGroupProps,
      icon: AnIcons.sliders,
      label: context.t.library.props.title,
      count: count,
      keepMounted: true,
      // AnFormField carries NO horizontal inset (unlike the AnRow family + AnKv, which self-inset s8),
      // so the raw form fields landed 8px left of the file tree / outline / group heads above them —
      // a child sitting further left than its own head. Pad to the 岛12+行族8=20px imaginary frame
      // (右岛内距单源律). 表单无自带退格,补 s8 对齐行族假想框(否则比自己的组头还靠左)。
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AnSpace.s8),
        child: _SkillForm(key: ValueKey(skill.name), skill: skill),
      ),
    );
  }
}

class _SkillForm extends ConsumerStatefulWidget {
  const _SkillForm({required this.skill, super.key});

  final Skill skill;

  @override
  ConsumerState<_SkillForm> createState() => _SkillFormState();
}

class _SkillFormState extends ConsumerState<_SkillForm> {
  late final TextEditingController _agent;
  late String _context;
  late List<String> _tools;
  late List<String> _args;
  late bool _disableModelInvocation;
  late bool _userInvocable;
  final _save = Debouncer(AnMotion.autosave);

  LibraryRepository get _repo => ref.read(libraryRepositoryProvider);

  @override
  void initState() {
    super.initState();
    final f = widget.skill.frontmatter;
    _agent = TextEditingController(text: f.agent);
    _context = f.context.isEmpty ? kSkillContextInline : f.context;
    _tools = [...f.allowedTools];
    _args = [...f.arguments];
    _disableModelInvocation = f.disableModelInvocation;
    _userInvocable = f.userInvocable;
  }

  @override
  void didUpdateWidget(_SkillForm old) {
    super.didUpdateWidget(old);
    // Adopt an EXTERNAL config change (e.g. an edit_skill via chat refreshing this skill) so the form's
    // mount-time snapshot can't silently clobber it on the next save. Same skill, changed frontmatter →
    // re-sync the config fields this island owns. 外部改动即同步,防本岛快照下次保存 clobber。
    final f = widget.skill.frontmatter;
    if (old.skill.name == widget.skill.name && f != old.skill.frontmatter) {
      _agent.text = f.agent;
      _context = f.context.isEmpty ? kSkillContextInline : f.context;
      _tools = [...f.allowedTools];
      _args = [...f.arguments];
      _disableModelInvocation = f.disableModelInvocation;
      _userInvocable = f.userInvocable;
    }
  }

  @override
  void dispose() {
    _save.dispose();
    _agent.dispose();
    super.dispose();
  }

  // A skill write is a PUT of the WHOLE frontmatter, and the body must ride along or the full-replace
  // resets it. READ-MODIFY-WRITE: fetch the CURRENT skill right before the PUT — the center editor may
  // have saved a newer body OR description than this form's mount-time snapshot (identity/description
  // edit in the center; this island owns only the CONFIG fields). 整套 PUT;读-改-写:PUT 前取**当前**
  // skill——中心可能已存更新的 body/描述(身份/描述归中心,本岛只管配置字段)。
  void _put() => _save.run(() async {
    try {
      final current = await _repo.getSkill(widget.skill.name);
      await _repo.replaceSkill(widget.skill.name, {
        'description': current.description,
        'body': current.body,
        'allowedTools': _tools,
        'context': _context,
        'agent': _agent.text.trim(),
        'arguments': _args,
        'disableModelInvocation': _disableModelInvocation,
        'userInvocable': _userInvocable,
      });
      if (!mounted) return;
      ref.invalidate(skillListProvider);
    } catch (_) {
      if (mounted) {
        ref
            .read(noticeCenterProvider.notifier)
            .show(context.t.library.actionFailed, tone: AnTone.danger);
      }
    }
  });

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final p = t.library.props;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Identity (slug title) + description edit in the CENTER header — this island is the skill's
        // CONFIG only. 身份(slug 标题)与描述在中心头部编辑;本岛只管配置。
        _Field(
          label: p.context,
          child: AnDropdown<String>(
            block: true,
            value: _context,
            options: [
              AnDropdownOption(
                value: kSkillContextInline,
                label: p.contextInline,
              ),
              AnDropdownOption(value: kSkillContextFork, label: p.contextFork),
            ],
            onChanged: (v) {
              setState(() => _context = v);
              _put();
            },
          ),
        ),
        // Agent is only meaningful (and required) for a fork skill. agent 仅 fork 有意义(且必填)。
        if (_context == kSkillContextFork)
          _Field(
            label: p.agent,
            desc: p.agentHint,
            child: AnInput(
              controller: _agent,
              block: true,
              onChanged: (_) => _put(),
            ),
          ),
        _Field(
          label: p.tools,
          // Assisted picker (builtin / functions / handlers / MCP, + free-text fallback) over the raw
          // pill set — entity ids show resolved names, everything else verbatim. 选择器+药丸(实体显名)。
          child: SkillToolsField(
            skillName: widget.skill.name,
            values: _tools,
            onChanged: (next) {
              setState(() => _tools = next);
              _put();
            },
          ),
        ),
        _Field(
          label: p.arguments,
          child: AnTags(
            tags: [for (final a in _args) AnTag(a)],
            placeholder: p.addArg,
            onChanged: (tags) {
              setState(() => _args = [for (final tag in tags) tag.label]);
              _put();
            },
          ),
        ),
        _Field(
          label: p.modelInvoke,
          // Stored inverted (disableModelInvocation); the toggle shows the plain "can invoke". 存反义,开关显正义。
          child: _OnOff(
            value: !_disableModelInvocation,
            onLabel: p.on,
            offLabel: p.off,
            onChanged: (v) {
              setState(() => _disableModelInvocation = !v);
              _put();
            },
          ),
        ),
        _Field(
          label: p.userInvoke,
          child: _OnOff(
            value: _userInvocable,
            onLabel: p.on,
            offLabel: p.off,
            onChanged: (v) {
              setState(() => _userInvocable = v);
              _put();
            },
          ),
        ),
      ],
    );
  }
}

/// A boolean as an On/Off dropdown (the app has no switch primitive; mirrors approval's yes/no). 布尔=开/关下拉。
class _OnOff extends StatelessWidget {
  const _OnOff({
    required this.value,
    required this.onChanged,
    required this.onLabel,
    required this.offLabel,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String onLabel;
  final String offLabel;

  @override
  Widget build(BuildContext context) => AnDropdown<bool>(
    block: true,
    value: value,
    options: [
      AnDropdownOption(value: true, label: onLabel),
      AnDropdownOption(value: false, label: offLabel),
    ],
    onChanged: (v) => onChanged(v),
  );
}

// ── skill files + provenance groups（WRK-076 F1/F2 右岛）─────────────────────────

/// One row of the skill file TREE — a pure projection so it unit-tests without pumping UI.
/// dir rows group, file rows navigate; depth = path segment depth (左岛树同款文法)。
/// skill 文件树的一行(纯投影可脱 UI 单测):目录行分组、文件行导航,depth=路径段深。
typedef SkillTreeRow = ({
  String path, // 完整相对路径(文件)或目录路径
  String label, // basename
  int depth,
  bool isDir,
});

/// Flatten the path-sorted file list into tree rows: a directory row is inserted the first
/// time its prefix appears; the manifest pins first. 平列转树行:目录首现插行,清单置顶。
List<SkillTreeRow> buildSkillTreeRows(List<SkillFile> files) {
  final rows = <SkillTreeRow>[];
  final seenDirs = <String>{};
  final sorted = [...files]
    ..sort((a, b) {
      if (a.path == kSkillManifestFileName) return -1;
      if (b.path == kSkillManifestFileName) return 1;
      return a.path.compareTo(b.path);
    });
  for (final f in sorted) {
    final parts = f.path.split('/');
    for (var i = 0; i < parts.length - 1; i++) {
      final dir = parts.sublist(0, i + 1).join('/');
      if (seenDirs.add(dir)) {
        rows.add((path: dir, label: '${parts[i]}/', depth: i, isDir: true));
      }
    }
    rows.add((
      path: f.path,
      label: parts.last,
      depth: parts.length - 1,
      isDir: false,
    ));
  }
  return rows;
}

/// The skill's FILE TREE group (三段式文法 §3, WRK-076 F3) — the skill's project navigator:
/// hierarchical rows (type icon + basename, dir rows group), tap-to-open in the center, the
/// current file highlighted, and a trailing «绑定» section listing the equip-bound entities
/// (fn_/hd_ from allowed-tools) that JUMP to the entities ocean (↗ hints the hop). Hover [⋯]
/// on a file row deletes it (manifest exempt).
///
/// skill 文件树组(三段式 §3,WRK-076 F3)——skill 的项目导航器:层级行(类型 icon+basename,
/// 目录行分组)、点击中心打开、当前文件高亮、尾部「绑定」小节列 equip 实体(点击跳 entities
/// 海洋,↗ 暗示跳走)。文件行 hover [⋯] 删除(清单豁免)。
class _SkillFilesGroup extends ConsumerWidget {
  const _SkillFilesGroup({required this.name});

  final String name;

  Future<void> _deleteFile(
    BuildContext context,
    WidgetRef ref,
    String path,
  ) async {
    final t = context.t;
    final ok = await ref
        .read(overlayProvider.notifier)
        .confirm(
          title: t.library.skillDeleteFileTitle,
          message: t.library.skillDeleteFileBody(path: path),
          confirmLabel: t.action.delete,
          cancelLabel: t.action.cancel,
          barrierLabel: t.feedback.dialogBarrier,
        );
    if (!ok || !context.mounted) return;
    try {
      await ref.read(libraryRepositoryProvider).deleteSkillFile(name, path);
      ref.invalidate(skillFilesProvider(name));
      if (context.mounted && ref.read(selectedSkillFileProvider) == path) {
        context.go(skillLocation(name)); // 删的是打开中的文件 → 回清单
      }
    } catch (_) {
      if (context.mounted) {
        ref
            .read(noticeCenterProvider.notifier)
            .show(context.t.library.actionFailed, tone: AnTone.danger);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final files = ref.watch(skillFilesProvider(name)).value;
    final bindings = ref.watch(skillBindingsProvider(name)).value ?? const [];
    // 单文件且零绑定 → 整组静默缺席(零人话律:一行 SKILL.md 的「树」是噪音)。
    if (files == null || (files.length <= 1 && bindings.isEmpty)) {
      return const SizedBox.shrink();
    }
    final current =
        ref.watch(selectedSkillFileProvider) ?? kSkillManifestFileName;
    final rows = buildSkillTreeRows(files);
    return _GroupSection(
      groupKey: kDocGroupSkillFiles,
      icon: AnIcons.folder,
      label: t.library.skillFiles,
      count: files.length + bindings.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final r in rows)
            if (r.isDir)
              AnRow(depth: r.depth, icon: AnIcons.folder, label: r.label)
            else
              AnRow(
                depth: r.depth,
                icon: skillFileIcon(r.path),
                label: r.label,
                selected: r.path == current,
                onSelect: () => context.go(
                  r.path == kSkillManifestFileName
                      ? skillLocation(name)
                      : skillFileLocation(name, r.path),
                ),
                actions: [
                  if (r.path != kSkillManifestFileName)
                    AnButton.iconOnly(
                      AnIcons.trash,
                      size: AnButtonSize.sm,
                      semanticLabel: t.library.skillDeleteFileTitle,
                      onPressed: () => _deleteFile(context, ref, r.path),
                    ),
                ],
              ),
          if (bindings.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AnSpace.s8,
                AnSpace.s8,
                0,
                AnSpace.s2,
              ),
              child: Text(
                t.library.skillBindings,
                style: AnText.meta.copyWith(color: context.colors.inkFaint),
              ),
            ),
            for (final b in bindings)
              AnRow(
                icon: AnIcons.byKey(b.toKind),
                label: b.toName.isEmpty ? b.toId : b.toName,
                meta: '↗', // 点击跳 entities 海洋(离开本页)的诚实暗示
                onSelect: () {
                  final loc = panelLocationFor(b.toKind, b.toId);
                  if (loc != null) context.go(loc);
                },
              ),
          ],
        ],
      ),
    );
  }
}

/// The PROVENANCE group (installed skills only, WRK-076 B4/F2): where it came from, the trust
/// gate (approve button while pending — AMBER, a power grant the user must see), and the
/// update check (drift → force-confirm dialog). 来源组(仅安装件):出处+信任门(待授权=琥珀按钮)
/// +检查更新(漂移→强制确认)。
class _SkillProvenanceGroup extends ConsumerWidget {
  const _SkillProvenanceGroup({required this.skill});

  final Skill skill;

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(libraryRepositoryProvider);
    try {
      await repo.approveSkillTools(skill.name);
      ref.invalidate(openSkillProvider(skill.name));
      ref.invalidate(skillListProvider);
    } catch (_) {
      if (context.mounted) {
        ref
            .read(noticeCenterProvider.notifier)
            .show(context.t.library.actionFailed, tone: AnTone.danger);
      }
    }
  }

  Future<void> _update(
    BuildContext context,
    WidgetRef ref, {
    required bool force,
  }) async {
    final t = context.t;
    final repo = ref.read(libraryRepositoryProvider);
    try {
      await repo.updateInstalledSkill(skill.name, force: force);
      ref.invalidate(openSkillProvider(skill.name));
      ref.invalidate(skillFilesProvider(skill.name));
      ref.invalidate(skillListProvider);
      if (context.mounted) {
        ref
            .read(noticeCenterProvider.notifier)
            .show(t.library.skillUpdateDone, tone: AnTone.ok);
      }
    } on ApiException catch (e) {
      if (!context.mounted) return;
      if (e.code == 'SKILL_LOCALLY_MODIFIED') {
        final go = await ref
            .read(overlayProvider.notifier)
            .confirm(
              title: t.library.skillCheckUpdate,
              message: t.library.skillLocallyModified,
              confirmLabel: t.library.skillForceUpdate,
              cancelLabel: t.action.cancel,
              barrierLabel: t.feedback.dialogBarrier,
            );
        if (go && context.mounted) {
          await _update(context, ref, force: true);
        }
        return;
      }
      ref
          .read(noticeCenterProvider.notifier)
          .show(context.t.library.actionFailed, tone: AnTone.danger);
    } catch (_) {
      if (context.mounted) {
        ref
            .read(noticeCenterProvider.notifier)
            .show(context.t.library.actionFailed, tone: AnTone.danger);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final c = context.colors;
    final prov = skill.provenance;
    final approved = prov?.toolsApproved ?? false;
    final hasTools = skill.frontmatter.allowedTools.isNotEmpty;
    return _GroupSection(
      groupKey: kDocGroupSkillProvenance,
      icon: AnIcons.download,
      label: t.library.skillProvenance,
      count: hasTools && !approved ? 1 : 0,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // AnKv self-insets s8 — it stays OUTSIDE the pad below. AnKv 自带 s8,置于下方退格外。
          if (prov != null)
            AnKv(
              rows: [
                AnKvRow(
                  t.library.skillInstalledFrom,
                  prov.source,
                  mono: true,
                  wrap: true,
                ),
                if (prov.installedAt != null)
                  AnKvRow(
                    t.library.skillInstalledAt,
                    fmtDateTime(prov.installedAt!),
                  ),
              ],
              dense: true,
            ),
          // The bare status text / chips / buttons carry no inset — pad to the s8 imaginary frame so
          // they align with the AnKv above and the file tree across the panel. 裸件补 s8 对齐行族假想框。
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AnSpace.s8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasTools) ...[
                  const SizedBox(height: AnSpace.s8),
                  // 信任门状态:待授权=琥珀(权力让渡必须可见),已授权=安静陈述。
                  Text(
                    approved
                        ? t.library.skillToolsApproved
                        : t.library.skillToolsPending,
                    style: AnText.meta.copyWith(
                      color: approved ? c.inkFaint : c.warn,
                    ),
                  ),
                  const SizedBox(height: AnSpace.s4),
                  Wrap(
                    spacing: AnSpace.s4,
                    runSpacing: AnSpace.s4,
                    children: [
                      for (final tool in skill.frontmatter.allowedTools)
                        AnChip(
                          tool,
                          tone: approved ? AnTone.none : AnTone.warn,
                        ),
                    ],
                  ),
                  if (!approved) ...[
                    const SizedBox(height: AnSpace.s8),
                    AnButton(
                      label: t.library.skillApproveTools,
                      outline: true,
                      onPressed: () => _approve(context, ref),
                    ),
                  ],
                ],
                const SizedBox(height: AnSpace.s8),
                AnButton(
                  label: t.library.skillCheckUpdate,
                  onPressed: () => _update(context, ref, force: false),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
