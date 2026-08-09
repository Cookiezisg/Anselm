import 'package:flutter/material.dart' show Material, MaterialType;
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
          // An existing skill cannot be installed through this dialog: the request has no force
          // action, and the backend deliberately returns a skip. Keep it visible for comparison,
          // but never make a no-op look selected.
          ..addAll(
            previews
                .where((p) => p.installable && !p.alreadyExists)
                .map((p) => p.name),
          );
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
    final hasNewCandidates =
        previews?.any((p) => p.installable && !p.alreadyExists) ?? false;
    // Material(transparency): this dialog lives in a RawDialogRoute (anPanelRoute), outside any
    // Scaffold — its AnInput/TextField (the source field below) needs a Material ancestor (else the
    // debug yellow underline / no-Material assert). Mirrors skill_tool_picker.dart's same fix for the
    // same reason (WRK-077 §5.13 顺带发现 — 与 iconOnly tooltip 同批的又一处「顺带」). Material(transparency):
    // 本对话框活在 RawDialogRoute(anPanelRoute)里,脱离 Scaffold——其 AnInput/TextField(下方来源框)须
    // Material 祖先(否则 debug 黄下划线/no-Material 断言)。同 skill_tool_picker.dart 已有的同款修法。
    return Material(
      type: MaterialType.transparency,
      child: Center(
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
                  const SizedBox(height: AnSpace.s6),
                  // Self-explain BEFORE the point of no return (解析来源): what this does (fetches over the
                  // net), where it lands (your library), and what pre-authorization means — the ONE safety
                  // note used to only surface after candidates were picked (skillInstallPreauthNote below),
                  // by which point the user had already committed to reading this far. 前置自解释(在「解析
                  // 来源」之前):做什么(联网取)、落哪(你的库)、预授权何意——原本唯一的安全提示曾只在勾选候选后
                  // 才现(下方 skillInstallPreauthNote),那时用户已读到这一步才看见最该先知道的话。
                  Text(
                    t.library.skillInstallExplainer,
                    style: AnText.meta.copyWith(color: c.inkMuted),
                  ),
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
                  if (previews != null &&
                      previews.any((p) => p.installable)) ...[
                    const SizedBox(height: AnSpace.s8),
                    Text(
                      hasNewCandidates
                          ? t.library.skillInstallPreauthNote
                          : t.library.skillInstallAlreadyInstalled,
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
                          onPressed: (_busy || _picked.isEmpty)
                              ? null
                              : _install,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
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
    final selectable = p.installable && !p.alreadyExists;
    return Padding(
      padding: const EdgeInsets.only(bottom: AnSpace.s8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnSwitch(
            value: picked && selectable,
            onChanged: selectable
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
