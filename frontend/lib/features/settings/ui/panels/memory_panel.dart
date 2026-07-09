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
    final all = ref.watch(memoriesProvider).value ?? const <Memory>[];
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
          SizedBox(
            width: 200,
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
          AnButton(
            label: t.settings.mem.newMemory,
            icon: AnIcons.plus,
            size: AnButtonSize.sm,
            onPressed: () => ref.read(settingsDetailProvider.notifier).push('addMemory'),
          ),
        ]),
        const SizedBox(height: AnSpace.s16),
        if (all.isEmpty)
          AnState(
            kind: AnStateKind.empty,
            title: t.settings.mem.empty,
            hint: t.settings.mem.emptyHint,
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
    return AnRow(
      leadless: true,
      labelWidget: Row(mainAxisSize: MainAxisSize.min, children: [
        // The pin — gold when resident, hollow otherwise; a tooltip'd one-tap toggle. 金 pin 常驻标。
        AnTooltip(
          message: t.settings.mem.pinTip,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () =>
                ref.read(memoriesProvider.notifier).setPinned(m.name, !m.pinned),
            child: Icon(AnIcons.pin,
                size: AnSize.icon, color: m.pinned ? c.warn : c.inkFaint),
          ),
        ),
        const SizedBox(width: AnSpace.s8),
        Text(m.name, style: AnText.mono.copyWith(color: c.ink)),
        if (m.description.isNotEmpty) ...[
          const SizedBox(width: AnSpace.s8),
          Flexible(
            child: Text(m.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AnText.label.copyWith(color: c.inkMuted)),
          ),
        ],
      ]),
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
      ref.read(overlayProvider.notifier).showToast(e.message, tone: AnToastTone.danger);
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
      await ref
          .read(memoriesProvider.notifier)
          .put(name, description: _desc.text.trim(), content: _content.text);
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
      constraints: const BoxConstraints(maxWidth: 640),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t.settings.mem.name, style: AnText.label.copyWith(color: c.inkMuted)),
        const SizedBox(height: AnSpace.s4),
        if (_creating)
          AnInput(
            controller: _name,
            placeholder: t.settings.mem.nameHint,
            mono: true,
            autofocus: true,
            onChanged: (_) => setState(() => _dirty = true),
          )
        else
          AnTooltip(
            message: t.settings.mem.nameLocked,
            child: AnInput(controller: _name, mono: true, enabled: false),
          ),
        const SizedBox(height: AnSpace.s12),
        Text(t.settings.mem.description, style: AnText.label.copyWith(color: c.inkMuted)),
        const SizedBox(height: AnSpace.s4),
        AnInput(
            controller: _desc, onChanged: (_) => setState(() => _dirty = true)),
        const SizedBox(height: AnSpace.s12),
        Text(t.settings.mem.content, style: AnText.label.copyWith(color: c.inkMuted)),
        const SizedBox(height: AnSpace.s4),
        CallbackShortcuts(
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
