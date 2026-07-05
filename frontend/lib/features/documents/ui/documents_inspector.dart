import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/contract/entities/document.dart';
import '../../../core/contract/entities/skill.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/overlay/an_overlay.dart';
import '../../../core/perf/debouncer.dart';
import '../../../core/shell/right_panel.dart';
import '../../../core/ui/an_button.dart';
import '../../../core/ui/an_divider.dart';
import '../../../core/ui/an_dropdown.dart';
import '../../../core/ui/an_form_field.dart';
import '../../../core/ui/an_inspector_head.dart';
import '../../../core/ui/an_input.dart';
import '../../../core/ui/an_row.dart';
import '../../../core/ui/an_scroll_behavior.dart';
import '../../../core/ui/an_skeleton.dart';
import '../../../core/ui/an_state.dart';
import '../../../core/ui/an_tags.dart';
import '../../../core/ui/an_toast.dart';
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
          title: title,
          trailing: AnButton.iconOnly(
            AnIcons.close,
            semanticLabel: context.t.shell.togglePanel,
            onPressed: () => ref.read(rightPanelCollapsedProvider.notifier).set(true),
          ),
        ),
        const AnDivider(),
        Expanded(
          child: ScrollConfiguration(
            behavior: const AnScrollBehavior(),
            child: SingleChildScrollView(padding: const EdgeInsets.all(AnSpace.s16), child: body),
          ),
        ),
      ],
    );
  }
}

/// The open document's OUTLINE — its headings as an indented, tappable table of contents (fed live by the
/// editor; a tap scrolls the editor to that heading). Quietly absent when the document has no headings.
/// 打开文档的大纲:标题作可点目录(编辑器活喂;点击滚到该标题);无标题时静默缺席。
class _OutlineSection extends ConsumerWidget {
  const _OutlineSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outline = ref.watch(docOutlineProvider);
    if (outline.isEmpty) return const SizedBox.shrink();
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.t.documents.props.outline,
            style: AnText.meta.weight(AnText.emphasisWeight).copyWith(color: c.inkFaint)),
        const SizedBox(height: AnGap.stackTight),
        for (var i = 0; i < outline.length; i++)
          AnRow(
            depth: outline[i].level - 1,
            label: outline[i].text,
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
        data: (doc) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _OutlineSection(),
            _DocForm(key: ValueKey(doc.id), doc: doc),
          ],
        ),
      ),
    );
  }
}

class _DocForm extends ConsumerStatefulWidget {
  const _DocForm({required this.doc, super.key});

  final DocumentNode doc;

  @override
  ConsumerState<_DocForm> createState() => _DocFormState();
}

class _DocFormState extends ConsumerState<_DocForm> {
  late final TextEditingController _name;
  late final TextEditingController _desc;
  late List<String> _tags;
  final _save = Debouncer(const Duration(milliseconds: 500));

