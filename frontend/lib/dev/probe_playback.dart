// probe_playback — the ONE thing `make -C frontend verify` structurally cannot answer:
// **does the native playback layer actually come up on this machine?**
//
// Widget tests run on the Dart VM with no platform channels, so a plugin whose native half is
// missing, mis-linked or refused by the sandbox still passes `flutter analyze` and `flutter test`.
// CLAUDE.md says as much: desktop real-run needs full platform tooling and is deliberately NOT in
// the gate. So this is a REAL desktop app whose only job is to decode real media, print a verdict
// and exit — a machine-checkable answer instead of "it looked fine".
//
// It is SELF-CONTAINED on purpose. Two earlier attempts passed a path in on the command line and
// both failed with "Operation not permitted": a sandboxed macOS app can read neither /private/tmp
// from the player NOR from Dart, because the entitlements grant only user-selected files. Embedding
// the clip and writing it into the app's OWN temp dir removes the variable entirely — and it happens
// to probe exactly where a real attachment lives.
//
// **Every assumption here was re-verified after the backend swap (ADR 0018).** Evidence gathered
// against one native stack says nothing about another, and the loopback+Authorization assumption in
// particular is one that fails ONLY against the real backend.
//
// Run: flutter run -d macos -t lib/dev/probe_playback.dart
// Exit 0 = the native layer decoded real media inside the sandbox.
//
// probe_playback —— `make -C frontend verify` **结构上答不了**的那一件事:
// **原生播放层在这台机器上到底起不起得来?**
//
// widget test 跑在 Dart VM 上、没有 platform channel,故一个原生那半缺失、链错、或被 sandbox 拒掉的
// 插件,照样通过 `flutter analyze` 与 `flutter test`。CLAUDE.md 自己写着:桌面真跑要完整平台工具链、
// **刻意不入门禁**。所以这是一个**真的**桌面应用,唯一的活是解一段真媒体、打印结论、退出——给一个
// **机器可判**的答案,而不是「看着没问题」。
//
// 它刻意**自带素材**。前两次尝试从命令行传路径进来,两次都以「Operation not permitted」失败:沙箱化的
// macOS app **既不能**从播放器、**也不能**从 Dart 读 /private/tmp,因为 entitlements 只授权用户亲选的
// 文件。把片子内嵌、写进 app **自己的**临时目录,把这个变量整个去掉——而那里恰好正是真附件待的地方。
//
// **换底座之后(ADR 0018)这里每一条假设都重验了一遍。** 在一套原生栈上取得的证据,对另一套什么也
// 证明不了;尤其 loopback + Authorization 那一条,是**只会在真后端面前失败**的那种假设。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

import 'package:anselm/core/media/media_video.dart';

