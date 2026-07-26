import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// WRK-083 L18 — the client must not call endpoints the backend does not serve.
//
// Real machine: 「保存并测试」 on a new key CREATED it (201) and PROBED it successfully (`:test` → 200),
// and then showed the user a red 「this method is not allowed for this path」 — because the repository
// followed the probe with `GET /api-keys/{id}` to re-read the row, and that endpoint **does not exist**
// (the contract has list / PATCH / DELETE / `:test`, no single GET). A wholly successful operation ended
// in an error message, and an untranslated backend one at that.
//
// The general shape — the client inventing a REST endpoint by analogy with its siblings — is invisible to
// every other line of defence: it compiles, its own tests pass against a fixture that implements whatever
// the client imagined, and the backend answers 405/404 only at runtime. So the guard reads the ACTUAL
// route table out of the Go source and holds the Dart call sites against it.
//
// Scope is deliberately narrow: only paths that are string LITERALS with at most a `$var` id segment, and
// only the `/api/v1/…` prefix. Dynamically assembled paths are out of reach and stay the reviewer's job —
// a guard that pretends to cover them would be worse than one that says what it covers.
//
// WRK-083 L18——客户端不该调用后端根本不提供的端点。
//
// 真机:新密钥上按「保存并测试」,**建成了**(201)、**探测也成功了**(`:test` → 200),然后给用户一行红字
// 「this method is not allowed for this path」——因为仓在探测之后又用 `GET /api-keys/{id}` 重读那一行,而这个端点
// **根本不存在**(契约只有 list / PATCH / DELETE / `:test`)。一次**完全成功**的操作以错误收场,而且是一句未翻译的
// 后端英文。
//
// 这个形状——客户端**照着兄弟端点类推**、发明一个 REST 端点——对其余每一道防线都是隐形的:它编译得过,它自己的测试
// 对着一个「客户端想象什么就实现什么」的 fixture 也全绿,只有后端在运行时才用 405/404 回答。故本守卫**从 Go 源码里
// 读出真实路由表**,再拿 Dart 调用点去对。
//
// 覆盖面**刻意收窄**:只认字符串**字面量**路径(至多带一个 `$var` id 段)、只认 `/api/v1/…` 前缀。动态拼接的路径够不着,
// 那部分仍归人复审——一条假装覆盖了它们的守卫,比一条说清自己覆盖到哪里的守卫更糟。

/// `GET /api/v1/api-keys/{id}` → ('GET', ['api','v1','api-keys','{}']).
({String method, List<String> parts})? _route(String method, String path) {
  final p = path.split('?').first;
  if (!p.startsWith('/api/v1/')) return null;
  final parts = <String>[];
  for (final seg in p.split('/').where((s) => s.isNotEmpty)) {
    // A `{id}` route segment, a `$var` Dart interpolation, or a `:action` suffix on either.
    // `{id}` 路由段 / `$var` Dart 插值 / 二者上的 `:action` 后缀。
    final action = seg.contains(':') ? ':${seg.split(':').last}' : '';
    final head = seg.split(':').first;
    final isVar =
        head.startsWith('{') || head.startsWith(r'$') || head.startsWith(r'${');
    parts.add((isVar ? '{}' : head) + action);
  }
  return (method: method, parts: parts);
}

String _key(({String method, List<String> parts}) r) =>
    '${r.method} /${r.parts.join('/')}';

void main() {
  test(
    'every literal API path the client calls is a route the backend serves (L18)',
    () {
      // ── the backend's real route table 后端真实路由表 ──
      final served = <String>{};
      for (final f in Directory(
        '../backend/internal/transport/httpapi',
      ).listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.go')) continue;
        for (final m in RegExp(
          r'''HandleFunc\(\s*"(GET|POST|PATCH|PUT|DELETE) ([^"]+)"''',
        ).allMatches(f.readAsStringSync())) {
          final r = _route(m.group(1)!, m.group(2)!);
          if (r != null) served.add(_key(r));
        }
      }
      expect(
        served.length,
        greaterThan(80),
        reason:
            'sanity: the route table was actually parsed (a broken scrape must fail LOUD, not vacuously pass)',
      );

      // ── every literal path the Dart client calls 客户端调用的每条字面量路径 ──
      final offenders = <String>[];
      final callRe = RegExp(
        r"\b(get|post|patch|put|delete)(?:Data|Entity|Page|Bare|Raw)?\(\s*'(/api/v1/[^']*)'",
      );
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final src = f.readAsStringSync();
        for (final m in callRe.allMatches(src)) {
          final raw = m.group(2)!;
          // A `${expr}` segment is NOT an id — it is a computed piece of the route itself, e.g. memories'
          // `${pinned ? 'pin' : 'unpin'}`, whose two values are BOTH real routes. Treating it as an id turns
          // one honest call into a false report, and a guard that cries wolf gets muted. Out of reach = say
          // so and skip, which is exactly the scope this file declares up top.
          // `${expr}` 段**不是** id,而是路由自身被算出来的一截(如 memories 的 `${pinned ? 'pin' : 'unpin'}`,两个取值
          // **都是**真路由)。把它当 id 会把一次诚实调用报成犯例,而一条乱喊的守卫会被人静音。够不着就**说出来并跳过**,
          // 这正是本文件开头声明的覆盖面。
          // Two shapes: `${pinned ? 'pin' : 'unpin'}` (a whole segment) and `conversations:$action` (the
          // ACTION). 两种形状:整段被算出来,以及**动作名**被算出来。
          if (raw.contains(r'${') || RegExp(r':\$').hasMatch(raw)) continue;
          final r = _route(m.group(1)!.toUpperCase(), raw);
          if (r == null) continue;
          // A `:action` POST is served by a catch-all `POST /…/{idAction}` handler in several domains, so
          // accept either the exact route or that shape. `:action` 型 POST 在多个域由 `{idAction}` 兜底路由承接。
          final exact = _key(r);
          final catchAll = _key((
            method: r.method,
            parts: [
              ...r.parts.sublist(0, r.parts.length - 1),
              r.parts.last.contains(':') ? '{}' : r.parts.last,
            ],
          ));
          if (served.contains(exact) || served.contains(catchAll)) continue;
          final line = src.substring(0, m.start).split('\n').length;
          offenders.add('${f.path}:$line  $exact');
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'these calls hit paths the backend does not route — they can only ever answer 404/405, and the '
            'user sees a raw backend error at the end of an operation that otherwise succeeded (WRK-083 L18):\n  '
            '${offenders.join("\n  ")}',
      );
    },
  );
}
