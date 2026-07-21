import 'package:flutter/widgets.dart';

import '../../i18n/strings.g.dart';
import 'an_chip.dart';
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

/// The scope badge — since WRK-066 批5 a THIN PRESET over the chip family head ([AnChip],
/// outlined): a quiet chip naming a section's storage scope (本机/工作区/全机). Its own knowledge
/// is only the enum→(label, icon) slang table — callers never hand-write scope labels. Sits at
/// [AnSection] level (WRK-062 S-16: one per section, NEVER page-level — a page can mix scopes and
/// a single header badge would lie).
///
/// 作用域徽——批5 起为芯片族薄预设(AnChip outlined):标一节设置存哪(本机/工作区/全机);自有知识仅
/// 枚举→(文案,字形) slang 表,调用方绝不手写文案。挂 AnSection 级(S-16:每节一枚,禁页头单枚——
/// 一页可混域,页头徽必撒谎)。
class AnScopeBadge extends StatelessWidget {
  const AnScopeBadge(this.scope, {super.key});

  final AnSettingScope scope;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final (label, icon) = switch (scope) {
      AnSettingScope.device => (t.settings.scope.device, AnIcons.laptop),
      AnSettingScope.workspace => (
        t.settings.scope.workspace,
        AnIcons.workspaceScope,
      ),
      AnSettingScope.machine => (
        t.settings.scope.machine,
        AnIcons.machineScope,
      ),
    };
    return AnChip(
      label,
      look: AnChipLook.outlined,
      icon: icon,
      semanticLabel: label,
    );
  }
}
