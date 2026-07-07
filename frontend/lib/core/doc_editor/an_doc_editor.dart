import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:webview_flutter/webview_flutter.dart';

import '../design/colors.dart';
import '../design/typography.dart';
import '../entity/mention_source.dart';
import '../platform/host_platform.dart';
import '../ui/an_markdown.dart';
import '../ui/entity_ref_codec.dart';
import 'doc_bridge.dart';

/// The document editor — a WYSIWYG-markdown surface backed by Milkdown/Crepe running inside a
/// WKWebView (macOS). Replaces the super_editor `AnDocEditor`. The editor HTML is a self-contained
/// offline bundle (`assets/editor/doc_editor.html`, built from `tool/doc-editor/` via `make doc-editor`).
///
/// Contract: markdown in via [initialMarkdown], out via [onChanged]; the title/description/tags header
/// lives INSIDE the webview (co-scroll — a product characteristic) and reports edits via [onMetaChanged].
/// The `@` picker asks [mentionSource] over the bridge; `[[id]]` pills prime their labels from it on load.
/// [onScroll] (webview scroll offset) drives the feature's floating-head collapse; [onOutline] carries the
/// heading geometry for the inspector's scroll-spy; [scrollToHeading] answers an outline-jump.
///
/// 文档编辑器:WKWebView 里跑 Milkdown/Crepe(离线单文件包)。markdown 进出;标题头在 webview 内(同滚);
/// @ 候选经桥问 mentionSource,[[id]] 药丸载入时从它灌标签;滚动/大纲经回调喂 feature。
class AnDocEditor extends StatefulWidget {
  const AnDocEditor({
    super.key,
    required this.initialMarkdown,
    required this.onChanged,
    this.crumb = '',
    this.name = '',
    this.nameEditable = true,
    this.description = '',
    this.tags = const [],
    this.onMetaChanged,
    this.mentionSource,
    this.onScroll,
    this.onActiveHeading,
    this.readOnly = false,
  });

  /// Headless test seam: when true the widget renders a placeholder instead of a real WKWebView, so
  /// widget tests that mount a screen containing the editor don't hit the (test-unavailable) webview
  /// platform. Production stays false. 无头测试开关:置 true 渲占位、不建真 webview,让含编辑器的组件测试可跑。
  static bool debugDisableWebview = false;

  final String initialMarkdown;
  final ValueChanged<String> onChanged;

  /// Document header fields (rendered inside the webview, above the editor body).
  final String crumb; // small breadcrumb line above the title (e.g. "Documents" / "Skills")
  final String name;
  final bool nameEditable; // skills: the name IS the identity — not renamable in place

  final String description;
  final List<String> tags;

  /// Fired when the title/description are edited in the webview header (debounced).
  final void Function(Map<String, dynamic> meta)? onMetaChanged;

  /// The `@` picker's data seam (function/handler/agent/workflow/document). Null = no `@` mentions.
  final MentionSource? mentionSource;

  /// The webview scroll offset changed (drives the floating-head collapse).
  final void Function(double offset)? onScroll;

  /// The active heading index changed on scroll (drives the outline's live focus). -1 = none.
  final void Function(int index)? onActiveHeading;

  final bool readOnly;

  @override
  State<AnDocEditor> createState() => AnDocEditorState();
}

class AnDocEditorState extends State<AnDocEditor> {
  WebViewController? _controller;
  DocBridge? _bridge;
  bool _booted = false;
  bool _bootStarted = false;

