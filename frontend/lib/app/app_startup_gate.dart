import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/colors.dart';
import '../core/design/tokens.dart';
import '../core/design/typography.dart';
import '../core/process/backend_controller.dart';
import '../core/runtime.dart';
import '../core/ui/an_button.dart';
import '../core/ui/icons.dart';
import '../i18n/strings.g.dart';

/// Gates the app shell on the sidecar backend's single phase: a connecting screen while it starts, a
/// RECOVERABLE crashed screen (with Retry) if it never came up, the shell once ready. The whole app
/// reads ONE phase ([backendStartupProvider]) — no feature ever handles "backend down" itself. Wraps
/// the shell as `MaterialApp.home`. 据 sidecar 后端单一 phase 门控整 app(连接中/崩溃可重试/就绪显壳)。
class AppStartupGate extends ConsumerWidget {
  const AppStartupGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(backendStartupProvider.select((s) => s.phase));
    return switch (phase) {
      BackendPhase.ready => child,
      BackendPhase.starting => const _GateScaffold(child: _Connecting()),
      BackendPhase.crashed => _GateScaffold(
          child: _Crashed(
            error: ref.watch(backendStartupProvider.select((s) => s.error)),
            onRetry: () => ref.read(backendStartupProvider.notifier).retry(),
          ),
        ),
    };
  }
}

class _GateScaffold extends StatelessWidget {
  const _GateScaffold({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.canvas,
      child: Center(
        child: Padding(padding: const EdgeInsets.all(AnSpace.s24), child: child),
      ),
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
        Text(context.t.startup.connecting, style: AnText.body.copyWith(color: c.inkMuted)),
      ],
    );
  }
}

class _Crashed extends StatelessWidget {
  const _Crashed({required this.error, required this.onRetry});
  final String? error;
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
          Text(t.startup.crashedTitle, textAlign: TextAlign.center, style: AnText.strong.copyWith(color: c.ink)),
          const SizedBox(height: AnSpace.s8),
          Text(t.startup.crashedHint, textAlign: TextAlign.center, style: AnText.body.copyWith(color: c.inkMuted)),
          if (error != null && error!.isNotEmpty) ...[
            const SizedBox(height: AnSpace.s8),
            Text(
              error!,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AnText.meta.copyWith(color: c.inkFaint),
            ),
          ],
          const SizedBox(height: AnSpace.s16),
          AnButton(label: t.startup.retry, variant: AnButtonVariant.primary, onPressed: onRetry),
        ],
      ),
    );
  }
}
