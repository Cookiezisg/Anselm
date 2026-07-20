import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/contract/api_error.dart';
import '../../../../core/contract/api_key.dart';
import '../../../../core/contract/model_capability.dart';
import '../../../../core/contract/workspace.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/model/model_capabilities.dart';
import '../../../../core/notice/notice_center.dart';
import '../../../../core/overlay/an_overlay.dart';
import '../../../../core/ui/an_brand_icon.dart';
import '../../../../core/ui/an_card.dart';
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
import '../../../../core/ui/an_spinner.dart';
import '../../../../core/ui/an_state.dart';
import '../../../../core/ui/an_switch.dart';
import '../../../../core/ui/an_tooltip.dart';
import '../../../../core/ui/brand_registry.dart';
import '../../../../core/ui/icons.dart';
import '../../../../core/model/status_state.dart';
import '../../../../i18n/strings.g.dart';
import '../../state/api_keys_provider.dart';
import '../../state/settings_detail_provider.dart';
import '../../state/workspace_prefs_provider.dart';

/// ④ 模型与密钥 — the resource flagship, FOUR zones (0719 重构): ① the managed free-tier card
/// (quota meter / enable CTA) ② the PROVIDERS zone — brand-logo key rows (managed locked on top),
/// the add flow starting from a vendor LOGO GRID, save auto-probes (`:test`) into the green/red
/// status ③ scenario defaults — each row collapses to a one-line summary and expands into the
/// reusable THREE-STAGE picker (credential → model [context window + vision] → native knobs
/// rendered generically) applying `{apiKeyId, modelId, options}` ④ the search zone (search-category
/// keys + the one-layer default pick). Every key mutation invalidates the capabilities catalog (S-15).
///
/// 模型与密钥——资源旗舰,四区(0719 重构):①受管免费档卡(配额条/启用 CTA)②提供商区——品牌 logo
/// 密钥行(受管行锁顶),添加流程从厂家 logo 网格起步,保存即探测(:test)落绿红状态 ③场景默认——
/// 每行收起一句话摘要,点开进**可复用三段面板**(凭证→模型[上下文窗+视觉徽]→原生 knobs 通用渲染),
/// 应用 `{apiKeyId, modelId, options}` ④搜索区(search 类密钥+一层默认选择)。密钥变更皆
/// invalidate 能力目录(S-15)。
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
              outline: true,
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
        const SizedBox(height: AnSpace.s24),
        const _SearchSection(),
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
        ref.read(noticeCenterProvider.notifier).show(
            Translations.of(context).settings.keys.freeFailed,
            tone: AnTone.warn);
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
    // The family card — a content-flow card is chip-tier (批7 B-043 圆角选档:settings 流内卡=AnCard,
    // 手搓 card-16 白卡是尺度阶梯下唯一真出格). 族卡:流内卡=chip 档,手搓 16 圆角卡收编。
    return AnCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(t.settings.keys.freeTier, style: AnText.label.copyWith(color: c.inkMuted)),
          const Spacer(),
          if (quota.hasValue && quota.value != null)
            AnButton(
              label: t.settings.keys.freeRefresh,
              size: AnButtonSize.sm,
              outline: true,
              onPressed: () => ref.read(freetierQuotaProvider.notifier).refresh(),
            ),
        ]),
        const SizedBox(height: AnSpace.s8),
        Row(children: [
          const AnBrandIcon.anselm(size: AnBrandSize.sm),
          const SizedBox(width: AnSpace.s8),
          Text(t.settings.keys.freeTierName,
              style: AnText.body.weight(AnText.emphasisWeight).copyWith(color: c.ink)),
        ]),
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
              style: AnText.label.copyWith(color: c.danger)),
          _ => const AnMeter(ratio: null),
        },
      ]),
    );
  }
}

/// One key row — brand-logo lead + resting identity (name + meta incl. the managed mark) + the
/// persistent probe dot at the trail + hover actions (BYOK only). 密钥一行:品牌 logo 前导 +
/// 静息身份常驻 + 探测状态点尾端常驻,动作 hover 现(仅 BYOK)。
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
        ref.read(noticeCenterProvider.notifier).show(e.message, tone: AnTone.danger);
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
      // Brand identity in the lead: the managed row wears the app mark, BYOK rows their vendor
      // logo (letter plate when unmapped). 前导品牌身份:受管=app 标,BYOK=厂牌 logo(缺者字母徽)。
      leadWidget: managed
          ? const AnBrandIcon.anselm(size: AnBrandSize.sm)
          : brandIconOr(kProviderBrand[row.provider],
              fallbackLabel: row.provider, size: AnBrandSize.sm),
      // The probe outcome stays visible at rest (the hover slot holds actions). 探测态尾端常驻。
      trailingDot:
          switch (row.testStatus) { 'ok' => AnStatus.done, 'error' => AnStatus.err, _ => null },
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
                ref.read(noticeCenterProvider.notifier).show(e.message, tone: AnTone.danger);
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

