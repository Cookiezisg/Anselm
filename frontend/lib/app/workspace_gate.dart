import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/colors.dart';
import '../core/design/tokens.dart';
import '../core/design/typography.dart';
import '../core/ui/an_button.dart';
import '../core/ui/icons.dart';
import '../core/workspace/workspace_bootstrap.dart';
import '../i18n/strings.g.dart';

/// Gates the shell on cold-start workspace resolution — it sits BELOW [AppStartupGate] (backend ready)
/// and ABOVE the shell: a brief "setting up your workspace" screen while [workspaceBootstrapProvider]
/// lists/creates the workspace + sets the active id, then the shell. Without it every entity request
/// would 401 (no workspace). Recoverable: an error screen with retry. 据冷启动工作区门控壳(在后端门控之下)。
class WorkspaceGate extends ConsumerWidget {
  const WorkspaceGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(workspaceBootstrapProvider);
    return async.when(
      data: (_) => child,
      loading: () => const _GateScaffold(child: _Connecting()),
      error: (e, _) => _GateScaffold(
        child: _Failed(
          error: e.toString(),
          onRetry: () => ref.invalidate(workspaceBootstrapProvider),
        ),
      ),
    );
  }
}

class _GateScaffold extends StatelessWidget {
  const _GateScaffold({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.canvas,
      child: Center(child: Padding(padding: const EdgeInsets.all(AnSpace.s24), child: child)),
    );
  }
}

class _Connecting extends StatelessWidget {
  const _Connecting();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: AnSize.iconLg,
          height: AnSize.iconLg,
          child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
        ),
        const SizedBox(height: AnSpace.s16),
        Text(context.t.coldStart.connecting, style: AnText.body.copyWith(color: c.inkMuted)),
      ],
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.t;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AnSize.content / 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AnIcons.error, size: AnSize.iconLg, color: c.danger),
          const SizedBox(height: AnSpace.s12),
          Text(t.coldStart.errorTitle, textAlign: TextAlign.center, style: AnText.strong.copyWith(color: c.ink)),
          const SizedBox(height: AnSpace.s8),
          Text(t.coldStart.errorHint, textAlign: TextAlign.center, style: AnText.body.copyWith(color: c.inkMuted)),
          const SizedBox(height: AnSpace.s16),
          AnButton(label: t.startup.retry, variant: AnButtonVariant.primary, onPressed: onRetry),
        ],
      ),
    );
  }
}
