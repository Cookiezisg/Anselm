import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show AppExitResponse;

import 'package:anselm/core/process/backend_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

// STEP 4 gate — the sidecar supervisor. A fake Process + fake launcher + fake health probe
// let us assert spawn env (incl. the minted token), dev-attach, health-gate failure, the
// SIGTERM→timeout→SIGKILL graceful shutdown, and the bounded crash-restart circuit breaker —
// all with no real binary and no real waits.

class _FakeProcess implements Process {
  _FakeProcess({this.exitOnSigterm = true});
  final bool exitOnSigterm;
  final _exit = Completer<int>();
  final killed = <ProcessSignal>[];

  @override
  int get pid => 4242;
  @override
  Future<int> get exitCode => _exit.future;
  @override
  Stream<List<int>> get stderr => Stream<List<int>>.empty();
  @override
  Stream<List<int>> get stdout => Stream<List<int>>.empty();
  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed.add(signal);
    if (signal == ProcessSignal.sigkill ||
        (signal == ProcessSignal.sigterm && exitOnSigterm)) {
      crash(signal == ProcessSignal.sigkill ? -9 : 0);
    }
    return true;
  }

  void crash(int code) {
    if (!_exit.isCompleted) _exit.complete(code);
  }
}

class _FixedAdapter implements HttpClientAdapter {
  _FixedAdapter(this.respond);
  final ResponseBody Function(RequestOptions) respond;
  @override
  Future<ResponseBody> fetch(
    RequestOptions o,
    Stream<Uint8List>? rs,
    Future<void>? cf,
  ) async => respond(o);
  @override
  void close({bool force = false}) {}
}

