import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/contract/workspace.dart';
import '../../../../core/contract/api_error.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/model/byte_format.dart';
import '../../../../core/runtime.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/workspace/workspace_switch.dart';
import '../../../../i18n/strings.g.dart';
import '../../state/settings_detail_provider.dart';
import '../../state/workspaces_provider.dart';

/// ⑧ 工作区 (WRK-062 §3, S3): the roster (active row highlighted, row click SWITCHES — the first
/// consumer of the S3-pre hot-switch cascade), create, and the pushed-in editor whose page tail is
/// the distributed danger zone (拍板 #5): AnTypeToConfirm armed with the REAL inventory numbers
/// (S-11) and the dynamic hazard lines. The active workspace and the last workspace never offer
/// delete. 工作区面板:名册(当前高亮,点行=切换——S3-pre 热切换的第一个消费者)/新建/推入编辑页,
/// 页尾=分布式危险区(真数字+动态警示);当前与最后一个不给删。
class WorkspacesPanel extends ConsumerWidget {
  const WorkspacesPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(settingsDetailProvider);
    if (detail != null && detail.kind == 'workspace' && detail.id != null) {
      return WorkspaceEditor(id: detail.id!, key: ValueKey(detail.id));
    }
    if (detail != null && detail.kind == 'addWorkspace') {
      return const _CreateForm();
    }
    return const _Roster();
  }
}

class _Roster extends ConsumerWidget {
  const _Roster();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Translations.of(context);
    final rows = ref.watch(workspacesProvider).value ?? const <Workspace>[];
    final active = ref.watch(activeWorkspaceProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnSection(
          label: t.settings.ws.section,
          variant: AnSectionVariant.quiet,
          actions: [
            AnButton(
              label: t.settings.ws.newWorkspace,
              icon: AnIcons.plus,
              size: AnButtonSize.sm,
              onPressed: () =>
                  ref.read(settingsDetailProvider.notifier).push('addWorkspace'),
            ),
          ],
          children: [
            for (final w in rows)
              AnRow(
                leadless: true,
                labelWidget: Row(mainAxisSize: MainAxisSize.min, children: [
                  AnSwatch(parseHexColor(w.avatarColor, context.colors.accent), size: AnSwatchSize.dot),
                  const SizedBox(width: AnSpace.s8),
                  Text(w.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AnText.body.copyWith(color: context.colors.ink)),
                ]),
                label: w.name,
                selected: w.id == active,
                meta: w.id == active ? t.settings.ws.current : '',
                // Row click = SWITCH (the hot-switch action); the active row re-selects as a no-op.
                // 点行=切换(热切换动作);当前行点了=无操作。
                onSelect: () =>
                    ref.read(workspaceSwitchProvider).switchTo(id: w.id, name: w.name),
                actions: [
                  AnButton(
                    label: t.settings.ws.edit,
                    size: AnButtonSize.sm,
                    onPressed: () => ref
                        .read(settingsDetailProvider.notifier)
                        .push('workspace', id: w.id),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}


class _CreateForm extends ConsumerStatefulWidget {
  const _CreateForm();

  @override
  ConsumerState<_CreateForm> createState() => _CreateFormState();
}

class _CreateFormState extends ConsumerState<_CreateForm> {
  final TextEditingController _name = TextEditingController();
  String _color = kAvatarPalette.first;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_saving || _name.text.trim().isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(workspacesProvider.notifier)
          .create(name: _name.text.trim(), avatarColor: _color);
      if (mounted) ref.read(settingsDetailProvider.notifier).pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AnFormField(label: t.settings.ws.name, child: AnInput(controller: _name, autofocus: true, onChanged: (_) => setState(() {}))),
        const SizedBox(height: AnSpace.s12),
        AnFormField(label: t.settings.ws.color, child: _ColorPicker(value: _color, onChanged: (v) => setState(() => _color = v))),
        if (_error != null) ...[
          const SizedBox(height: AnSpace.s8),
          Text(_error!, style: AnText.label.copyWith(color: c.danger)),
        ],
        const SizedBox(height: AnSpace.s16),
        Row(children: [
          AnButton(
            label: t.settings.ws.create,
            variant: AnButtonVariant.primary,
            onPressed: _saving || _name.text.trim().isEmpty ? null : _create,
          ),
          const SizedBox(width: AnSpace.s8),
          AnButton(
            label: t.settings.keys.cancel,
            onPressed: () => ref.read(settingsDetailProvider.notifier).pop(),
          ),
        ]),
      ]),
    );
  }
}

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Family swatch cells (批5c A-028 — the hand-rolled 22×22 discs retire). 族色板格。
    return Row(children: [
      for (final hex in kAvatarPalette)
        Padding(
          padding: const EdgeInsets.only(right: AnSpace.s8),
          child: AnSwatch(parseHexColor(hex, c.accent), selected: value == hex, onTap: () => onChanged(hex)),
        ),
    ]);
  }
}

