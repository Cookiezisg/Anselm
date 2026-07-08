import 'package:flutter/widgets.dart';

import '../../i18n/strings.g.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'icons.dart';

/// Where a setting LIVES — the three storage scopes a value can belong to. 设置值的三个存储域。
enum AnSettingScope {
  /// This machine's app preferences (SharedPreferences). 本机 app 偏好。
  device,

  /// The active workspace's backend row. 当前工作区(后端)。
  workspace,

  /// Machine-wide backend file (settings.json — all workspaces). 全机(后端 settings.json,跨工作区)。
  machine,
}

/// The scope badge — a quiet 12px outline chip naming a section's storage scope (本机/工作区/全机).
/// Sits at [AnSection] level (WRK-062 S-16: one per section, NEVER page-level — a page can mix
/// scopes and a single header badge would lie). Text derives from the enum via slang; callers never
/// hand-write scope labels.
///
/// 作用域徽——安静的 12px 描边小丸,标一节设置存哪(本机/工作区/全机)。挂 AnSection 级(S-16:每节一枚,
/// 禁页头单枚——一页可混域,页头徽必撒谎)。文案由枚举经 slang 派生,调用方绝不手写。
class AnScopeBadge extends StatelessWidget {
  const AnScopeBadge(this.scope, {super.key});

  final AnSettingScope scope;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = Translations.of(context);
    final (label, icon) = switch (scope) {
      AnSettingScope.device => (t.settings.scope.device, AnIcons.laptop),
      AnSettingScope.workspace => (t.settings.scope.workspace, AnIcons.workspaceScope),
      AnSettingScope.machine => (t.settings.scope.machine, AnIcons.machineScope),
    };
    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AnSpace.s6, vertical: 1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AnRadius.chip),
          border: Border.all(color: c.line, width: AnSize.hairline),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: AnSize.iconSm, color: c.inkFaint),
          const SizedBox(width: AnSpace.s4),
          Text(label, style: AnText.meta.copyWith(color: c.inkFaint)),
        ]),
      ),
    );
  }
}
