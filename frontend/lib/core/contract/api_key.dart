import 'package:freezed_annotation/freezed_annotation.dart';

part 'api_key.freezed.dart';
part 'api_key.g.dart';

/// An API credential row — mirrors backend `apikey.APIKey` (the encrypted key itself never travels;
/// [keyMasked] is the display form). [testStatus] ∈ pending|ok|error (open set kept as String — the
/// probe vocabulary may grow). NOTE the row carries NO `managed` flag: managed-ness is provider-level
/// metadata — join [ProviderMeta.managed] (设置面按 provider 目录判受管,行上没有).
///
/// API 凭证行——镜像后端 apikey.APIKey(密文永不下发,keyMasked 是展示形)。testStatus∈pending|ok|error
/// (保持开放 String)。行上**没有 managed 字段**:受管性是 provider 级元数据,须 join ProviderMeta.managed。
@freezed
abstract class ApiKey with _$ApiKey {
  const factory ApiKey({
    required String id,
    required String provider,
    required String displayName,
    @Default('') String keyMasked,
    @Default('') String baseUrl,
    @Default('') String apiFormat,
    @Default('pending') String testStatus,
    @Default('') String testError,
    DateTime? lastTestedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _ApiKey;

  factory ApiKey.fromJson(Map<String, dynamic> json) => _$ApiKeyFromJson(json);
}

/// One provider-catalog entry — `GET /providers` (static backend catalog; `mock` only under dev).
/// provider 目录一项——GET /providers(后端静态目录;mock 仅 dev 下发)。
@freezed
abstract class ProviderMeta with _$ProviderMeta {
  const factory ProviderMeta({
    required String name,
    required String displayName,
    @Default('') String defaultBaseUrl,
    @Default(false) bool baseUrlRequired,
    @Default(false) bool managed,
    @Default('llm') String category, // llm | search
    /// Whether this app ships a hand-written spec for the provider (its knobs, its base URL, its
    /// quirks written against its own docs). The ~160 others come straight from models.dev by the
    /// mechanical `npm` → dialect mapping: they work, but nothing here vouches for them — and the UI
    /// needs that distinction to tell「你的 key 不对」apart from「这家我们没试过」.
    ///
    /// 本 app 是否为这家手写过 spec(旋钮、base URL、怪癖照它自己的文档写)。其余约 160 家直接来自
    /// models.dev、由机械的 `npm` → 方言映射抵达:它们**能用**,但这里不为它们背书——而 UI 需要这个
    /// 区分,才能把「你的 key 不对」与「这家我们没试过」分开。
    @Default(true) bool curated,

    /// The wire we speak to it. Rendered only when something goes wrong: a failure on an
    /// un-curated provider is a different sentence from a failure on a curated one.
    /// 我们对它说的那条线缆。只在出问题时渲染:未验证的家失败,与已验证的家失败,是两句不同的话。
    @Default('openai-compatible') String dialect,

    /// A base-URL TEMPLATE the catalog published instead of a usable address — four providers do
    /// this because their endpoint contains the customer's own account or host name
    /// (`https://${DATABRICKS_HOST}/…`). Shown as a hint, never prefilled: submitted verbatim it
    /// produces a connect failure whose message never mentions the literal `${…}` still in the field.
    ///
    /// 目录发布的 base URL **模板**、不是可用地址——四家这样,因为端点里含着客户自己的账号或主机名。
    /// 作为**提示**展示、**绝不预填**:原样提交会换来一次连接失败,而那条消息只字不提字段里还躺着的
    /// 那个字面 `${…}`。
    @Default('') String baseUrlHint,

    /// What the credential field actually holds. Every provider but one takes a pasted string;
    /// Vertex takes a service-account JSON FILE, and a text box labelled「API key」is the wrong
    /// control for it — the user would go looking for a key that does not exist on their project.
    ///
    /// 凭证字段**实际装的是什么**。除一家外每家都收一个粘贴的字符串;Vertex 收的是一个服务账号
    /// **JSON 文件**,而一个写着「API key」的文本框对它是**错的控件**——用户会去找一把在他项目里
    /// 根本不存在的 key。
    @Default('api_key') String credential, // api_key | service_account_json
    /// How many models the catalog lists for this provider — the one number that separates a
    /// first-party vendor from an aggregator when 173 cards are laid out at once.
    ///
    /// **0 means「we do not know」, not「none」**: the local entries (ollama, custom, mock, the
    /// search providers) have no catalog inventory at all. Omit the line rather than print a zero.
    ///
    /// 目录为这家收录的模型数——173 张卡一次铺开时,把一手厂商与聚合器分开的**就是这个数**。
    ///
    /// **0 的意思是「我们不知道」、不是「一个也没有」**:本地条目(ollama / custom / mock / 搜索家)
    /// 根本没有目录清单。该**不渲那一行**,而不是印一个零。
    @Default(0) int models,
  }) = _ProviderMeta;

  factory ProviderMeta.fromJson(Map<String, dynamic> json) =>
      _$ProviderMetaFromJson(json);
}

/// The free-tier month quota — `GET /freetier/quota` (backend proxies the gateway; 404
/// FREETIER_NOT_PROVISIONED maps to null at the repository seam). [available] folds the gateway's
/// global day budget, so it can be false while [remaining] > 0.
/// 免费档本月配额——后端代理网关;404 在数据缝映射为 null。available 折网关全局日预算,remaining>0 仍可能 false。
@freezed
abstract class FreetierQuota with _$FreetierQuota {
  const factory FreetierQuota({
    required int limit,
    required int used,
    required int remaining,
    @Default('') String resetAt,
    @Default(true) bool available,
  }) = _FreetierQuota;

  factory FreetierQuota.fromJson(Map<String, dynamic> json) =>
      _$FreetierQuotaFromJson(json);
}

/// One enrolled voice — `GET /api/v1/voices` (WRK-082 H9).
///
/// **The inventory is not a quota, and the DTO is where that starts being true.** Nothing frees a
/// slot with the passage of time: a voice occupies its place until someone deletes it, and creating
/// one cost real money once. So the UI that renders this must say「delete one」and never「try again
/// tomorrow」— see [VoiceInventory] for the arithmetic that makes the refusal legible.
///
/// 一个已登记的音色(H9)。
///
/// **库存不是配额,而这件事从 DTO 就开始为真。** 时间流逝不腾位:一个音色占着它的位直到有人删掉,而
/// 创建它花过一次真钱。故渲染它的 UI 必须说「删一个」、绝不说「明天再来」——让那句拒绝读得懂的算术
/// 在 [VoiceInventory] 里。
@freezed
abstract class ClonedVoice with _$ClonedVoice {
  const factory ClonedVoice({
    required String id,
    required String name,
    @Default('') String provider,
    @Default('') String upstreamId,
    @Default('') String sourceAttachmentId,
    @Default('') String createdAt,
  }) = _ClonedVoice;

  factory ClonedVoice.fromJson(Map<String, dynamic> json) =>
      _$ClonedVoiceFromJson(json);
}

/// The voice list plus its inventory arithmetic — the cap IS the reason a user reads this page.
/// A list of two that does not say「that is all you may keep」leaves the next enrollment's refusal
/// unexplained.
///
/// 音色列表 + 库存算术——**上限正是用户来读这一页的理由**。一个列出两行却不说「你只能留这些」的列表,
/// 会让下一次登记的拒绝无从解释。
@freezed
abstract class VoiceInventory with _$VoiceInventory {
  const factory VoiceInventory({
    @Default(<ClonedVoice>[]) List<ClonedVoice> items,
    @Default(0) int capacity,
    @Default(0) int remaining,
  }) = _VoiceInventory;

  factory VoiceInventory.fromJson(Map<String, dynamic> json) =>
      _$VoiceInventoryFromJson(json);
}
