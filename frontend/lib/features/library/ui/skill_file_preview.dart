import 'dart:convert' show utf8;
import 'dart:io' show Platform, Process;
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/editor/an_editor.dart';
import '../../../core/model/byte_format.dart';
import '../../../core/notice/notice_center.dart';
import '../../../core/perf/debouncer.dart';
import '../../../core/ui/an_button.dart';
import '../../../core/ui/an_code_editor.dart';
import '../../../core/ui/an_deferred_loading.dart';
import '../../../core/ui/an_last_good.dart';
import '../../../core/ui/an_page.dart';
import '../../../core/ui/an_skeleton.dart';
import '../../../core/ui/an_state.dart';
import '../../../core/ui/icons.dart';
import '../../../i18n/strings.g.dart';
import '../../../core/model/status_state.dart';
import '../data/library_repository.dart';
import '../model/doc_outline.dart';
import '../state/library_state.dart';

/// The preview family for one bundled skill file (WRK-076 F3 「什么都能预览」): dispatch by
/// extension — markdown gets the REAL rich-text editor (feeding the inspector outline), text
/// gets the code editor, images/SVG/CSV/fonts get true previews, and everything else gets an
/// honest info card with a system-open escape hatch (no dead ends, ever).
///
/// 单个捆绑文件的预览族(WRK-076 F3「什么都能预览」):按扩展名分派——markdown 上真富文本编辑器
/// (喂右岛大纲)、文本上代码编辑器、图片/SVG/CSV/字体真预览、其余诚实信息卡+系统打开逃生口
/// (永无死路)。
enum SkillFileKind { markdown, code, image, svg, csv, font, other }

SkillFileKind skillFileKindOf(String path) {
  final i = path.lastIndexOf('.');
  final ext = i < 0 ? '' : path.substring(i).toLowerCase();
  return switch (ext) {
    '.md' || '.markdown' => SkillFileKind.markdown,
    '.py' ||
    '.js' ||
    '.mjs' ||
    '.cjs' ||
    '.ts' ||
    '.sh' ||
    '.json' ||
    '.yaml' ||
    '.yml' ||
    '.toml' ||
    '.txt' => SkillFileKind.code,
    '.png' ||
    '.jpg' ||
    '.jpeg' ||
    '.gif' ||
    '.webp' ||
    '.bmp' => SkillFileKind.image,
    '.svg' => SkillFileKind.svg,
    '.csv' => SkillFileKind.csv,
    '.ttf' || '.otf' => SkillFileKind.font,
    _ => SkillFileKind.other,
  };
}

String? skillFileLang(String path) {
  final i = path.lastIndexOf('.');
  final ext = i < 0 ? '' : path.substring(i).toLowerCase();
  return switch (ext) {
    '.py' => 'python',
    '.js' || '.mjs' || '.cjs' => 'javascript',
    '.ts' => 'typescript',
    '.json' => 'json',
    '.yaml' || '.yml' => 'yaml',
    '.toml' => 'toml',
    '.sh' => 'bash',
    '.md' || '.markdown' => 'markdown',
    '.csv' => 'plaintext',
    '.svg' => 'xml',
    _ => null,
  };
}

/// The tree/list icon for a bundled file, by kind. 树行的按类型 icon。
IconData skillFileIcon(String path) => switch (skillFileKindOf(path)) {
  SkillFileKind.markdown => AnIcons.doc,
  SkillFileKind.code || SkillFileKind.csv => AnIcons.fileCode,
  SkillFileKind.image || SkillFileKind.svg => AnIcons.image,
  _ => AnIcons.file,
};

/// Open a file with the OS default app / reveal it in the system file manager — the universal
/// escape hatch for anything we don't render inline. Desktop-only process calls; failures are
/// soft (a notice), never a crash.
///
/// 用系统默认应用打开 / 在系统文件管理器里定位——一切不内嵌渲染类型的万能逃生口。桌面进程
/// 调用;失败软处理(notice)、绝不崩。
Future<void> openWithSystem(String absPath) async {
  if (Platform.isMacOS) {
    await Process.run('open', [absPath]);
  } else if (Platform.isWindows) {
    await Process.run('explorer', [absPath]);
  } else {
    await Process.run('xdg-open', [absPath]);
  }
}

Future<void> revealInSystem(String absPath) async {
  if (Platform.isMacOS) {
    await Process.run('open', ['-R', absPath]);
  } else if (Platform.isWindows) {
    await Process.run('explorer', ['/select,', absPath]);
  } else {
    // Linux 无跨桌面标准的「定位」——打开所在目录即诚实近似。
    final dir = absPath.substring(0, absPath.lastIndexOf('/'));
    await Process.run('xdg-open', [dir]);
  }
}

