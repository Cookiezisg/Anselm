// probe_media_kit — the ONE thing `make -C frontend verify` structurally cannot answer:
// **does the native playback layer actually come up on this machine?**
//
// Widget tests run on the Dart VM with no platform channels, so a plugin whose native half is
// missing, mis-linked or refused by the sandbox still passes `flutter analyze` and `flutter test`.
// CLAUDE.md says as much: desktop real-run needs full Xcode/CocoaPods and is deliberately NOT in
// the gate. So this is a REAL desktop app whose only job is to decode real media through libmpv,
// print a verdict and exit — a machine-checkable answer instead of "it looked fine".
//
// It is SELF-CONTAINED on purpose. The first two attempts passed a path in on the command line and
// both failed with "Operation not permitted": a sandboxed macOS app can read neither /private/tmp
// from libmpv NOR from Dart, because the entitlements grant only user-selected files. Embedding the
// clip and writing it into the app's OWN temp dir removes the variable entirely — and it happens to
// probe exactly where a real attachment lives.
//
// Run: flutter run -d macos -t lib/dev/probe_media_kit.dart
// Exit 0 = the native layer decoded real media inside the sandbox.
//
// probe_media_kit —— `make -C frontend verify` **结构上答不了**的那一件事:
// **原生播放层在这台机器上到底起不起得来?**
//
// widget test 跑在 Dart VM 上、没有 platform channel,故一个原生那半缺失、链错、或被 sandbox 拒掉的
// 插件,照样通过 `flutter analyze` 与 `flutter test`。CLAUDE.md 自己写着:桌面真跑要完整
// Xcode/CocoaPods、**刻意不入门禁**。所以这是一个**真的**桌面应用,唯一的活是经 libmpv 解一段真媒体、
// 打印结论、退出——给一个**机器可判**的答案,而不是「看着没问题」。
//
// 它刻意**自带素材**。前两次尝试从命令行传路径进来,两次都以「Operation not permitted」失败:沙箱化的
// macOS app **既不能**从 libmpv、**也不能**从 Dart 读 /private/tmp,因为 entitlements 只授权用户亲选的
// 文件。把片子内嵌、写进 app **自己的**临时目录,把这个变量整个去掉——而那里恰好正是真附件待的地方。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';

