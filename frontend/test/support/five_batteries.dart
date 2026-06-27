import 'package:anselm/core/contract/entities/function.dart';
import 'package:anselm/features/entities/data/entity_fixtures.dart';

/// The FIVE BATTERIES (Phase 4.1 STEP 6 hardening) — the edge-case data matrix every entities surface is
/// driven through so a regression in overflow / volume / encoding / injection-inertness is caught:
///   - empty     空    : zero rows (the list/detail empty states).
///   - overflow  超长  : a 200-char no-space token (must ellipsis, NEVER throw a RenderFlex overflow).
///   - huge      海量  : thousands of rows (first page renders; no choke).
///   - extreme   极值  : CJK + emoji (incl. ZWJ family + flag) + RTL + zero-width chars.
///   - injection 注入  : `<script>`, template braces, `${...}`, backticks — Flutter `Text` renders these
///                       verbatim (no XSS / no interpolation); tests assert the literal appears.
///
/// 五电池(4.1 STEP 6 加固)——每个 entities 面被驱过的边界数据矩阵,逮溢出/海量/编码/注入解释的回归。
enum Battery { empty, overflow, huge, extreme, injection }

final _t = DateTime.utc(2026, 6, 27);

FunctionEntity _fn(String id, String name, {String description = ''}) =>
    FunctionEntity(id: id, name: name, description: description, createdAt: _t, updatedAt: _t);

/// A 200-char single token with NO spaces — the worst case for a row that must ellipsis, not overflow.
/// 200 字符无空格单 token——必须 ellipsis、不得溢出的最坏情形。
const overflowName =
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
    'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';

/// CJK + emoji (ZWJ family + flag) + RTL (Arabic) + zero-width (ZWSP/ZWJ). 极值串。
const extremeName = '函数·🤖·نظام·a​b‍c·🇨🇳·👨‍👩‍👧‍👦';

/// Injection-like strings — must render inert (verbatim). 注入串(须惰性渲染)。
const injectionScript = '<script>alert(1)</script>';
const injectionTemplate = '{{7*7}}';
const injectionDollar = r'${jndi:ldap://x}';

/// The function rows for a battery (other kinds stay empty). 各电池的函数行。
List<FunctionEntity> batteryFunctions(Battery b) => switch (b) {
      Battery.empty => const [],
      Battery.overflow => [_fn('fn_long', overflowName, description: overflowName)],
      Battery.huge => [for (var i = 0; i < 5000; i++) _fn('fn_$i', 'function-$i')],
      Battery.extreme => [_fn('fn_x', extremeName, description: extremeName)],
      Battery.injection => [
          _fn('fn_s', injectionScript, description: injectionScript),
          _fn('fn_t', injectionTemplate),
          _fn('fn_d', injectionDollar),
        ],
    };

/// A fixture repo seeded with [b]'s function rows. 用电池函数种 fixture。
FixtureEntityRepository batteryRepo(Battery b) =>
    FixtureEntityRepository(functions: batteryFunctions(b));