  // The WKWebView backend of webview_flutter is macOS-only. On Linux/Windows there's NO backend —
  // constructing a WebViewController throws — so those platforms degrade to read-only rendered markdown
  // (below) instead of crashing. Editing is a macOS feature (Windows via WebView2 is future work, A6).
  // webview 仅 macOS;Linux/Windows 无后端→建 controller 会崩→降级只读渲染 markdown。
  bool get _webviewEnabled => !AnDocEditor.debugDisableWebview && HostPlatform.isMacOS;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Boot once, after the first frame's dependencies are available (Theme.of valid here).
    if (!_bootStarted && _webviewEnabled) {
      _bootStarted = true;
      _boot();
    }
  }

  Future<void> _boot() async {
    // Capture theme-derived values BEFORE any await (no BuildContext use across async gaps).
    final theme = Theme.of(context);
    final bg = theme.colorScheme.surface;
    final isDark = theme.brightness == Brightness.dark;

    final controller = WebViewController()..setJavaScriptMode(JavaScriptMode.unrestricted);
    final bridge = DocBridge(controller);
    bridge.onChange = widget.onChanged;
    bridge.onMeta = (m) {
      widget.onMetaChanged?.call(m);
    };
    bridge.onScroll = (o) {
      widget.onScroll?.call(o);
    };
    bridge.onActiveHeading = (i) {
      widget.onActiveHeading?.call(i);
    };
    bridge.onMentionSearch = _onMentionSearch;
    _controller = controller;
    _bridge = bridge;

    // Opaque token background so the WKWebView surface never flashes white before content reveals.
    // macOS WKWebView does NOT implement setBackgroundColor (throws "opaque is not implemented on macOS");
    // the editor HTML's own <body> background carries the token color instead. 桥不支持时靠 HTML body 底色。
    try {
      await controller.setBackgroundColor(bg);
    } catch (_) {
      /* macOS: unimplemented — HTML body background handles it */
    }
    // Surface JS console + load errors (WKWebView differs from headless chromium). Harmless in production.
    await controller.setOnConsoleMessage((m) => debugPrint('[doc-editor/js] ${m.level.name}: ${m.message}'));

    // Channel must be attached BEFORE loadFlutterAsset so the ready handshake is never missed.
    await bridge.attach();
    await controller.setNavigationDelegate(NavigationDelegate(
      onWebResourceError: (e) => debugPrint('[doc-editor/load] ${e.errorCode} ${e.description}'),
    ));
    await controller.loadFlutterAsset('assets/editor/doc_editor.html');

    // READY = the JS handshake (editor mounted), NOT onPageFinished (fires before ProseMirror mounts).
    await bridge.ready.timeout(const Duration(seconds: 10), onTimeout: () {
      debugPrint('[doc-editor] ready handshake TIMED OUT — editor did not mount');
    });
    await _injectFonts(bridge);
    await bridge.setTheme(isDark);
    await _primeMentions(bridge, widget.initialMarkdown);
    await bridge.setMeta({
      'crumb': widget.crumb,
      'name': widget.name,
      'description': widget.description,
      'tags': widget.tags,
    });
    await bridge.setMarkdown(widget.initialMarkdown);
    if (mounted) setState(() => _booted = true);
  }

  /// Answer an `@` search from the webview picker: [mentionSource] → {id,kind,label} rows → resolve.
  Future<void> _onMentionSearch(String query, String reqId) async {
    final source = widget.mentionSource;
    final bridge = _bridge;
    if (source == null || bridge == null) return;
    try {
      final cands = await source.search(query);
      await bridge.resolveMention(
        reqId,
        [for (final c in cands) {'id': c.id, 'kind': c.type, 'label': c.name}],
      );
    } catch (_) {
      await bridge.resolveMention(reqId, const []);
    }
  }

  /// Prime `[[id]]` pill labels before the first paint (kind comes from the id prefix, JS-side). Names
  /// resolve via the mention source; unresolved ids fall back to the bare id. 载入前灌药丸标签(kind 由前缀)。
  Future<void> _primeMentions(DocBridge bridge, String markdown) async {
    final source = widget.mentionSource;
    if (source == null) return;
    final ids = extractEntityRefIds(markdown);
    if (ids.isEmpty) return;
    try {
      final names = await source.resolveNames(ids);
      if (names.isEmpty) return;
      await bridge.primeMentionCache([
        for (final e in names.entries) {'id': e.key, 'label': e.value},
      ]);
    } catch (_) {
      /* best-effort — pills fall back to the bare id */
    }
  }

  // Inject the app's bundled Latin + code fonts into the webview as @font-face (they are Flutter assets
  // the WKWebView can't otherwise see). MiSans (20 MB) is intentionally NOT injected — CJK falls back to
  // the system PingFang SC; revisit if 1:1 CJK fidelity is required. Latin+代码字体经桥注入。
  Future<void> _injectFonts(DocBridge bridge) async {
    Future<void> inject(String family, String asset) async {
      final data = await rootBundle.load(asset);
      final b64 = base64Encode(data.buffer.asUint8List());
      await bridge.injectFont(family, b64);
    }

    await inject('Inter', 'assets/fonts/InterVariable.ttf');
    await inject('JetBrains Mono', 'assets/fonts/JetBrainsMono.ttf');
  }

  @override
  void didUpdateWidget(covariant AnDocEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bridge = _bridge;
    if (bridge == null || !bridge.isReady) return;
    // Live theme flip (light/dark) without a remount.
    bridge.setTheme(Theme.of(context).brightness == Brightness.dark);
    if (oldWidget.crumb != widget.crumb ||
        oldWidget.name != widget.name ||
        oldWidget.description != widget.description ||
        oldWidget.tags != widget.tags) {
      bridge.setMeta({
        'crumb': widget.crumb,
        'name': widget.name,
        'nameEditable': widget.nameEditable,
        'description': widget.description,
        'tags': widget.tags,
      });
    }
    // NOTE: initialMarkdown is intentionally NOT re-pushed here — switching documents remounts via a
    // new widget key (protects the open editor's cursor from autosave echoes). initialMarkdown 不重推。
  }

  // ---- imperative outline seam (async, bridge-backed) — for the outline scroll-spy/jump ----
  Future<List<dynamic>> headingRects() async => _bridge?.headingRects() ?? const [];
  Future<void> scrollToHeading(int index) async => _bridge?.scrollToHeading(index);
  Future<void> scrollToTop() async => _bridge?.scrollToTop();

  @override
  void dispose() {
    _bridge?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (AnDocEditor.debugDisableWebview) {
      return const ColoredBox(color: Color(0x00000000), child: SizedBox.expand()); // headless test placeholder
    }
    if (!HostPlatform.isMacOS) {
      return _degradeReadOnly(context); // Linux/Windows: no webview_flutter backend → read-only markdown
    }
    final controller = _controller;
    if (controller == null) {
      return const ColoredBox(color: Color(0x00000000), child: SizedBox.expand()); // pre-boot
    }
    return Stack(
      children: [
        WebViewWidget(controller: controller),
        if (!_booted)
          const Positioned.fill(
            child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
          ),
      ],
    );
  }

  /// Read-only degrade for platforms with no webview backend (Linux/Windows): the doc header + the
  /// content rendered read-only via [AnMarkdown]. No editing (that's a macOS feature). 无 webview 后端时
  /// 的只读降级:头 + AnMarkdown 渲染正文,不可编辑。
  Widget _degradeReadOnly(BuildContext context) {
    final c = context.colors;
    return SingleChildScrollView(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.crumb.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(widget.crumb, style: AnText.label.copyWith(color: c.inkFaint)),
                  ),
                if (widget.name.isNotEmpty) Text(widget.name, style: AnText.readingH1),
                if (widget.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(widget.description, style: AnText.label.copyWith(color: c.inkMuted)),
                  ),
                const SizedBox(height: 16),
                AnMarkdown(widget.initialMarkdown),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
