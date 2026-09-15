import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Resolves the sidecar's at-rest master key (ADR 0006, WRK-062 拍板 #14): FRESH installs mint a
/// random 256-bit seed into the OS keychain and inject it as `ANSELM_MASTER_KEY`; EXISTING installs
/// (a database already on disk, no keychain entry) return null so the backend keeps its legacy
/// machine-fingerprint seed — injecting a fresh key there would orphan every stored ciphertext
/// (api-key / MCP secrets would need re-entry). Any keychain failure also degrades to null: startup
/// must never brick on keychain quirks (unsigned dev builds, missing libsecret on Linux, …).
///
/// sidecar 落盘加密主密钥解析(ADR 0006,拍板 #14):全新安装铸 256-bit 随机种子入 OS keychain 并经
/// `ANSELM_MASTER_KEY` 注入;既有安装(盘上已有库、keychain 无条目)返回 null 走后端机器指纹旧径——
/// 硬注新钥=既有密文全成孤儿。keychain 任何故障同样退化 null:启动绝不因 keychain 怪癖变砖。
class MasterKey {
  MasterKey({
    Future<String?> Function(String key)? read,
    Future<void> Function(String key, String value)? write,
    bool Function()? hasExistingDatabase,
    Random? random,
    Duration keychainTimeout = const Duration(seconds: 3),
    int keychainReadAttempts = 3,
  }) : _read = read ?? _storageRead,
       _write = write ?? _storageWrite,
       _hasExistingDatabase = hasExistingDatabase ?? _defaultHasDatabase,
       _random = random ?? Random.secure(),
       _keychainTimeout = keychainTimeout,
       _keychainReadAttempts = keychainReadAttempts;

  // macOS: the legacy login keychain (NOT the data-protection keychain) — the latter requires a
  // development-certificate signature + keychain-access-groups entitlement, which local ad-hoc
  // builds don't have. Revisit when WRK-043 lands Developer ID signing (see ADR 0008).
  // macOS 用 login keychain:data-protection keychain 需真证书签名+entitlement,本地 ad-hoc 构建
  // 没有;WRK-043 落 Developer ID 签名后再切(ADR 0008)。
  static const _storage = FlutterSecureStorage(
    mOptions: MacOsOptions(usesDataProtectionKeychain: false),
  );
  static const storageKey = 'anselm.master-key';

  final Future<String?> Function(String key) _read;
  final Future<void> Function(String key, String value) _write;
  final bool Function() _hasExistingDatabase;
  final Random _random;
  final Duration _keychainTimeout;
  final int _keychainReadAttempts;

  static Future<String?> _storageRead(String key) => _storage.read(key: key);
  static Future<void> _storageWrite(String key, String value) =>
      _storage.write(key: key, value: value);

  /// The backend's default data root is `$HOME/.anselm` (sandboxed: HOME is the container Data dir,
  /// so this check follows the same redirection the sidecar sees). When a launch explicitly supplies
  /// `ANSELM_DATA_DIR`, that configured root is authoritative instead of HOME.
  /// 后端默认数据根;沙盒下 HOME 同被重定向,此检查与 sidecar 看到的是同一处。启动显式提供
  /// `ANSELM_DATA_DIR` 时,以该配置根为准,不能误查 HOME。
  static bool _defaultHasDatabase() {
    final configured = Platform.environment['ANSELM_DATA_DIR'];
    if (configured != null && configured.isNotEmpty) {
      return hasDatabaseAt(configured);
    }
    final home = Platform.environment['HOME'] ?? '';
    return home.isNotEmpty && hasDatabaseAt('$home/.anselm');
  }

  /// Shared for the environment resolver and its filesystem seam test. 供环境解析与文件系统缝测试共用。
  static bool hasDatabaseAt(String dataDir) =>
      File('$dataDir/anselm.db').existsSync();

  /// Resolve the key to inject, or null for the legacy fingerprint path. 解析注入钥;null=旧径。
  Future<String?> resolve() async {
    try {
      // A native keychain prompt or daemon can leave its future pending indefinitely. Startup must
      // not become hostage to that UI: time out each operation and keep the documented legacy path.
      // 原生钥匙串弹窗或 daemon 可能让 future 永久 pending。启动不能被它绑架:每步有界,超时走旧径。
      final existing = await _readWithRetry();
      if (existing != null && existing.isNotEmpty) return existing;
      if (_hasExistingDatabase()) return null; // pre-keychain install 旧装机
      final minted = _mint();
      await _write(storageKey, minted).timeout(_keychainTimeout);
      // Read-back guards against SILENT write failures (e.g. a missing keychain-access-groups
      // entitlement reports success but stores nothing) — a key we can't re-read next launch must
      // not seed ciphertexts. 读回防静默写失败——下次启动读不回的钥绝不能拿去封密文。
      final back = await _read(storageKey).timeout(_keychainTimeout);
      return back == minted ? minted : null;
    } catch (e) {
      debugPrint(
        '[master-key] keychain unavailable — legacy fingerprint path: $e',
      );
      return null;
    }
  }

  /// One slow read must not silently switch an existing install from its keychain key to the
  /// fingerprint: every ciphertext on disk (device proof, stored provider keys) is sealed under
  /// whichever key the sidecar last saw, and the switch is invisible until decryption fails. When a
  /// database already exists a timed-out read is retried a bounded number of times, which covers a
  /// keychain that is merely slow (just unlocked, a daemon restarting, a prompt the user is answering).
  /// A fresh install has nothing to protect and takes the first answer.
  /// 一次慢读不能把已装机从钥匙串钥无声切到指纹:盘上所有密文(device proof、存的 provider key)都封在
  /// sidecar 上次看到的那把钥下,切换要到解密失败才暴露。已有数据库时对超时的读做有界重试,覆盖钥匙串
  /// 只是慢(刚解锁、daemon 重启、用户正在答弹窗)的情况;全新安装无物可护,取第一次结果。
  Future<String?> _readWithRetry() async {
    for (var attempt = 1; ; attempt++) {
      try {
        return await _read(storageKey).timeout(_keychainTimeout);
      } on TimeoutException {
        final attempts = _hasExistingDatabase() ? _keychainReadAttempts : 1;
        if (attempt >= attempts) rethrow;
        debugPrint(
          '[master-key] keychain read timed out (attempt $attempt/$attempts), retrying',
        );
      }
    }
  }

  String _mint() {
    final bytes = Uint8List.fromList(
      List.generate(32, (_) => _random.nextInt(256)),
    );
    return base64UrlEncode(bytes);
  }
}
