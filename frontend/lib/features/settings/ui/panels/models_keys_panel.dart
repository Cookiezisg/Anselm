import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/contract/api_error.dart';
import '../../../../core/contract/api_key.dart';
import '../../../../core/contract/workspace.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/model/model_capabilities.dart';
import '../../../../core/overlay/an_overlay.dart';
import '../../../../core/ui/an_chip.dart';
import '../../../../core/ui/an_form_field.dart';
import '../../../../core/ui/an_button.dart';
import '../../../../core/ui/an_dropdown.dart';
import '../../../../core/ui/an_input.dart';
import '../../../../core/ui/an_meter.dart';
import '../../../../core/ui/an_row.dart';
import '../../../../core/ui/an_scope_badge.dart';
import '../../../../core/ui/an_section.dart';
import '../../../../core/ui/an_secret_field.dart';
import '../../../../core/ui/an_segmented.dart';
import '../../../../core/ui/an_setting_row.dart';
import '../../../../core/ui/an_state.dart';
import '../../../../core/ui/an_toast.dart';
import '../../../../core/ui/icons.dart';
import '../../../../core/model/status_state.dart';
import '../../../../i18n/strings.g.dart';
import '../../state/api_keys_provider.dart';
import '../../state/settings_detail_provider.dart';
import '../../state/workspace_prefs_provider.dart';

/// ④ 模型与密钥 — the resource flagship (WRK-062 §3-④): the managed free-tier card (quota meter /
/// enable CTA / amber budget banner), the BYOK key list (managed rows locked on top), the pushed-in
/// add/edit form (S-3 state machine: first submit POSTs, retries PATCH the bound id; rotation is
/// destructive and says so, S-4), and the workspace scenario defaults (dialogue can't be cleared,
/// S-6). Every key mutation invalidates the capabilities catalog (S-15).
/// 模型与密钥——资源旗舰:受管免费档卡(配额条/启用 CTA/琥珀横幅)+BYOK 列表(受管行锁顶)+推入表单
/// (S-3 状态机/S-4 旋转警示)+场景默认(dialogue 不可清,S-6);每次密钥变更 invalidate 能力目录(S-15)。
class ModelsKeysPanel extends ConsumerWidget {
  const ModelsKeysPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(settingsDetailProvider);
    if (detail != null && (detail.kind == 'addKey' || detail.kind == 'editKey')) {
      return KeyForm(editingId: detail.id);
    }
    final t = Translations.of(context);
    final keys = ref.watch(apiKeysProvider);
    final providers = ref.watch(providersProvider).value ?? const <ProviderMeta>[];
    final managedNames = {for (final p in providers) if (p.managed) p.name};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _FreeTierCard(),
        const SizedBox(height: AnSpace.s24),
        AnSection(
          label: t.settings.keys.keysSection,
          variant: AnSectionVariant.quiet,
          actions: [
            const AnScopeBadge(AnSettingScope.workspace),
            const SizedBox(width: AnSpace.s8),
            AnButton(
              label: t.settings.keys.addKey,
              icon: AnIcons.plus,
              size: AnButtonSize.sm,
              onPressed: () => ref.read(settingsDetailProvider.notifier).push('addKey'),
            ),
          ],
          children: [
            switch (keys) {
              AsyncData(:final value) when value.isEmpty => Padding(
                  padding: const EdgeInsets.symmetric(vertical: AnSpace.s16),
                  child: AnState(
                      kind: AnStateKind.empty,
                      title: t.settings.keys.keysSection,
                      hint: t.settings.keys.addKey,
                      size: AnStateSize.inset),
                ),
              AsyncData(:final value) => Column(children: [
                  // Managed rows pinned on top, locked (no edit/delete affordances — S-1's UI half).
                  // 受管行锁顶,无编辑删除入口(S-1 前端半)。
                  for (final k in [
                    ...value.where((k) => managedNames.contains(k.provider)),
                    ...value.where((k) => !managedNames.contains(k.provider)),
                  ])
                    _KeyRow(row: k, managed: managedNames.contains(k.provider)),
                ]),
              AsyncError() => AnState(
                  kind: AnStateKind.error,
                  title: t.settings.keys.keyOpFailed,
                  size: AnStateSize.inset),
              _ => const SizedBox(height: AnSize.row),
            },
          ],
        ),
        const SizedBox(height: AnSpace.s24),
        const _DefaultsSection(),
      ],
    );
  }
}

