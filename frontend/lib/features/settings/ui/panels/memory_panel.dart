import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/contract/api_error.dart';
import '../../../../core/contract/memory.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/model/time_format.dart';
import '../../../../core/ui/ui.dart';
import '../../../../i18n/strings.g.dart';
import '../../state/memories_provider.dart';
import '../../state/settings_detail_provider.dart';

/// ⑥ 记忆 (WRK-062 §3, S4): the file-backed memory roster — pinned filter, inline pin toggle (the
/// gold pin rides every conversation's context), the pushed-in editor (the slug name is the
/// filename: validated at create, LOCKED on edit; the update PUT never sends pinned/source, F147),
/// and confirm-to-delete (a physical file delete). 记忆面板:名册(固定过滤+行内金 pin)/推入编辑
/// (slug 建时校验、编辑锁死;更新绝不送 pinned/source)/确认删除(物理删文件)。
class MemoryPanel extends ConsumerWidget {
  const MemoryPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(settingsDetailProvider);
    if (detail != null && (detail.kind == 'memory' || detail.kind == 'addMemory')) {
      return MemoryEditor(
          name: detail.kind == 'memory' ? detail.id : null,
          key: ValueKey(detail.id ?? '+new'));
    }
    return const _Roster();
  }
}

/// The create-time slug rule (the backend's, mirrored for instant feedback). 建名规则(镜像后端)。
final memoryNameRule = RegExp(r'^[a-z][a-z0-9_-]{0,63}$');

class _Roster extends ConsumerStatefulWidget {
  const _Roster();

  @override
  ConsumerState<_Roster> createState() => _RosterState();
}

class _RosterState extends ConsumerState<_Roster> {
  bool _pinnedOnly = false;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    final all = ref.watch(memoriesProvider).value ?? const <Memory>[];
    final empty = all.isEmpty;
    final rows = all
        .where((m) => !_pinnedOnly || m.pinned)
        .where((m) =>
            _query.isEmpty ||
            m.name.contains(_query.toLowerCase()) ||
            m.description.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          // With zero memories the pinned filter + search are noise (nothing to narrow) — they
          // retire (零计数律, MCP 空态先例), leaving the New button as the sole add entry and the
          // guiding lead below to carry the panel (空态穿目标形态律). 零记忆时过滤/搜索退役,新建钮独任入口。
          if (!empty) ...[
            SizedBox(
              width: AnSize.ctlSlot,
              child: AnSegmented<bool>(
                options: [
                  AnSegmentedOption(value: false, label: t.settings.mem.filterAll),
                  AnSegmentedOption(value: true, label: t.settings.mem.filterPinned),
                ],
                value: _pinnedOnly,
                onChanged: (v) => setState(() => _pinnedOnly = v),
              ),
            ),
            const SizedBox(width: AnSpace.s12),
            Expanded(
              child: AnInput(
                placeholder: t.settings.mem.searchHint,
                onChanged: (v) => setState(() => _query = v.trim()),
              ),
            ),
            const SizedBox(width: AnSpace.s12),
          ] else
            const Spacer(),
          AnButton(
            label: t.settings.mem.newMemory,
            icon: AnIcons.plus,
            size: AnButtonSize.sm,
            outline: true,
            onPressed: () => ref.read(settingsDetailProvider.notifier).push('addMemory'),
          ),
        ]),
        const SizedBox(height: AnSpace.s16),
        if (empty)
          // A quiet invitation, NOT a «No memories yet» tombstone — the New button above IS the add
          // entry it points at (空态穿目标形态律 + 零人话律). 安静引导句(非墓碑);上方新建钮即其指向的入口。
          Text(t.settings.mem.emptyLead, style: AnText.label.copyWith(color: c.inkMuted))
        else if (rows.isEmpty)
          // A populated roster whose filter/search matched nothing — say so, don't render a void.
          // 名册非空但过滤/搜索无命中:诚实说明,不留空白。
          AnState(
            kind: AnStateKind.empty,
            title: t.settings.mem.noMatches,
            size: AnStateSize.inset,
          )
        else
          for (final m in rows) _MemoryRow(m: m),
      ],
    );
  }
}

class _MemoryRow extends ConsumerWidget {
  const _MemoryRow({required this.m});

  final Memory m;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Translations.of(context);
    final c = context.colors;
    // The pin rides the lead slot (批6c A-060 — the inline labelWidget Row retires); the
    // description becomes the wrapping hint, the same face as the MCP tool rows. The pin is a real
    // control — AnInteractive (keyboard focus + Enter/Space + button semantics) with the toggled
    // state folded in, NOT a bare GestureDetector (批5 缩略图 ✕ 立法; setPinned 全仓唯一入口在此,
    // 键盘不可达=功能锁死). pin 进 lead 槽;描述走 hint 换行(与 mcp 工具行同脸);pin 是真控件。
    return AnRow(
      leadWidget: AnTooltip(
        message: t.settings.mem.pinTip,
        child: MergeSemantics(
          child: Semantics(
            toggled: m.pinned,
            label: t.settings.mem.pinTip,
            child: AnInteractive(
              onTap: () => ref.read(memoriesProvider.notifier).setPinned(m.name, !m.pinned),
              builder: (ctx, states) => Icon(AnIcons.pin,
                  size: AnSize.icon,
                  color: m.pinned ? c.warn : (states.isActive ? c.inkMuted : c.inkFaint)),
            ),
          ),
        ),
      ),
      mono: true,
      hint: m.description.isEmpty ? null : m.description,
      label: m.name,
      meta:
          '${m.source == 'ai' ? t.settings.mem.sourceAi : t.settings.mem.sourceUser} · ${fmtDate(m.updatedAt)}',
      onSelect: () =>
          ref.read(settingsDetailProvider.notifier).push('memory', id: m.name),
      actions: [
        AnButton(
          label: t.settings.mem.confirmDelete,
          size: AnButtonSize.sm,
          variant: AnButtonVariant.danger,
          onPressed: () => _delete(context, ref),
        ),
      ],
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final t = Translations.of(context);
    final ok = await ref.read(overlayProvider.notifier).confirm(
          title: t.settings.mem.deleteTitle,
          message: t.settings.mem.deleteBody(name: m.name),
          confirmLabel: t.settings.mem.confirmDelete,
          cancelLabel: t.settings.keys.cancel,
          barrierLabel: t.settings.mem.deleteTitle,
        );
    if (!ok) return;
    try {
      await ref.read(memoriesProvider.notifier).remove(m.name);
    } on ApiException catch (e) {
      ref.read(noticeCenterProvider.notifier).show(e.message, tone: AnTone.danger);
    }
  }

}

