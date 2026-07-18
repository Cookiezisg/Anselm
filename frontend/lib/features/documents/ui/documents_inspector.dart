import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/contract/entities/skill.dart';
import '../../../core/model/byte_format.dart';
import '../../../core/model/status_state.dart';
import '../../../core/model/time_format.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/overlay/an_overlay.dart';
import '../../../core/perf/debouncer.dart';
import '../../../core/shell/right_panel.dart';
import '../../../core/ui/an_divider.dart';
import '../../../core/ui/an_kv.dart';
import '../../../core/ui/an_group_label.dart';
import '../../../core/ui/an_dropdown.dart';
import '../../../core/ui/an_form_field.dart';
import '../../../core/ui/an_inspector_head.dart';
import '../../../core/ui/an_input.dart';
import '../../../core/ui/an_row.dart';
import '../../../core/ui/an_scroll_behavior.dart';
import '../../../core/ui/an_skeleton.dart';
import '../../../core/ui/an_state.dart';
import '../../../core/ui/an_tags.dart';
import '../../../core/ui/icons.dart';
import '../../../i18n/strings.g.dart';
import '../data/document_repository.dart';
import '../state/document_state.dart';

/// The Documents ocean's right-island PROPERTIES inspector. A page shows its metadata (name / description /
/// tags, + read-only path·size·modified) saved via **partial PATCH**; a skill shows its frontmatter
/// (description / context / agent / allowed tools / arguments / invocation toggles) saved via **PUT full
/// replace** — the backend has no partial skill update, so every write re-sends the whole frontmatter AND the
/// untouched body (which is why the loaded `body` is carried through). Edits debounce-save through the
/// repository seam; a save invalidates the rail list so a rename shows up there, but NOT the open provider
/// (the form keeps its cursor). No selection → an inset empty state.
///
/// 文档海洋右岛属性面板。页=元数据(name/desc/tags + 只读 path·size·modified)走分部 PATCH;skill=frontmatter
/// (desc/context/agent/工具/参数/调用开关)走 PUT 全覆盖(后端无分部更新,每次重发整套 frontmatter + 原 body)。
/// 编辑去抖保存;存后 invalidate rail 列表(改名可见)但不 invalidate open provider(表单保光标)。无选=空态。
class DocumentsInspector extends ConsumerWidget {
  const DocumentsInspector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sel = ref.watch(selectedDocProvider);
    if (sel == null) {
      return _InspectorShell(
        icon: AnIcons.doc,
        title: context.t.documents.props.title,
        body: AnState(
          kind: AnStateKind.empty,
          size: AnStateSize.inset,
          title: context.t.documents.props.empty,
          hint: context.t.documents.props.emptyHint,
        ),
      );
    }
    return sel.isSkill
        ? _SkillProperties(key: ValueKey('skill:${sel.id}'), name: sel.id)
        : _DocProperties(key: ValueKey(sel.id), id: sel.id);
  }
}

/// The shared inspector chrome — the head band carries the OPEN DOCUMENT'S NAME (the panel is "about this
/// page", not a generic form; ✕ collapses the right island) over a scrolling s16 body whose FIRST section
/// is the live outline. 共享外壳:头带=**打开文档的名字**(面板是「关于此页」,非泛型表单;✕ 收右岛)+ s16 滚动
/// body,**首段=活大纲**。
class _InspectorShell extends ConsumerWidget {
  const _InspectorShell({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnInspectorHead(
          icon: icon,
          label: title,
          onClose: () => ref.read(rightPanelCollapsedProvider.notifier).set(true),
          closeSemantics: context.t.shell.togglePanel,
        ),
        Expanded(
          child: ScrollConfiguration(
            behavior: const AnScrollBehavior(),
            // No horizontal pad — the [AnIsland]'s 12px is the sole island inset (single-source law).
            // 水平 0:岛壳 12 即唯一岛级内距。
            child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: AnSpace.s16), child: body),
          ),
        ),
      ],
    );
  }
}

