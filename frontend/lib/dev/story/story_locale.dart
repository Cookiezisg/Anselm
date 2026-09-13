/// Locale switch for the story dataset. Every user-visible string in the story fixtures goes
/// through [StoryLocale.t] so one data structure yields an English and a Chinese product story.
/// Identifiers (entity names, ids, paths, code) stay English in both — that mirrors real usage.
///
/// story 数据集的语言开关。所有用户可见文案经 [StoryLocale.t]，一套结构出中英两套故事；
/// 标识符（实体名、id、路径、代码）两种语言都保持英文，与真实使用一致。
class StoryLocale {
  const StoryLocale({required this.zh});

  /// True when the Chinese story is requested. 是否中文故事。
  final bool zh;

  /// Pick the string for the active locale. 按当前语言取文案。
  String t(String en, String zhText) => zh ? zhText : en;

  /// BCP-47 tag the workspace row should carry. workspace 行应携带的语言标签。
  String get languageTag => zh ? 'zh-CN' : 'en';
}
