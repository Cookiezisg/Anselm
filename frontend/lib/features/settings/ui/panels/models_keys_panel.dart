import 'dart:convert';

import 'package:file_selector/file_selector.dart';
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
import '../../../../core/model/number_format.dart';
import '../../../../core/model/time_format.dart';
import '../../../../core/notice/notice_center.dart';
import '../../../../core/overlay/an_overlay.dart';
import '../../../../core/ui/an_auto_grid.dart';
import '../../../../core/ui/an_brand_icon.dart';
import '../../../../core/ui/an_card.dart';
import '../../../../core/ui/an_chip.dart';
import '../../../../core/ui/an_form_field.dart';
import '../../../../core/ui/an_hover_region.dart';
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
import 'voices_card.dart';

String? _serviceAccountValidationError(BuildContext context, String raw) {
  if (raw.isEmpty) return null;
  final t = Translations.of(context);
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return t.settings.keys.serviceAccountBad;
    }
    if (decoded['type'] != 'service_account' ||
        decoded['private_key'] is! String ||
        (decoded['private_key'] as String).isEmpty ||
        decoded['project_id'] is! String ||
        (decoded['project_id'] as String).isEmpty) {
      return t.settings.keys.serviceAccountBad;
    }
    return null;
  } on FormatException {
    return t.settings.keys.serviceAccountBad;
  }
}

String _modelOperationError(Translations t, ApiException error) =>
    switch (error.code) {
      AnselmErr.modelNotAgentCapable => t.settings.keys.agentModelNotCapable,
      _ => error.message,
    };

/// ④ 模型与密钥 — the resource flagship, THREE zones (0725 重构 — category finally drawn on the
/// face, WRK-077 施工序⑪): ① the MODEL-KEYS zone — the managed free-tier card (quota meter / enable
/// CTA) atop brand-logo BYOK rows for llm-category providers (managed row locked on top), the add
/// flow starting from a vendor LOGO GRID scoped to that category, save auto-probes (`:test`) into
/// the green/red status ② scenario defaults — each row collapses to a one-line summary and expands
/// into the reusable THREE-STAGE picker (credential → model [context window + capabilities] →
/// native knobs rendered generically) applying `{apiKeyId, modelId, options}` ③ the SEARCH-KEYS zone
/// — BYOK rows for search-category providers (its own logo-grid-scoped add flow) with the
/// default-search pick living beside the keys it governs (never a floating zone at the panel's
/// bottom); rows that haven't probed OK say so plainly, since the default picker only offers
/// `testStatus == 'ok'` keys. Every key mutation invalidates the capabilities catalog (S-15).
///
/// 模型与密钥——资源旗舰,三区(0725 重构——类别终于上脸,WRK-077 施工序⑪):①模型密钥区——受管免费档卡
/// (配额条/启用 CTA)顶着 llm 类 BYOK 品牌 logo 密钥行(受管行锁顶),添加流程从**限同类**的厂家 logo
/// 网格起步,保存即探测(:test)落绿红状态 ②场景默认——每行收起一句话摘要,点开进**可复用三段面板**
/// (凭证→模型[上下文窗+能力徽]→原生 knobs 通用渲染),应用 `{apiKeyId, modelId, options}` ③搜索密钥区
/// ——search 类 BYOK 行(自带限同类添加流程)与它管的默认搜索选择挨着(不再是面板底部的孤悬区);未探测
/// 通过的行明说,因为默认选择器只收 testStatus == 'ok' 的 key。密钥变更皆 invalidate 能力目录(S-15)。
class ModelsKeysPanel extends ConsumerWidget {
  const ModelsKeysPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(settingsDetailProvider);
    if (detail != null &&
        (detail.kind == 'addKey' || detail.kind == 'editKey')) {
      return KeyForm(editingId: detail.id, category: detail.category);
    }

    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _FreeTierCard(),
        SizedBox(height: AnSpace.s12),
        // Directly under the free-tier card because that is what it belongs to: cloning exists only
        // in the managed tier, and enrolling a voice spends managed allowance.
        // **紧贴**免费档卡下面,因为它就属于那里:克隆只存在于受管档,登记一个音色花的是受管额度。
        VoicesCard(),
        SizedBox(height: AnSpace.s24),
        _ModelKeysSection(),
        SizedBox(height: AnSpace.s24),
        _DefaultsSection(),
        SizedBox(height: AnSpace.s24),
        _SearchKeysSection(),
      ],
    );
  }
}

/// Zone ① (body) — model keys: BYOK rows for llm-category providers, managed row pinned on top and
/// locked. A provider absent from the catalog (or the catalog still loading) defaults here — [category]
/// on [ProviderMeta] itself defaults to 'llm', so "not explicitly search" IS the model classification,
/// never a silent vanish while `providersProvider` is in flight. 模型密钥区:llm 类 BYOK 行,受管行锁顶。
/// 目录里查无(或目录尚未拉到)的 provider 默认落此区——ProviderMeta.category 本身默认 'llm',「非显式
/// search」即模型分类,不会在 providersProvider 飞行中悄悄消失。
class _ModelKeysSection extends ConsumerWidget {
  const _ModelKeysSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Translations.of(context);
    final keys = ref.watch(apiKeysProvider);
    final providers =
        ref.watch(providersProvider).value ?? const <ProviderMeta>[];
    final managedNames = {
      for (final p in providers)
        if (p.managed) p.name,
    };
    final searchNames = {
      for (final p in providers)
        if (p.category == 'search') p.name,
    };

    return AnSection(
      label: t.settings.keys.modelKeysSection,
      variant: AnSectionVariant.quiet,
      actions: [
        const AnScopeBadge(AnSettingScope.workspace),
        const SizedBox(width: AnSpace.s8),
        AnButton(
          label: t.settings.keys.addKey,
          icon: AnIcons.plus,
          size: AnButtonSize.sm,
          outline: true,
          onPressed: () => ref
              .read(settingsDetailProvider.notifier)
              .push('addKey', category: 'llm'),
        ),
      ],
      children: [
        switch (keys) {
          AsyncData(:final value)
              when value.every((k) => searchNames.contains(k.provider)) =>
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AnSpace.s16),
              child: AnState(
                kind: AnStateKind.empty,
                // NOT the section title (WRK-083 墓碑): an empty state that repeats the heading right
                // above it is a gravestone — an icon, a word you already read, and no way forward.
                // Every other empty state in settings names the EMPTINESS (`noTools` / `noEnvs` /
                // `noMatches`) and says what to do next; these two borrowed a `*Section` key instead.
                // **不用分区标题**(WRK-083 墓碑):一个复读它正上方标题的空态就是块墓碑——一个图标、一个你刚
                // 读过的词、以及无路可走。设置里其余每一处空态都点名**空本身**(noTools/noEnvs/noMatches)并说下一步
                // 该做什么;唯独这两处借了 `*Section` 的 key。
                title: t.settings.keys.noModelKeys,
                hint: t.settings.keys.noModelKeysHint,
                size: AnStateSize.inset,
              ),
            ),
          AsyncData(:final value) => Column(
            children: [
              // Managed rows pinned on top, locked (no edit/delete affordances — S-1's UI half).
              // 受管行锁顶,无编辑删除入口(S-1 前端半)。
              for (final k in [
                ...value.where(
                  (k) =>
                      managedNames.contains(k.provider) &&
                      !searchNames.contains(k.provider),
                ),
                ...value.where(
                  (k) =>
                      !managedNames.contains(k.provider) &&
                      !searchNames.contains(k.provider),
                ),
              ])
                _KeyRow(row: k, managed: managedNames.contains(k.provider)),
            ],
          ),
          AsyncError() => AnState(
            kind: AnStateKind.error,
            title: t.settings.keys.keyOpFailed,
            size: AnStateSize.inset,
          ),
          _ => const SizedBox(height: AnSize.row),
        },
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
        ref
            .read(noticeCenterProvider.notifier)
            .show(
              Translations.of(context).settings.keys.freeFailed,
              tone: AnTone.warn,
            );
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                t.settings.keys.freeTier,
                style: AnText.label.copyWith(color: c.inkMuted),
              ),
              const Spacer(),
              if (quota.hasValue && quota.value != null)
                AnButton(
                  label: t.settings.keys.freeRefresh,
                  size: AnButtonSize.sm,
                  outline: true,
                  onPressed: () =>
                      ref.read(freetierQuotaProvider.notifier).refresh(),
                ),
            ],
          ),
          const SizedBox(height: AnSpace.s8),
          Row(
            children: [
              const AnBrandIcon.anselm(size: AnBrandSize.sm),
              const SizedBox(width: AnSpace.s8),
              Text(
                t.settings.keys.freeTierName,
                style: AnText.body
                    .weight(AnText.emphasisWeight)
                    .copyWith(color: c.ink),
              ),
            ],
          ),
          const SizedBox(height: AnSpace.s12),
          switch (quota) {
            AsyncData(:final value) when value == null => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.settings.keys.freeEnableHint,
                  style: AnText.meta.copyWith(color: c.inkFaint),
                ),
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
                    used: fmtCompactCount(
                      value.used,
                      locale: LocaleSettings.currentLocale.languageTag,
                    ),
                    limit: fmtCompactCount(
                      value.limit,
                      locale: LocaleSettings.currentLocale.languageTag,
                    ),
                    reset: fmtStamp(value.resetAt),
                  ),
                ),
                if (!value.available) ...[
                  const SizedBox(height: AnSpace.s8),
                  AnChip(t.settings.keys.freeUnavailable, tone: AnTone.warn),
                ],
              ],
            ),
            // The error branch carries the SAME repair CTA as the empty branch. A dead install
            // lands exactly here (the quota proxy 401s), and before this the card showed one line
            // of red text and nothing actionable — the workspace was dead-ended in the UI even
            // after the backend learned to heal (ProvisionNow re-registers on INVALID_INSTALL).
            // 错误分支带上与空分支**同一个**修复入口。install 死了恰好落在这里(配额代理 401),此前这卡
            // 只渲一行红字、无可操作——即便后端已会自愈(ProvisionNow 对 INVALID_INSTALL 重新登记),
            // UI 上 workspace 仍是死结。
            AsyncError() => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  quota.error is ApiException &&
                          (quota.error as ApiException).isTransient
                      ? t.settings.keys.freeTransientRepairHint
                      : t.settings.keys.freeRepairHint,
                  style: AnText.meta.copyWith(color: c.danger),
                ),
                const SizedBox(height: AnSpace.s8),
                AnButton(
                  label: _provisioning
                      ? t.settings.keys.freeProvisioning
                      : t.settings.keys.freeRepair,
                  variant: AnButtonVariant.primary,
                  onPressed: _provisioning ? null : _provision,
                ),
              ],
            ),
            _ => const AnMeter(ratio: null),
          },
        ],
      ),
    );
  }
}

