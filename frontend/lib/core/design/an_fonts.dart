/// FONT AXES — the three ORTHOGONAL, machine-level font choices (user 0719 拍板), and the mechanism
/// that resolves each into a concrete `(family, fallback)` pair. This is framework-free (no Riverpod,
/// no Flutter widgets) — pure resolution the design layer and the reactive providers both read.
///
/// The three axes and their辖区 (jurisdiction — which surfaces each governs):
///   ① UI      — every OPERATING surface + embedded chrome: left island, floating heads / crumbs /
///               tabs / buttons / menus / popovers / tooltips / toasts / tray, the right island,
///               Settings, tool cards, the composer, entity detail KV / tables / badges. The [AnText]
///               ladder rides this axis (its family delegates here).
///   ② CONTENT — the READING-column prose ONLY: chat message-bubble markdown + the documents editor
///               body (incl. the document big title). Nowhere else. OVERRIDES the UI face on those two
///               surfaces when set to serif / system; code inside content still rides ③.
///   ③ CODE    — every MONOSPACE surface, and it OVERRIDES content: code blocks (bubble / doc / code
///               window / debug JSON), inline code chips, terminals, diffs, JSON trees, and mono
///               id/cron/path/duration values. The [AnText] mono ladder delegates here.
///
/// The default of EVERY axis is the FIRST option = today's bundled faces, so an untouched install is a
/// zero-perception no-op (every existing test stays green — that is the proof of "zero感知").
///
/// HOT vs RESTART (the honest split, reported to the user): the CONTENT axis is HOT — its surfaces build
/// their styles at runtime (AnMarkdown / the editor stylesheet), so `contentFaceProvider` drives a live
/// re-render. The UI + CODE axes are RESTART-APPLIED: their faces are baked into ~18 `AnText` styles
/// consumed by hundreds of const-eligible `Text` widgets across the whole app; hot-swapping those
/// reliably would need a full remount (fighting Flutter's const-widget rebuild elision) on the global
/// type底座 flagged「改动谨慎」. Instead [applyAtBoot] resolves them ONCE before `runApp` (persisted
/// choice → next launch); the settings rows say「重启后生效」(the network-proxy precedent). Low value
/// to hot-swap anyway (bundled↔system / code face are set-and-forget).
///
/// 字体三轴(机器级偏好,0719 拍板)+ 把每轴解析成 (family, fallback) 的机制。框架无关(无 Riverpod/widget)。
/// 三轴辖区:①UI=一切操作面+嵌入 chrome(AnText 阶梯族延迟到本轴);②内容=阅读列 prose(chat 泡+文档正文含大
/// 标题,别处不动,衬线/系统时覆盖 UI 脸、内容内代码仍走③);③代码=一切等宽且凌驾内容(AnText mono 阶梯延迟到此)。
/// 各轴默认=首项=现状随包脸→零感知(现有测试全绿即证)。热切换 vs 重启:内容轴热(样式运行时构造);UI+代码轴
/// 重启生效([applyAtBoot] 在 runApp 前解析一次,面板标「重启后生效」)——它们烤进 AnText const 阶梯、全库消费,
/// 可靠热换需整树重挂(与 const 剪枝作对),而这是「改动谨慎」的字体底座;且这两轴本就是一次性设定,热换价值低。
library;

import 'package:flutter/painting.dart' show TextStyle;

/// A resolved face — the primary [family] (null = the PLATFORM default, i.e. "follow system") plus the
/// ordered [fallback] chain (CJK / platform insurance). 已解析脸:主 family(null=平台默认=跟随系统)+
/// 有序回落链(CJK/平台保险)。
class AnFace {
  const AnFace(this.family, this.fallback);

  final String? family;
  final List<String> fallback;

  /// Layer this face onto a prose [base] style — swap ONLY the family + fallback, preserve everything
  /// else (size / height / weight / colour / features / decoration). Handles the family==null ("system")
  /// case that `copyWith` cannot express (copyWith reads `null` as "keep") by rebuilding the style
  /// without a primary family, so the platform default leads the [fallback] chain. Used by the CONTENT
  /// (②) surfaces to layer serif / system over their reading styles — never for chrome or code.
  /// 把本脸覆盖到 prose 样式:只换 family+fallback,余皆保留;family==null(系统)时重建无主 family(copyWith 无法
  /// 表达该清空),让平台默认领衔回落链。仅内容面用(衬线/系统覆盖阅读样式),不碰 chrome / 代码。
  TextStyle on(TextStyle base) {
    final withFallback = base.copyWith(fontFamilyFallback: fallback);
    if (family != null) return withFallback.copyWith(fontFamily: family);
    // copyWith can't NULL a field — rebuild every field so the primary family becomes null (system default).
    return TextStyle(
      inherit: withFallback.inherit,
      color: withFallback.color,
      backgroundColor: withFallback.backgroundColor,
      fontSize: withFallback.fontSize,
      fontWeight: withFallback.fontWeight,
      fontStyle: withFallback.fontStyle,
      letterSpacing: withFallback.letterSpacing,
      wordSpacing: withFallback.wordSpacing,
      textBaseline: withFallback.textBaseline,
      height: withFallback.height,
      leadingDistribution: withFallback.leadingDistribution,
      locale: withFallback.locale,
      foreground: withFallback.foreground,
      background: withFallback.background,
      shadows: withFallback.shadows,
      fontFeatures: withFallback.fontFeatures,
      fontVariations: withFallback.fontVariations,
      decoration: withFallback.decoration,
      decorationColor: withFallback.decorationColor,
      decorationStyle: withFallback.decorationStyle,
      decorationThickness: withFallback.decorationThickness,
      debugLabel: withFallback.debugLabel,
      fontFamilyFallback: withFallback.fontFamilyFallback,
      overflow: withFallback.overflow,
    );
  }
}