/// The pushed-in add/edit form. ADD starts from a vendor LOGO GRID (pick the provider by its mark),
/// then the credential form; ollama/custom REQUIRE a base URL before save arms. The S-3 state
/// machine holds: the FIRST successful submit binds the id; every retry PATCHes it (never a second
/// POST → no 409 zombies). Editing = PATCH from the start; a non-empty secret ROTATES (destructive,
/// S-4 says so in place). Save auto-probes (`:test`) — a spinner rides the button while in flight.
///
/// 推入表单——添加从**厂家 logo 网格**起步(按牌选商),再进凭证表单;ollama/custom 必填 baseUrl 才
/// 解锁保存。S-3 状态机不变:首次提交成功即绑 id,重试一律 PATCH;编辑态起步即 PATCH,非空密钥=旋转
/// (S-4 就地警示);保存后自动探测(:test),飞行中按钮带转圈。
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

    // ADD stage 0 — the vendor logo grid: pick the provider by its mark, then the form. 添加第 0
    // 段:厂家 logo 网格,按牌选商再进表单。
    if (!editing && _provider.isEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t.settings.keys.pickProvider, style: AnText.label.copyWith(color: c.inkMuted)),
        const SizedBox(height: AnSpace.s12),
        Wrap(
          spacing: AnSpace.s8,
          runSpacing: AnSpace.s8,
          children: [
            for (final p in providers)
              SizedBox(
                width: AnSize.providerCell,
                child: AnCard(
                  selectable: true,
                  onSelect: () => setState(() {
                    _provider = p.name;
                    if (_baseUrl.text.isEmpty) _baseUrl.text = p.defaultBaseUrl;
                  }),
                  child: Column(children: [
                    brandIconOr(kProviderBrand[p.name], fallbackLabel: p.displayName),
                    const SizedBox(height: AnSpace.s6),
                    Text(p.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: AnText.label.copyWith(color: c.ink)),
                  ]),
                ),
              ),
          ],
        ),
        const SizedBox(height: AnSpace.s16),
        AnButton(
          label: t.settings.keys.cancel,
          onPressed: () => ref.read(settingsDetailProvider.notifier).pop(),
        ),
      ]);
    }

    // The base URL is a HARD requirement for self-hosted dialects. 自托管方言 baseUrl 硬必填。
    final baseUrlMissing =
        (meta?.baseUrlRequired ?? false) && _baseUrl.text.trim().isEmpty;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AnSize.formMaxWidth),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          brandIconOr(kProviderBrand[_provider],
              fallbackLabel: meta?.displayName ?? _provider, size: AnBrandSize.sm),
          const SizedBox(width: AnSpace.s8),
          Text(meta?.displayName ?? _provider,
              style: AnText.body.weight(AnText.emphasisWeight).copyWith(color: c.ink)),
          if (!editing) ...[
            const SizedBox(width: AnSpace.s8),
            AnButton(
              label: t.settings.keys.changeProvider,
              size: AnButtonSize.sm,
              onPressed: () => setState(() => _provider = ''),
            ),
          ],
        ]),
        const SizedBox(height: AnSpace.s12),
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
          AnFormField(
              label: t.settings.keys.baseUrlLabel,
              desc: (meta?.baseUrlRequired ?? false) ? t.settings.keys.baseUrlRequiredHint : null,
              child: AnInput(controller: _baseUrl, block: true, mono: true)),
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
          if (_saving) ...[
            AnSpinner(size: AnSize.iconSm, semanticLabel: t.settings.keys.savingProbe),
            const SizedBox(width: AnSpace.s8),
          ],
          AnButton(
            label: _saving ? t.settings.keys.savingProbe : t.settings.keys.saveKey,
            variant: AnButtonVariant.primary,
            onPressed: _saving ||
                    baseUrlMissing ||
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

/// Zone ③ — scenario defaults: three collapsed one-line rows, each expanding into the reusable
/// three-stage picker. 场景默认区:三行收起摘要,点开进可复用三段面板。
class _DefaultsSection extends ConsumerWidget {
  const _DefaultsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Translations.of(context);
    final ws = ref.watch(workspacePrefsProvider).value;

    return AnSection(
      label: t.settings.keys.defaults,
      variant: AnSectionVariant.quiet,
      actions: [
        const AnScopeBadge(AnSettingScope.workspace),
        const SizedBox(width: AnSpace.s8),
        AnButton(
          label: t.settings.keys.refreshModels,
          size: AnButtonSize.sm,
          outline: true,
          onPressed: () => ref.invalidate(modelCapabilitiesProvider),
        ),
      ],
      children: [
        _ScenarioDefaultRow(
            scenario: 'dialogue',
            label: t.settings.keys.scenarioDialogue,
            desc: t.settings.keys.scenarioDialogueDesc,
            current: ws?.defaultDialogue,
            clearable: false), // S-6: dialogue 不渲清除项
        _ScenarioDefaultRow(
            scenario: 'utility',
            label: t.settings.keys.scenarioUtility,
            desc: t.settings.keys.scenarioUtilityDesc,
            current: ws?.defaultUtility,
            clearable: true),
        _ScenarioDefaultRow(
            scenario: 'agent',
            label: t.settings.keys.scenarioAgent,
            desc: t.settings.keys.scenarioAgentDesc,
            current: ws?.defaultAgent,
            clearable: true),
        if (ws != null && ws.defaultDialogue == null)
          Padding(
            padding: const EdgeInsets.only(left: AnSpace.s8, top: AnSpace.s4),
            // Human words on the face; the wire code rides the tooltip (0719: 裸码不上脸). 人话上脸,
            // 线缆码收 tooltip。
            child: AnTooltip(
              message: 'MODEL_NOT_CONFIGURED',
              child: Text(t.settings.keys.notConfiguredWarn,
                  style: AnText.meta.copyWith(color: context.colors.warn)),
            ),
          ),
      ],
    );
  }
}