/// The managed free-tier card. 受管免费档卡。
class _FreeTierCard extends ConsumerStatefulWidget {
  const _FreeTierCard();

  @override
  ConsumerState<_FreeTierCard> createState() => _FreeTierCardState();
}

class _FreeTierCardState extends ConsumerState<_FreeTierCard> {
  bool _provisioning = false;

  Future<void> _provision() async {
    if (_provisioning) return;
    setState(() => _provisioning = true);
    try {
      final ok = await ref.read(freetierQuotaProvider.notifier).provision();
      if (!ok && mounted) {
        ref.read(overlayProvider.notifier).showToast(
            Translations.of(context).settings.keys.freeFailed,
            tone: AnToastTone.warn);
      }
    } finally {
      if (mounted) setState(() => _provisioning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    final quota = ref.watch(freetierQuotaProvider);
    return Container(
      padding: const EdgeInsets.all(AnSpace.s16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AnRadius.card),
        border: Border.all(color: c.line, width: AnSize.hairline),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(t.settings.keys.freeTier, style: AnText.label.copyWith(color: c.inkMuted)),
          const Spacer(),
          if (quota.hasValue && quota.value != null)
            AnButton(
              label: t.settings.keys.freeRefresh,
              size: AnButtonSize.sm,
              onPressed: () => ref.read(freetierQuotaProvider.notifier).refresh(),
            ),
        ]),
        const SizedBox(height: AnSpace.s8),
        Text(t.settings.keys.freeTierName,
            style: AnText.body.weight(AnText.emphasisWeight).copyWith(color: c.ink)),
        const SizedBox(height: AnSpace.s12),
        switch (quota) {
          AsyncData(:final value) when value == null => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.settings.keys.freeEnableHint,
                    style: AnText.meta.copyWith(color: c.inkFaint)),
                const SizedBox(height: AnSpace.s8),
                AnButton(
                  label: _provisioning
                      ? t.settings.keys.freeProvisioning
                      : t.settings.keys.freeEnable,
                  variant: AnButtonVariant.primary,
                  onPressed: _provisioning ? null : _provision,
                ),
              ],
            ),
          AsyncData(:final value) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnMeter(
                  ratio: value!.limit <= 0 ? null : value.used / value.limit,
                  label: t.settings.keys.freeUsage(
                      used: '${value.used}', limit: '${value.limit}', reset: value.resetAt),
                ),
                if (!value.available) ...[
                  const SizedBox(height: AnSpace.s8),
                  AnChip(t.settings.keys.freeUnavailable, tone: AnTone.warn),
                ],
              ],
            ),
          AsyncError() => Text(t.settings.keys.keyOpFailed,
              style: AnText.meta.copyWith(color: c.danger)),
          _ => const AnMeter(ratio: null),
        },
      ]),
    );
  }
}

/// One key row — resting identity (dot + name + meta incl. the managed mark) + hover actions
/// (BYOK only: status badge + test/edit/delete). 密钥一行:静息身份常驻,动作 hover 现(仅 BYOK)。
class _KeyRow extends ConsumerWidget {
  const _KeyRow({required this.row, required this.managed});