Dio _probe({required bool ok}) {
  final d = Dio();
  d.httpClientAdapter = _FixedAdapter((o) {
    if (!ok) throw Exception('connection refused');
    return ResponseBody.fromString(
      '{"data":{"status":"ok"}}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  });
  return d;
}

Future<void> _until(
  bool Function() cond, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!cond()) {
    if (DateTime.now().isAfter(deadline)) {
      throw TimeoutException('condition not met');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  test(
    'dev-attach (ANSELM_BACKEND_URL): health-gates, no spawn, no token',
    () async {
      final launched = <Map<String, String>?>[];
      final c = BackendController(
        externalUrl: () => 'http://127.0.0.1:12345',
        probe: _probe(ok: true),
        launcher: (exe, args, {environment}) async {
          launched.add(environment);
          return _FakeProcess();
        },
      );
      await c.start();
      expect(c.state.value.isReady, isTrue);
      expect(c.state.value.baseUrl, 'http://127.0.0.1:12345');
      expect(
        c.state.value.authToken,
        isNull,
      ); // dev backend has no per-launch token
      expect(launched, isEmpty); // nothing spawned
    },
  );

  test(
    'spawn: passes ANSELM_ADDR + minted ANSELM_AUTH_TOKEN, reaches ready',
    () async {
      final launched = <Map<String, String>?>[];
      final c = BackendController(
        binaryPath: Platform
            .resolvedExecutable, // a path that exists; launcher is faked
        externalUrl: () => null,
        probe: _probe(ok: true),
        launcher: (exe, args, {environment}) async {
          launched.add(environment);
          return _FakeProcess();
        },
      );
      await c.start();
      expect(c.state.value.isReady, isTrue);
      expect(c.state.value.baseUrl, startsWith('http://127.0.0.1:'));
      expect(c.state.value.authToken, isNotNull);
      expect(
        c.state.value.authToken!.length,
        greaterThan(20),
      ); // 32 bytes base64url
      expect(launched.single!['ANSELM_ADDR'], startsWith('127.0.0.1:'));
      expect(launched.single!['ANSELM_AUTH_TOKEN'], c.state.value.authToken);
      // WRK-070 T2: the deadman switch must be ARMED on every spawn — without this env the backend
      // never watches stdin, and a crashed/killed GUI orphans it under launchd.
      // 死人开关必须每次 spawn 都上膛,否则 GUI 崩溃/被杀 = sidecar 孤儿。
      expect(launched.single!['ANSELM_PARENT_WATCH'], '1');
    },
  );

  test(
    'WRK-070 T2: stopBackendOnExit SIGTERMs the sidecar, AWAITS its exit, then allows app exit',
    () async {
      final proc = _FakeProcess();
      final c = BackendController(
        binaryPath: Platform.resolvedExecutable,
        externalUrl: () => null,
        probe: _probe(ok: true),
        launcher: (exe, args, {environment}) async => proc,
      );
      await c.start();
      expect(proc.killed, isEmpty);

      final response = await stopBackendOnExit(c);

      expect(
        proc.killed,
        [ProcessSignal.sigterm],
        reason: '优雅链的第一步必须是 SIGTERM(有序关停 + kill-set 收 llama),不是 SIGKILL',
      );
      expect(
        response,
        AppExitResponse.exit,
        reason: '绝不 cancel:stop() 自带 SIGTERM→宽限→SIGKILL 升级,退出必须永远可靠',
      );
    },
  );

  // C-030: start() is idempotent — a concurrent/repeat call JOINS the in-flight launch rather than
  // spawning a second process. This is what lets the app kick the spawn off EARLY (main, before window
  // init) while the startup gate ALSO start()s on first read: both share one launch.
  test(
    'C-030: concurrent + repeat start() join the in-flight launch — no double-spawn',
    () async {
      final launched = <Map<String, String>?>[];
      final c = BackendController(
        binaryPath: Platform.resolvedExecutable,
        externalUrl: () => null,
        probe: _probe(ok: true),
        launcher: (exe, args, {environment}) async {
          launched.add(environment);
          return _FakeProcess();
        },
      );
      // Fire twice concurrently (main's early kick-off + the gate's first read). 并发两次(main 提前 + gate 首读)。
      await Future.wait([c.start(), c.start()]);
      expect(c.state.value.isReady, isTrue);
      expect(
        launched.length,
        1,
        reason: 'concurrent start() must JOIN, not double-spawn',
      );
      await c
          .start(); // a repeat call after ready also joins the (completed) launch 就绪后再 start 也并入
      expect(launched.length, 1);
    },
  );

  test(
    'C-030: start() RE-ENTERS after a crash — Retry still respawns (guard does not block it)',
    () async {
      final launched = <Map<String, String>?>[];
      var healthOk =
          false; // first launch: health never comes up → crash 首启健康失败→崩溃
      final probe = Dio()
        ..httpClientAdapter = _FixedAdapter((o) {
          if (!healthOk) throw Exception('connection refused');
          return ResponseBody.fromString(
            '{"data":{"status":"ok"}}',
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        });
      final c = BackendController(
        binaryPath: Platform.resolvedExecutable,
        externalUrl: () => null,
        probe: probe,
        probeInterval: const Duration(milliseconds: 1),
        launcher: (exe, args, {environment}) async {
          launched.add(environment);
          return _FakeProcess();
        },
      );
      await c.start();
      expect(c.state.value.phase, BackendPhase.crashed);
      final afterCrash = launched.length;

      // The backend now "comes up" — Retry (start again) must RE-ENTER _start, not join the crashed launch.
      // 后端「起来了」——重试须重入 _start(不并入已崩溃启动)。
      healthOk = true;
      await c.start();
      expect(c.state.value.isReady, isTrue);
      expect(
        launched.length,
        greaterThan(afterCrash),
        reason:
            'a crashed controller must re-spawn on Retry, not return the failed in-flight future',
      );
    },
  );

  test('health never comes up → crashed (bounded attempts, no hang)', () async {
    final c = BackendController(
      binaryPath: Platform.resolvedExecutable,
      externalUrl: () => null,
      probe: _probe(ok: false),
      launcher: (exe, args, {environment}) async => _FakeProcess(),
      maxHealthAttempts: 3,
      probeInterval: const Duration(milliseconds: 1),
    );
    await c.start();
    expect(c.state.value.phase, BackendPhase.crashed);
    expect(c.state.value.error, contains('did not become healthy'));
  });

  test(
    'graceful shutdown: SIGTERM, then SIGKILL when the child overstays the grace',
    () async {
      late _FakeProcess proc;
      final c = BackendController(
        binaryPath: Platform.resolvedExecutable,
        externalUrl: () => null,
        probe: _probe(ok: true),
        launcher: (exe, args, {environment}) async {
          proc = _FakeProcess(
            exitOnSigterm: false,
          ); // ignores SIGTERM → forces the SIGKILL path
          return proc;
        },
        shutdownGrace: const Duration(milliseconds: 50),
      );
      await c.start();
      await c.stop();
      expect(proc.killed, [ProcessSignal.sigterm, ProcessSignal.sigkill]);
    },
  );

  test(
    'graceful shutdown: SIGTERM only when the child exits within the grace',
    () async {
      late _FakeProcess proc;
      final c = BackendController(
        binaryPath: Platform.resolvedExecutable,
        externalUrl: () => null,
        probe: _probe(ok: true),
        launcher: (exe, args, {environment}) async {
          proc = _FakeProcess(); // exits on SIGTERM
          return proc;
        },
        shutdownGrace: const Duration(seconds: 2),
      );
      await c.start();
      await c.stop();
      expect(proc.killed, [
        ProcessSignal.sigterm,
      ]); // exited gracefully, no SIGKILL needed
    },
  );

  test(
    'bounded crash-restart: respawns, then trips the circuit breaker → crashed',
    () async {
      final procs = <_FakeProcess>[];
      final c = BackendController(
        binaryPath: Platform.resolvedExecutable,
        externalUrl: () => null,
        probe: _probe(ok: true),
        launcher: (exe, args, {environment}) async {
          final p = _FakeProcess();
          procs.add(p);
          return p;
        },
        maxRestarts: 2,
        restartBackoffBase: const Duration(milliseconds: 1),
        probeInterval: const Duration(milliseconds: 1),
      );
      await c.start();
      expect(procs.length, 1);

      procs[0].crash(1); // unexpected exit → restart #1
      await _until(() => procs.length == 2);
      await _until(() => c.state.value.isReady);

      procs[1].crash(1); // restart #2
      await _until(() => procs.length == 3);
      await _until(() => c.state.value.isReady);

      procs[2].crash(1); // would be restart #3 > maxRestarts(2) → give up
      await _until(() => c.state.value.phase == BackendPhase.crashed);
      expect(procs.length, 3); // no 4th spawn
      expect(c.state.value.error, contains('giving up'));
    },
  );
}