/// One scenario row: collapsed = a one-line summary (model · key) + the change affordance;
/// expanded = the [ModelPickerPanel]. 一行场景默认:收起=一句话摘要+修改钮;展开=三段面板。
class _ScenarioDefaultRow extends ConsumerStatefulWidget {
  const _ScenarioDefaultRow({
    required this.scenario,
    required this.label,
    required this.desc,
    required this.current,
    required this.clearable,
  });

  final String scenario;
  final String label;
  final String desc;
  final ModelRef? current;
  final bool clearable;

  @override
  ConsumerState<_ScenarioDefaultRow> createState() => _ScenarioDefaultRowState();
}

class _ScenarioDefaultRowState extends ConsumerState<_ScenarioDefaultRow> {
  bool _open = false;

  Future<void> _apply(String apiKeyId, String modelId, Map<String, String> options) async {
    try {
      await ref.read(workspacePrefsProvider.notifier).setDefaultModel(widget.scenario,
          apiKeyId: apiKeyId, modelId: modelId, options: options);
      if (mounted) setState(() => _open = false);
    } on ApiException catch (e) {
      ref.read(noticeCenterProvider.notifier).show(e.message, tone: AnTone.danger);
    }
  }

  Future<void> _clear() async {
    try {
      await ref.read(workspacePrefsProvider.notifier).clearDefaultModel(widget.scenario);
      if (mounted) setState(() => _open = false);
    } on ApiException catch (e) {
      ref.read(noticeCenterProvider.notifier).show(e.message, tone: AnTone.danger);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    final caps = ref.watch(modelCapabilitiesProvider).value ?? const <ModelCapability>[];
    final cur = widget.current;
    final capOfCur = cur == null
        ? null
        : caps
            .where((x) => x.apiKeyId == cur.apiKeyId && x.modelId == cur.modelId)
            .firstOrNull;
    final summary = cur == null
        ? t.settings.keys.noDefault
        : '${capOfCur?.displayName.isNotEmpty == true ? capOfCur!.displayName : cur.modelId}'
            '${capOfCur == null ? '' : ' · ${capOfCur.keyName}'}';

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      AnSettingRow(
        label: widget.label,
        desc: widget.desc,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AnSize.ctlSlotLg),
            child: Text(summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AnText.label
                    .copyWith(color: cur == null ? c.inkFaint : c.inkMuted)),
          ),
          const SizedBox(width: AnSpace.s8),
          AnButton(
            label: _open ? t.settings.keys.pickerClose : t.settings.keys.pickerChange,
            size: AnButtonSize.sm,
            outline: true,
            onPressed: () => setState(() => _open = !_open),
          ),
        ]),
      ),
      if (_open)
        Padding(
          padding: const EdgeInsets.only(top: AnSpace.s8, bottom: AnSpace.s8),
          child: ModelPickerPanel(
            key: ValueKey('picker:${widget.scenario}'),
            caps: caps,
            initial: cur,
            clearable: widget.clearable && cur != null,
            onApply: _apply,
            onClear: _clear,
            onAddKey: () => ref.read(settingsDetailProvider.notifier).push('addKey'),
          ),
        ),
    ]);
  }
}

