import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/tokens.dart';
import '../ui/an_button.dart';
import 'shell_chrome.dart';

/// The shell floating-head's compact title — the breadcrumb that fades in once the mounted ocean's big
/// in-content title has scrolled under the head ([ShellHead.collapsed]); tapping it scrolls the big title
/// back to top ([ShellHead.onTap]). Goes in [AnShell.head]. Pure projection of [shellHeadProvider]; the
/// ocean feeds it. Invisible (opacity 0 + inert) until collapsed, so it never blocks the click-through head.
///
/// 壳浮层头的紧凑标题——海洋大标题滚到头下时淡入,点击回顶。放 AnShell.head;投影 shellHeadProvider(海洋喂)。
/// 未折叠时不可见且惰性,不挡浮层头点击穿透。
class OceanBreadcrumb extends ConsumerWidget {
  const OceanBreadcrumb({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final head = ref.watch(shellHeadProvider);
    final show = head.collapsed && head.title.isNotEmpty;
    return AnimatedOpacity(
      opacity: show ? 1 : 0,
      duration: AnMotionPref.reduced(context) ? Duration.zero : AnMotion.mid,
      curve: AnMotion.easeOut,
      child: IgnorePointer(
        ignoring: !show,
        child: AnButton(
          label: head.title,
          variant: AnButtonVariant.ghost,
          size: AnButtonSize.sm,
          onPressed: head.onTap,
        ),
      ),
    );
  }
}
