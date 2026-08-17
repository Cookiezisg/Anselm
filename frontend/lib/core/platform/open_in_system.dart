/// Hand a local PATH to the OS: open it with the default app, reveal it in the file manager, or open a
/// terminal in it. The desktop escape hatch for everything the app does not render inline — and it lives in
/// `core/platform` rather than inside a feature because two features already need it (Library's bundled-file
/// preview, chat's residency menu) and features must not import each other.
///
/// These are LOCAL paths, deliberately NOT routed through [openExternalUrl]: that gate exists to refuse
/// `file:` URLs arriving from tool output or markdown, and it must keep refusing them. Callers here pass a
/// path the USER chose (a directory picker, a bundled file they are already viewing), which is a different
/// provenance entirely.
///
/// Failures are SOFT everywhere — a missing `open`, a sandboxed environment, a path that vanished: nothing
/// throws and nothing crashes a menu. The bool says whether the OS was asked successfully; it does not
/// promise the user saw a window (no OS gives that answer synchronously).
///
/// 把一个本地**路径**交给系统:用默认应用打开、在文件管理器里定位、或在它里面打开终端。一切不内嵌渲染之物的
/// 桌面逃生口——它住在 `core/platform` 而非某个 feature 里,因为已有两个 feature 需要它(Library 的捆绑文件预览、
/// chat 的驻地菜单),而 feature 之间不得互相 import。
///
/// 这些是**本地路径**,**刻意不**走 [openExternalUrl]:那道闸的存在就是为了拒掉来自工具输出或 markdown 的
/// `file:` URL,它必须继续拒。此处调用方传的是**用户自己选**的路径(目录选择器、他正在看的捆绑文件),来源完全
/// 不同。
///
/// 失败处处**软处理**——没有 `open`、沙箱环境、路径消失了:都不抛、也不会崩掉一个菜单。返回的 bool 说的是
/// 「系统被成功请求了」,而**不**承诺用户看到了窗口(没有哪个系统会同步回答那件事)。
library;

import 'dart:io';

import 'package:flutter/services.dart';

/// Open a path with the OS default application (a file in its editor, a directory in the file manager).
/// macOS uses the AppKit bridge rather than spawning `open`: the shipped App Sandbox can ask Finder to
/// open a path through NSWorkspace, but cannot reliably hand an arbitrary local path to a child process.
/// macOS 走 AppKit 桥而不是起 `open`:发行版 App Sandbox 可以让 NSWorkspace 请求 Finder 打开路径,却不能可靠地把任意
/// 本地路径交给子进程。
///
/// 用系统默认应用打开一个路径(文件用它的编辑器、目录用文件管理器)。
Future<bool> openWithSystem(String absPath) {
  if (Platform.isMacOS) return _invokeMacPath(absPath, reveal: false);
  return _run(switch (_os()) {
    _Os.windows => ('explorer', [absPath]),
    _Os.linux => ('xdg-open', [absPath]),
    _Os.macos => throw StateError('macOS is handled by NSWorkspace'),
  });
}

/// REVEAL a path in the file manager — select it inside its parent rather than opening it. On Linux there
/// is no cross-desktop "select this" verb, so opening the containing directory is the honest approximation
/// (and for a directory argument that is what "reveal" means anyway).
///
/// 在文件管理器里**定位**一个路径——在其父目录里选中它、而不是打开它。Linux 上没有跨桌面的「选中这个」动词,
/// 故打开所在目录是诚实的近似(而对一个目录参数,「定位」本来就是这个意思)。
Future<bool> revealInSystem(String absPath) {
  if (Platform.isMacOS) return _invokeMacPath(absPath, reveal: true);
  return _run(switch (_os()) {
    _Os.windows => ('explorer', ['/select,', absPath]),
    _Os.linux => ('xdg-open', [_parentOf(absPath)]),
    _Os.macos => throw StateError('macOS is handled by AppKit'),
  });
}

/// Open a TERMINAL whose working directory is [absDir].
///
/// Each platform's incantation is its own: macOS hands the directory to Terminal.app; Windows starts a
/// shell with `/K cd /d` so the window STAYS open (a bare `cmd /c cd` would flash and vanish); Linux has no
/// standard terminal at all, so the Debian-ish `x-terminal-emulator` alternative is tried and a false
/// return is the honest answer when it is absent — the caller shows a notice rather than pretending.
///
/// 打开一个工作目录为 [absDir] 的**终端**。
///
/// 各平台的咒语各不相同:macOS 把目录交给 Terminal.app;Windows 用 `/K cd /d` 起一个 shell,使窗口**留着**
/// (裸 `cmd /c cd` 会一闪而没);Linux 根本没有标准终端,故试 Debian 系的 `x-terminal-emulator`,它不在时返 false
/// 就是诚实答案——调用方给一条提示、而不是装作成功。
Future<bool> openInTerminal(String absDir) => _run(switch (_os()) {
  _Os.macos => ('open', ['-a', 'Terminal', absDir]),
  _Os.windows => ('cmd', ['/c', 'start', 'cmd', '/K', 'cd', '/d', absDir]),
  _Os.linux => ('x-terminal-emulator', ['--working-directory=$absDir']),
});

enum _Os { macos, windows, linux }

// Anything that is not macOS or Windows gets the freedesktop path — the app is desktop-only, and a BSD
// running xdg-open is far likelier than a fourth branch being correct.
// 非 macOS / Windows 一律走 freedesktop 路径——本 app 只上桌面,跑着 xdg-open 的 BSD 远比第四条分支正确更可能。
_Os _os() {
  if (Platform.isMacOS) return _Os.macos;
  if (Platform.isWindows) return _Os.windows;
  return _Os.linux;
}

Future<bool> _run((String, List<String>) cmd) async {
  try {
    final result = await Process.run(cmd.$1, cmd.$2);
    return result.exitCode == 0;
  } catch (_) {
    return false; // no such binary / sandboxed: a menu item that quietly does nothing beats a crash
  }
}

const _macSystemPathChannel = MethodChannel('app/system_path');

Future<bool> _invokeMacPath(String absPath, {required bool reveal}) async {
  try {
    return await _macSystemPathChannel.invokeMethod<bool>('openPath', {
          'path': absPath,
          'reveal': reveal,
        }) ??
        false;
  } catch (_) {
    return false;
  }
}

// The containing directory, by separator — not `path.dirname`: this file has no package dependency and a
// path that is already a directory (or has no separator) must degrade to itself rather than to "".
// 所在目录,按分隔符切——不用 path.dirname:本文件无包依赖,且一个本来就是目录(或没有分隔符)的路径必须退化成
// 它自己、而不是退化成 ""。
String _parentOf(String absPath) {
  final i = absPath.lastIndexOf(Platform.pathSeparator);
  return i <= 0 ? absPath : absPath.substring(0, i);
}
