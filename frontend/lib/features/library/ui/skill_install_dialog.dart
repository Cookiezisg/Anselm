import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contract/entities/skill.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/model/status_state.dart';
import '../../../core/notice/notice_center.dart';
import '../../../core/ui/an_button.dart';
import '../../../core/ui/an_card.dart';
import '../../../core/ui/an_chip.dart';
import '../../../core/ui/an_input.dart';
import '../../../core/ui/an_switch.dart';
import '../../../core/ui/an_state.dart';
import '../../../i18n/strings.g.dart';
import '../data/library_repository.dart';
import '../state/library_state.dart';

/// The install-from-source flow (WRK-076 F2): paste a source → inspect → pick candidates with
/// their allowed-tools SHOWN UP FRONT (the trust gate starts here) → install. Mirrors the MCP
/// wiring体验. Renders as a centered panel inside an overlay barrier.
/// 从来源安装流:粘来源→解析→勾选候选(allowedTools 前置=信任门起点)→装。镜像 MCP 接线体验。
class SkillInstallDialog extends ConsumerStatefulWidget {
  const SkillInstallDialog({super.key});

  @override
  ConsumerState<SkillInstallDialog> createState() => _SkillInstallDialogState();
}

class _SkillInstallDialogState extends ConsumerState<SkillInstallDialog> {
  final _sourceCtl = TextEditingController();
  List<SkillInstallPreview>? _previews;
  final Set<String> _picked = {};
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _sourceCtl.dispose();
    super.dispose();
  }

  Future<void> _inspect() async {
    final src = _sourceCtl.text.trim();
    if (src.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _previews = null;
    });
    try {
      final previews = await ref
          .read(libraryRepositoryProvider)
          .inspectSkillSource(src);
      setState(() {
        _previews = previews;
        _picked
          ..clear()
          ..addAll(previews.where((p) => p.installable).map((p) => p.name));
      });
    } catch (e) {
      setState(() => _error = _reason(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _install() async {
    final src = _sourceCtl.text.trim();
    if (_picked.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await ref
          .read(libraryRepositoryProvider)
          .installSkills(src, names: _picked.toList());
      ref.invalidate(skillListProvider);
      if (!mounted) return;
      final t = context.t;
      ref
          .read(noticeCenterProvider.notifier)
          .show(
            res.installed.isEmpty
                ? t.library.skillInstallNone
                : t.library.skillInstallDone,
            tone: res.installed.isEmpty ? AnTone.warn : AnTone.ok,
          );
      Navigator.of(context).maybePop();
    } catch (e) {
      setState(() => _error = _reason(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _reason(Object e) {
    final m = e.toString();
    final i = m.lastIndexOf(': ');
    return i >= 0 && i + 2 < m.length ? m.substring(i + 2) : m;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    final c = context.colors;
    final previews = _previews;
    return Center(
      child: SizedBox(
        width: 520,
        child: AnCard(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(t.library.skillInstallTitle, style: AnText.h3),
                const SizedBox(height: AnSpace.s12),
                Row(
                  children: [
                    Expanded(
                      child: AnInput(
                        controller: _sourceCtl,
                        placeholder: t.library.skillInstallHint,
                        onSubmitted: (_) => _inspect(),
                      ),
                    ),
                    const SizedBox(width: AnSpace.s8),
                    AnButton(
                      label: t.library.skillInstallInspect,
                      onPressed: _busy ? null : _inspect,
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: AnSpace.s8),
                  Text(_error!, style: AnText.meta.copyWith(color: c.danger)),
                ],
                const SizedBox(height: AnSpace.s12),
                Flexible(
                  child: previews == null
                      ? const SizedBox.shrink()
                      : previews.isEmpty
                      ? AnState(
                          kind: AnStateKind.empty,
                          title: t.library.skillInstallNone,
                        )
                      : ListView(
                          shrinkWrap: true,
                          children: [
                            for (final p in previews)
                              _candidateTile(context, p),
                          ],
                        ),
                ),
                if (previews != null && previews.any((p) => p.installable)) ...[
                  const SizedBox(height: AnSpace.s8),
                  Text(
                    t.library.skillInstallPreauthNote,
                    style: AnText.meta.copyWith(color: c.warn),
                  ),
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
                        label: t.library.skillInstallGo,
                        variant: AnButtonVariant.primary,
                        onPressed: (_busy || _picked.isEmpty) ? null : _install,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _candidateTile(BuildContext context, SkillInstallPreview p) {
    final c = context.colors;
    final t = context.t;
    final picked = _picked.contains(p.name);
    return Padding(
      padding: const EdgeInsets.only(bottom: AnSpace.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnSwitch(
            value: picked && p.installable,
            onChanged: p.installable
                ? (v) => setState(
                    () => v ? _picked.add(p.name) : _picked.remove(p.name),
                  )
                : null,
          ),
          const SizedBox(width: AnSpace.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      p.name,
                      style: AnText.body.weight(AnText.emphasisWeight),
                    ),
                    if (p.alreadyExists) ...[
                      const SizedBox(width: AnSpace.s6),
                      AnChip(t.library.skillInstalledBadge, tone: AnTone.none),
                    ],
                  ],
                ),
                if (p.description.isNotEmpty)
                  Text(
                    p.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AnText.meta.copyWith(color: c.inkMuted),
                  ),
                if (!p.installable && p.reason.isNotEmpty)
                  Text(p.reason, style: AnText.meta.copyWith(color: c.warn)),
                // allowed-tools 前置亮相(琥珀=权力让渡,信任门从挑选步开始)。
                if (p.allowedTools.isNotEmpty) ...[
                  const SizedBox(height: AnSpace.s4),
                  Wrap(
                    spacing: AnSpace.s4,
                    runSpacing: AnSpace.s4,
                    children: [
                      for (final tool in p.allowedTools)
                        AnChip(tool, tone: AnTone.warn),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