/// One key row — brand-logo lead + resting identity (name + meta incl. the managed mark) + the
/// persistent probe dot at the trail + hover actions (BYOK only). [hint] is an optional note under
/// the label — the search-keys zone uses it for the honesty patch ("hasn't probed OK, won't be
/// offered as the default"). 密钥一行:品牌 logo 前导 + 静息身份常驻 + 探测状态点尾端常驻,动作 hover
/// 现(仅 BYOK)。hint=label 下可选注记——搜索密钥区借它做诚实补丁(「未探测通过,不会进默认」)。
class _KeyRow extends ConsumerWidget {
  const _KeyRow({required this.row, required this.managed, this.hint});

  final ApiKey row;
  final bool managed;
  final String? hint;

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
        final refs = details is Map && details['references'] is List
            ? (details['references'] as List).whereType<Map>().toList()
            : const <Map>[];
        final lines = refs
            .map((r) {
              final kind = r['kind']?.toString();
              final id = r['id']?.toString();
              final name = r['name']?.toString().trim();
              final label = switch (kind) {
                'scenario_default' => switch (id) {
                  'dialogue' => t.settings.keys.referenceDialogue,
                  'utility' => t.settings.keys.referenceUtility,
                  'agent' => t.settings.keys.referenceAgent,
                  _ => t.settings.keys.referenceUnknown,
                },
                'search_default' => t.settings.keys.referenceSearch,
                'agent_override' =>
                  name == null || name.isEmpty
                      ? t.settings.keys.referenceAgentOverride
                      : '${t.settings.keys.referenceAgentOverride} · $name',
                _ =>
                  name == null || name.isEmpty
                      ? t.settings.keys.referenceUnknown
                      : name,
              };
              return '· $label';
            })
            .join('\n');
        await overlay.info(
          title: t.settings.keys.inUseTitle,
          message: '${t.settings.keys.inUseHint}\n$lines',
          closeLabel: t.feedback.dismiss,
          barrierLabel: t.settings.keys.inUseTitle,
        );
      } else {
        ref
            .read(noticeCenterProvider.notifier)
            .show(e.message, tone: AnTone.danger);
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
          : brandIconOr(
              kProviderBrand[row.provider],
              fallbackLabel: row.provider,
              size: AnBrandSize.sm,
            ),
      // The probe outcome stays visible at rest (the hover slot holds actions). 探测态尾端常驻。
      trailingDot: switch (row.testStatus) {
        'ok' => AnStatus.done,
        'error' => AnStatus.err,
        _ => null,
      },
      // Row click = edit (BYOK). Also load-bearing: AnInteractive only tracks hover when the row is
      // activatable, so without onSelect the hover actions would be unreachable on a real mouse.
      // 行点击=编辑(BYOK)。且承重:AnInteractive 仅在可激活时跟踪 hover,没 onSelect 真鼠标够不到动作。
      onSelect: managed
          ? null
          : () => ref
                .read(settingsDetailProvider.notifier)
                .push('editKey', id: row.id),
      label: row.displayName,
      hint: hint,
      // Managed identity rides the ALWAYS-visible meta — the hover slot is for actions, and a
      // managed row has none. 受管身份走常驻 meta——hover 槽只放动作,受管行没有动作。
      meta:
          '${managed ? '${t.settings.keys.managedBadge} · ' : ''}${row.provider} · ${row.keyMasked}',
      actions: [
        if (!managed) ...[
          AnChip(label, tone: tone),
          const SizedBox(width: AnSpace.s2),
          AnButton.iconOnly(
            AnIcons.probe,
            semanticLabel: t.settings.keys.testKey,
            size: AnButtonSize.sm,
            onPressed: () async {
              try {
                await ref.read(apiKeysProvider.notifier).test(row.id);
              } on ApiException catch (e) {
                ref
                    .read(noticeCenterProvider.notifier)
                    .show(e.message, tone: AnTone.danger);
              }
            },
          ),
          const SizedBox(width: AnSpace.s2),
          AnButton.iconOnly(
            AnIcons.edit,
            semanticLabel: t.settings.keys.editKey,
            size: AnButtonSize.sm,
            onPressed: () => ref
                .read(settingsDetailProvider.notifier)
                .push('editKey', id: row.id),
          ),
          const SizedBox(width: AnSpace.s2),
          AnButton.iconOnly(
            AnIcons.trash,
            semanticLabel: t.settings.keys.deleteKey,
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
  const KeyForm({this.editingId, this.category, super.key});

  final String? editingId;

  /// The provider category ('llm' | 'search') the stage-0 logo grid scopes to — null shows every
  /// non-managed provider (the pre-0725 behaviour; editing never sets this since the provider is
  /// already fixed). 厂家 logo 网格限定的类别;null=不过滤(0725 前行为;编辑态不设,provider 已定)。
  final String? category;

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
  String _errorCode = '';
  int _errorStatus = 0;
  bool _credentialSaved = false;
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

  /// Which KIND of failure the last attempt was — three kinds, and telling them apart is the whole
  /// point (WRK-085 §7):
  ///
  ///   - **the key is wrong** — the ordinary case, and the backend's own message already says it;
  ///   - **we have never tried this provider** (`curated == false`) — reached by the mechanical
  ///     `npm` → dialect mapping out of models.dev. It probably works. But if it does not, the fault
  ///     may well be ours, and letting the user re-copy a correct key three times while we say
  ///     nothing is the dishonest option;
  ///   - **the address is wrong** — indistinguishable from a bad key at the wire (a base URL that
  ///     points somewhere real but wrong answers 401 exactly like a bad key does). Whenever the base
  ///     URL is one the USER supplied, an auth failure must point at that field too.
  ///
  /// 上一次尝试是**哪一种**失败——三种,而把它们分开正是全部要点(WRK-085 §7):
  ///
  ///   - **key 不对**——寻常情形,后端自己的消息已经说了;
  ///   - **这家我们没试过**(`curated == false`)——靠 models.dev 的机械 `npm` → 方言映射抵达。它
  ///     **多半能用**。但万一不能,过错很可能在我们这边,而让用户在我们一声不吭的情况下把一把**正确的**
  ///     key 重抄三遍,是那个不诚实的选项;
  ///   - **地址不对**——在线缆上与「key 不对」**无法区分**(一个指向真实但错误的地方的 base URL,
  ///     答的 401 与一把坏 key 一模一样)。凡 base URL 是**用户自己填的**,鉴权失败就必须**同时指向那一栏**。
  bool get _looksLikeAuth =>
      _errorStatus == 401 ||
      _errorStatus == 403 ||
      _errorCode == 'API_KEY_TEST_FAILED' ||
      _errorCode.contains('AUTH');

  bool _blameBaseUrl(ProviderMeta? meta) =>
      _error != null &&
      _looksLikeAuth &&
      (meta?.baseUrlRequired ?? false) &&
      _baseUrl.text.trim().isNotEmpty;

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
      _errorCode = '';
      _errorStatus = 0;
      _credentialSaved = false;
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
        _credentialSaved = true;
      } else {
        // In edit mode an empty Base URL is an intentional clear, not an omitted PATCH field. The
        // backend treats `baseUrl: ""` as the durable reset; passing null would be removed by the
        // JSON map and silently preserve the old address.
        // 编辑态空地址是明确清空，不是省略 PATCH 字段。后端以 `baseUrl: ""` 持久化重置；传 null 会被
        // JSON map 删除，悄悄保留旧地址。
        await keys.patch(
          _boundId!,
          displayName: _name.text.trim(),
          baseUrl: _baseUrl.text.trim(),
          key: _secret.text.isEmpty ? null : _secret.text,
        );
        _credentialSaved = true;
      }
      _secret.clear(); // the redeemable promise ③ 可兑现承诺③
      await keys.test(_boundId!);
      if (mounted) ref.read(settingsDetailProvider.notifier).pop();
    } on ApiException catch (e) {
      // The code and status are kept so the form can say WHICH KIND of failure this is. The backend's
      // own message is never replaced — it may be the only true sentence we have.
      // 存下 code 与 status,好让表单能说清这是**哪一种**失败。后端自己的消息**绝不替换**——它可能是
      // 我们手上唯一一句真话。
      setState(() {
        _error = e.message;
        _errorCode = e.code;
        _errorStatus = e.httpStatus;
      });
    } catch (e) {
      setState(() {
        _error = '$e';
        _errorCode = '';
        _errorStatus = 0;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    final providers =
        (ref.watch(providersProvider).value ?? const <ProviderMeta>[])
            .where((p) => !p.managed)
            .where(
              (p) => widget.category == null || p.category == widget.category,
            )
            .toList();
    final meta = providers.where((p) => p.name == _provider).firstOrNull;
    final editing = widget.editingId != null;

    // ADD stage 0 — the provider market. 添加第 0 段:供应商市场。
    if (!editing && _provider.isEmpty) {
      return _ProviderMarket(
        providers: providers,
        onPick: (p) => setState(() {
          _provider = p.name;
          if (_baseUrl.text.isEmpty) _baseUrl.text = p.defaultBaseUrl;
        }),
      );
    }

    // The base URL is a HARD requirement for self-hosted dialects. 自托管方言 baseUrl 硬必填。
    final baseUrlMissing =
        (meta?.baseUrlRequired ?? false) && _baseUrl.text.trim().isEmpty;
    final credentialInvalid =
        meta?.credential == 'service_account_json' &&
        _serviceAccountValidationError(context, _secret.text) != null;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: AnSize.formMaxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              brandIconOr(
                kProviderBrand[_provider],
                fallbackLabel: meta?.displayName ?? _provider,
                size: AnBrandSize.sm,
              ),
              const SizedBox(width: AnSpace.s8),
              Text(
                meta?.displayName ?? _provider,
                style: AnText.body
                    .weight(AnText.emphasisWeight)
                    .copyWith(color: c.ink),
              ),
              if (!editing) ...[
                const SizedBox(width: AnSpace.s8),
                AnButton(
                  label: t.settings.keys.changeProvider,
                  size: AnButtonSize.sm,
                  onPressed: () => setState(() => _provider = ''),
                ),
              ],
            ],
          ),
          const SizedBox(height: AnSpace.s12),
          AnFormField(
            label: t.settings.keys.displayNameLabel,
            child: AnInput(controller: _name, block: true),
          ),
          const SizedBox(height: AnSpace.s12),
          // The credential control follows what the provider actually takes. Vertex is the only one
          // that wants a service-account JSON FILE, and offering it a box labelled「API key」would
          // send the user hunting for a key their Google project does not have. The file is still
          // stored as one string — it IS one — so this changes the control, not the shape.
          // 凭证控件跟着**这家真正收什么**走。Vertex 是唯一要服务账号 **JSON 文件**的,给它一个写着
          // 「API key」的框,会把用户送去找一把他的 Google 项目**根本没有**的 key。文件仍然作为**一个
          // 字符串**存(它**本来就是**),故这里换的是控件、不是形状。
          if (meta?.credential == 'service_account_json')
            AnFormField(
              label: t.settings.keys.serviceAccountLabel,
              desc: t.settings.keys.serviceAccountHint,
              child: _ServiceAccountField(
                controller: _secret,
                editing: editing,
              ),
            )
          else
            AnFormField(
              label: t.settings.keys.secretLabel,
              child: AnSecretField(
                controller: _secret,
                placeholder: editing ? t.settings.keys.rotatePlaceholder : null,
                revealLabel: t.settings.keys.reveal,
                concealLabel: t.settings.keys.conceal,
              ),
            ),
          if (editing)
            Padding(
              padding: const EdgeInsets.only(top: AnSpace.s4),
              // The rotate note is a NOTE under the control, never a field label. 旋转注记非字段标签。
              child: Text(
                t.settings.keys.rotateWarn,
                style: AnText.meta.copyWith(color: c.warn),
              ),
            ),
          if (meta == null ||
              meta.baseUrlRequired ||
              _baseUrl.text.isNotEmpty ||
              editing) ...[
            const SizedBox(height: AnSpace.s12),
            AnFormField(
              label: t.settings.keys.baseUrlLabel,
              // A catalog TEMPLATE outranks the generic「required」note: it says WHERE the account
              // name goes, which is the only thing the user is actually missing.
              // 目录**模板**压过那句笼统的「必填」:它说的是**账号名填在哪**,而那正是用户唯一缺的东西。
              // An auth failure on a user-supplied address outranks both hints: at that moment the
              // most useful sentence on the form is「it might be this field, not your key」.
              // 用户自填地址上的鉴权失败**压过**两条提示:那一刻表单上最有用的一句话是
              // 「可能是这一栏、不是你的 key」。
              desc: _blameBaseUrl(meta)
                  ? t.settings.keys.baseUrlSuspect
                  : ((meta?.baseUrlHint.isNotEmpty ?? false)
                        ? t.settings.keys.baseUrlTemplateHint(
                            shape: meta!.baseUrlHint,
                          )
                        : ((meta?.baseUrlRequired ?? false)
                              ? t.settings.keys.baseUrlRequiredHint
                              : null)),
              child: AnInput(controller: _baseUrl, block: true, mono: true),
            ),
          ],
          if (_provider == 'custom') ...[
            const SizedBox(height: AnSpace.s12),
            AnFormField(
              label: t.settings.keys.apiFormatLabel,
              child: AnSegmented<String>(
                options: const [
                  AnSegmentedOption(
                    value: 'openai-compatible',
                    label: 'OpenAI',
                  ),
                  AnSegmentedOption(
                    value: 'anthropic-compatible',
                    label: 'Anthropic',
                  ),
                ],
                value: _apiFormat,
                onChanged: (v) => setState(() => _apiFormat = v),
              ),
            ),
          ],
          if (_error != null) ...[
            if (_credentialSaved && _errorCode == 'API_KEY_TEST_FAILED')
              Padding(
                padding: const EdgeInsets.only(top: AnSpace.s8),
                child: Text(
                  t.settings.keys.keySavedProbeFailed,
                  style: AnText.label.copyWith(color: c.warn),
                ),
              ),
            Padding(
              // Match the other settings forms' inline-error idiom (label + s8), not meta + s12. 与其余设置表一致。
              padding: const EdgeInsets.only(top: AnSpace.s8),
              child: Text(
                _error!,
                style: AnText.label.copyWith(color: c.danger),
              ),
            ),
            // The second line names the KIND. Never replaces the backend's own sentence above it —
            // this one is our guess, that one is what actually happened.
            // 第二行给出**种类**。绝不替换上面那句后端自己的话——这一句是我们的**猜测**,那一句是
            // **真正发生的事**。
            if (_blameBaseUrl(meta))
              Padding(
                padding: const EdgeInsets.only(top: AnSpace.s4),
                child: Text(
                  t.settings.keys.diagCheckBaseUrl,
                  style: AnText.meta.copyWith(color: c.warn),
                ),
              )
            else if (!(meta?.curated ?? true))
              Padding(
                padding: const EdgeInsets.only(top: AnSpace.s4),
                child: Text(
                  t.settings.keys.diagUnverified,
                  style: AnText.meta.copyWith(color: c.warn),
                ),
              ),
          ],
          const SizedBox(height: AnSpace.s16),
          Row(
            children: [
              if (_saving) ...[
                AnSpinner(
                  size: AnSize.iconSm,
                  semanticLabel: t.settings.keys.savingProbe,
                ),
                const SizedBox(width: AnSpace.s8),
              ],
              AnButton(
                label: _saving
                    ? t.settings.keys.savingProbe
                    : t.settings.keys.saveKey,
                variant: AnButtonVariant.primary,
                onPressed:
                    _saving ||
                        baseUrlMissing ||
                        credentialInvalid ||
                        (_boundId == null &&
                            (_provider.isEmpty || _secret.text.isEmpty))
                    ? null
                    : _save,
              ),
              const SizedBox(width: AnSpace.s8),
              AnButton(
                label: t.settings.keys.cancel,
                onPressed: () =>
                    ref.read(settingsDetailProvider.notifier).pop(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Zone ③ — scenario defaults: six collapsed one-line rows, each expanding into the reusable
/// three-stage picker. 场景默认区:六行收起摘要,点开进可复用三段面板。
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
          clearable: false,
        ), // S-6: dialogue 不渲清除项
        _ScenarioDefaultRow(
          scenario: 'utility',
          label: t.settings.keys.scenarioUtility,
          desc: t.settings.keys.scenarioUtilityDesc,
          current: ws?.defaultUtility,
          clearable: true,
        ),
        _ScenarioDefaultRow(
          scenario: 'agent',
          label: t.settings.keys.scenarioAgent,
          desc: t.settings.keys.scenarioAgentDesc,
          current: ws?.defaultAgent,
          clearable: true,
        ),
        _GenScenarioRow(
          scenario: 'image',
          current: ws?.defaultImage,
          providerDefaults: _imageProviderDefaults,
          toggleKey: const ValueKey('imageDefaultToggle'),
          label: t.settings.keys.scenarioImage,
          desc: t.settings.keys.scenarioImageDesc,
          autoSummary: t.settings.keys.imageAutoSummary,
          noRoute: t.settings.keys.imageNoRoute,
          noRouteHint: t.settings.keys.imageNoRouteHint,
          managedOption: t.settings.keys.imageManagedOption,
        ),
        _GenScenarioRow(
          scenario: 'speech',
          current: ws?.defaultSpeech,
          providerDefaults: _speechProviderDefaults,
          toggleKey: const ValueKey('speechDefaultToggle'),
          label: t.settings.keys.scenarioSpeech,
          desc: t.settings.keys.scenarioSpeechDesc,
          autoSummary: t.settings.keys.imageAutoSummary,
          noRoute: t.settings.keys.speechNoRoute,
          noRouteHint: t.settings.keys.imageNoRouteHint,
          managedOption: t.settings.keys.imageManagedOption,
        ),
        _GenScenarioRow(
          scenario: 'video',
          current: ws?.defaultVideo,
          providerDefaults: _videoProviderDefaults,
          toggleKey: const ValueKey('videoDefaultToggle'),
          label: t.settings.keys.scenarioVideo,
          desc: t.settings.keys.scenarioVideoDesc,
          autoSummary: t.settings.keys.imageAutoSummary,
          noRoute: t.settings.keys.videoNoRoute,
          noRouteHint: t.settings.keys.imageNoRouteHint,
          managedOption: t.settings.keys.imageManagedOption,
        ),
        if (ws != null && ws.defaultDialogue == null)
          Padding(
            padding: const EdgeInsets.only(left: AnSpace.s8, top: AnSpace.s4),
            // Human words on the face; the wire code rides the tooltip (0719: 裸码不上脸). 人话上脸,
            // 线缆码收 tooltip。
            child: AnTooltip(
              message: 'MODEL_NOT_CONFIGURED',
              child: Text(
                t.settings.keys.notConfiguredWarn,
                style: AnText.meta.copyWith(color: context.colors.warn),
              ),
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
  ConsumerState<_ScenarioDefaultRow> createState() =>
      _ScenarioDefaultRowState();
}

class _ScenarioDefaultRowState extends ConsumerState<_ScenarioDefaultRow> {
  bool _open = false;

  Future<void> _apply(
    String apiKeyId,
    String modelId,
    Map<String, String> options,
  ) async {
    final t = Translations.of(context);
    try {
      await ref
          .read(workspacePrefsProvider.notifier)
          .setDefaultModel(
            widget.scenario,
            apiKeyId: apiKeyId,
            modelId: modelId,
            options: options,
          );
      if (mounted) setState(() => _open = false);
    } on ApiException catch (e) {
      ref
          .read(noticeCenterProvider.notifier)
          .show(_modelOperationError(t, e), tone: AnTone.danger);
    }
  }

  Future<void> _clear() async {
    final t = Translations.of(context);
    try {
      await ref
          .read(workspacePrefsProvider.notifier)
          .clearDefaultModel(widget.scenario);
      if (mounted) setState(() => _open = false);
    } on ApiException catch (e) {
      ref
          .read(noticeCenterProvider.notifier)
          .show(_modelOperationError(t, e), tone: AnTone.danger);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    final capsState = ref.watch(modelCapabilitiesProvider);
    final caps = capsState.value ?? const <ModelCapability>[];
    final cur = widget.current;
    final capOfCur = cur == null
        ? null
        : caps
              .where(
                (x) => x.apiKeyId == cur.apiKeyId && x.modelId == cur.modelId,
              )
              .firstOrNull;
    final summary = cur == null
        ? t.settings.keys.noDefault
        : '${capOfCur?.displayName.isNotEmpty == true ? capOfCur!.displayName : cur.modelId}'
              '${capOfCur == null ? '' : ' · ${capOfCur.keyName}'}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnSettingRow(
          label: widget.label,
          desc: widget.desc,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: AnSize.ctlSlotLg),
                child: Text(
                  summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AnText.label.copyWith(
                    color: cur == null ? c.inkFaint : c.inkMuted,
                  ),
                ),
              ),
              const SizedBox(width: AnSpace.s8),
              AnButton(
                label: _open
                    ? t.settings.keys.pickerClose
                    : t.settings.keys.pickerChange,
                size: AnButtonSize.sm,
                outline: true,
                onPressed: () => setState(() => _open = !_open),
              ),
            ],
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.only(top: AnSpace.s8, bottom: AnSpace.s8),
            child: _DefaultModelModePanel(
              key: ValueKey('picker:${widget.scenario}'),
              caps: caps,
              catalogLoading: capsState.isLoading && caps.isEmpty,
              catalogError: capsState.hasError && caps.isEmpty,
              onRetryCatalog: () => ref.invalidate(modelCapabilitiesProvider),
              initial: cur,
              clearable: widget.clearable && cur != null,
              onApply: _apply,
              onClear: _clear,
              // Scenario defaults are ALWAYS an llm-category model route — scope the grid so the
              // jump-to-add-key doesn't dump search vendors into a model picker. 场景默认恒为 llm
              // 类模型路线——网格限类,不把搜索厂家掺进模型选择器。
              onAddKey: () => ref
                  .read(settingsDetailProvider.notifier)
                  .push('addKey', category: 'llm'),
            ),
          ),
      ],
    );
  }
}

/// The workspace-default selector separates Anselm Auto from external models.
/// Anselm's gateway is one fixed product mode: it owns routing and reasoning,
/// therefore it intentionally has no credential/model/knob picker. The old
/// three-stage picker remains available only after the user explicitly picks
/// an external model route.
///
/// 默认模型选择器把 Anselm Auto 与外部模型分开。网关是一个固定产品模式：路由与推理由它
/// 自己拥有，故刻意没有 credential/model/knob picker；用户明确选择外部模型后才进入原
/// 三段 picker。
class _DefaultModelModePanel extends StatefulWidget {
  const _DefaultModelModePanel({
    required this.caps,
    required this.onApply,
    this.initial,
    this.clearable = false,
    this.onClear,
    this.onAddKey,
    this.catalogLoading = false,
    this.catalogError = false,
    this.onRetryCatalog,
    super.key,
  });

  final List<ModelCapability> caps;
  final ModelRef? initial;
  final bool clearable;
  final void Function(
    String apiKeyId,
    String modelId,
    Map<String, String> options,
  )
  onApply;
  final VoidCallback? onClear;
  final VoidCallback? onAddKey;
  final bool catalogLoading;
  final bool catalogError;
  final VoidCallback? onRetryCatalog;

  @override
  State<_DefaultModelModePanel> createState() => _DefaultModelModePanelState();
}

class _DefaultModelModePanelState extends State<_DefaultModelModePanel> {
  late bool _external;

  List<ModelCapability> get _managed =>
      widget.caps.where((cap) => cap.provider == 'anselm').toList();
  List<ModelCapability> get _externalCaps =>
      widget.caps.where((cap) => cap.provider != 'anselm').toList();

  @override
  void initState() {
    super.initState();
    final current = widget.initial;
    _external =
        current != null &&
        _externalCaps.any(
          (cap) =>
              cap.apiKeyId == current.apiKeyId &&
              cap.modelId == current.modelId,
        );
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final managed = _managed.firstOrNull;
    if (managed == null) {
      // Before free-tier provisioning there is no Auto route to offer; retaining
      // the external picker is honest and keeps setup unblocked.
      return ModelPickerPanel(
        caps: _externalCaps,
        catalogLoading: widget.catalogLoading && _externalCaps.isEmpty,
        catalogError: widget.catalogError && _externalCaps.isEmpty,
        onRetryCatalog: widget.onRetryCatalog,
        initial: widget.initial,
        clearable: widget.clearable,
        onApply: widget.onApply,
        onClear: widget.onClear,
        onAddKey: widget.onAddKey,
      );
    }

    return AnCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnRow(
            leadWidget: const AnBrandIcon.anselm(size: AnBrandSize.sm),
            label: t.settings.keys.anselmAuto,
            meta: t.settings.keys.anselmAutoDesc,
            selected: !_external,
            onSelect: () => widget.onApply(
              managed.apiKeyId,
              managed.modelId,
              const <String, String>{},
            ),
          ),
          // The managed route is a complete mode, not a picker stage. Keep its recovery action
          // visible here when this scenario is clearable; otherwise a configured utility/agent
          // default cannot be removed while Anselm Auto is the only route. 受管路线是完整模式而非
          // picker 阶段；可清除场景须在这里保留自救入口，否则只有 Anselm Auto 时无法清除默认。
          if (!_external && widget.clearable && widget.onClear != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: AnSpace.s8),
                child: AnButton(
                  label: t.settings.keys.clearDefault,
                  size: AnButtonSize.sm,
                  outline: true,
                  onPressed: widget.onClear,
                ),
              ),
            ),
          if (_externalCaps.isNotEmpty) ...[
            const SizedBox(height: AnSpace.s8),
            AnRow(
              leadWidget: const AnBrandIcon.glyph('↗', size: AnBrandSize.sm),
              label: t.settings.keys.externalModel,
              meta: t.settings.keys.externalModelDesc,
              selected: _external,
              onSelect: () => setState(() => _external = true),
            ),
            if (_external) ...[
              const SizedBox(height: AnSpace.s12),
              ModelPickerPanel(
                caps: _externalCaps,
                catalogLoading: widget.catalogLoading && _externalCaps.isEmpty,
                catalogError: widget.catalogError && _externalCaps.isEmpty,
                onRetryCatalog: widget.onRetryCatalog,
                // A managed default is not a valid initial selection for the external
                // catalog. Passing it through leaves the picker with a selected key that
                // is absent from `caps`, so the model stage renders empty on first entry.
                // 受管默认不是外部目录的合法初始选择；否则首次进入时会选中一个不在
                // `caps` 中的 key，导致模型阶段空白。
                initial:
                    widget.initial != null &&
                        _externalCaps.any(
                          (cap) =>
                              cap.apiKeyId == widget.initial!.apiKeyId &&
                              cap.modelId == widget.initial!.modelId,
                        )
                    ? widget.initial
                    : null,
                clearable: widget.clearable,
                onApply: widget.onApply,
                onClear: widget.onClear,
                onAddKey: widget.onAddKey,
              ),
            ],
          ],
        ],
      ),
    );
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
    this.catalogLoading = false,
    this.catalogError = false,
    this.onRetryCatalog,
    super.key,
  });

  final List<ModelCapability> caps;
  final ModelRef? initial;
  final bool clearable;
  final void Function(
    String apiKeyId,
    String modelId,
    Map<String, String> options,
  )
  onApply;
  final VoidCallback? onClear;
  final VoidCallback? onAddKey;
  final bool catalogLoading;
  final bool catalogError;
  final VoidCallback? onRetryCatalog;

  @override
  State<ModelPickerPanel> createState() => _ModelPickerPanelState();
}