/// One bundled file rendered in the center, by kind. [skillDir] powers the system-open actions
/// (absolute path = dir + / + rel). Non-markdown views CLEAR the inspector outline on mount —
/// the outline follows the open file (markdown feeds it, everything else leaves it absent).
///
/// 中心的单捆绑文件按类型渲染。[skillDir] 驱动系统打开(绝对路径 = dir + / + rel)。非 markdown
/// 视图挂载即清右岛大纲——大纲跟随打开的文件(markdown 喂、其余缺席)。
class SkillFilePreview extends ConsumerStatefulWidget {
  const SkillFilePreview({
    required this.name,
    required this.path,
    required this.skillDir,
    this.rawMode = false,
    this.onManifestSaved,
    super.key,
  });

  final String name;
  final String path;
  final String skillDir;

  /// Force the code-editor branch regardless of kind — the manifest's «源码» mode edits the
  /// raw fenced file. 强制源码分支(清单源码模式编辑带围栏原文)。
  final bool rawMode;
  final VoidCallback? onManifestSaved;

  @override
  ConsumerState<SkillFilePreview> createState() => _SkillFilePreviewState();
}

class _SkillFilePreviewState extends ConsumerState<SkillFilePreview> {
  final _save = Debouncer(AnMotion.autosave);
  bool _sourceMode = false; // svg/csv 的「源码」切换(默认渲染预览)

  SkillFileKind get _kind => skillFileKindOf(widget.path);

  String get _absPath => '${widget.skillDir}/${widget.path}';