/// Apply a nullable content override — `null` = no change (sans follows the UI face). Keeps every call
/// site a one-liner. 可空内容覆盖:null=不改(sans 跟随 UI 脸);让各调用点一行。
TextStyle applyContentFace(AnFace? face, TextStyle base) => face == null ? base : face.on(base);

/// The font-axis resolver + the boot-applied holder for the RESTART axes (UI / code). The CONTENT axis
/// resolves per-build via [contentOverrideFor] and is never stored here (it's hot). 字体轴解析器 + 重启轴
/// (UI/代码)的启动持有;内容轴每帧解析、不存此(热)。
abstract final class AnFonts {
  // ── ① UI axis faces ──
  // Bundled = the deterministic bilingual UI (Inter Latin/numerals + MiSans Simplified-Chinese), same
  // on every machine. System = the OS UI face: family null → macOS San Francisco / Windows Segoe UI /
  // Linux the platform default; the fallback carries the OS CJK face (PingFang SC / Microsoft YaHei).
  // 内置=确定双拼;系统=OS UI 脸(family null→macOS SF/Windows Segoe UI/Linux 平台默认),回落带 OS 中文脸。
  static const AnFace _uiBundled =
      AnFace('Inter', ['MiSans', 'PingFang SC', 'Microsoft YaHei', 'Segoe UI', 'Noto Sans', 'sans-serif']);
  static const AnFace _uiSystem =
      AnFace(null, ['PingFang SC', 'Microsoft YaHei', 'Segoe UI', 'Noto Sans CJK SC', 'sans-serif']);

  // ── ② CONTENT axis: the serif face ──
  // Source Han Serif SC carries BOTH Latin and Simplified-Chinese in one face at Light (w300) + Regular
  // (w400), so serif prose keeps the two-weight body/emphasis contrast across scripts. The fallback is
  // the platform serif (macOS Songti SC / Windows SimSun). 思源宋 SC 拉丁+简中同脸、Light/Regular 两档;
  // 回落=平台衬线(macOS Songti SC / Windows SimSun)。
  static const AnFace serifFace =
      AnFace('Source Han Serif SC', ['Songti SC', 'STSong', 'SimSun', 'Noto Serif CJK SC', 'serif']);

  // ── ③ CODE axis faces ──
  // The head family swaps; the fallback keeps MiSans FIRST so CJK inside mono (code comments, tool
  // output, terminals) stays deterministic, then platform monos. System = family null → the OS mono via
  // the fallback (macOS SF Mono/Menlo · Windows Consolas). 头脸切换,回落 MiSans 置首(mono 里的中文确定)
  // 再平台 mono;系统=family null→经回落取 OS mono。
  static const List<String> _monoFallback = ['MiSans', 'SF Mono', 'SFMono-Regular', 'Menlo', 'Consolas', 'monospace'];
  static const AnFace _codeJetBrains = AnFace('JetBrains Mono', _monoFallback);
  static const AnFace _codeFira = AnFace('Fira Code', _monoFallback);
  static const AnFace _codeCascadia = AnFace('Cascadia Code', _monoFallback);
  static const AnFace _codeSystem = AnFace(null, _monoFallback);

  // ── the RESTART-axis holders (default = bundled, so no-boot = today) 重启轴持有(默认=内置=现状) ──
  static AnFace ui = _uiBundled;
  static AnFace mono = _codeJetBrains;

  /// The UI/code choices ACTIVE at boot — the settings rows compare the current selection against these
  /// to show a「待重启」pending hint only when the pick差 from what's rendering. 启动时生效的 UI/代码选择,
  /// 面板据此仅在选择偏离当前渲染时提示待重启。
  static String bootedUi = 'bundled';
  static String bootedCode = 'jetbrainsMono';

  /// The pref-string → face maps (the wire values persisted by [SettingsKeys.fontUi] / .fontCode /
  /// .fontContent). Unknown → the default (forward-compatible). 偏好串→脸映射;未知→默认(向前兼容)。
  static AnFace uiFaceFor(String choice) => switch (choice) {
        'system' => _uiSystem,
        _ => _uiBundled,
      };

  static AnFace codeFaceFor(String choice) => switch (choice) {
        'firaCode' => _codeFira,
        'cascadiaCode' => _codeCascadia,
        'system' => _codeSystem,
        _ => _codeJetBrains,
      };

  /// The CONTENT override — null means "no override" (sans = FOLLOW the UI face already baked into the
  /// [AnText] reading ladder), so content=sans is a true zero-touch pass-through. serif / system return
  /// a concrete face the prose surfaces layer over their reading styles. 内容覆盖:null=不覆盖(sans=跟随
  /// 已烤进 AnText 阅读阶梯的 UI 脸,真零改直通);衬线/系统返回具体脸供 prose 面覆盖其阅读样式。
  static AnFace? contentOverrideFor(String choice) => switch (choice) {
        'serif' => serifFace,
        'system' => _uiSystem, // the OS text face, regardless of the UI axis OS 文本脸(不随 UI 轴)
        _ => null, // sans — follow the booted UI face 跟随已定 UI 脸
      };

  /// Resolve the RESTART axes ONCE before `runApp` from the persisted choices. Idempotent; the CONTENT
  /// axis is NOT here (it's hot via a provider). 启动前从持久化选择解析重启轴一次(幂等);内容轴不在此(热)。
  static void applyAtBoot({required String ui, required String code}) {
    bootedUi = ui;
    bootedCode = code;
    AnFonts.ui = uiFaceFor(ui);
    AnFonts.mono = codeFaceFor(code);
  }
}
