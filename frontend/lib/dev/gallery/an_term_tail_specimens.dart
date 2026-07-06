import '../../features/chat/ui/tool_card_skins.dart';
import 'specimen.dart';

// AnTermTail (B4.3, WRK-056 #46) — the terminal live tail: termFold folds in-place cursor rewrites
// (\r progress bars, cursor-up multi-line docker-pull) into their final frame; ansiSpans themes SGR
// colors. 终端活尾:折叠 + ANSI 主题化。

const _esc = '\x1B';

// A docker-pull style cursor-up multi-line progress renderer, mid-stream. docker pull cursor-up。
final _dockerPull = 'Pulling base-image\n'
    'a1b2: Downloading  40%\n'
    'c3d4: Downloading  10%\n'
    'e5f6: Waiting\n'
    '$_esc[3A' // cursor up 3
    '$_esc[2Ka1b2: Pull complete\n' // ESC[2K erases the old line before the rewrite (as docker does) 擦行再重写
    '$_esc[2Kc3d4: Downloading  85%\n'
    '$_esc[2Ke5f6: Extracting  20%';

// A \r progress bar (each frame overwrites the line). \r 进度条整行重写。
final _progressBar = 'Compiling anselm\n'
    '[=====>         ] 33%\r'
    '[==========>    ] 67%\r'
    '[===============] 100%  done';

// ANSI-colored build log (red error / green ok / yellow warn / dim). ANSI 彩色日志。
final _ansiLog = '$_esc[32m✓$_esc[0m 24 passed\n'
    '$_esc[33m⚠$_esc[0m 2 deprecation warnings\n'
    '$_esc[31m✗ FAIL$_esc[0m src/parser.test.ts\n'
    '$_esc[2m  expected 3, got 4$_esc[0m';

final anTermTailGalleryItem = GalleryItem(
  'AnTermTail 终端活尾(#46)',
  'Bash 前台活期的活尾:termFold 折叠原地重写(\\r 进度条整行刷新、cursor-up 多行 docker-pull 折成最终帧,'
      '不堆行)+ ansiSpans 把 SGR 色映 design token(红 danger/绿 ok/黄 warn/暗 faint,bold→w400)+ 顶缘渐隐。',
  [
    GallerySpecimen('docker-pull cursor-up(多行原地重写→最终帧,顶缘渐隐)',
        (c) => AnTermTail(text: _dockerPull), span: true),
    GallerySpecimen('\\r 进度条(整行重写只留最终帧)',
        (c) => AnTermTail(text: _progressBar), span: true),
    GallerySpecimen('ANSI 彩色日志(红/绿/黄/暗 映 token)',
        (c) => AnTermTail(text: _ansiLog), span: true),
  ],
);