  @override
  void initState() {
    super.initState();
    if (_kind != SkillFileKind.markdown) {
      // 大纲跟随:非 markdown 文件无大纲——组静默缺席。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(docOutlineProvider.notifier).clear();
      });
    }
  }

  @override
  void dispose() {
    _save.flush();
    super.dispose();
  }

  void _saveText(String text) {
    final repo = ref.read(libraryRepositoryProvider);
    _save.run(() async {
      try {
        await repo.writeSkillFile(widget.name, widget.path, utf8.encode(text));
        widget.onManifestSaved?.call();
        ref.invalidate(skillFilesProvider(widget.name));
      } catch (_) {
        if (mounted) {
          ref
              .read(noticeCenterProvider.notifier)
              .show(context.t.library.skillFileSaveFailed, tone: AnTone.danger);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rawMode) return _textEditor();
    return switch (_kind) {
      SkillFileKind.markdown => _MarkdownFileView(
        key: ValueKey('md:${widget.path}'),
        name: widget.name,
        path: widget.path,
        onSave: _saveText,
      ),
      SkillFileKind.code => _textEditor(),
      SkillFileKind.image => _imageView(),
      SkillFileKind.svg => _sourceMode ? _textEditor() : _svgView(),
      SkillFileKind.csv => _sourceMode ? _textEditor() : _csvView(),
      SkillFileKind.font => _fontView(),
      SkillFileKind.other => _infoCard(),
    };
  }

  // ── text / code(可编辑,防抖裸字节 PUT)──────────────────────────────────────
  Widget _textEditor() {
    final t = context.t;
    // Last-known-good: a same-file refresh keeps content mounted; file switches rebuild the whole
    // preview via the upstream per-file ValueKey. last-known-good:同文件刷新不闪,切文件上游整树重建。
    return AnLastGood(
      value: ref.watch(
        skillFileTextProvider((name: widget.name, path: widget.path)),
      ),
      placeholder: const AnPage(child: AnSkeleton.lines(8)),
      errorBuilder: (_, _, _) => AnState(
        kind: AnStateKind.error,
        title: t.library.loadFailed,
        hint: t.library.errorHint,
      ),
      builder: (context, text) => AnPage(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: AnSpace.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_kind == SkillFileKind.svg || _kind == SkillFileKind.csv)
                _modeToggleRow(preview: false),
              AnCodeEditor(
                code: text,
                lang: skillFileLang(widget.path),
                editable: true,
                wrap: true,
                onChanged: _saveText,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── image(真预览:Image.memory)─────────────────────────────────────────────
  Widget _imageView() {
    return _bytesView(
      (bytes, size) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Image.memory(
              Uint8List.fromList(bytes),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => _infoCard(),
            ),
          ),
          const SizedBox(height: AnSpace.s8),
          _fileMetaLine(size),
        ],
      ),
    );
  }

  // ── svg(渲染预览,双模)────────────────────────────────────────────────────
  Widget _svgView() {
    return _bytesView(
      (bytes, size) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _modeToggleRow(preview: true),
          Flexible(
            child: SvgPicture.memory(
              Uint8List.fromList(bytes),
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: AnSpace.s8),
          _fileMetaLine(size),
        ],
      ),
    );
  }

  // ── csv(表格预览,双模;行数封顶防巨表)───────────────────────────────────────
  static const int _csvRowCap = 200;

  Widget _csvView() {
    final t = context.t;
    final c = context.colors;
    return AnLastGood(
      value: ref.watch(
        skillFileTextProvider((name: widget.name, path: widget.path)),
      ),
      placeholder: const AnPage(child: AnSkeleton.lines(8)),
      errorBuilder: (_, _, _) => AnState(
        kind: AnStateKind.error,
        title: t.library.loadFailed,
        hint: t.library.errorHint,
      ),
      builder: (context, text) {
        List<List<dynamic>> rows;
        try {
          rows = const CsvToListConverter(
            shouldParseNumbers: false,
          ).convert(text, eol: '\n');
        } catch (_) {
          return _textEditor(); // 解析不了 → 诚实退回源码
        }
        final capped = rows.length > _csvRowCap;
        final shown = capped ? rows.sublist(0, _csvRowCap) : rows;
        return AnPage(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: AnSpace.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _modeToggleRow(preview: true),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Table(
                    defaultColumnWidth: const IntrinsicColumnWidth(),
                    border: TableBorder.all(
                      color: c.line,
                      width: AnSize.hairline,
                    ),
                    children: [
                      for (var r = 0; r < shown.length; r++)
                        TableRow(
                          children: [
                            for (final cell in shown[r])
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AnSpace.s8,
                                  vertical: AnSpace.s4,
                                ),
                                child: Text(
                                  '$cell',
                                  style: r == 0
                                      ? AnText.meta
                                            .weight(AnText.emphasisWeight)
                                            .copyWith(color: c.ink)
                                      : AnText.meta.copyWith(color: c.inkMuted),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
                if (capped)
                  Padding(
                    padding: const EdgeInsets.only(top: AnSpace.s6),
                    child: Text(
                      t.library.skillCsvCapped(n: _csvRowCap),
                      style: AnText.meta.copyWith(color: c.inkFaint),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── font(动态加载样张)────────────────────────────────────────────────────
  Widget _fontView() {
    final t = context.t;
    final c = context.colors;
    return _bytesView((bytes, size) {
      final family = 'skillfont-${widget.path.hashCode}';
      return FutureBuilder<void>(
        future: () async {
          final loader = FontLoader(family)
            ..addFont(
              Future.value(ByteData.view(Uint8List.fromList(bytes).buffer)),
            );
          await loader.load();
        }(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const AnDeferredLoading(child: AnSkeleton.lines(4));
          }
          if (snap.hasError) return _infoCard();
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 样张字号走 typography 档(字号单源律):readingH1=样张大字、reading=正文样张。
                Text(
                  'Aa Bb Cc 0123456789',
                  style: AnText.readingH1.copyWith(fontFamily: family),
                ),
                const SizedBox(height: AnSpace.s8),
                Text(
                  t.library.skillFontSample,
                  style: AnText.reading.copyWith(fontFamily: family),
                ),
                const SizedBox(height: AnSpace.s12),
                _fileMetaLine(size),
                const SizedBox(height: AnSpace.s2),
                Text(
                  t.library.skillFontNote,
                  style: AnText.meta.copyWith(color: c.inkFaint),
                ),
              ],
            ),
          );
        },
      );
    });
  }

  // ── other(诚实信息卡 + 系统打开逃生口)───────────────────────────────────────
  Widget _infoCard() {
    final t = context.t;
    final files = ref.watch(skillFilesProvider(widget.name)).value;
    final size = files?.where((f) => f.path == widget.path).firstOrNull?.size;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnState(
            kind: AnStateKind.empty,
            size: AnStateSize.inset,
            title: widget.path,
            hint: t.library.skillFileBinary,
          ),
          if (size != null) _fileMetaLine(size),
          const SizedBox(height: AnSpace.s12),
          _systemActions(),
        ],
      ),
    );
  }

  // ── shared bits ────────────────────────────────────────────────────────────
  Widget _bytesView(Widget Function(List<int> bytes, int size) builder) {
    return AnLastGood(
      value: ref.watch(
        skillFileBytesProvider((name: widget.name, path: widget.path)),
      ),
      placeholder: const AnPage(child: AnSkeleton.lines(6)),
      // 超 1MB 读护栏等一切读错 → 信息卡 + 系统打开(诚实降级、永无死路)。
      errorBuilder: (_, _, _) => _infoCard(),
      builder: (context, bytes) => AnPage(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AnSpace.s12),
          child: builder(bytes, bytes.length),
        ),
      ),
    );
  }

  Widget _fileMetaLine(int size) {
    final c = context.colors;
    return Text(
      '${widget.path} · ${formatBytes(size)}',
      style: AnText.meta.copyWith(color: c.inkFaint),
    );
  }

  Widget _modeToggleRow({required bool preview}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AnSpace.s8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          AnButton(
            label: preview
                ? t.library.skillSourceMode
                : t.library.skillPreviewMode,
            size: AnButtonSize.sm,
            outline: true,
            onPressed: () => setState(() => _sourceMode = !_sourceMode),
          ),
          const SizedBox(width: AnSpace.s8),
          _systemActions(),
        ],
      ),
    );
  }

  Widget _systemActions() {
    final t = context.t;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnButton(
          label: t.library.skillOpenSystem,
          size: AnButtonSize.sm,
          outline: true,
          onPressed: widget.skillDir.isEmpty
              ? null
              : () => openWithSystem(_absPath),
        ),
        const SizedBox(width: AnSpace.s4),
        AnButton(
          label: t.library.skillRevealSystem,
          size: AnButtonSize.sm,
          outline: true,
          onPressed: widget.skillDir.isEmpty
              ? null
              : () => revealInSystem(_absPath),
        ),
      ],
    );
  }
}

