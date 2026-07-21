import 'dart:math';

import 'package:anselm/core/process/master_key.dart';
import 'package:flutter_test/flutter_test.dart';

// ADR 0008 branch matrix: existing entry wins / fresh install mints+verifies / legacy install
// (db on disk, no entry) NEVER mints / silent write failure or thrown keychain both degrade to
// null. ADR 0008 分支矩阵:有条目直用/全新铸钥读回/旧装机绝不铸/静默写失败与抛错都退化 null。

void main() {
  test('existing keychain entry wins — no mint, no db check', () async {
    var wrote = false;
    final mk = MasterKey(
      read: (_) async => 'seed-already-there',
      write: (_, _) async => wrote = true,
      hasExistingDatabase: () => throw StateError('must not be consulted'),
    );
    expect(await mk.resolve(), 'seed-already-there');
    expect(wrote, isFalse);
  });

  test(
    'fresh install mints a 256-bit key, stores it, read-back verifies',
    () async {
      final store = <String, String>{};
      final mk = MasterKey(
        read: (k) async => store[k],
        write: (k, v) async => store[k] = v,
        hasExistingDatabase: () => false,
        random: Random(42),
      );
      final key = await mk.resolve();
      expect(key, isNotNull);
      expect(store[MasterKey.storageKey], key);
      expect(
        key!.length,
        greaterThanOrEqualTo(43),
        reason: 'base64url(32B) ≥ 43 chars',
      );
      // Second resolve returns the SAME key (stable across relaunches). 二次解析同钥。
      expect(await mk.resolve(), key);
    },
  );

  test(
    'legacy install (db exists, no entry) keeps the fingerprint path — never mints',
    () async {
      var wrote = false;
      final mk = MasterKey(
        read: (_) async => null,
        write: (_, _) async => wrote = true,
        hasExistingDatabase: () => true,
      );
      expect(await mk.resolve(), isNull);
      expect(wrote, isFalse, reason: '旧装机注新钥=密文全孤儿,绝不铸');
    },
  );

  test('SILENT write failure (read-back mismatch) degrades to null', () async {
    final mk = MasterKey(
      read: (_) async => null, // write "succeeds" but nothing sticks 写“成功”但没落
      write: (_, _) async {},
      hasExistingDatabase: () => false,
    );
    expect(
      await mk.resolve(),
      isNull,
      reason: '读不回的钥绝不能拿去封密文(缺 entitlement 的静默失效)',
    );
  });

  test('a throwing keychain degrades to null — startup never bricks', () async {
    final mk = MasterKey(
      read: (_) async => throw StateError('no keyring daemon'),
      write: (_, _) async {},
      hasExistingDatabase: () => false,
    );
    expect(await mk.resolve(), isNull);
  });
}