  DocumentsRepository get _repo => ref.read(documentsRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.doc.name);
    _desc = TextEditingController(text: widget.doc.description);
    _tags = [...widget.doc.tags];
  }

  @override
  void dispose() {
    _save.dispose();
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  // A partial PATCH; on success refresh the rail (a rename must show there). Content lives in the editor, not
  // here. 分部 PATCH;成功刷 rail(改名要现);正文归编辑器、不在此。
  Future<void> _patch(Map<String, dynamic> fields) async {
    try {
      await _repo.updateDocument(widget.doc.id, fields);
      if (!mounted) return;
      ref.invalidate(documentTreeProvider);
    } catch (_) {
      if (mounted) ref.read(overlayProvider.notifier).showToast(context.t.documents.actionFailed, tone: AnToastTone.danger);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final p = t.documents.props;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Field(
          label: p.name,
          child: AnInput(
            controller: _name,
            block: true,
            onChanged: (v) => _save.run(() => _patch({'name': v.trim()})),
          ),
        ),
        _Field(
          label: p.description,
          child: AnInput(
            controller: _desc,
            block: true,
            multiline: true,
            onChanged: (v) => _save.run(() => _patch({'description': v})),
          ),
        ),
        _Field(
          label: p.tags,
          child: AnTags(
            tags: [for (final tag in _tags) AnTag(tag)],
            placeholder: p.addTag,
            onChanged: (tags) {
              setState(() => _tags = [for (final tag in tags) tag.label]);
              _patch({'tags': _tags});
            },
          ),
        ),
        const AnDivider(),
        const SizedBox(height: AnSpace.s12),
        _MetaRow(label: p.path, value: widget.doc.path),
        _MetaRow(label: p.size, value: _fmtSize(widget.doc.sizeBytes)),
        _MetaRow(label: p.modified, value: _fmtDate(widget.doc.updatedAt)),
        const SizedBox(height: AnSpace.s12),
        const AnDivider(),
        const SizedBox(height: AnSpace.s12),
        _Backlinks(id: widget.doc.id),
      ],
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
              Text(t.documents.props.backlinks,
                  style: AnText.meta.weight(AnText.emphasisWeight).copyWith(color: c.inkFaint)),
              const SizedBox(height: AnGap.stack),
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

/// A read-only meta line (faint label · value), for path/size/modified. 只读 meta 行(淡标签·值)。
class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: AnGap.stackTight),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 72, child: Text(label, style: AnText.meta.copyWith(color: c.inkFaint))),
          Expanded(
            child: Text(value.isEmpty ? '—' : value, style: AnText.meta.copyWith(color: c.inkMuted)),
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
  late final TextEditingController _desc;
  late final TextEditingController _agent;
  late String _context;
  late List<String> _tools;
  late List<String> _args;
  late bool _disableModelInvocation;
  late bool _userInvocable;
  final _save = Debouncer(const Duration(milliseconds: 500));

  DocumentsRepository get _repo => ref.read(documentsRepositoryProvider);

  @override
  void initState() {
    super.initState();
    final f = widget.skill.frontmatter;
    _desc = TextEditingController(text: widget.skill.description);
    _agent = TextEditingController(text: f.agent);
    _context = f.context.isEmpty ? kSkillContextInline : f.context;
    _tools = [...f.allowedTools];
    _args = [...f.arguments];
    _disableModelInvocation = f.disableModelInvocation;
    _userInvocable = f.userInvocable;
  }

  @override
  void dispose() {
    _save.dispose();
    _desc.dispose();
    _agent.dispose();
    super.dispose();
  }

  // A skill write is a PUT of the WHOLE frontmatter, and the body must ride along or the full-replace
  // resets it. READ-MODIFY-WRITE: fetch the CURRENT body right before the PUT — the center editor may
  // have saved a newer body than this form's mount-time snapshot (two writers, one document). 整套 PUT;
  // body 读-改-写:PUT 前取**当前** body——中心编辑器可能已存了比本表单快照更新的正文(双写者一文档)。
  void _put() => _save.run(() async {
        try {
          final current = await _repo.getSkill(widget.skill.name);
          await _repo.replaceSkill(widget.skill.name, {
            'description': _desc.text.trim(),
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
          if (mounted) ref.read(overlayProvider.notifier).showToast(context.t.documents.actionFailed, tone: AnToastTone.danger);
        }
      });

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final p = t.documents.props;
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Name is the slug/identity — read-only (renaming = create + delete, not offered here). name=slug 只读。
        _Field(
          label: p.name,
          child: Text(widget.skill.name, style: AnText.body.weight(AnText.emphasisWeight).copyWith(color: c.ink)),
        ),
        _Field(
          label: p.description,
          child: AnInput(controller: _desc, block: true, multiline: true, onChanged: (_) => _put()),
        ),
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

String _fmtSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
  return '${(kb / 1024).toStringAsFixed(1)} MB';
}

String _fmtDate(DateTime d) {
  String two(int n) => n.toString().padLeft(2, '0');
  final l = d.toLocal();
  return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
}