/// The open document's OUTLINE — its headings as an indented, tappable table of contents (fed live by the
/// editor; a tap scrolls the editor to that heading; the entry the viewport is READING highlights live via
/// [docOutlineActiveProvider]). Quietly absent when the document has no headings.
/// 打开文档的大纲:标题作可点目录(编辑器活喂;点击滚到该标题;**视口正读的项实时高亮**);无标题时静默缺席。
class _OutlineSection extends ConsumerWidget {
  const _OutlineSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outline = ref.watch(docOutlineProvider);
    if (outline.isEmpty) return const SizedBox.shrink();
    final active = ref.watch(docOutlineActiveProvider);
    // Indent RELATIVE to the shallowest heading present — a document whose sections start at h2 reads
    // flush-left, not pre-indented one step. 缩进按最浅层级归一:从 h2 起头的文档顶格,不预缩一级。
    var minLevel = 6;
    for (final e in outline) {
      if (e.level < minLevel) minLevel = e.level;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The ONE group label (批6 A-081 — two hand-rolls with two different gaps unify). 唯一段标。
        AnGroupLabel(context.t.documents.props.outline),
        for (var i = 0; i < outline.length; i++)
          AnRow(
            depth: outline[i].level - minLevel,
            label: outline[i].text,
            leadless: true, // a TOC has no icons — the reserved slot reads as mystery indent 目录无图标,空槽=莫名缩进
            selected: active == i,
            onSelect: () => ref.read(outlineJumpProvider.notifier).jump(i),
          ),
        const SizedBox(height: AnSpace.s12),
        const AnDivider(),
        const SizedBox(height: AnSpace.s12),
      ],
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
    final name = doc.value?.name.trim() ?? '';
    return _InspectorShell(
      icon: AnIcons.doc,
      // The head IS the open page's name (falls back while loading / for the unnamed). 头=页名。
      title: name.isEmpty ? t.documents.untitled : name,
      body: doc.when(
        loading: () => const AnSkeleton.lines(5),
        error: (_, _) =>
            AnState(kind: AnStateKind.error, size: AnStateSize.inset, title: t.documents.loadFailed),
        // The island is "about this page" only: outline (live focus) / file meta / backlinks. The page's
        // OWN properties (name/description/tags) edit in the CENTER under the big title. 右岛只谈「这一页」:
        // 大纲(实时焦点)/文件 meta/反链;页自身属性(名/描述/标签)在中心大标题下编辑。
        data: (doc) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _OutlineSection(),
            // The family KV list (批6 A-082 — the hand-rolled fixed-column label-value retires;
            // the path wraps: a flush-right ellipsis would cut its most useful tail). 族键值列
            // (定宽列手搓退役;path 换行——贴右省略会砍最有用的尾段)。
            AnKv(dense: true, rows: [
              AnKvRow(t.documents.props.path, doc.path, mono: true, wrap: true),
              AnKvRow(t.documents.props.size, formatBytes(doc.sizeBytes)),
              AnKvRow(t.documents.props.modified, fmtDateTime(doc.updatedAt)),
            ]),
            const SizedBox(height: AnSpace.s12),
            const AnDivider(),
            const SizedBox(height: AnSpace.s12),
            _Backlinks(id: doc.id),
          ],
        ),
      ),
    );
  }
}

/// The document's BACKLINKS — pages whose bodies `[[id]]`-wikilink this one (incoming `link` edges, names
/// hydrated server-side). A document row navigates to the linker; non-document linkers (a conversation, a
/// workflow) render inert — their oceans own their navigation. 反向链接:正文 wikilink 指向本页的页面(入向
/// link 边);文档行点击即导航,非文档链接方(对话/工作流)惰性展示——导航归其海洋。
class _Backlinks extends ConsumerWidget {
  const _Backlinks({required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.t;
    final c = context.colors;
    return ref.watch(backlinksProvider(id)).when(
          loading: () => const AnSkeleton.lines(2),
          error: (_, _) => const SizedBox.shrink(), // quiet: backlinks are auxiliary 反链是辅助信息,静默降级
          data: (links) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnGroupLabel(t.documents.props.backlinks),
              if (links.isEmpty)
                Text(t.documents.props.noBacklinks, style: AnText.meta.copyWith(color: c.inkFaint))
              else
                for (final link in links)
                  AnRow(
                    icon: AnIcons.byKey(link.fromKind),
                    label: link.fromName.isEmpty ? link.fromId : link.fromName,
                    onSelect: link.fromKind == 'document'
                        ? () => context.go(documentLocation(link.fromId))
                        : null,
                  ),
            ],
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
    return _InspectorShell(
      icon: AnIcons.skill,
      // The slug IS the identity — the head shows it directly. slug 即身份,头直显。
      title: name,
      body: ref.watch(openSkillProvider(name)).when(
            loading: () => const AnSkeleton.lines(6),
            error: (_, _) =>
                AnState(kind: AnStateKind.error, size: AnStateSize.inset, title: t.documents.loadFailed),
            data: (skill) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _OutlineSection(),
                _SkillForm(key: ValueKey(skill.name), skill: skill),
              ],
            ),
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

  DocumentsRepository get _repo => ref.read(documentsRepositoryProvider);

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
          if (mounted) ref.read(overlayProvider.notifier).showToast(context.t.documents.actionFailed, tone: AnTone.danger);
        }
      });

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final p = t.documents.props;
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
              AnDropdownOption(value: kSkillContextInline, label: p.contextInline),
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
            child: AnInput(controller: _agent, block: true, onChanged: (_) => _put()),
          ),
        _Field(
          label: p.tools,
          child: AnTags(
            tags: [for (final tool in _tools) AnTag(tool)],
            placeholder: p.addTool,
            onChanged: (tags) {
              setState(() => _tools = [for (final tag in tags) tag.label]);
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
  const _OnOff({required this.value, required this.onChanged, required this.onLabel, required this.offLabel});

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



