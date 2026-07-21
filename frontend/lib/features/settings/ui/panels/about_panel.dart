import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/platform/open_external_url.dart';
import '../../../../core/ui/ui.dart';
import '../../../../i18n/strings.g.dart';
import '../../model/settings_search.dart';
import '../../state/update_check_provider.dart';
import '../../state/workspaces_provider.dart';
import '../settings_anchor.dart';

/// ⑬ 关于 (WRK-062 §3, S3): versions (app + engine), the v1 update check (拍板 #7 — query GitHub
/// Releases, report, link out; never download), and copy-diagnostics. 关于页:版本(应用+引擎)/
/// v1 更新检查(只报告+外链)/诊断复制。
class AboutPanel extends ConsumerWidget {
  const AboutPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Translations.of(context);
    final c = context.colors;
    // Local sidecar answers sub-threshold — an empty meta for a frame is honest, a '…' sentinel is
    // theater (AnDeferredLoading philosophy). 本地 sidecar 亚阈返回:空串诚实,'…' 哨兵是剧场。
    final engine = ref.watch(backendVersionProvider).value ?? '';
    final app = ref.watch(appVersionProvider).value ?? '';
    final check = ref.watch(updateCheckProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnSection(
          label: t.settings.about.versions,
          variant: AnSectionVariant.quiet,
          children: [
            // The check button rides the app-version row's tail — the thing it updates (0719 P2:
            // 漂浮孤行退役,动作归位进字段结构). 检查更新钉在应用版本行尾——它更新的正是这个值。
            SettingsAnchor(
              item: SettingsItem.aboutAppVersion,
              child: AnSettingRow(
                label: t.settings.about.appVersion,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      app,
                      style: AnText.metaTabular().copyWith(color: c.inkMuted),
                    ),
                    const SizedBox(width: AnSpace.s12),
                    AnButton(
                      label: check.isLoading
                          ? t.settings.about.checking
                          : t.settings.about.checkUpdates,
                      size: AnButtonSize.sm,
                      outline: true,
                      onPressed: check.isLoading
                          ? null
                          : () =>
                                ref.read(updateCheckProvider.notifier).check(),
                    ),
                  ],
                ),
              ),
            ),
            if (check.value != null)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: _CheckOutcome(status: check.value),
              ),
            SettingsAnchor(
              item: SettingsItem.aboutBackendVersion,
              child: AnSettingRow(
                label: t.settings.about.backendVersion,
                child: Text(
                  engine,
                  style: AnText.metaTabular().copyWith(color: c.inkMuted),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AnSpace.s24),
        // Font credits — satisfies the MiSans license's「specifically note in the software that MiSans
        // Fonts was used」obligation (the rest of the bundle is OFL; full texts in assets/fonts/*-OFL.txt +
        // MiSans-License.txt). 字体致谢——履行 MiSans 许可「软件中注明使用了 MiSans」义务(其余 OFL)。
        SettingsAnchor(
          item: SettingsItem.aboutFonts,
          child: AnSettingRow(
            label: t.settings.about.fonts,
            desc: t.settings.about.fontsCredit,
            child: const SizedBox.shrink(),
          ),
        ),
        const SizedBox(height: AnSpace.s24),
        SettingsAnchor(
          item: SettingsItem.aboutDiagnostics,
          child: AnSettingRow(
            label: t.settings.about.diagnostics,
            desc: t.settings.about.diagDesc,
            child: AnButton(
              label: t.settings.about.copyDiagnostics,
              size: AnButtonSize.sm,
              outline: true,
              onPressed: () async {
                final text =
                    'Anselm $app · engine $engine · '
                    '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
                await Clipboard.setData(ClipboardData(text: text));
                if (context.mounted) {
                  ref
                      .read(noticeCenterProvider.notifier)
                      .show(t.settings.about.copied, tone: AnTone.ok);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _CheckOutcome extends StatelessWidget {
  const _CheckOutcome({required this.status});

  final UpdateStatus? status;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    final s = status;
    if (s == null) return const SizedBox.shrink();
    return switch (s.outcome) {
      UpdateOutcome.upToDate => Text(
        t.settings.about.upToDate(v: s.latest),
        style: AnText.label.copyWith(color: c.inkMuted),
      ),
      UpdateOutcome.unknown => Text(
        t.settings.about.cantCheck,
        style: AnText.label.copyWith(color: c.inkMuted),
      ),
      UpdateOutcome.available => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              t.settings.about.updateAvailable(v: s.latest),
              overflow: TextOverflow.ellipsis,
              style: AnText.label.copyWith(color: c.accent),
            ),
          ),
          const SizedBox(width: AnSpace.s8),
          AnButton(
            label: t.settings.about.download,
            size: AnButtonSize.sm,
            variant: AnButtonVariant.primary,
            onPressed: () => openExternalUrl(s.url),
          ),
        ],
      ),
    };
  }
}

/// The running app's own version (package info). 应用自身版本。
final appVersionProvider = FutureProvider<String>(
  (ref) async => (await PackageInfo.fromPlatform()).version,
);