/// The REUSABLE three-stage model picker (0719 拍板): ① credential (probed keys that actually serve
/// models) → ② model under that key (context window + vision/docs badges) → ③ the model's native
/// knobs rendered generically from the descriptor (enum → dropdown / bool → switch / int → number,
/// defaults prefilled) → apply `{apiKeyId, modelId, options}`. With no capabilities at all it renders
/// the zero-state guidance jumping to the key zone.
///
/// 可复用三段模型面板(0719 拍板):①凭证(真正供模型的已探测 key)→②该 key 下的模型(上下文窗+视觉/
/// 文档徽)→③原生 knobs 通用渲染(enum 下拉/bool 开关/int 数字,default 预填)→应用
/// `{apiKeyId, modelId, options}`。全空时渲零可用引导,跳密钥区。
class ModelPickerPanel extends StatefulWidget {
  const ModelPickerPanel({
    required this.caps,
    required this.onApply,
    this.initial,
    this.clearable = false,
    this.onClear,
    this.onAddKey,
    super.key,
  });

  final List<ModelCapability> caps;
  final ModelRef? initial;
  final bool clearable;
  final void Function(String apiKeyId, String modelId, Map<String, String> options) onApply;
  final VoidCallback? onClear;
  final VoidCallback? onAddKey;

  @override
  State<ModelPickerPanel> createState() => _ModelPickerPanelState();
}

