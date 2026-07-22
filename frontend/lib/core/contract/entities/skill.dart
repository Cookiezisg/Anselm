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
    @Default('') String source, // user | ai
    @Default('') String context, // inline | fork
    @Default('') String body, // only from GET /skills/{name}
    @Default(Frontmatter()) Frontmatter frontmatter,
    required DateTime updatedAt, // file mtime
  }) = _Skill;
  factory Skill.fromJson(Map<String, dynamic> json) => _$SkillFromJson(json);
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
