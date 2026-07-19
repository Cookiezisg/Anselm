import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../ui/icons.dart';

/// Installs the process-wide error sinks + a recoverable [ErrorWidget] so a build/throw NEVER shows the
/// gray crash screen. Call once in main() inside `runZonedGuarded`:
///   - [FlutterError.onError] — framework (build/layout/paint) errors → console dump + sink.
///   - [PlatformDispatcher.instance.onError] — uncaught async/platform errors → handled (don't crash).
///   - [ErrorWidget.builder] — replaces a thrown subtree with [_AnErrorWidget] in place.
/// A full logging facade (rotating file sink, crash report) is the crash-recovery cluster (later); here
/// the sink is debugPrint. 安装全局错误汇 + 可恢复 ErrorWidget(构建抛错绝不灰屏);完整日志设施属后续簇。
void installErrorHandlers() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details); // keep the rich console dump
    debugPrint('[anselm] flutter error: ${details.exceptionAsString()}');
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('[anselm] uncaught: $error\n$stack');
    return true; // handled — keep the isolate alive
  };
  ErrorWidget.builder = (FlutterErrorDetails details) => const _AnErrorWidget();
}

/// The in-place replacement for a widget that threw. It must render SELF-CONTAINED — it can appear
/// anywhere, possibly above the theme/Directionality — so it pulls colors from the static [AnColors.light]
/// palette (not `context.colors`), supplies its own [Directionality] + explicit text styles, and reads
/// copy from slang's context-free global `t`. 自含的报错替身(可能在 theme/Directionality 之上),用静态调色板
/// + 自带 Directionality/文字样式 + 全局 t。
class _AnErrorWidget extends StatelessWidget {
  const _AnErrorWidget();

  @override
  Widget build(BuildContext context) {
    const c = AnColors.light;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(
        color: c.canvas,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AnSpace.s24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AnIcons.error, size: AnSize.iconLg, color: c.danger),
                const SizedBox(height: AnSpace.s12),
                Text(
                  t.startup.errorTitle,
                  textAlign: TextAlign.center,
                  style: AnText.strong.copyWith(color: c.ink),
                ),
                const SizedBox(height: AnSpace.s8),
                Text(
                  t.startup.errorHint,
                  textAlign: TextAlign.center,
                  style: AnText.body.copyWith(color: c.inkMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