/// The pushed-in editor: rename + recolor, and the danger zone at the page tail (active/last rows
/// never see it). 推入编辑页:改名改色+页尾危险区(当前/最后一个没有)。
class WorkspaceEditor extends ConsumerStatefulWidget {
  const WorkspaceEditor({required this.id, super.key});

  final String id;

  @override
  ConsumerState<WorkspaceEditor> createState() => _WorkspaceEditorState();
}

class _WorkspaceEditorState extends ConsumerState<WorkspaceEditor> {
  final TextEditingController _name = TextEditingController();
  bool _hydrated = false;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _saveName(Workspace w) async {
    final name = _name.text.trim();
    if (_busy || name.isEmpty || name == w.name) return;
    setState(() => _busy = true);
    try {
      await ref.read(workspacesProvider.notifier).rename(w.id, name);
    } on ApiException catch (e) {
      ref.read(overlayProvider.notifier).showToast(e.message, tone: AnTone.danger);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(Workspace w) async {
    if (_busy) return;
    setState(() => _busy = true);
    final t = Translations.of(context);
    try {
      await ref.read(workspacesProvider.notifier).remove(w.id);
      if (mounted) ref.read(settingsDetailProvider.notifier).pop();
    } on ApiException catch (e) {
      // Stay put + refetch — never auto-switch after a failed delete (S-11). 失败留在原地+重取。
      ref.invalidate(workspacesProvider);
      ref
          .read(overlayProvider.notifier)
          .showToast('${t.settings.ws.deleteFailed} · ${e.message}', tone: AnTone.danger);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    final rows = ref.watch(workspacesProvider).value ?? const <Workspace>[];
    final w = rows.where((r) => r.id == widget.id).firstOrNull;
    if (w == null) return const SizedBox.shrink();
    if (!_hydrated) {
      _name.text = w.name;
      _hydrated = true;
    }
    final active = ref.watch(activeWorkspaceProvider);
    final deletable = w.id != active && rows.length > 1;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AnFormField(label: t.settings.ws.name, child: AnInput(
            controller: _name,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _saveName(w))),
        const SizedBox(height: AnSpace.s12),
        AnFormField(label: t.settings.ws.color, child: _ColorPicker(
          value: w.avatarColor ?? '',
          onChanged: (v) async {
            try {
              await ref.read(workspacesProvider.notifier).recolor(w.id, v);
            } on ApiException catch (e) {
              ref
                  .read(overlayProvider.notifier)
                  .showToast(e.message, tone: AnTone.danger);
            }
          },
        )),
        const SizedBox(height: AnSpace.s16),
        AnButton(
          label: t.settings.ws.save,
          variant: AnButtonVariant.primary,
          onPressed:
              _busy || _name.text.trim().isEmpty || _name.text.trim() == w.name
                  ? null
                  : () => _saveName(w),
        ),
        if (deletable) ...[
          const SizedBox(height: AnSpace.s32),
          _DangerZone(w: w, busy: _busy, onDelete: () => _delete(w)),
        ] else ...[
          const SizedBox(height: AnSpace.s32),
          Text(w.id == active ? t.settings.ws.current : t.settings.ws.lastOne,
              style: AnText.label.copyWith(color: c.inkFaint)),
        ],
      ]),
    );
  }
}

class _DangerZone extends ConsumerWidget {
  const _DangerZone({required this.w, required this.busy, required this.onDelete});

  final Workspace w;
  final bool busy;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Translations.of(context);
    final c = context.colors;
    final stats = ref.watch(workspaceStatsProvider(w.id)).value;

    final String? warning;
    if (stats == null) {
      warning = null;
    } else if (stats.runningFlowruns > 0) {
      warning = t.settings.ws.runningWarn(n: stats.runningFlowruns);
    } else if (stats.generatingConversations > 0) {
      warning = t.settings.ws.generatingWarn(n: stats.generatingConversations);
    } else {
      warning = null;
    }

    final body = stats == null
        ? Text(t.settings.ws.statsLoading, style: AnText.label.copyWith(color: c.inkMuted))
        : Text(
            t.settings.ws.dangerBody(
              name: w.name,
              conversations: stats.conversations,
              entities:
                  stats.functions + stats.handlers + stats.agents + stats.workflows,
              documents: stats.documents,
              blob: stats.blobBytes < 0
                  ? t.settings.ws.blobUnknown
                  : formatBytes(stats.blobBytes),
            ),
            style: AnText.label.copyWith(color: c.inkMuted),
          );

    return AnTypeToConfirm(
      title: t.settings.ws.dangerTitle,
      warning: warning,
      body: body,
      expected: w.name,
      inputHint: t.settings.ws.typeNameHint(name: w.name),
      confirmLabel: t.settings.ws.confirmDelete,
      busy: busy,
      onConfirm: onDelete,
    );
  }
}