/// A 1-second 64x64 H.264/mp4 produced by ffmpeg — a REAL container with a real keyframe, not
/// synthetic bytes, so a pass means libmpv genuinely demuxed and decoded something.
///
/// ffmpeg 产的 1 秒 64x64 H.264/mp4——**真**容器、真关键帧,不是合成字节,故通过即意味着 libmpv 真的
/// 解复用并解码了东西。
const String _tinyMp4Base64 =
    'AAAAIGZ0eXBpc29tAAACAGlzb21pc28yYXZjMW1wNDEAAAAIZnJlZQAABMptZGF0AAACrgYF//+q3EXpvebZSLeWLNgg2SPu73gyNjQgLSBjb3JlIDE2NSByMzIyMiBiMzU2MDVhIC0gSC4yNjQvTVBFRy00IEFWQyBjb2RlYyAtIENvcHlsZWZ0IDIwMDMtMjAyNSAtIGh0dHA6Ly93d3cudmlkZW9sYW4ub3JnL3gyNjQuaHRtbCAtIG9wdGlvbnM6IGNhYmFjPTEgcmVmPTMgZGVibG9jaz0xOjA6MCBhbmFseXNlPTB4MzoweDExMyBtZT1oZXggc3VibWU9NyBwc3k9MSBwc3lfcmQ9MS4wMDowLjAwIG1peGVkX3JlZj0xIG1lX3JhbmdlPTE2IGNocm9tYV9tZT0xIHRyZWxsaXM9MSA4eDhkY3Q9MSBjcW09MCBkZWFkem9uZT0yMSwxMSBmYXN0X3Bza2lwPTEgY2hyb21hX3FwX29mZnNldD0tMiB0aHJlYWRzPTIgbG9va2FoZWFkX3RocmVhZHM9MSBzbGljZWRfdGhyZWFkcz0wIG5yPTAgZGVjaW1hdGU9MSBpbnRlcmxhY2VkPTAgYmx1cmF5X2NvbXBhdD0wIGNvbnN0cmFpbmVkX2ludHJhPTAgYmZyYW1lcz0zIGJfcHlyYW1pZD0yIGJfYWRhcHQ9MSBiX2JpYXM9MCBkaXJlY3Q9MSB3ZWlnaHRiPTEgb3Blbl9nb3A9MCB3ZWlnaHRwPTIga2V5aW50PTI1MCBrZXlpbnRfbWluPTEwIHNjZW5lY3V0PTQwIGludHJhX3JlZnJlc2g9MCByY19sb29rYWhlYWQ9NDAgcmM9Y3JmIG1idHJlZT0xIGNyZj00MC4wIHFjb21wPTAuNjAgcXBtaW49MCBxcG1heD02OSBxcHN0ZXA9NCBpcF9yYXRpbz0xLjQwIGFxPTE6MS4wMACAAAABUWWIhACf0kjHkTw/4RcH5PwbhzH6ADqkeWRrd/0GXUEpgyA32gsKltQHwwtbAFnTi19VFGc2HvcO7DshMQLGdGbClrR2jH3lzhpf9W/E/03E4Lj7XZDPZHxS79Kh2m1MGFyUwbLByRDTpK887Fvb4OAsAvwT7hj1WCjj9qV8/JhjyHY1y0tqzTM7Gk4FOfNSibikrVv54gHtLTJZ2N2obc5GFiMDMWYAek1YpvDCAODXueMEqG+SxNmDEJtmOAc/AntPl+HL077CCo0sM7PyO/ZPwZma7MZj8UNAJS0ukhBObplgL2ufkz+14wXTZo9EUoHzMczl7mXDc3ra00aZ+kW446YEgTsc95UNIzL6VHkR3kA6vvbbEhd+usXU+bHz3lBMglO4sK9aYDD2cC3JFg5EqEWx+qLnZOdUqI91EfNEa/JPNI/1NBQvvmIiq1aX+REAAAAhQZokbE3/bNl7dIrqhPSS1vp+in1qrkEFDY8GPIlGdtz/AAAAC0GeQniO/74qP/vhAAAACwGeYXRCX8UkUs/AAAAACgGeY2pCX8d3AXsAAAAhQZpoSahBaJlMCO9yPi+Qu9QA/FFYS9SdxasMFGKztiNhAAAAC0GehkURLHe8fK+fAAAACAGepXRCX6WBAAAACQGep2pCX8c34AAAABlBmqlJqEFsmUwIS/986GDzl8xp/5VMB1VgAAADsm1vb3YAAABsbXZoZAAAAAAAAAAAAAAAAAAAA+gAAAPoAAEAAAEAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAAALcdHJhawAAAFx0a2hkAAAAAwAAAAAAAAAAAAAAAQAAAAAAAAPoAAAAAAAAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAQAAAAABAAAAAQAAAAAAAJGVkdHMAAAAcZWxzdAAAAAAAAAABAAAD6AAACAAAAQAAAAACVG1kaWEAAAAgbWRoZAAAAAAAAAAAAAAAAAAAKAAAACgAVcQAAAAAAC1oZGxyAAAAAAAAAAB2aWRlAAAAAAAAAAAAAAAAVmlkZW9IYW5kbGVyAAAAAf9taW5mAAAAFHZtaGQAAAABAAAAAAAAAAAAAAAkZGluZgAAABxkcmVmAAAAAAAAAAEAAAAMdXJsIAAAAAEAAAG/c3RibAAAAL9zdHNkAAAAAAAAAAEAAACvYXZjMQAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAABAAEAASAAAAEgAAAAAAAAAARVMYXZjNjIuMjguMTAxIGxpYngyNjQAAAAAAAAAAAAAABj//wAAADVhdmNDAWQACv/hABhnZAAKrNlEJsBEAAADAAQAAAMAUDxIllgBAAZo6+Dksiz9+PgAAAAAEHBhc3AAAAABAAAAAQAAABRidHJ0AAAAAAAAJhAAAAAAAAAAGHN0dHMAAAAAAAAAAQAAAAoAAAQAAAAAFHN0c3MAAAAAAAAAAQAAAAEAAABgY3R0cwAAAAAAAAAKAAAAAQAACAAAAAABAAAUAAAAAAEAAAgAAAAAAQAAAAAAAAABAAAEAAAAAAEAABQAAAAAAQAACAAAAAABAAAAAAAAAAEAAAQAAAAAAQAACAAAAAAcc3RzYwAAAAAAAAABAAAAAQAAAAoAAAABAAAAPHN0c3oAAAAAAAAAAAAAAAoAAAQHAAAAJQAAAA8AAAAPAAAADgAAACUAAAAPAAAADAAAAA0AAAAdAAAAFHN0Y28AAAAAAAAAAQAAADAAAABidWR0YQAAAFptZXRhAAAAAAAAACFoZGxyAAAAAAAAAABtZGlyYXBwbAAAAAAAAAAAAAAAAC1pbHN0AAAAJal0b28AAAAdZGF0YQAAAAEAAAAATGF2ZjYyLjEyLjEwMQ==';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  final file = File('${Directory.systemTemp.path}/probe-media-kit.mp4');
  await file.writeAsBytes(base64Decode(_tinyMp4Base64));
  stdout.writeln(
    'probe_media_kit: wrote ${await file.length()} bytes to ${file.path}',
  );

  final player = Player();
  // A hard deadline, because the interesting failure is a HANG: libmpv that loaded but cannot
  // decode tends to sit silent rather than throw, and a probe that waits forever reports nothing.
  // 硬性时限,因为有意思的失败是**挂起**:载入了却解不了码的 libmpv 往往沉默而非抛错,而一个永远等下去
  // 的探针什么也报不出来。
  final deadline = Timer(const Duration(seconds: 20), () {
    stderr.writeln('probe_media_kit: FAIL — no duration within 20s');
    exit(1);
  });

  player.stream.error.listen((e) => stderr.writeln('  mpv error: $e'));

  // Subscribe BEFORE open(): duration is emitted during load, so a listener attached afterwards can
  // miss it and then wait forever for an event that already happened.
  // 在 open() **之前**订阅:duration 在加载中发出,事后才挂的监听会错过它,然后为一个已经发生过的事件
  // 永远等下去。
  final gotDuration = player.stream.duration.firstWhere(
    (d) => d > Duration.zero,
  );
  try {
    await player.open(Media(file.path), play: false);
    final duration = player.state.duration > Duration.zero
        ? player.state.duration
        : await gotDuration;
    deadline.cancel();
    stdout.writeln(
      'probe_media_kit: OK (file) — libmpv decoded it, duration ${duration.inMilliseconds}ms',
    );
    await player.dispose();
  } catch (e) {
    deadline.cancel();
    stderr.writeln('probe_media_kit: FAIL (file) — $e');
    exit(1);
  }

  // ── The assumption the whole design rests on ───────────────────────────────
  //
  // The video card does NOT hand libmpv a path — a sandboxed macOS app cannot — it hands it a
  // loopback URL plus the sidecar's auth headers. The sidecar is loopback-hardened
  // (RequireBearerToken), so if libmpv does not actually SEND those headers, video passes every
  // test and fails only against the real backend. This serves the same clip over HTTP behind a
  // REQUIRED Authorization header, and refuses anything without it.
  //
  // ── 整个设计所依赖的那个假设 ──
  //
  // 视频卡**不**给 libmpv 路径(沙箱化的 macOS app 给不了),它给的是一个 loopback URL 加 sidecar 的
  // 鉴权头。而 sidecar 做了 loopback 加固(RequireBearerToken)——故若 libmpv **并不真的送**这些头,
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
      req.response.headers.contentType = ContentType('video', 'mp4');
      req.response.add(bytes);
      await req.response.close();
    }
  }());

  final httpPlayer = Player();
  final httpDeadline = Timer(const Duration(seconds: 20), () {
    stderr.writeln(
      'probe_media_kit: FAIL (http) — no duration within 20s'
      '${sawHeader ? '' : ' AND the Authorization header never arrived'}',
    );
    exit(1);
  });
  httpPlayer.stream.error.listen((e) => stderr.writeln('  mpv error: $e'));
  final httpDuration = httpPlayer.stream.duration.firstWhere(
    (d) => d > Duration.zero,
  );
  try {
    await httpPlayer.open(
      Media(
        'http://127.0.0.1:${server.port}/clip.mp4',
        httpHeaders: const {'Authorization': 'Bearer $token'},
      ),
      play: false,
    );
    final d = httpPlayer.state.duration > Duration.zero
        ? httpPlayer.state.duration
        : await httpDuration;
    httpDeadline.cancel();
    if (!sawHeader) {
      // Decoding without the header would mean the server let it through — the guard would be
      // vacuous and would keep being vacuous forever.
      // 没送头也解出来了,意味着服务端放行了——那这条守卫是空的,而且会一直空下去。
      stderr.writeln(
        'probe_media_kit: FAIL (http) — decoded WITHOUT the header; guard is vacuous',
      );
      exit(1);
    }
    stdout.writeln(
      'probe_media_kit: OK (http+headers) — libmpv sent Authorization and decoded, '
      'duration ${d.inMilliseconds}ms',
    );
    await httpPlayer.dispose();
    await server.close(force: true);
    exit(0);
  } catch (e) {
    httpDeadline.cancel();
    stderr.writeln('probe_media_kit: FAIL (http) — $e');
    exit(1);
  }
}