class _ModelPickerPanelState extends State<ModelPickerPanel> {
  String? _keyId;
  String? _modelId;
  final Map<String, String> _knobValues = {};
  final Map<String, TextEditingController> _intCtls = {};
  late final TextEditingController _nativeOptionsCtl;
  bool _advancedNativeOptions = false;
  String? _nativeOptionsError;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    if (init != null) {
      _keyId = init.apiKeyId;
      _modelId = init.modelId;
      _knobValues.addAll(init.options);
    }
    _nativeOptionsCtl = TextEditingController(text: _nativeOptionsJSON());
  }

  @override
  void dispose() {
    for (final ctl in _intCtls.values) {
      ctl.dispose();
    }
    _nativeOptionsCtl.dispose();
    super.dispose();
  }

  ModelCapability? get _cap => _modelId == null
      ? null
      : widget.caps
            .where((x) => x.apiKeyId == _keyId && x.modelId == _modelId)
            .firstOrNull;

  String _knobValue(ModelKnob k) => _knobValues[k.key] ?? k.defaultValue;

  TextEditingController _intCtl(ModelKnob k) => _intCtls.putIfAbsent(
    k.key,
    () => TextEditingController(text: _knobValue(k)),
  );

  /// ctx window → compact figure (128000 → 128K). 上下文窗→紧凑数字。
  static String fmtCtx(int n) => n >= 1000 ? '${(n / 1000).round()}K' : '$n';

  Map<String, String> _selectedOptions([ModelCapability? cap]) {
    final selected = cap ?? _cap;
    if (selected == null) return const <String, String>{};
    return <String, String>{
      for (final k in selected.knobs)
        if ((_knobValues[k.key] ?? '').isNotEmpty &&
            _knobValues[k.key] != k.defaultValue)
          k.key: _knobValues[k.key]!,
    };
  }

  String _nativeOptionsJSON([ModelCapability? cap]) =>
      const JsonEncoder.withIndent('  ').convert(_selectedOptions(cap));

  void _syncNativeOptions([ModelCapability? cap]) {
    if (!_advancedNativeOptions) return;
    final next = _nativeOptionsJSON(cap);
    if (_nativeOptionsCtl.text == next) return;
    _nativeOptionsCtl.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  void _setKnob(ModelKnob knob, String value) {
    setState(() {
      _knobValues[knob.key] = value;
      _nativeOptionsError = null;
      _syncNativeOptions();
    });
  }

  void _selectKey(String id) {
    if (_keyId == id) return;
    setState(() {
      _keyId = id;
      _modelId = null;
      _knobValues.clear();
      _intCtls.clear();
      _nativeOptionsError = null;
      _nativeOptionsCtl.text = _nativeOptionsJSON();
    });
  }

  void _selectModel(ModelCapability model) {
    if (_modelId == model.modelId) return;
    setState(() {
      _modelId = model.modelId;
      _knobValues.clear();
      _intCtls.clear();
      _nativeOptionsError = null;
      _nativeOptionsCtl.text = _nativeOptionsJSON(model);
    });
  }

  bool _validNativeValue(ModelKnob knob, String value) => switch (knob.type) {
    'enum' => knob.values.contains(value),
    'bool' => value == 'true' || value == 'false',
    'int' => int.tryParse(value) != null,
    _ => false,
  };

  void _applyNativeOptions(BuildContext context, ModelCapability cap) {
    final t = Translations.of(context);
    try {
      final decoded = jsonDecode(_nativeOptionsCtl.text);
      if (decoded is! Map) {
        setState(
          () => _nativeOptionsError = t.settings.keys.nativeSettingsInvalid,
        );
        return;
      }
      final knobs = {for (final k in cap.knobs) k.key: k};
      final next = <String, String>{};
      for (final entry in decoded.entries) {
        if (entry.key is! String || entry.value is! String) {
          setState(
            () => _nativeOptionsError = t.settings.keys.nativeSettingsInvalid,
          );
          return;
        }
        final knob = knobs[entry.key];
        if (knob == null) {
          setState(
            () =>
                _nativeOptionsError = t.settings.keys.nativeSettingsUnsupported,
          );
          return;
        }
        if (!_validNativeValue(knob, entry.value)) {
          setState(
            () => _nativeOptionsError =
                t.settings.keys.nativeSettingsInvalidValue,
          );
          return;
        }
        if (entry.value != knob.defaultValue) next[entry.key] = entry.value;
      }
      setState(() {
        _knobValues
          ..clear()
          ..addAll(next);
        for (final knob in cap.knobs.where((k) => k.type == 'int')) {
          final ctl = _intCtls[knob.key];
          if (ctl != null) ctl.text = _knobValue(knob);
        }
        _nativeOptionsError = null;
        _syncNativeOptions(cap);
      });
    } on FormatException {
      setState(
        () => _nativeOptionsError = t.settings.keys.nativeSettingsInvalid,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;

    // A refresh must not hide a usable last-good catalog. Only an empty catalog owns the
    // loading/error state surface; otherwise the current keys/models remain actionable.
    // 刷新期间不得藏掉仍可用的 last-good 目录；只有空目录才占用加载/错误面。
    if (widget.catalogLoading && widget.caps.isEmpty) {
      return AnState(
        kind: AnStateKind.loading,
        title: t.settings.keys.modelCatalogLoading,
        size: AnStateSize.inset,
      );
    }

    if (widget.catalogError && widget.caps.isEmpty) {
      return AnState(
        kind: AnStateKind.error,
        title: t.settings.keys.modelCatalogFailed,
        hint: t.settings.keys.modelCatalogFailedHint,
        action: widget.onRetryCatalog == null
            ? null
            : AnButton(
                label: t.settings.keys.refreshModels,
                size: AnButtonSize.sm,
                onPressed: widget.onRetryCatalog,
              ),
        size: AnStateSize.inset,
      );
    }

    if (widget.caps.isEmpty) {
      // Zero usable models — guidance, not a dead dropdown (0719 零可用引导). 零可用引导。
      return AnCard(
        child: Row(
          children: [
            Expanded(
              child: Text(
                t.settings.keys.noCapsGuide,
                style: AnText.label.copyWith(color: c.inkMuted),
              ),
            ),
            // A stale default must remain recoverable even while the capability catalog is empty;
            // hiding Clear here strands the user behind the unavailable provider. 能力目录暂空时，
            // 失效默认仍必须可自救清除；否则用户会被不可用 provider 卡死。
            if (widget.clearable && widget.onClear != null) ...[
              AnButton(
                label: t.settings.keys.clearDefault,
                size: AnButtonSize.sm,
                outline: true,
                onPressed: widget.onClear,
              ),
              const SizedBox(width: AnSpace.s8),
            ],
            if (widget.onAddKey != null)
              AnButton(
                label: t.settings.keys.addKey,
                size: AnButtonSize.sm,
                outline: true,
                onPressed: widget.onAddKey,
              ),
          ],
        ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t.settings.keys.stageCredential,
            style: AnText.meta.copyWith(color: c.inkFaint),
          ),
          const SizedBox(height: AnSpace.s4),
          for (final id in keyIds)
            Builder(
              builder: (context) {
                final sample = widget.caps.firstWhere((x) => x.apiKeyId == id);
                return AnRow(
                  leadWidget: brandIconOr(
                    kProviderBrand[sample.provider],
                    fallbackLabel: sample.keyName.isEmpty
                        ? sample.provider
                        : sample.keyName,
                    size: AnBrandSize.sm,
                  ),
                  label: sample.keyName.isEmpty
                      ? sample.provider
                      : sample.keyName,
                  meta: sample.provider,
                  selected: id == _keyId,
                  onSelect: () => _selectKey(id),
                );
              },
            ),
          if (_keyId != null) ...[
            const SizedBox(height: AnSpace.s12),
            Text(
              t.settings.keys.stageModel,
              style: AnText.meta.copyWith(color: c.inkFaint),
            ),
            const SizedBox(height: AnSpace.s4),
            // Stage ② — the models this key serves, with capability specs. 该 key 的模型+能力规格。
            for (final m in models)
              AnRow(
                leadless: true,
                label: m.displayName.isEmpty ? m.modelId : m.displayName,
                meta: [
                  if (m.textInputLimit > 0)
                    t.settings.keys.textContextBadge(
                      context: fmtCtx(m.textInputLimit),
                    )
                  else if (m.contextWindow > 0)
                    fmtCtx(m.contextWindow),
                  if (m.multimodalInputLimit > 0)
                    t.settings.keys.mediaContextBadge(
                      context: fmtCtx(m.multimodalInputLimit),
                    ),
                  if (m.vision) t.settings.keys.visionBadge,
                  if (m.video) t.settings.keys.videoBadge,
                  if (m.audio) t.settings.keys.audioBadge,
                  if (m.nativeDocs) t.settings.keys.docsBadge,
                  // A model without tools is LISTED and labelled, never hidden. It is a good chat
                  // model and a useless agent; the catalog used to drop it, which read as「that
                  // model does not exist」with no way to learn otherwise (H12-b).
                  // 没有工具的模型**列出来并标注**、绝不隐藏。它是个好聊天模型、一个没用的 agent;
                  // 此前目录直接丢掉它,读起来是「那个模型不存在」,且无从知道并非如此(H12-b)。
                  if (!m.tools) t.settings.keys.chatOnlyBadge,
                ].join(' · '),
                selected: m.modelId == _modelId,
                onSelect: () => _selectModel(m),
              ),
          ],
          if (cap != null && cap.knobs.isNotEmpty) ...[
            const SizedBox(height: AnSpace.s12),
            Text(
              t.settings.keys.stageKnobs,
              style: AnText.meta.copyWith(color: c.inkFaint),
            ),
            const SizedBox(height: AnSpace.s4),
            // Stage ③ — native knobs, generically rendered from the descriptor. 原生 knobs 通用渲染。
            for (final k in cap.knobs)
              AnSettingRow(
                label: k.label.isEmpty ? k.key : k.label,
                child: switch (k.type) {
                  'enum' => SizedBox(
                    width: AnSize.ctlSlot,
                    child: AnDropdown<String>(
                      options: [
                        for (final v in k.values)
                          AnDropdownOption(value: v, label: v),
                      ],
                      value: k.values.contains(_knobValue(k))
                          ? _knobValue(k)
                          : null,
                      onChanged: (v) => _setKnob(k, v),
                    ),
                  ),
                  'bool' => AnSwitch(
                    value: _knobValue(k) == 'true',
                    onChanged: (v) => _setKnob(k, '$v'),
                  ),
                  _ => SizedBox(
                    width: AnSize.numField,
                    child: AnInput(
                      controller: _intCtl(k),
                      mono: true,
                      onChanged: (v) => _setKnob(k, v.trim()),
                    ),
                  ),
                },
              ),
          ],
          if (cap != null && cap.knobs.isNotEmpty) ...[
            const SizedBox(height: AnSpace.s12),
            AnSettingRow(
              label: t.settings.keys.nativeSettings,
              desc: t.settings.keys.nativeSettingsDesc,
              child: AnSwitch(
                value: _advancedNativeOptions,
                onChanged: (enabled) => setState(() {
                  _advancedNativeOptions = enabled;
                  _nativeOptionsError = null;
                  if (enabled) _nativeOptionsCtl.text = _nativeOptionsJSON(cap);
                }),
              ),
            ),
            if (_advancedNativeOptions) ...[
              const SizedBox(height: AnSpace.s8),
              AnInput(
                controller: _nativeOptionsCtl,
                multiline: true,
                mono: true,
                block: true,
                semanticLabel: t.settings.keys.nativeSettings,
              ),
              if (_nativeOptionsError != null) ...[
                const SizedBox(height: AnSpace.s4),
                Text(
                  _nativeOptionsError!,
                  style: AnText.meta.copyWith(color: c.danger),
                ),
              ],
              const SizedBox(height: AnSpace.s8),
              AnButton(
                label: t.settings.keys.nativeSettingsApply,
                size: AnButtonSize.sm,
                outline: true,
                onPressed: () => _applyNativeOptions(context, cap),
              ),
            ],
          ],
          const SizedBox(height: AnSpace.s12),
          Row(
            children: [
              AnButton(
                label: t.settings.keys.pickerApply,
                variant: AnButtonVariant.primary,
                size: AnButtonSize.sm,
                onPressed: (cap == null)
                    ? null
                    : () {
                        widget.onApply(
                          cap.apiKeyId,
                          cap.modelId,
                          _selectedOptions(cap),
                        );
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
            ],
          ),
        ],
      ),
    );
  }
}

/// Zone ③ (body) — search keys: the search-category default pick living BESIDE the BYOK rows it
/// governs (0725 重构: 不再是面板底部的孤悬区), its own logo-grid-scoped add flow. The default
/// dropdown only offers `testStatus == 'ok'` keys (honesty half 1); every OTHER row says plainly it
/// hasn't probed OK and won't be offered (honesty half 2) — otherwise a freshly-added key silently
/// vanishes from the dropdown with no clue why. 搜索密钥区:默认选择与它管的 BYOK 行挨着(0725 重构:
/// 不再悬空面板底),自带限类添加流程。默认下拉只收 testStatus == 'ok'(诚实一半);其余每行明说未
/// 探测通过、不会进默认(诚实二半)——否则刚加的 key 从下拉里消失却无从知晓原因。
class _SearchKeysSection extends ConsumerWidget {
  const _SearchKeysSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Translations.of(context);
    final ws = ref.watch(workspacePrefsProvider).value;
    final keysAsync = ref.watch(apiKeysProvider);
    final allKeys = keysAsync.value ?? const <ApiKey>[];
    final providers =
        ref.watch(providersProvider).value ?? const <ProviderMeta>[];
    final searchProviders = {
      for (final p in providers)
        if (p.category == 'search') p.name,
    };
    final managedNames = {
      for (final p in providers)
        if (p.managed) p.name,
    };
    final searchKeys = allKeys
        .where((k) => searchProviders.contains(k.provider))
        .toList();
    final okKeys = searchKeys.where((k) => k.testStatus == 'ok').toList();

    return AnSection(
      label: t.settings.keys.searchSection,
      variant: AnSectionVariant.quiet,
      actions: [
        const AnScopeBadge(AnSettingScope.workspace),
        const SizedBox(width: AnSpace.s8),
        AnButton(
          label: t.settings.keys.addKey,
          icon: AnIcons.plus,
          size: AnButtonSize.sm,
          outline: true,
          onPressed: () => ref
              .read(settingsDetailProvider.notifier)
              .push('addKey', category: 'search'),
        ),
      ],
      children: [
        AnSettingRow(
          label: t.settings.keys.searchDefault,
          desc: t.settings.keys.searchDefaultDesc,
          child: SizedBox(
            width: AnSize.ctlSlotLg,
            child: AnDropdown<String>(
              options: [
                AnDropdownOption(
                  value: '',
                  label: t.settings.keys.clearDefault,
                ),
                for (final k in okKeys)
                  AnDropdownOption(
                    value: k.id,
                    label: k.displayName,
                    meta: k.provider,
                  ),
              ],
              value: (ws?.defaultSearchKeyId?.isEmpty ?? true)
                  ? null
                  : ws!.defaultSearchKeyId,
              placeholder: t.settings.keys.noDefault,
              block: true,
              onChanged: (v) async {
                try {
                  if (v.isEmpty) {
                    await ref
                        .read(workspacePrefsProvider.notifier)
                        .clearDefaultSearch();
                  } else {
                    await ref
                        .read(workspacePrefsProvider.notifier)
                        .setDefaultSearch(v);
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
        switch (keysAsync) {
          AsyncData() when searchKeys.isEmpty => Padding(
            padding: const EdgeInsets.symmetric(vertical: AnSpace.s16),
            child: AnState(
              kind: AnStateKind.empty,
              // Same rule as the model-keys empty above (WRK-083 墓碑). 同上,见模型密钥空态。
              title: t.settings.keys.noSearchKeys,
              hint: t.settings.keys.noSearchKeysHint,
              size: AnStateSize.inset,
            ),
          ),
          AsyncData() => Column(
            children: [
              for (final k in searchKeys)
                _KeyRow(
                  row: k,
                  // Derived, not hard-coded false: no search provider is managed today, but a hard
                  // `false` would hand a future managed one the edit/delete affordances that S-1 says
                  // it must not have — and nothing would fail until it shipped.
                  // 推导得来、不写死 false:今天没有受管的搜索厂家,但写死 false 会给将来某个受管厂家发上
                  // S-1 明令它不该有的编辑/删除入口,而在它上线之前不会有任何东西报错。
                  managed: managedNames.contains(k.provider),
                  hint: k.testStatus == 'ok'
                      ? null
                      : t.settings.keys.searchKeyNotProbedHint,
                ),
            ],
          ),
          AsyncError() => AnState(
            kind: AnStateKind.error,
            title: t.settings.keys.keyOpFailed,
            size: AnStateSize.inset,
          ),
          _ => const SizedBox(height: AnSize.row),
        },
      ],
    );
  }
}

/// One GENERATION scenario row (WRK-082 批B/批C). Candidates are KEYS, not chat models —
/// generation models live outside the chat capability catalog, so the picker offers each capable
/// tested key with its provider's default generation model. Unset is honest: the tool auto-routes
/// managed-first; zero capable keys renders the how-to-get hint (honest absence, §3.5 — the tool
/// itself is absent in that state too).
///
/// It is ONE widget parameterized by scenario rather than one per modality: image and speech
/// differ only in their provider table and their words, and a second copy is precisely where the
/// two would start behaving differently (the backend made the same call with `resolveIn`).
///
/// 一个**生成**场景行(批B/批C)。候选是 **key** 而非聊天模型——生成模型不在聊天能力目录里,选择器
/// 按「该能力已探测 key × 该家默认生成模型」出选项。未设置=诚实自动(受管优先);零可用 key 渲
/// 「怎么获得」提示(诚实缺席,§3.5——彼态下工具本身也不存在)。
///
/// 它是**按场景参数化的一个** widget、而非每模态一个:图像与语音只差 provider 表与措辞,而抄第二份
/// 正是两者会开始表现不同的地方(后端在 `resolveIn` 上做了同一个判断)。
class _GenScenarioRow extends ConsumerStatefulWidget {
  const _GenScenarioRow({
    required this.scenario,
    required this.current,
    required this.providerDefaults,
    required this.toggleKey,
    required this.label,
    required this.desc,
    required this.autoSummary,
    required this.noRoute,
    required this.noRouteHint,
    required this.managedOption,
  });

  /// Wire scenario name (`image` / `speech`) — the same string the backend routes on.
  final String scenario;
  final ModelRef? current;

  /// Capable providers × default generation model — MIRRORS the backend's own hand-written table
  /// (`tool/generate/generate.go`). A closed legislated set; kept in lockstep by hand until a wire
  /// surface exists.
  ///
  /// 该能力的家 × 默认生成模型——**镜像后端**自己那张手写表。封闭立法集,在出现 wire 面之前人工同步。
  final Map<String, String> providerDefaults;
  final ValueKey<String> toggleKey;
  final String label;
  final String desc;
  final String autoSummary;
  final String noRoute;
  final String noRouteHint;
  final String managedOption;

  @override
  ConsumerState<_GenScenarioRow> createState() => _GenScenarioRowState();
}

/// Image-capable providers × default generation model — mirrors backend `imageProviders`.
///
/// 图像家 × 默认生成模型——镜像后端 `imageProviders`。
const Map<String, String> _imageProviderDefaults = {
  'anselm': 'anselm-auto',
  'openai': 'gpt-image-2',
  'google': 'gemini-3.1-flash-image-preview',
  'qwen': 'qwen-image-2.0',
  'zhipu': 'cogview-4',
};

/// Speech-capable providers × default TTS model — mirrors backend `speechProviders` (批C).
/// Note it is NOT the same set of models as the image table even where the provider is shared:
/// a key that can draw cannot necessarily speak, which is why the two rows filter independently.
///
/// 语音家 × 默认 TTS 模型——镜像后端 `speechProviders`(批C)。注意即使 provider 相同,模型也**不是**
/// 图像那张表里的那些:能画的 key 未必能说话,这正是两行各自独立过滤的原因。
/// Video-capable providers × default generation model — mirrors backend `videoProviders`
/// (WRK-082 H1). `anselm` leads, exactly like the image and speech tables: video IS in the free
/// tier, so a workspace with no key of its own can still pick a video default and get one.
///
/// 视频家 × 默认生成模型——镜像后端 `videoProviders`(H1)。`anselm` 打头,与图像、语音两张表**完全
/// 一样**:视频**在**免费档里,故一个自己一把 key 都没有的 workspace 照样能选一个视频默认、并真拿到片子。
const Map<String, String> _videoProviderDefaults = {
  'anselm': 'anselm-auto',
  'qwen': 'wan2.7-t2v',
  'google': 'veo-3.1-fast-generate-preview',
};

const Map<String, String> _speechProviderDefaults = {
  'anselm': 'anselm-auto',
  'openai': 'gpt-4o-mini-tts',
  'google': 'gemini-2.5-flash-preview-tts',
  'qwen': 'qwen3-tts-flash',
  'zhipu': 'glm-tts',
};

class _GenScenarioRowState extends ConsumerState<_GenScenarioRow> {
  bool _open = false;

  Future<void> _apply(String apiKeyId, String modelId) async {
    final t = Translations.of(context);
    try {
      await ref
          .read(workspacePrefsProvider.notifier)
          .setDefaultModel(
            widget.scenario,
            apiKeyId: apiKeyId,
            modelId: modelId,
            options: const {},
          );
      if (mounted) setState(() => _open = false);
    } on ApiException catch (e) {
      ref
          .read(noticeCenterProvider.notifier)
          .show(_modelOperationError(t, e), tone: AnTone.danger);
    }
  }

  Future<void> _clear() async {
    final t = Translations.of(context);
    try {
      await ref
          .read(workspacePrefsProvider.notifier)
          .clearDefaultModel(widget.scenario);
      if (mounted) setState(() => _open = false);
    } on ApiException catch (e) {
      ref
          .read(noticeCenterProvider.notifier)
          .show(_modelOperationError(t, e), tone: AnTone.danger);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    final keys = ref.watch(apiKeysProvider).value ?? const <ApiKey>[];
    final candidates = [
      for (final k in keys)
        if (k.testStatus == 'ok' &&
            widget.providerDefaults.containsKey(k.provider))
          k,
    ];
    final cur = widget.current;
    final curKey = cur == null
        ? null
        : keys.where((k) => k.id == cur.apiKeyId).firstOrNull;
    final summary = cur == null
        ? widget.autoSummary
        : '${cur.modelId}${curKey == null ? '' : ' · ${curKey.displayName}'}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnSettingRow(
          label: widget.label,
          desc: widget.desc,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: AnSize.ctlSlotLg),
                child: Text(
                  summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AnText.label.copyWith(
                    color: cur == null ? c.inkFaint : c.inkMuted,
                  ),
                ),
              ),
              const SizedBox(width: AnSpace.s8),
              AnButton(
                key: widget.toggleKey,
                label: _open
                    ? t.settings.keys.pickerClose
                    : t.settings.keys.pickerChange,
                size: AnButtonSize.sm,
                outline: true,
                onPressed: () => setState(() => _open = !_open),
              ),
            ],
          ),
        ),
        if (_open)
          Padding(
            padding: const EdgeInsets.only(top: AnSpace.s8, bottom: AnSpace.s8),
            child: candidates.isEmpty
                // Honest absence: say what is missing and how to get it — never an empty grid.
                // 诚实缺席:说清缺什么、怎么获得——绝不空网格。
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.noRoute,
                        style: AnText.label.copyWith(color: c.inkMuted),
                      ),
                      const SizedBox(height: AnSpace.s4),
                      Text(
                        widget.noRouteHint,
                        style: AnText.label.copyWith(color: c.inkFaint),
                      ),
                      const SizedBox(height: AnSpace.s8),
                      AnButton(
                        label: t.settings.keys.addKey,
                        size: AnButtonSize.sm,
                        outline: true,
                        onPressed: () => ref
                            .read(settingsDetailProvider.notifier)
                            .push('addKey', category: 'llm'),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final k in candidates)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AnSpace.s4),
                          child: AnButton(
                            label: k.provider == 'anselm'
                                ? widget.managedOption
                                : '${k.displayName} · ${t.settings.keys.imageDefaultModelOf(model: widget.providerDefaults[k.provider]!)}',
                            size: AnButtonSize.sm,
                            outline: true,
                            onPressed: () => _apply(
                              k.id,
                              widget.providerDefaults[k.provider]!,
                            ),
                          ),
                        ),
                      if (cur != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: AnButton(
                            label: t.settings.keys.clearDefault,
                            size: AnButtonSize.sm,
                            outline: true,
                            onPressed: _clear,
                          ),
                        ),
                    ],
                  ),
          ),
      ],
    );
  }
}

