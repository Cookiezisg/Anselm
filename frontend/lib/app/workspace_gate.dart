import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ui/an_button.dart';
import '../core/ui/an_state.dart';
import '../core/workspace/workspace_bootstrap.dart';
import '../i18n/strings.g.dart';
import 'gate_backdrop.dart';

/// Gates the shell on cold-start workspace resolution — it sits BELOW [AppStartupGate] (backend ready)
/// and ABOVE the shell: a brief "setting up your workspace" screen while [workspaceBootstrapProvider]
/// lists/creates the workspace + sets the active id, then the shell. Without it every entity request
/// would 401 (no workspace). Recoverable: an error screen with retry. The connecting / failed screens
/// are [AnState] (loading / fatal error) — composed, not hand-rolled. 据冷启动工作区门控壳;屏走 AnState。
class WorkspaceGate extends ConsumerWidget {
  const WorkspaceGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(workspaceBootstrapProvider);
    final t = context.t;
    return async.when(
      data: (_) => child,
      loading: () => GateBackdrop(child: AnState(kind: AnStateKind.loading, title: t.coldStart.connecting)),
      error: (e, _) => GateBackdrop(
        child: AnState(
          kind: AnStateKind.error,
          fatal: true,
          title: t.coldStart.errorTitle,
          hint: t.coldStart.errorHint,
          detail: e.toString(),
          action: AnButton(
            label: t.startup.retry,
            variant: AnButtonVariant.primary,
            onPressed: () => ref.invalidate(workspaceBootstrapProvider),
          ),
        ),
      ),
    );
  }
}
