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
  })  : _read = read ?? _storageRead,
        _write = write ?? _storageWrite,
        _hasExistingDatabase = hasExistingDatabase ?? _defaultHasDatabase,
        _random = random ?? Random.secure();

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

  static Future<String?> _storageRead(String key) => _storage.read(key: key);
  static Future<void> _storageWrite(String key, String value) =>
      _storage.write(key: key, value: value);

  /// The backend's default data root is `$HOME/.anselm` (sandboxed: HOME is the container Data dir,
  /// so this check follows the same redirection the sidecar sees). 后端默认数据根;沙盒下 HOME 同被
  /// 重定向,此检查与 sidecar 看到的是同一处。
  static bool _defaultHasDatabase() {
    final home = Platform.environment['HOME'] ?? '';
    if (home.isEmpty) return false;
    return File('$home/.anselm/anselm.db').existsSync();
  }

  /// Resolve the key to inject, or null for the legacy fingerprint path. 解析注入钥;null=旧径。
  Future<String?> resolve() async {
    try {
      final existing = await _read(storageKey);
      if (existing != null && existing.isNotEmpty) return existing;
      if (_hasExistingDatabase()) return null; // pre-keychain install 旧装机
      final minted = _mint();
      await _write(storageKey, minted);
      // Read-back guards against SILENT write failures (e.g. a missing keychain-access-groups
      // entitlement reports success but stores nothing) — a key we can't re-read next launch must
      // not seed ciphertexts. 读回防静默写失败——下次启动读不回的钥绝不能拿去封密文。
      final back = await _read(storageKey);
      return back == minted ? minted : null;
    } catch (e) {
      debugPrint('[master-key] keychain unavailable — legacy fingerprint path: $e');
      return null;
    }
  }

  String _mint() {
    final bytes = Uint8List.fromList(List.generate(32, (_) => _random.nextInt(256)));
    return base64UrlEncode(bytes);
  }
}