/// A 1-second 64x64 H.264/mp4 produced by ffmpeg — a REAL container with a real keyframe, not
/// synthetic bytes, so a pass means the decoder genuinely demuxed and decoded something.
///
/// ffmpeg 产的 1 秒 64x64 H.264/mp4——**真**容器、真关键帧,不是合成字节,故通过即意味着解码器真的
/// 解复用并解码了东西。
const String _tinyMp4Base64 =
    'AAAAIGZ0eXBpc29tAAACAGlzb21pc28yYXZjMW1wNDEAAAAIZnJlZQAABMptZGF0AAACrgYF//+q3EXpvebZSLeWLNgg2SPu73gyNjQgLSBjb3JlIDE2NSByMzIyMiBiMzU2MDVhIC0gSC4yNjQvTVBFRy00IEFWQyBjb2RlYyAtIENvcHlsZWZ0IDIwMDMtMjAyNSAtIGh0dHA6Ly93d3cudmlkZW9sYW4ub3JnL3gyNjQuaHRtbCAtIG9wdGlvbnM6IGNhYmFjPTEgcmVmPTMgZGVibG9jaz0xOjA6MCBhbmFseXNlPTB4MzoweDExMyBtZT1oZXggc3VibWU9NyBwc3k9MSBwc3lfcmQ9MS4wMDowLjAwIG1peGVkX3JlZj0xIG1lX3JhbmdlPTE2IGNocm9tYV9tZT0xIHRyZWxsaXM9MSA4eDhkY3Q9MSBjcW09MCBkZWFkem9uZT0yMSwxMSBmYXN0X3Bza2lwPTEgY2hyb21hX3FwX29mZnNldD0tMiB0aHJlYWRzPTIgbG9va2FoZWFkX3RocmVhZHM9MSBzbGljZWRfdGhyZWFkcz0wIG5yPTAgZGVjaW1hdGU9MSBpbnRlcmxhY2VkPTAgYmx1cmF5X2NvbXBhdD0wIGNvbnN0cmFpbmVkX2ludHJhPTAgYmZyYW1lcz0zIGJfcHlyYW1pZD0yIGJfYWRhcHQ9MSBiX2JpYXM9MCBkaXJlY3Q9MSB3ZWlnaHRiPTEgb3Blbl9nb3A9MCB3ZWlnaHRwPTIga2V5aW50PTI1MCBrZXlpbnRfbWluPTEwIHNjZW5lY3V0PTQwIGludHJhX3JlZnJlc2g9MCByY19sb29rYWhlYWQ9NDAgcmM9Y3JmIG1idHJlZT0xIGNyZj00MC4wIHFjb21wPTAuNjAgcXBtaW49MCBxcG1heD02OSBxcHN0ZXA9NCBpcF9yYXRpbz0xLjQwIGFxPTE6MS4wMACAAAABUWWIhACf0kjHkTw/4RcH5PwbhzH6ADqkeWRrd/0GXUEpgyA32gsKltQHwwtbAFnTi19VFGc2HvcO7DshMQLGdGbClrR2jH3lzhpf9W/E/03E4Lj7XZDPZHxS79Kh2m1MGFyUwbLByRDTpK887Fvb4OAsAvwT7hj1WCjj9qV8/JhjyHY1y0tqzTM7Gk4FOfNSibikrVv54gHtLTJZ2N2obc5GFiMDMWYAek1YpvDCAODXueMEqG+SxNmDEJtmOAc/AntPl+HL077CCo0sM7PyO/ZPwZma7MZj8UNAJS0ukhBObplgL2ufkz+14wXTZo9EUoHzMczl7mXDc3ra00aZ+kW446YEgTsc95UNIzL6VHkR3kA6vvbbEhd+usXU+bHz3lBMglO4sK9aYDD2cC3JFg5EqEWx+qLnZOdUqI91EfNEa/JPNI/1NBQvvmIiq1aX+REAAAAhQZokbE3/bNl7dIrqhPSS1vp+in1qrkEFDY8GPIlGdtz/AAAAC0GeQniO/74qP/vhAAAACwGeYXRCX8UkUs/AAAAACgGeY2pCX8d3AXsAAAAhQZpoSahBaJlMCO9yPi+Qu9QA/FFYS9SdxasMFGKztiNhAAAAC0GehkURLHe8fK+fAAAACAGepXRCX6WBAAAACQGep2pCX8c34AAAABlBmqlJqEFsmUwIS/986GDzl8xp/5VMB1VgAAADsm1vb3YAAABsbXZoZAAAAAAAAAAAAAAAAAAAA+gAAAPoAAEAAAEAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAAALcdHJhawAAAFx0a2hkAAAAAwAAAAAAAAAAAAAAAQAAAAAAAAPoAAAAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAQAAAAABAAAAAQAAAAAAAJGVkdHMAAAAcZWxzdAAAAAAAAAABAAAD6AAACAAAAQAAAAACVG1kaWEAAAAgbWRoZAAAAAAAAAAAAAAAAAAAKAAAACgAVcQAAAAAAC1oZGxyAAAAAAAAAAB2aWRlAAAAAAAAAAAAAAAAVmlkZW9IYW5kbGVyAAAAAf9taW5mAAAAFHZtaGQAAAABAAAAAAAAAAAAAAAkZGluZgAAABxkcmVmAAAAAAAAAAEAAAAMdXJsIAAAAAEAAAG/c3RibAAAAL9zdHNkAAAAAAAAAAEAAACvYXZjMQAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAABAAEAASAAAAEgAAAAAAAAAARVMYXZjNjIuMjguMTAxIGxpYngyNjQAAAAAAAAAAAAAABj//wAAADVhdmNDAWQACv/hABhnZAAKrNlEJsBEAAADAAQAAAMAUDxIllgBAAZo6+Dksiz9+PgAAAAAEHBhc3AAAAABAAAAAQAAABRidHJ0AAAAAAAAJhAAAAAAAAAAGHN0dHMAAAAAAAAAAQAAAAoAAAQAAAAAFHN0c3MAAAAAAAAAAQAAAAEAAABgY3R0cwAAAAAAAAAKAAAAAQAACAAAAAABAAAUAAAAAAEAAAgAAAAAAQAAAAAAAAABAAAEAAAAAAEAABQAAAAAAQAACAAAAAABAAAAAAAAAAEAAAQAAAAAAQAACAAAAAAcc3RzYwAAAAAAAAABAAAAAQAAAAoAAAABAAAAPHN0c3oAAAAAAAAAAAAAAAoAAAQHAAAAJQAAAA8AAAAPAAAADgAAACUAAAAPAAAADAAAAA0AAAAdAAAAFHN0Y28AAAAAAAAAAQAAADAAAABidWR0YQAAAFptZXRhAAAAAAAAACFoZGxyAAAAAAAAAABtZGlyYXBwbAAAAAAAAAAAAAAAAC1pbHN0AAAAJal0b28AAAAdZGF0YQAAAAEAAAAATGF2ZjYyLjEyLjEwMQ==';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initMediaPlayback();

  final file = File('${Directory.systemTemp.path}/probe-playback.mp4');
  await file.writeAsBytes(base64Decode(_tinyMp4Base64));
  stdout.writeln(
    'probe_playback: wrote ${await file.length()} bytes to ${file.path}',
  );

  // ── 1. Can the native layer decode a real file inside the sandbox? ──
  final fromFile = VideoPlayerController.file(file);
  try {
    await fromFile.initialize().timeout(const Duration(seconds: 20));
    final d = fromFile.value.duration;
    if (d <= Duration.zero) throw StateError('no duration');
    stdout.writeln(
      'probe_playback: OK (file) — decoded it, duration ${d.inMilliseconds}ms',
    );
    await fromFile.dispose();
  } catch (e) {
    stderr.writeln('probe_playback: FAIL (file) — $e');
    exit(1);
  }

  // ── 2. The assumption the whole design rests on ──
  //
  // The video card does NOT hand the player a path — a sandboxed macOS app cannot — it hands it a
  // loopback URL plus the sidecar's auth headers. The sidecar is loopback-hardened
  // (RequireBearerToken), so if the player does not actually SEND those headers, video passes every
  // test and fails only against the real backend. This serves the same clip over HTTP behind a
  // REQUIRED Authorization header, and refuses anything without it.
  //
  // ── 2. 整个设计所依赖的那个假设 ──
  //
  // 视频卡**不**给播放器路径(沙箱化的 macOS app 给不了),它给的是一个 loopback URL 加 sidecar 的
  // 鉴权头。而 sidecar 做了 loopback 加固(RequireBearerToken)——故若播放器**并不真的送**这些头,
  // 视频会在每个测试里都好好的、只在真后端面前失败。下面用 HTTP 供同一段片子、**强制要求**
  // Authorization 头,没有它就拒。
  const token = 'probe-token-not-a-secret';
  var sawHeader = false;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final bytes = await file.readAsBytes();
  unawaited(() async {
    await for (final req in server) {
      if (req.headers.value('authorization') != 'Bearer $token') {
        req.response.statusCode = HttpStatus.unauthorized;
        await req.response.close();
        continue;
      }
      sawHeader = true;
      // RANGE support is mandatory, not decoration. AVFoundation opens every media URL with
      // `Range: bytes=0-1` and refuses a server that answers 200-with-no-range
      // (CoreMediaErrorDomain -12939). A toy server that ignored ranges made this probe fail against
      // a perfectly good player — so the probe now serves ranges the way the real sidecar does
      // (http.ServeContent), or it would be testing a fiction.
      // **Range 支持是必需的、不是装饰。** AVFoundation 打开每个媒体 URL 都先发 `Range: bytes=0-1`,
      // 答 200-无 range 就拒绝(CoreMediaErrorDomain -12939)。一个忽略 range 的玩具服务器,让这个探针
      // 在一个**完全正常**的播放器面前失败——故探针现在按**真 sidecar 的方式**(http.ServeContent)供
      // range,否则它测的是一个虚构。
      final range = req.headers.value('range');
      final match = RegExp(r'bytes=(\d*)-(\d*)').firstMatch(range ?? '');
      req.response.headers.contentType = ContentType('video', 'mp4');
      req.response.headers.set('accept-ranges', 'bytes');
      if (match != null) {
        final start = int.tryParse(match.group(1) ?? '') ?? 0;
        final end = int.tryParse(match.group(2) ?? '') ?? bytes.length - 1;
        final slice = bytes.sublist(
          start,
          end + 1 > bytes.length ? bytes.length : end + 1,
        );
        req.response.statusCode = HttpStatus.partialContent;
        req.response.headers
          ..set(
            'content-range',
            'bytes $start-${start + slice.length - 1}/${bytes.length}',
          )
          ..contentLength = slice.length;
        req.response.add(slice);
      } else {
        req.response.headers.contentLength = bytes.length;
        req.response.add(bytes);
      }
      await req.response.close();
    }
  }());

  final overHttp = VideoPlayerController.networkUrl(
    Uri.parse('http://127.0.0.1:${server.port}/clip.mp4'),
    httpHeaders: const {'Authorization': 'Bearer $token'},
  );
  try {
    await overHttp.initialize().timeout(const Duration(seconds: 20));
    final d = overHttp.value.duration;
    if (d <= Duration.zero) throw StateError('no duration');
    if (!sawHeader) {
      // Decoding without the header would mean the server let it through — the guard would be
      // vacuous and would keep being vacuous forever.
      // 没送头也解出来了,意味着服务端放行了——那这条守卫是空的,而且会一直空下去。
      stderr.writeln(
        'probe_playback: FAIL (http) — decoded WITHOUT the header; guard is vacuous',
      );
      exit(1);
    }
    stdout.writeln(
      'probe_playback: OK (http+headers) — the player sent Authorization and decoded, '
      'duration ${d.inMilliseconds}ms',
    );
    await overHttp.dispose();
    await server.close(force: true);
  } catch (e) {
    stderr.writeln(
      'probe_playback: FAIL (http) — $e'
      '${sawHeader ? '' : ' AND the Authorization header never arrived'}',
    );
    exit(1);
  }

  // ── 3. Audio, and the number that decides whether it may share this stack ──
  //
  // Read-aloud is short-clip and HIGH FREQUENCY (re-listening to the same message is a common
  // action). If spinning up a controller costs a noticeable pause before sound, audio should not
  // share the video stack. So this measures open→playing on a read-aloud-shaped clip rather than
  // assuming — the same number was measured for the previous backend, and it does not carry over.
  //
  // ── 3. 音频,以及决定它能否共用这套栈的那个数 ──
  //
  // 朗读是**短音频 + 高频**(重听同一条是常见动作)。若起一个 controller 要付出「按下之后明显一顿」的
  // 代价,音频就不该与视频共栈。故这里**量** open→playing(朗读规格),而不是假设——上一套底座量过同一个
  // 数,而**那个数不能顺延过来**。
  final wav = File('${Directory.systemTemp.path}/probe-playback.wav');
  await wav.writeAsBytes(_readAloudShapedWav());
  // THREE plays, not one. The first carries one-time framework warm-up (~1.8s observed); what
  // read-aloud actually feels is the SECOND press and every one after (~124ms observed). Reporting a
  // cold start as "the latency" would condemn this stack on the wrong number — and reporting only a
  // warm one would flatter it.
  // **三次,不是一次。** 第一次含一次性的框架预热(实测 ~1.8s);而朗读真正让人感觉到的是**第二次**按下
  // 及之后的每一次(实测 ~124ms)。把冷启动当「延迟」上报,会用错误的数字给这套栈定罪;只报热的又会
  // 替它粉饰。
  final timings = <int>[];
  try {
    for (var i = 0; i < 3; i++) {
      final audio = VideoPlayerController.file(wav);
      final t0 = DateTime.now();
      await audio.initialize().timeout(const Duration(seconds: 20));
      await audio.play();
      timings.add(DateTime.now().difference(t0).inMilliseconds);
      await audio.dispose();
    }
    stdout.writeln(
      'probe_playback: OK (audio) — open→playing cold ${timings.first}ms, '
      'warm ${timings.sublist(1).join('/')}ms on a 2s read-aloud clip',
    );
    exit(0);
  } catch (e) {
    stderr.writeln('probe_playback: FAIL (audio) — $e');
    exit(1);
  }
}

