import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/settings_prefs.dart';

/// The three documents right-island group keys (三段式文法 §3 · batch 2, 用户 0719) — the accordion group
/// heads (Outline / Properties / Backlinks) fold against these. Members of the DECLARED `an.right.collapsed.`
/// prefix family, so the fold survives a restart (a machine-level panel preference — the 轻量版 of the
/// follow three-notch precedent). 文档右岛三组键;声明前缀族成员,折叠态跨重启(机器级面板偏好)。
const String kDocGroupOutline = 'documents.outline';
const String kDocGroupProps = 'documents.props';
const String kDocGroupBacklinks = 'documents.backlinks';
const String kDocGroupSkillFiles = 'documents.skillfiles';
const String kDocGroupSkillProvenance = 'documents.skillprovenance';

/// Every foldable documents-group key — the ⋯ menu's «展开全部 / 收起全部» walk this (never a wildcard).
/// 全部可折叠组键(⋯ 全展/全收遍历它)。
const List<String> kDocGroups = [
  kDocGroupOutline,
  kDocGroupSkillFiles,
  kDocGroupSkillProvenance,
  kDocGroupProps,
  kDocGroupBacklinks,
];

/// The documents right-island GROUP-fold set (三段式文法 §3) — the set of COLLAPSED group keys, mirroring
/// the chat sidestage's group axis but PERSISTED (not session-only): each group's fold is a member of the
/// declared `an.right.collapsed.` prefix family via [SettingsPrefs.getFamilyBool]/[setFamilyBool], so the
/// user's fold intent is a stable preference that outlives a restart (like the follow three-notch). Default:
/// nothing collapsed (every group open — the fold is opt-in, never hides content by default). Absent groups
/// (a skill has no Backlinks; a heading-less doc has no Outline) keep their stored state regardless of
/// presence — a group reappearing restores its fold.
///
/// 文档右岛组折叠集——已收起组键集,镜像 chat 侧幕的组轴但**持久化**(非会话级):每组折叠是声明前缀族成员,
/// 用户折叠意图=跨重启的稳定偏好(同跟随三档)。默认全展开(折叠 opt-in,绝不默认藏内容);缺席组(skill 无反链、
/// 无标题文档无大纲)照存其态,组重现即恢复折叠。
class DocGroupCollapseController extends Notifier<Set<String>> {
  static const String _family = 'an.right.collapsed.';

  SettingsPrefs get _prefs => ref.read(settingsPrefsProvider);

  @override
  Set<String> build() => {
    for (final g in kDocGroups)
      if (_prefs.getFamilyBool(_family, g, def: false)) g,
  };

  /// Flip one group's fold and persist it. 翻转一组折叠并落盘。
  void toggle(String key) {
    final collapsed = !state.contains(key);
    _prefs.setFamilyBool(_family, key, collapsed);
    state = collapsed ? {...state, key} : ({...state}..remove(key));
  }

  /// Reveal every group — the head ⋯ «展开全部». 全部展开。
  void expandAll() {
    for (final g in kDocGroups) {
      _prefs.setFamilyBool(_family, g, false);
    }
    if (state.isNotEmpty) state = const <String>{};
  }

  /// Fold every group — the head ⋯ «收起全部». 全部收起。
  void collapseAll() {
    for (final g in kDocGroups) {
      _prefs.setFamilyBool(_family, g, true);
    }
    state = {...kDocGroups};
  }
}

final docGroupCollapseProvider =
    NotifierProvider<DocGroupCollapseController, Set<String>>(
      DocGroupCollapseController.new,
    );