  final ApiKey row;
  final bool managed;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final t = Translations.of(context);
    final overlay = ref.read(overlayProvider.notifier);
    final ok = await overlay.confirm(
      title: t.settings.keys.deleteKeyTitle,
      message: t.settings.keys.deleteKeyBody(name: row.displayName),
      confirmLabel: t.settings.keys.confirmDelete,
      cancelLabel: t.settings.keys.cancel,
      barrierLabel: t.settings.keys.deleteKeyTitle,
    );
    if (!ok) return;
    try {
      await ref.read(apiKeysProvider.notifier).remove(row.id);
    } on ApiException catch (e) {
      if (e.code == 'API_KEY_IN_USE') {
        // The reference inventory dialog — the backend names every referencing site. 引用清单。
        final details = e.details;
        final refs = (details is Map ? details['references'] as List? : null) ?? const [];
        final lines = refs
            .map((r) => '· ${(r as Map)['kind']} — ${r['name'] ?? r['id']}')
            .join('\n');
        await overlay.confirm(
          title: t.settings.keys.inUseTitle,
          message: '${t.settings.keys.inUseHint}\n$lines',
          confirmLabel: t.settings.keys.cancel,
          cancelLabel: t.settings.keys.cancel,
          barrierLabel: t.settings.keys.inUseTitle,
        );
      } else {
        overlay.showToast(e.message, tone: AnToastTone.danger);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Translations.of(context);
    final (label, tone) = switch (row.testStatus) {
      'ok' => (t.settings.keys.statusOk, AnTone.ok),
      'error' => (t.settings.keys.statusError, AnTone.danger),
      _ => (t.settings.keys.statusPending, AnTone.none),
    };
    return AnRow(
      icon: managed ? AnIcons.lock : AnIcons.apiKey,
      dot: switch (row.testStatus) { 'ok' => AnStatus.done, 'error' => AnStatus.err, _ => null },
      // Row click = edit (BYOK). Also load-bearing: AnInteractive only tracks hover when the row is
      // activatable, so without onSelect the hover actions would be unreachable on a real mouse.
      // 行点击=编辑(BYOK)。且承重:AnInteractive 仅在可激活时跟踪 hover,没 onSelect 真鼠标够不到动作。
      onSelect: managed
          ? null
          : () => ref.read(settingsDetailProvider.notifier).push('editKey', id: row.id),
      label: row.displayName,
      // Managed identity rides the ALWAYS-visible meta — the hover slot is for actions, and a
      // managed row has none. 受管身份走常驻 meta——hover 槽只放动作,受管行没有动作。
      meta:
          '${managed ? '${t.settings.keys.managedBadge} · ' : ''}${row.provider} · ${row.keyMasked}',
      actions: [
        if (!managed) ...[
          AnChip(label, tone: tone),
          AnButton(
            label: t.settings.keys.testKey,
            size: AnButtonSize.sm,
            onPressed: () async {
              try {
                await ref.read(apiKeysProvider.notifier).test(row.id);
              } on ApiException catch (e) {
                ref.read(overlayProvider.notifier).showToast(e.message, tone: AnToastTone.danger);
              }
            },
          ),
          AnButton(
            label: t.settings.keys.editKey,
            size: AnButtonSize.sm,
            onPressed: () =>
                ref.read(settingsDetailProvider.notifier).push('editKey', id: row.id),
          ),
          AnButton(
            label: t.settings.keys.deleteKey,
            size: AnButtonSize.sm,
            variant: AnButtonVariant.danger,
            onPressed: () => _delete(context, ref),
          ),
        ],
      ],
    );
  }
}

/// The pushed-in add/edit form — the S-3 state machine: the FIRST successful submit binds the id;
/// every retry PATCHes it (never a second POST → no 409 zombies). Editing = PATCH from the start;
/// a non-empty secret ROTATES (destructive, S-4 says so in place). Save auto-probes.
/// 推入表单——S-3 状态机:首次提交成功即绑 id,重试一律 PATCH(绝不二次 POST);编辑态起步即 PATCH,
/// 非空密钥=旋转(S-4 就地警示);保存后自动探测。
class KeyForm extends ConsumerStatefulWidget {
  const KeyForm({this.editingId, super.key});

  final String? editingId;

  @override
  ConsumerState<KeyForm> createState() => _KeyFormState();
}

class _KeyFormState extends ConsumerState<KeyForm> {
  String? _boundId; // S-3: set after the first successful POST 首次 POST 成功后绑定
  String _provider = '';
  final _name = TextEditingController();
  final _secret = TextEditingController();
  final _baseUrl = TextEditingController();
  String _apiFormat = 'openai-compatible';
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Typing must re-evaluate the save button's enablement (its condition reads the controllers).
    // 输入须触发重建——保存钮的启用条件读 controller。
    _name.addListener(_onFieldChange);
    _secret.addListener(_onFieldChange);
    _baseUrl.addListener(_onFieldChange);
    _boundId = widget.editingId;
    if (_boundId != null) {
      final row = ref
          .read(apiKeysProvider)
          .value
          ?.where((k) => k.id == _boundId)
          .firstOrNull;
      if (row != null) {
        _provider = row.provider;
        _name.text = row.displayName;
        _baseUrl.text = row.baseUrl;
        if (row.apiFormat.isNotEmpty) _apiFormat = row.apiFormat;
      }
    }
  }