/// The pushed-in editor. Create validates the slug live; edit LOCKS the name (it is the filename).
/// A dirty back-out asks first. 推入编辑:建时活校验 slug;编辑锁名;脏返回先问。
class MemoryEditor extends ConsumerStatefulWidget {
  const MemoryEditor({this.name, super.key});

  /// null = create. null=新建。
  final String? name;

  @override
  ConsumerState<MemoryEditor> createState() => _MemoryEditorState();
}

class _MemoryEditorState extends ConsumerState<MemoryEditor> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _desc = TextEditingController();
  final TextEditingController _content = TextEditingController();
  bool _hydrated = false;
  bool _dirty = false;
  bool _saving = false;
  // Create-only pin choice: a new memory can be pinned in one step. On an existing row the backend
  // ignores body pinned (F147) and the roster's inline toggle owns it, so the field is hidden on edit.
  // 仅创建时的 pin 选择:新记忆可一步置顶。既有行后端忽略 body pinned(F147)、由名册行内 toggle 掌管,故编辑时不渲。
  bool _pinned = false;
  String? _error;

  bool get _creating => widget.name == null;

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _creating ? _name.text.trim() : widget.name!;
    if (_saving) return;
    if (_creating && !memoryNameRule.hasMatch(name)) {
      setState(() => _error = Translations.of(context).settings.mem.invalidName);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(memoriesProvider.notifier).put(name,
          description: _desc.text.trim(),
          content: _content.text,
          // pinned only bites at create; an edit's put ignores it server-side (F147). pin 仅建时生效。
          pinned: _creating && _pinned);
      if (mounted) ref.read(settingsDetailProvider.notifier).pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _back() async {
    final t = Translations.of(context);
    if (!_dirty) {
      ref.read(settingsDetailProvider.notifier).pop();
      return;
    }
    final discard = await ref.read(overlayProvider.notifier).confirm(
          title: t.settings.mem.dirtyTitle,
          message: t.settings.mem.dirtyBody,
          confirmLabel: t.settings.mem.discard,
          cancelLabel: t.settings.mem.keepEditing,
          barrierLabel: t.settings.mem.dirtyTitle,
        );
    if (discard && mounted) ref.read(settingsDetailProvider.notifier).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    if (!_creating && !_hydrated) {
      final row = (ref.read(memoriesProvider).value ?? const <Memory>[])
          .where((m) => m.name == widget.name)
          .firstOrNull;
      _name.text = widget.name!;
      _desc.text = row?.description ?? '';
      _content.text = row?.content ?? '';
      _hydrated = true;
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AnSize.formMaxWidthWide),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // The ONE form block ×3 (批6c A-061); the Cmd+S shortcut stays wrapped TIGHT around the
        // content input (scout 风险注记). 唯一表单字段块×3;Cmd+S 贴身包不动。
        AnFormField(
          label: t.settings.mem.name,
          child: _creating
              ? AnInput(
                  controller: _name,
                  placeholder: t.settings.mem.nameHint,
                  mono: true,
                  autofocus: true,
                  onChanged: (_) => setState(() => _dirty = true),
                )
              : AnTooltip(
                  message: t.settings.mem.nameLocked,
                  child: AnInput(controller: _name, mono: true, enabled: false),
                ),
        ),
        const SizedBox(height: AnSpace.s12),
        AnFormField(
          label: t.settings.mem.description,
          child: AnInput(controller: _desc, onChanged: (_) => setState(() => _dirty = true)),
        ),
        const SizedBox(height: AnSpace.s12),
        AnFormField(
          label: t.settings.mem.content,
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _save,
            },
            child: AnInput(
              controller: _content,
              multiline: true,
              mono: true,
              onChanged: (_) => setState(() => _dirty = true),
            ),
          ),
        ),
        if (_creating) ...[
          const SizedBox(height: AnSpace.s12),
          // Create-only: pin the new memory to every conversation in one step (settings form-row
          // grammar — horizontal label + hint + trailing switch). 仅建时:一步置顶新记忆(设置表单行文法)。
          AnField(
            label: t.settings.mem.pinned,
            hint: t.settings.mem.pinTip,
            child: AnSwitch(
              value: _pinned,
              onChanged: (v) => setState(() {
                _pinned = v;
                _dirty = true;
              }),
              semanticLabel: t.settings.mem.pinTip,
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: AnSpace.s8),
          Text(_error!, style: AnText.label.copyWith(color: c.danger)),
        ],
        const SizedBox(height: AnSpace.s16),
        Row(children: [
          AnButton(
            label: t.settings.mem.save,
            variant: AnButtonVariant.primary,
            onPressed: _saving || (_creating && _name.text.trim().isEmpty) ? null : _save,
          ),
          const SizedBox(width: AnSpace.s8),
          AnButton(label: t.settings.keys.cancel, onPressed: _back),
        ]),
      ]),
    );
  }
}