class _ModelPickerPanelState extends State<ModelPickerPanel> {
  String? _keyId;
  String? _modelId;
  final Map<String, String> _knobValues = {};
  final Map<String, TextEditingController> _intCtls = {};

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    if (init != null) {
      _keyId = init.apiKeyId;
      _modelId = init.modelId;
      _knobValues.addAll(init.options);
    }
  }

  @override
  void dispose() {
    for (final ctl in _intCtls.values) {
      ctl.dispose();
    }
    super.dispose();
  }

  ModelCapability? get _cap => _modelId == null
      ? null
      : widget.caps
          .where((x) => x.apiKeyId == _keyId && x.modelId == _modelId)
          .firstOrNull;

  String _knobValue(ModelKnob k) => _knobValues[k.key] ?? k.defaultValue;

  TextEditingController _intCtl(ModelKnob k) =>
      _intCtls.putIfAbsent(k.key, () => TextEditingController(text: _knobValue(k)));

  /// ctx window → compact figure (128000 → 128K). 上下文窗→紧凑数字。
  static String fmtCtx(int n) => n >= 1000 ? '${(n / 1000).round()}K' : '$n';

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;

    if (widget.caps.isEmpty) {
      // Zero usable models — guidance, not a dead dropdown (0719 零可用引导). 零可用引导。
      return AnCard(
        child: Row(children: [
          Expanded(
            child: Text(t.settings.keys.noCapsGuide,
                style: AnText.label.copyWith(color: c.inkMuted)),
          ),
          if (widget.onAddKey != null)
            AnButton(
              label: t.settings.keys.addKey,
              size: AnButtonSize.sm,
              outline: true,
              onPressed: widget.onAddKey,
            ),
        ]),
      );
    }

    // Stage ① — credentials that actually serve models. 真正供模型的凭证。
    final keyIds = <String>[];
    for (final cap in widget.caps) {
      if (!keyIds.contains(cap.apiKeyId)) keyIds.add(cap.apiKeyId);
    }
    final models = _keyId == null
        ? const <ModelCapability>[]
        : widget.caps.where((x) => x.apiKeyId == _keyId).toList();
    final cap = _cap;

    return AnCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(t.settings.keys.stageCredential, style: AnText.meta.copyWith(color: c.inkFaint)),
        const SizedBox(height: AnSpace.s4),
        for (final id in keyIds)
          Builder(builder: (context) {
            final sample = widget.caps.firstWhere((x) => x.apiKeyId == id);
            return AnRow(
              leadWidget: brandIconOr(kProviderBrand[sample.provider],
                  fallbackLabel: sample.keyName.isEmpty ? sample.provider : sample.keyName,
                  size: AnBrandSize.sm),
              label: sample.keyName.isEmpty ? sample.provider : sample.keyName,
              meta: sample.provider,
              selected: id == _keyId,
              onSelect: () => setState(() {
                if (_keyId != id) {
                  _keyId = id;
                  _modelId = null;
                  _knobValues.clear();
                  _intCtls.clear();
                }
              }),
            );
          }),
        if (_keyId != null) ...[
          const SizedBox(height: AnSpace.s12),
          Text(t.settings.keys.stageModel, style: AnText.meta.copyWith(color: c.inkFaint)),
          const SizedBox(height: AnSpace.s4),
          // Stage ② — the models this key serves, with capability specs. 该 key 的模型+能力规格。
          for (final m in models)
            AnRow(
              leadless: true,
              label: m.displayName.isEmpty ? m.modelId : m.displayName,
              meta: [
                if (m.contextWindow > 0) fmtCtx(m.contextWindow),
                if (m.vision) t.settings.keys.visionBadge,
                if (m.nativeDocs) t.settings.keys.docsBadge,
              ].join(' · '),
              selected: m.modelId == _modelId,
              onSelect: () => setState(() {
                if (_modelId != m.modelId) {
                  _modelId = m.modelId;
                  _knobValues.clear();
                  _intCtls.clear();
                }
              }),
            ),
        ],
        if (cap != null && cap.knobs.isNotEmpty) ...[
          const SizedBox(height: AnSpace.s12),
          Text(t.settings.keys.stageKnobs, style: AnText.meta.copyWith(color: c.inkFaint)),
          const SizedBox(height: AnSpace.s4),
          // Stage ③ — native knobs, generically rendered from the descriptor. 原生 knobs 通用渲染。
          for (final k in cap.knobs)
            AnSettingRow(
              label: k.label.isEmpty ? k.key : k.label,
              child: switch (k.type) {
                'enum' => SizedBox(
                    width: AnSize.ctlSlot,
                    child: AnDropdown<String>(
                      options: [for (final v in k.values) AnDropdownOption(value: v, label: v)],
                      value: k.values.contains(_knobValue(k)) ? _knobValue(k) : null,
                      onChanged: (v) => setState(() => _knobValues[k.key] = v),
                    ),
                  ),
                'bool' => AnSwitch(
                    value: _knobValue(k) == 'true',
                    onChanged: (v) => setState(() => _knobValues[k.key] = '$v'),
                  ),
                _ => SizedBox(
                    width: AnSize.numField,
                    child: AnInput(
                      controller: _intCtl(k),
                      mono: true,
                      onChanged: (v) => _knobValues[k.key] = v.trim(),
                    ),
                  ),
              },
            ),
        ],
        const SizedBox(height: AnSpace.s12),
        Row(children: [
          AnButton(
            label: t.settings.keys.pickerApply,
            variant: AnButtonVariant.primary,
            size: AnButtonSize.sm,
            onPressed: (cap == null)
                ? null
                : () {
                    final options = <String, String>{
                      for (final k in cap.knobs)
                        if ((_knobValues[k.key] ?? '').isNotEmpty &&
                            _knobValues[k.key] != k.defaultValue)
                          k.key: _knobValues[k.key]!,
                    };
                    widget.onApply(cap.apiKeyId, cap.modelId, options);
                  },
          ),
          if (widget.clearable && widget.onClear != null) ...[
            const SizedBox(width: AnSpace.s8),
            AnButton(
              label: t.settings.keys.clearDefault,
              size: AnButtonSize.sm,
              onPressed: widget.onClear,
            ),
          ],
        ]),
      ]),
    );
  }
}

/// Zone ④ — the search zone: the search-category default key, a one-layer pick over probed search
/// keys. 搜索区:默认搜索 key,一层选择(已探测 search 类 key)。
class _SearchSection extends ConsumerWidget {
  const _SearchSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Translations.of(context);
    final ws = ref.watch(workspacePrefsProvider).value;
    final keys = ref.watch(apiKeysProvider).value ?? const <ApiKey>[];
    final providers = ref.watch(providersProvider).value ?? const <ProviderMeta>[];
    final searchProviders = {for (final p in providers) if (p.category == 'search') p.name};
    final searchKeys = keys
        .where((k) => searchProviders.contains(k.provider) && k.testStatus == 'ok')
        .toList();

    return AnSection(
      label: t.settings.keys.searchSection,
      variant: AnSectionVariant.quiet,
      actions: const [AnScopeBadge(AnSettingScope.workspace)],
      children: [
        AnSettingRow(
          label: t.settings.keys.searchDefault,
          desc: t.settings.keys.searchDefaultDesc,
          child: SizedBox(
            width: AnSize.ctlSlotLg,
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
                      .read(noticeCenterProvider.notifier)
                      .show(e.message, tone: AnTone.danger);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}
