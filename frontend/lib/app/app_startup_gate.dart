import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/process/backend_controller.dart';
import '../core/runtime.dart';
import '../core/ui/an_button.dart';
import '../core/ui/an_state.dart';
import '../i18n/strings.g.dart';
import 'gate_backdrop.dart';

/// Gates the app shell on the sidecar backend's single phase: a connecting screen while it starts, a
/// RECOVERABLE crashed screen (with Retry) if it never came up, the shell once ready. The whole app
/// reads ONE phase ([backendStartupProvider]) — no feature ever handles "backend down" itself. Wraps
/// the shell as `MaterialApp.home`. The connecting / crashed screens are [AnState] (loading / fatal
/// error) — the gate composes the primitive, it does not hand-roll the placeholder.
///
/// 据 sidecar 后端单一 phase 门控整 app(连接中/崩溃可重试/就绪显壳)。连接/崩溃屏走 AnState(loading/fatal error),
/// gate 只组装原语、不手搓占位。
class AppStartupGate extends ConsumerWidget {
  const AppStartupGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(backendStartupProvider.select((s) => s.phase));
    final t = context.t;
    return switch (phase) {
      BackendPhase.ready => child,
      BackendPhase.starting =>
        GateBackdrop(child: AnState(kind: AnStateKind.loading, title: t.startup.connecting)),
      BackendPhase.crashed => GateBackdrop(
          child: AnState(
            kind: AnStateKind.error,
            fatal: true, // app can't start — louder than an in-content error 应用起不来,比内容内错更响
            title: t.startup.crashedTitle,
            hint: t.startup.crashedHint,
            detail: ref.watch(backendStartupProvider.select((s) => s.error)),
            action: AnButton(
              label: t.startup.retry,
              variant: AnButtonVariant.primary,
              onPressed: () => ref.read(backendStartupProvider.notifier).retry(),
            ),
          ),
        ),
    };
  }
}