/// A bundled markdown file in the REAL rich-text editor (headless — no crumb/title chrome,
/// that belongs to the manifest page), feeding the inspector outline and answering its jumps.
/// The outline-follows-the-open-file law's markdown half.
///
/// 附属 markdown 文件上真富文本编辑器(无头——面包屑/标题 chrome 归清单页),喂右岛大纲并响应
/// 大纲跳转。「大纲跟随打开文件」律的 markdown 半。
class _MarkdownFileView extends ConsumerStatefulWidget {
  const _MarkdownFileView({
    required this.name,
    required this.path,
    required this.onSave,
    super.key,
  });

  final String name;
  final String path;
  final void Function(String markdown) onSave;

  @override
  ConsumerState<_MarkdownFileView> createState() => _MarkdownFileViewState();
}

class _MarkdownFileViewState extends ConsumerState<_MarkdownFileView> {
  final GlobalKey<AnEditorState> _editorKey = GlobalKey<AnEditorState>();
  final ScrollController _scroll = ScrollController();
  final _outline = Debouncer(AnMotion.searchDebounce);

  @override
  void dispose() {
    _outline.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _feedOutline(String markdown) {
    ref.read(docOutlineProvider.notifier).set(extractDocOutline(markdown));
  }

  /// The manifest page's jump formula, minus the co-scroll header (the editor IS the top of
  /// this scroll body). 清单页跳转公式的无头版(编辑器即滚动体顶部)。
  void _jumpToHeading(int index) {
    final ids = _editorKey.currentState?.headingNodeIds ?? const [];
    if (index < 0 || index >= ids.length || !_scroll.hasClients) return;
    final top = _editorKey.currentState?.contentTopForNode(ids[index]);
    if (top == null) return;
    final target = (top - AnSpace.s16).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    _scroll.animateTo(target, duration: AnMotion.mid, curve: AnMotion.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.t;
    ref.listen(outlineJumpProvider, (prev, next) {
      if (next != null && next != prev) _jumpToHeading(next.index);
    });
    return AnLastGood(
      value: ref.watch(
        skillFileTextProvider((name: widget.name, path: widget.path)),
      ),
      placeholder: const AnPage(child: AnSkeleton.lines(8)),
      errorBuilder: (_, _, _) => AnState(
        kind: AnStateKind.error,
        title: t.library.loadFailed,
        hint: t.library.errorHint,
      ),
      builder: (context, text) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _feedOutline(text);
        });
        return AnPage(
          child: SingleChildScrollView(
            controller: _scroll,
            padding: const EdgeInsets.symmetric(vertical: AnSpace.s12),
            child: AnEditor(
              key: _editorKey,
              shrinkWrap: true,
              initialMarkdown: text,
              onChangedMarkdown: (md) {
                widget.onSave(md);
                _outline.run(() {
                  if (mounted) _feedOutline(md);
                });
              },
            ),
          ),
        );
      },
    );
  }
}