/// A 2-second 24kHz/16-bit/mono sine as a real RIFF/WAVE stream — the exact shape read-aloud
/// produces. Synthesized rather than embedded because the base64 of 94KB of PCM would dwarf this
/// file, and a real header is what makes the measurement mean anything.
///
/// 一段 2 秒 24kHz/16bit/mono 正弦,真 RIFF/WAVE 流——正是朗读产出的规格。**合成**而非内嵌,因为 94KB
/// PCM 的 base64 会把本文件淹掉;而正因为头是真的,这次测量才有意义。
Uint8List _readAloudShapedWav() {
  const rate = 24000, seconds = 2;
  final samples = rate * seconds;
  final out = BytesBuilder();
  void str(String v) => out.add(v.codeUnits);
  void u32(int v) =>
      out.add([v & 255, v >> 8 & 255, v >> 16 & 255, v >> 24 & 255]);
  void u16(int v) => out.add([v & 255, v >> 8 & 255]);
  str('RIFF');
  u32(36 + samples * 2);
  str('WAVE');
  str('fmt ');
  u32(16);
  u16(1);
  u16(1);
  u32(rate);
  u32(rate * 2);
  u16(2);
  u16(16);
  str('data');
  u32(samples * 2);
  for (var i = 0; i < samples; i++) {
    final v = (math.sin(2 * math.pi * 440 * i / rate) * 12000).round();
    u16(v & 0xFFFF);
  }
  return out.toBytes();
}
