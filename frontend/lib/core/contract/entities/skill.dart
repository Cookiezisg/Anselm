import 'package:freezed_annotation/freezed_annotation.dart';

part 'skill.freezed.dart';
part 'skill.g.dart';

/// A skill — a file-based Agent Skill (a `SKILL.md`: YAML frontmatter + markdown body). USER-editable
/// **file-like knowledge**; the slug [name] IS its identity (no generated id, same as memory — so there
/// is no rename, `PUT` overwrites in place). [body] is populated ONLY by the single-Get (the list omits
/// it to stay light). [description]/[context]/[source] are convenience mirrors of the frontmatter fields.
/// skill.go:26。
@freezed
abstract class Skill with _$Skill {
  const factory Skill({
    required String name,
    @Default('') String description, // mirror of frontmatter.description
    @Default('') String source, // user | ai | installed（installed 由 sidecar 推导）
    @Default('') String context, // inline | fork
    @Default('') String body, // only from GET /skills/{name}
    @Default(Frontmatter()) Frontmatter frontmatter,
    Provenance? provenance, // only installed + single-Get（List 省略）
    @Default('') String dir, // 目录绝对路径,仅 single-Get——系统打开/Finder 显示用
    required DateTime updatedAt, // file mtime
  }) = _Skill;
  factory Skill.fromJson(Map<String, dynamic> json) => _$SkillFromJson(json);
}

/// Install provenance — where an installed skill came from + the trust-gate state. Mirrors
/// domain/skill.go Provenance (WRK-076 B4). `toolsApproved=false` means the skill's
/// allowed-tools are a REQUESTED grant: activation injects the body but withholds the
/// pre-approval until the user approves. 安装来源档案:出处+信任门态;未授权=预授权不装。
@freezed
abstract class Provenance with _$Provenance {
  const factory Provenance({
    @Default('') String source, // owner/repo[@ref][#subdir] 或 URL
    @Default('') String repo,
    @Default('') String ref,
    @Default('') String subdir,
    DateTime? installedAt,
    @Default(false) bool toolsApproved,
  }) = _Provenance;
  factory Provenance.fromJson(Map<String, dynamic> json) =>
      _$ProvenanceFromJson(json);
}

/// One bundled file inside a skill directory (manifest included) — the files surface's list
/// row. Path is slash-relative to the skill root. skill 目录内单个捆绑文件(含清单),slash 相对路径。
@freezed
abstract class SkillFile with _$SkillFile {
  const factory SkillFile({
    required String path,
    @Default(0) int size,
    DateTime? updatedAt,
  }) = _SkillFile;
  factory SkillFile.fromJson(Map<String, dynamic> json) =>
      _$SkillFileFromJson(json);
}

/// One candidate a skill source offers (POST /skills:inspect-source) — the install dialog
/// renders this with allowedTools UP FRONT (the trust gate starts at the picking step).
/// 来源候选预览:allowedTools 前置亮相,信任门从挑选步开始。
@freezed
abstract class SkillInstallPreview with _$SkillInstallPreview {
  const factory SkillInstallPreview({
    required String name,
    @Default('') String description,
    @Default(<String>[]) List<String> allowedTools,
    @Default(0) int fileCount,
    @Default(0) int totalBytes,
    @Default(false) bool installable,
    @Default('') String reason,
    @Default(false) bool alreadyExists,
  }) = _SkillInstallPreview;
  factory SkillInstallPreview.fromJson(Map<String, dynamic> json) =>
      _$SkillInstallPreviewFromJson(json);
}

/// One authorizable builtin tool from `GET /tools` — the allowed-tools picker's BUILTIN candidate
/// (call [name] + one-line [summary]). Entity ids (fn_/hd_) and MCP tools are picked from their own
/// live sources, not this static set. 可授权内置工具(GET /tools):allowed-tools 选择器的内置候选。
@freezed
abstract class SkillToolDescriptor with _$SkillToolDescriptor {
  const factory SkillToolDescriptor({
    required String name,
    @Default('') String summary,
  }) = _SkillToolDescriptor;
  factory SkillToolDescriptor.fromJson(Map<String, dynamic> json) =>
      _$SkillToolDescriptorFromJson(json);
}

/// What one POST /skills:install actually did, per name. 一次安装逐名结果。
@freezed
abstract class SkillInstallResult with _$SkillInstallResult {
  const factory SkillInstallResult({
    @Default(<String>[]) List<String> installed,
    @Default(<String, String>{}) Map<String, String> skipped,
  }) = _SkillInstallResult;
  factory SkillInstallResult.fromJson(Map<String, dynamic> json) =>
      _$SkillInstallResultFromJson(json);
}

/// A skill's YAML frontmatter — the structured metadata the properties panel edits. Mirrors the standard
/// Agent Skills fields (name/description/allowed-tools/…) plus Anselm's `source` extension. The wire is
/// camelCase (json tags); only a subset is user-editable via HTTP today (model/effort/whenToUse are
/// import-preserved but not exposed for write). skill.go:42。
@freezed
abstract class Frontmatter with _$Frontmatter {
  const factory Frontmatter({
    @Default('') String name,
    @Default('') String description,
    @Default('') String license, // 规范核心（B1 保真新暴露）
    @Default('') String compatibility, // 规范核心:环境需求声明
    @Default(<String, String>{}) Map<String, String> metadata, // 规范扩展逃生口
    @Default(<String>[])
    List<String>
    allowedTools, // pre-authorized tools (fn_/hd_ id · Read/Bash · mcp:server/tool)
    @Default('') String context, // inline | fork
    @Default('') String agent, // required when context == fork
    @Default(<String>[]) List<String> arguments,
    @Default(false) bool disableModelInvocation,
    @Default(false) bool userInvocable,
    @Default('') String whenToUse,
    @Default('') String model,
    @Default('') String effort,
    @Default('') String source, // user | ai
  }) = _Frontmatter;
  factory Frontmatter.fromJson(Map<String, dynamic> json) =>
      _$FrontmatterFromJson(json);
}

/// Skill context modes + source values — small closed sets the properties-panel dropdowns constrain.
/// skill.go:60/66。
const String kSkillContextInline = 'inline';
const String kSkillContextFork = 'fork';
const String kSkillSourceUser = 'user';
const String kSkillSourceAI = 'ai';
const String kSkillSourceInstalled = 'installed'; // sidecar 推导,非 frontmatter 值
const String kSkillManifestFileName = 'SKILL.md';

/// Physical guardrails mirrored from the backend (domain/skill/skill.go) for client-side
/// pre-validation: body (manifest) ≤ 32 KB, bundled file ≤ 1 MB, description ≤ 1024 chars.
/// TWO name regexes (WRK-076 D3): the GUARD form is what can exist on disk (lenient — digit
/// start and legacy `_` accepted, URL-safe by construction); the SPEC form is the Agent Skills
/// open-spec shape enforced on CREATE only (no `_`, single hyphens).
/// 后端护栏镜像:清单 ≤32KB、附属文件 ≤1MB、description ≤1024。双正则(WRK-076 D3):守卫形态=
/// 盘上可存在(从宽,允数字开头与存量 `_`,天然 URL 安全);规范形态=新建从严(无 `_`、单连字符)。
const int kSkillMaxBodyBytes = 32 * 1024;
const int kSkillMaxFileBytes = 1024 * 1024;
const int kSkillMaxDescriptionChars = 1024;
final RegExp kSkillNameRegex = RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$');
final RegExp kSkillSpecNameRegex = RegExp(
  r'^[a-z0-9]+(-[a-z0-9]+)*$',
); // 创建时另须 ≤64 字符
