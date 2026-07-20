import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/contract/api_error.dart';
import '../../../../core/contract/network.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/ui/ui.dart';
import '../../../../i18n/strings.g.dart';
import '../../data/settings_repository.dart';
import '../../model/settings_search.dart';
import '../settings_anchor.dart';

/// ⑪ 网络 (WRK-062 §3, S5, 拍板 #19): the machine-level outbound proxy (settings.json `network`
/// section). Edits PATCH the whole config; a restart note is always shown (the backend caches the
/// proxy in its HTTP transports). Empty = direct. Also the home of 工单⑦ (shell env passthrough is
/// automatic via the sidecar inheriting the parent env — nothing to configure).
///
/// 网络面板:机器级出站代理(settings.json network 段)。编辑整体 PATCH;常驻重启提示;空=直连。
class NetworkPanel extends ConsumerStatefulWidget {
  const NetworkPanel({super.key});

  @override
  ConsumerState<NetworkPanel> createState() => _NetworkPanelState();
}

class _NetworkPanelState extends ConsumerState<NetworkPanel> {
  final _http = TextEditingController();
  final _https = TextEditingController();
  final _no = TextEditingController();
  bool _hydrated = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Typing re-evaluates the save button's enablement (it compares against the loaded config —
    // no edits, nothing to save). 输入须触发重建:保存钮以「与已载配置有差」为启用条件。
    for (final ctl in [_http, _https, _no]) {
      ctl.addListener(_onFieldChange);
    }
  }

  void _onFieldChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _http.dispose();
    _https.dispose();
    _no.dispose();
    super.dispose();
  }

  bool _dirty(NetworkConfig cfg) =>
      _http.text.trim() != cfg.httpProxy ||
      _https.text.trim() != cfg.httpsProxy ||
      _no.text.trim() != cfg.noProxy;

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final t = Translations.of(context);
    try {
      await ref.read(settingsRepositoryProvider).patchNetwork(NetworkConfig(
            httpProxy: _http.text.trim(),
            httpsProxy: _https.text.trim(),
            noProxy: _no.text.trim(),
          ));
      ref.invalidate(networkConfigProvider);
      ref.read(noticeCenterProvider.notifier).show(t.settings.network.saved, tone: AnTone.ok);
    } on ApiException catch (e) {
      ref.read(noticeCenterProvider.notifier).show(e.message, tone: AnTone.danger);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    final cfg = ref.watch(networkConfigProvider).value;
    if (cfg != null && !_hydrated) {
      _http.text = cfg.httpProxy;
      _https.text = cfg.httpsProxy;
      _no.text = cfg.noProxy;
      _hydrated = true;
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const AnScopeBadge(AnSettingScope.machine),
        const SizedBox(width: AnSpace.s8),
        Expanded(
            child: Text(t.settings.network.proxyHint,
                style: AnText.label.copyWith(color: c.inkMuted))),
      ]),
      const SizedBox(height: AnSpace.s16),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: AnSize.formMaxWidth),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // The ONE label-above form block (批6c A-063 — the second private «label+input» dies;
          // the quiet 13 label steps up to the family face, 刻意收敛帧核). 唯一表单字段块。
          SettingsAnchor(
            item: SettingsItem.networkHttpProxy,
            child: AnFormField(label: t.settings.network.httpProxy, child: AnInput(controller: _http, mono: true, placeholder: t.settings.network.proxyPlaceholder)),
          ),
          const SizedBox(height: AnSpace.s12),
          SettingsAnchor(
            item: SettingsItem.networkHttpsProxy,
            child: AnFormField(label: t.settings.network.httpsProxy, child: AnInput(controller: _https, mono: true, placeholder: t.settings.network.proxyPlaceholder)),
          ),
          const SizedBox(height: AnSpace.s12),
          SettingsAnchor(
            item: SettingsItem.networkNoProxy,
            child: AnFormField(label: t.settings.network.noProxy, child: AnInput(controller: _no, mono: true, placeholder: 'localhost,127.0.0.1')),
          ),
          const SizedBox(height: AnSpace.s16),
          // The restart caveat lives in the callout family — not a bare orange sentence floating
          // between fields (0719 P1-5). 重启注记归 callout 族,不再是字段间裸奔的橙句。
          AnCallout(t.settings.network.restartNote, severity: AnCalloutSeverity.warn),
          const SizedBox(height: AnSpace.s16),
          AnButton(
            label: t.settings.network.save,
            variant: AnButtonVariant.primary,
            // Enabled only with actual edits — a permanently-armed save invites no-op writes, and
            // the disabled face is the standard one, honestly earned. 有真实改动才可点。
            onPressed: cfg == null || _saving || !_dirty(cfg) ? null : _save,
          ),
        ]),
      ),
    ]);
  }

}

/// The live network config. 活动网络配置。
final networkConfigProvider =
    FutureProvider<NetworkConfig>((ref) => ref.watch(settingsRepositoryProvider).getNetwork());