/// The credential control for a provider whose「key」is a service-account JSON file (Vertex, and
/// only Vertex). It is a paste area plus a file picker, because both are real paths: people copy
/// the file's contents out of a terminal, and people also have it sitting on disk.
///
/// **What it must not do is look like an API-key box.** That is the whole reason this widget exists
/// — the field is the same string column underneath, but a user shown「API key」for Vertex goes
/// looking through their Google project for something that was never issued.
///
/// 凭证控件,给「key」是服务账号 JSON 文件的那一家(Vertex,且只有 Vertex)。它是一个粘贴区加一个文件
/// 选择器,因为两条路都是真的:有人从终端里把文件内容拷出来,也有人文件就躺在磁盘上。
///
/// **它绝不能长得像一个 API key 框。** 那正是这个 widget 存在的全部理由——底下仍是同一个字符串列,但
/// 一个在 Vertex 这里看见「API key」的用户,会去自己的 Google 项目里翻一样**从来没被签发过**的东西。
class _ServiceAccountField extends StatefulWidget {
  const _ServiceAccountField({required this.controller, required this.editing});

  final TextEditingController controller;
  final bool editing;

  @override
  State<_ServiceAccountField> createState() => _ServiceAccountFieldState();
}

class _ServiceAccountFieldState extends State<_ServiceAccountField> {
  String? _error;