  void _onFieldChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _name.dispose();
    _secret.dispose();
    _baseUrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final keys = ref.read(apiKeysProvider.notifier);
    try {
      if (_boundId == null) {
        final row = await keys.create(
          provider: _provider,
          displayName: _name.text.trim(),
          key: _secret.text,
          baseUrl: _baseUrl.text.trim().isEmpty ? null : _baseUrl.text.trim(),
          apiFormat: _provider == 'custom' ? _apiFormat : null,
        );
        _boundId = row.id; // S-3: retries PATCH from here on 此后重试一律 PATCH
      } else {
        await keys.patch(
          _boundId!,
          displayName: _name.text.trim(),
          baseUrl: _baseUrl.text.trim().isEmpty ? null : _baseUrl.text.trim(),
          key: _secret.text.isEmpty ? null : _secret.text,
        );
      }
      _secret.clear(); // the redeemable promise ③ 可兑现承诺③
      await keys.test(_boundId!);
      if (mounted) ref.read(settingsDetailProvider.notifier).pop();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    final providers = (ref.watch(providersProvider).value ?? const <ProviderMeta>[])
        .where((p) => !p.managed)
        .toList();
    final meta = providers.where((p) => p.name == _provider).firstOrNull;
    final editing = widget.editingId != null;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!editing) ...[
          AnFormField(label: t.settings.keys.provider, child: AnDropdown<String>(
            options: [
              for (final p in providers) AnDropdownOption(value: p.name, label: p.displayName),
            ],
            value: _provider.isEmpty ? null : _provider,
            block: true,
            onChanged: (v) => setState(() {
              _provider = v;
              final m = providers.where((p) => p.name == v).firstOrNull;
              if (m != null && _baseUrl.text.isEmpty) _baseUrl.text = m.defaultBaseUrl;
            }),
          )),
          const SizedBox(height: AnSpace.s12),
        ],
        AnFormField(label: t.settings.keys.displayNameLabel, child: AnInput(controller: _name, block: true)),
        const SizedBox(height: AnSpace.s12),
        AnFormField(label: t.settings.keys.secretLabel, child: AnSecretField(
          controller: _secret,
          placeholder: editing ? t.settings.keys.rotatePlaceholder : null,
          revealLabel: t.settings.keys.reveal,
          concealLabel: t.settings.keys.conceal,
        )),
        if (editing)
          Padding(
            padding: const EdgeInsets.only(top: AnSpace.s4),
            // The rotate note is a NOTE under the control, never a field label. 旋转注记非字段标签。
            child: Text(t.settings.keys.rotateWarn, style: AnText.meta.copyWith(color: c.warn)),
          ),
        if (meta == null || meta.baseUrlRequired || _baseUrl.text.isNotEmpty || editing) ...[
          const SizedBox(height: AnSpace.s12),
          AnFormField(label: t.settings.keys.baseUrlLabel, child: AnInput(controller: _baseUrl, block: true, mono: true)),
        ],
        if (_provider == 'custom') ...[
          const SizedBox(height: AnSpace.s12),
          AnFormField(label: t.settings.keys.apiFormatLabel, child: AnSegmented<String>(
            options: const [
              AnSegmentedOption(value: 'openai-compatible', label: 'OpenAI'),
              AnSegmentedOption(value: 'anthropic-compatible', label: 'Anthropic'),
            ],
            value: _apiFormat,
            onChanged: (v) => setState(() => _apiFormat = v),
          )),
        ],
        if (_error != null)
          Padding(
            // Match the other settings forms' inline-error idiom (label + s8), not meta + s12. 与其余设置表一致。
            padding: const EdgeInsets.only(top: AnSpace.s8),
            child: Text(_error!, style: AnText.label.copyWith(color: c.danger)),
          ),
        const SizedBox(height: AnSpace.s16),
        Row(children: [
          AnButton(
            label: t.settings.keys.saveKey,
            variant: AnButtonVariant.primary,
            onPressed: _saving ||
                    (_boundId == null && (_provider.isEmpty || _secret.text.isEmpty))
                ? null
                : _save,
          ),
          const SizedBox(width: AnSpace.s8),
          AnButton(
            label: t.settings.keys.cancel,
            onPressed: () => ref.read(settingsDetailProvider.notifier).pop(),
          ),
        ]),
      ]),
    );
  }
}

/// Scenario defaults + the default search key. 场景默认与搜索默认。
class _DefaultsSection extends ConsumerWidget {
  const _DefaultsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Translations.of(context);
    final ws = ref.watch(workspacePrefsProvider).value;
    final caps = ref.watch(modelCapabilitiesProvider).value ?? const [];
    final keys = ref.watch(apiKeysProvider).value ?? const <ApiKey>[];
    final providers = ref.watch(providersProvider).value ?? const <ProviderMeta>[];
    final searchProviders = {for (final p in providers) if (p.category == 'search') p.name};

