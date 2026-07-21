import '../../core/ui/an_live_tail.dart';
import '../../core/ui/an_term_viewport.dart';
import 'specimen.dart';

// AnLiveTail term face (WRK-066 族六, absorbed the old AnTermTail) — the terminal live tail: termFold
// folds in-place cursor rewrites (\r progress bars, cursor-up multi-line docker-pull) into their final
// frame; ansiSpans themes SGR colors; white window face. 活尾族 term 脸(吸收旧 AnTermTail):折叠+ANSI
// 主题化+白窗面。

const _esc = '\x1B';

// A docker-pull style cursor-up multi-line progress renderer, mid-stream. docker pull cursor-up。
final _dockerPull =
    'Pulling base-image\n'
    'a1b2: Downloading  40%\n'
    'c3d4: Downloading  10%\n'
    'e5f6: Waiting\n'
    '$_esc[3A' // cursor up 3
    '$_esc[2Ka1b2: Pull complete\n' // ESC[2K erases the old line before the rewrite (as docker does) 擦行再重写
    '$_esc[2Kc3d4: Downloading  85%\n'
    '$_esc[2Ke5f6: Extracting  20%';

// A \r progress bar (each frame overwrites the line). \r 进度条整行重写。
final _progressBar =
    'Compiling anselm\n'
    '[=====>         ] 33%\r'
    '[==========>    ] 67%\r'
    '[===============] 100%  done';

// ANSI-colored build log (red error / green ok / yellow warn / dim). ANSI 彩色日志。
final _ansiLog =
    '$_esc[32m✓$_esc[0m 24 passed\n'
    '$_esc[33m⚠$_esc[0m 2 deprecation warnings\n'
    '$_esc[31m✗ FAIL$_esc[0m src/parser.test.ts\n'
    '$_esc[2m  expected 3, got 4$_esc[0m';

final anTermTailGalleryItem = GalleryItem(
  'AnLiveTail term 脸(族六终端尾)',
  'Bash 前台活期的活尾(吸收旧 AnTermTail):termFold 折叠原地重写(\\r 进度条整行刷新、cursor-up 多行 '
      'docker-pull 折成最终帧,不堆行)+ ansiSpans 把 SGR 色映 design token(红 danger/绿 ok/黄 warn/暗 faint,'
      'bold→w400)+ 顶缘渐隐融白窗面。',
  [
    GallerySpecimen(
      'docker-pull cursor-up(多行原地重写→最终帧,顶缘渐隐)',
      (c) => AnLiveTail(_dockerPull),
      span: true,
    ),
    GallerySpecimen(
      '\\r 进度条(整行重写只留最终帧)',
      (c) => AnLiveTail(_progressBar),
      span: true,
    ),
    GallerySpecimen(
      'ANSI 彩色日志(红/绿/黄/暗 映 token)',
      (c) => AnLiveTail(_ansiLog),
      span: true,
    ),
  ],
);

// A long build log (> the 320 viewport → bounded + stick-to-bottom). 长日志→有界钉底。
final _longLog = [
  for (var i = 1; i <= 40; i++)
    i == 30
        ? '$_esc[32m✓$_esc[0m compiled module_$i.dart'
        : (i == 37
              ? '$_esc[31m✗ error in module_$i.dart:12$_esc[0m'
              : 'compiling module_$i.dart …'),
].join('\n');

final anTermViewportGalleryItem = GalleryItem(
  'AnTermViewport 有界回滚终端窗(#6)',
  'Bash 落定体终端窗:termFold+ANSI + 有界(320)+ 钉底(终端语义,新输出在底)+ 上滚顶缘渐隐 + '
      '「回到最新」浮标 + 超 6000 字只物化尾部 +「显示更早 N 行」懒加载(全文在内存、视口始终有界=逃生口)。',
  [
    GallerySpecimen(
      '长日志(40 行 > 320 视口 → 有界钉底,末行在底)',
      (c) => AnTermViewport(text: _longLog),
      span: true,
    ),
  ],
);