  Future<void> _pick() async {
    const group = XTypeGroup(label: 'JSON', extensions: ['json']);
    final file = await openFile(acceptedTypeGroups: const [group]);
    if (file == null) return;
    final text = await file.readAsString();
    if (!mounted) return;
    setState(() {
      widget.controller.text = text.trim();
      _error = _validate(widget.controller.text);
    });
  }

  /// Checked HERE, before the key is saved, because the next chance is a token exchange whose
  /// failure the user reads as「my Google account is broken」. A file that is not a service account
  /// is the mistake this field will actually see.
  /// **在这里**查、在 key 存下之前,因为下一次机会是一次换 token,而它的失败在用户读来是「我的 Google
  /// 账号坏了」。**不是服务账号的文件**,正是这一栏真正会遇到的错误。
  String? _validate(String raw) {
    return _serviceAccountValidationError(context, raw);
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnInput(
          controller: widget.controller,
          block: true,
          mono: true,
          multiline: true,
          placeholder: widget.editing
              ? t.settings.keys.rotatePlaceholder
              : t.settings.keys.serviceAccountPlaceholder,
          onChanged: (v) => setState(() => _error = _validate(v)),
        ),
        const SizedBox(height: AnSpace.s6),
        Row(
          children: [
            AnButton(
              label: t.settings.keys.serviceAccountPick,
              size: AnButtonSize.sm,
              outline: true,
              onPressed: _pick,
            ),
            if (_error != null) ...[
              const SizedBox(width: AnSpace.s8),
              Flexible(
                child: Text(
                  _error!,
                  style: AnText.meta.copyWith(color: c.danger),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// The provider market — the WHOLE catalog laid out by default, search is a filter and never a gate.
/// Same grammar as [McpMarket] (`mcp_forms.dart`), deliberately: two-column [AnAutoGrid] of brand
/// cards, an autofocus search that narrows, an [AnState] empty face, hover/focus-revealed CTA, whole
/// card taps through.
///
/// **The old face was a `Wrap` of logo tiles with no search.** That was right for ten providers and
/// is unusable for 173: the ones that sort first are aggregators (NanoGPT ~600 models, Kilo ~350),
/// so a first-party vendor is buried below the fold. A user configuring BYOK already has one company
/// in mind — they are not browsing — which is why the search box is the answer and grouping is not:
/// a grouping is itself a table someone has to maintain.
///
/// 供应商市场——**整个目录默认全铺**,搜索只是过滤、绝不是门。文法与 [McpMarket](`mcp_forms.dart`)
/// **刻意相同**:双列 [AnAutoGrid] 品牌卡、autofocus 搜索逐渐收窄、[AnState] 空脸、hover/focus 揭示
/// CTA、整卡点击进表单。
///
/// **旧脸是一个没有搜索的 logo `Wrap`。** 十家时它是对的,173 家时它不能用:排在前面的是聚合器
/// (NanoGPT 约 600 模型、Kilo 约 350),一手厂商被压到屏幕之外。来配 BYOK 的用户**心里已经有一家了**
/// ——他不是来浏览的——所以答案是搜索框、而不是分组:**分组本身就是一张要人维护的表**。
class _ProviderMarket extends ConsumerStatefulWidget {
  const _ProviderMarket({required this.providers, required this.onPick});

  final List<ProviderMeta> providers;
  final void Function(ProviderMeta) onPick;

  @override
  ConsumerState<_ProviderMarket> createState() => _ProviderMarketState();
}

class _ProviderMarketState extends ConsumerState<_ProviderMarket> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    final q = _query.toLowerCase();
    // Match the id too, not just the display name: someone who knows `togetherai` should not have to
    // guess that we render it「Together AI」. 也匹配 id、不只显示名:知道 `togetherai` 的人不该还要
    // 猜我们把它渲成「Together AI」。
    final rows = widget.providers
        .where(
          (p) =>
              q.isEmpty ||
              p.displayName.toLowerCase().contains(q) ||
              p.name.toLowerCase().contains(q),
        )
        .toList();
    // The rows that already have a key wear the「已配置」face instead of a CTA.
    // 已经有 key 的那些家戴「已配置」脸、不给 CTA。
    final configured = {
      for (final k in ref.watch(apiKeysProvider).value ?? const <ApiKey>[])
        k.provider,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          t.settings.keys.pickProvider,
          style: AnText.label.copyWith(color: c.inkMuted),
        ),
        const SizedBox(height: AnSpace.s8),
        AnInput(
          placeholder: t.settings.keys.searchProviders,
          autofocus: true,
          onChanged: (v) => setState(() => _query = v.trim()),
        ),
        const SizedBox(height: AnSpace.s12),
        AnAutoGrid(
          minColWidth: AnSize.block,
          children: [
            for (final p in rows)
              _ProviderCard(
                key: ValueKey(p.name),
                meta: p,
                configured: configured.contains(p.name),
                onPick: () => widget.onPick(p),
              ),
          ],
        ),
        if (rows.isEmpty)
          AnState(
            kind: AnStateKind.empty,
            size: AnStateSize.inset,
            title: t.settings.keys.noProviderMatch,
          ),
        const SizedBox(height: AnSpace.s16),
        Row(
          children: [
            AnButton(
              label: t.settings.keys.cancel,
              onPressed: () => ref.read(settingsDetailProvider.notifier).pop(),
            ),
          ],
        ),
      ],
    );
  }
}

/// One provider card. Carries the two facts that matter when 173 of these are on screen at once:
/// **how many models** (the only thing separating a first-party vendor from an aggregator) and
/// **whether anything here vouches for it** — `curated=false` means we reached it by the mechanical
/// `npm` → dialect mapping and never tried it, and the user deserves to know that BEFORE a failure,
/// not as an excuse afterwards.
///
/// 一张供应商卡。带着 173 张同时在屏时**真正要紧的两个事实**:**有多少模型**(把一手厂商与聚合器
/// 分开的唯一东西)与**这里有没有为它背书**——`curated=false` 意思是我们靠机械的 `npm` → 方言映射
/// 抵达它、从没试过,而用户有权在**失败之前**知道这件事,而不是把它当事后的托辞。
class _ProviderCard extends StatefulWidget {
  const _ProviderCard({
    required this.meta,
    required this.configured,
    required this.onPick,
    super.key,
  });

  final ProviderMeta meta;
  final bool configured;
  final VoidCallback onPick;

  @override
  State<_ProviderCard> createState() => _ProviderCardState();
}

class _ProviderCardState extends State<_ProviderCard> {
  bool _hovered = false;
  bool _focusWithin = false;

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    final p = widget.meta;
    final reveal = _hovered || _focusWithin;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (has) => setState(() => _focusWithin = has),
      child: AnHoverRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnCard(
          selectable: true,
          onSelect: widget.onPick,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  brandIconOr(
                    kProviderBrand[p.name],
                    fallbackLabel: p.displayName,
                    size: AnBrandSize.sm,
                  ),
                  const SizedBox(width: AnSpace.s8),
                  Expanded(
                    child: Text(
                      p.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AnText.body.copyWith(color: c.ink),
                    ),
                  ),
                  const SizedBox(width: AnSpace.s8),
                  _trailing(t, reveal),
                ],
              ),
              // `models == 0` means「no catalog inventory」(ollama, custom, the search providers),
              // NOT「zero models」 — printing a zero would be a fact we do not have.
              // `models == 0` 的意思是**「没有目录清单」**(ollama / custom / 搜索家),**不是**「零个
              // 模型」——印一个零等于印一个我们**并不掌握**的事实。
              if (p.models > 0) ...[
                const SizedBox(height: AnSpace.s6),
                Text(
                  t.settings.keys.modelCount(n: p.models),
                  style: AnText.meta.copyWith(color: c.inkMuted),
                ),
              ],
              if (!p.curated) ...[
                const SizedBox(height: AnSpace.s6),
                AnChip(
                  t.settings.keys.unverified,
                  tone: AnTone.warn,
                  tooltip: t.settings.keys.unverifiedHint,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Reveal-gated CTA, laid out at rest so nothing reflows on hover and inert when hidden so a rest
  /// click falls through to the whole-card tap — the [McpMarket] `_MarketCard` trick verbatim.
  /// 揭示门控 CTA:闲时也占位(hover 不重排)、隐时惰化(静止点击透传给整卡)——逐字照抄
  /// [McpMarket] 的 `_MarketCard`。
  Widget _trailing(Translations t, bool reveal) {
    if (widget.configured) {
      return AnChip(t.settings.keys.alreadyConfigured, tone: AnTone.ok);
    }
    return IgnorePointer(
      ignoring: !reveal,
      child: Opacity(
        opacity: reveal ? 1 : 0,
        child: AnButton(
          label: t.settings.keys.addKeyCta,
          variant: AnButtonVariant.primary,
          size: AnButtonSize.sm,
          semanticLabel: t.settings.keys.addKeyNamed(
            name: widget.meta.displayName,
          ),
          onPressed: widget.onPick,
        ),
      ),
    );
  }
}