    ModelRef? refOf(String scenario) => switch (scenario) {
          'dialogue' => ws?.defaultDialogue,
          'utility' => ws?.defaultUtility,
          _ => ws?.defaultAgent,
        };

    Widget scenarioRow(String scenario, String label, String desc, {required bool clearable}) {
      final current = refOf(scenario);
      final currentKey =
          current == null ? null : '${current.apiKeyId}::${current.modelId}';
      return AnSettingRow(
        label: label,
        desc: desc,
        child: SizedBox(
          width: 320,
          child: AnDropdown<String>(
            options: [
              if (clearable)
                AnDropdownOption(value: '', label: t.settings.keys.clearDefault),
              for (final cap in caps)
                AnDropdownOption(
                  value: '${cap.apiKeyId}::${cap.modelId}',
                  label: cap.displayName.isEmpty ? cap.modelId : cap.displayName,
                  meta: cap.keyName,
                ),
            ],
            value: currentKey,
            placeholder: t.settings.keys.noDefault,
            block: true,
            onChanged: (v) async {
              try {
                if (v.isEmpty) {
                  await ref.read(workspacePrefsProvider.notifier).clearDefaultModel(scenario);
                } else {
                  final parts = v.split('::');
                  await ref.read(workspacePrefsProvider.notifier).setDefaultModel(scenario,
                      apiKeyId: parts[0], modelId: parts.sublist(1).join('::'));
                }
              } on ApiException catch (e) {
                ref.read(overlayProvider.notifier).showToast(e.message, tone: AnToastTone.danger);
              }
            },
          ),
        ),
      );
    }

    final searchKeys = keys
        .where((k) => searchProviders.contains(k.provider) && k.testStatus == 'ok')
        .toList();

    return AnSection(
      label: t.settings.keys.defaults,
      variant: AnSectionVariant.quiet,
      actions: [
        const AnScopeBadge(AnSettingScope.workspace),
        const SizedBox(width: AnSpace.s8),
        AnButton(
          label: t.settings.keys.refreshModels,
          size: AnButtonSize.sm,
          onPressed: () => ref.invalidate(modelCapabilitiesProvider),
        ),
      ],
      children: [
        scenarioRow('dialogue', t.settings.keys.scenarioDialogue,
            t.settings.keys.scenarioDialogueDesc,
            clearable: false), // S-6: dialogue 不渲清除项
        const SizedBox(height: AnSpace.s4),
        scenarioRow('utility', t.settings.keys.scenarioUtility, t.settings.keys.scenarioUtilityDesc,
            clearable: true),
        const SizedBox(height: AnSpace.s4),
        scenarioRow('agent', t.settings.keys.scenarioAgent, t.settings.keys.scenarioAgentDesc,
            clearable: true),
        const SizedBox(height: AnSpace.s4),
        AnSettingRow(
          label: t.settings.keys.searchDefault,
          desc: t.settings.keys.searchDefaultDesc,
          child: SizedBox(
            width: 320,
            child: AnDropdown<String>(
              options: [
                AnDropdownOption(value: '', label: t.settings.keys.clearDefault),
                for (final k in searchKeys)
                  AnDropdownOption(value: k.id, label: k.displayName, meta: k.provider),
              ],
              value: (ws?.defaultSearchKeyId?.isEmpty ?? true) ? null : ws!.defaultSearchKeyId,
              placeholder: t.settings.keys.noDefault,
              block: true,
              onChanged: (v) async {
                try {
                  if (v.isEmpty) {
                    await ref.read(workspacePrefsProvider.notifier).clearDefaultSearch();
                  } else {
                    await ref.read(workspacePrefsProvider.notifier).setDefaultSearch(v);
                  }
                } on ApiException catch (e) {
                  ref
                      .read(overlayProvider.notifier)
                      .showToast(e.message, tone: AnToastTone.danger);
                }
              },
            ),
          ),
        ),
        if (ws != null && ws.defaultDialogue == null)
          Padding(
            padding: const EdgeInsets.only(left: AnSpace.s8, top: AnSpace.s4),
            child: Text(t.settings.keys.notConfiguredWarn,
                style: AnText.meta.copyWith(color: context.colors.warn)),
          ),
      ],
    );
  }
}
