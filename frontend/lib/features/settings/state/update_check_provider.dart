import 'dart:io';

import 'package:anselm_updater/anselm_updater.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The v1 update check (WRK-062 拍板 #7): query the GitHub Releases API for the latest tag, compare
/// against the RUNNING app version, and REPORT — never download, never install (auto_updater rides
/// WRK-043). Uses its own bare Dio: this is the one outbound internet call in the app and it must
/// not carry the loopback bearer/workspace headers. Every failure (offline, private repo, no
/// releases yet) collapses to [UpdateOutcome.unknown] — an honest "couldn't check", never a fake
/// "up to date".
///
/// v1 更新检查(拍板 #7):查 GitHub Releases 最新 tag、与运行中版本比对、只**报告**——不下载不安装
/// (全自动归 WRK-043)。用独立裸 Dio:app 唯一出网调用,绝不能带 loopback bearer/workspace 头。一切
/// 失败(离线/私库/尚无 release)收敛为 unknown——诚实「查不了」,绝不假「已最新」。
enum UpdateOutcome { upToDate, available, unknown }

/// The native in-app updater (Sparkle on macOS). Where it is supported it OWNS checking and
/// installing — the GitHub Releases check below stays the path for the other platforms.
/// 原生应用内更新器(macOS 走 Sparkle)。支持的平台上由它负责检查与安装;下面的 GitHub Releases 检查
/// 留给其它平台。
final nativeUpdaterProvider = Provider<AnselmUpdater>(
  (_) => const AnselmUpdater(),
);

/// [installerUrl] and [sumsUrl] are set only on Windows when the latest release carries a setup
/// executable and a checksum file — the inputs of [UpdateCheckController.installUpdate].
/// 仅 Windows 且最新 release 带安装器与校验文件时才有 installerUrl/sumsUrl,供 installUpdate 使用。
typedef UpdateStatus = ({
  UpdateOutcome outcome,
  String latest,
  String url,
  String? installerUrl,
  String? sumsUrl,
});

/// The release feed of this product. 本产品的发行源。
const kReleasesApi =
    'https://api.github.com/repos/Cookiezisg/Anselm/releases/latest';
const kReleasesPage = 'https://github.com/Cookiezisg/Anselm/releases';

class UpdateCheckController extends AsyncNotifier<UpdateStatus?> {
  @override
  Future<UpdateStatus?> build() async => null; // manual / startup-triggered only 只手动或启动触发

  Future<UpdateStatus> check() async {
    state = const AsyncLoading<UpdateStatus?>();
    final result = await _fetch();
    state = AsyncData(result);
    return result;
  }

  Future<UpdateStatus> _fetch() async {
    try {
      final dio = ref.read(updateCheckDioProvider);
      final r = await dio.get<Map<String, dynamic>>(
        kReleasesApi,
        options: Options(headers: {'Accept': 'application/vnd.github+json'}),
      );
      final tag = (r.data?['tag_name'] as String?) ?? '';
      final url = (r.data?['html_url'] as String?) ?? kReleasesPage;
      if (tag.isEmpty) return _unknown;
      final local = (await PackageInfo.fromPlatform()).version;
      final assets = (r.data?['assets'] as List?) ?? const [];
      String? assetUrl(bool Function(String name) pick) {
        for (final a in assets) {
          if (a is Map && pick(a['name'] as String? ?? '')) {
            return a['browser_download_url'] as String?;
          }
        }
        return null;
      }

      return (
        outcome: isNewerVersion(tag, local)
            ? UpdateOutcome.available
            : UpdateOutcome.upToDate,
        latest: tag,
        url: url,
        installerUrl: Platform.isWindows
            ? assetUrl((n) => n.endsWith('-windows-x64-setup.exe'))
            : null,
        sumsUrl: assetUrl((n) => n == 'SHA256SUMS.txt'),
      );
    } catch (_) {
      return _unknown;
    }
  }

  static const UpdateStatus _unknown = (
    outcome: UpdateOutcome.unknown,
    latest: '',
    url: kReleasesPage,
    installerUrl: null,
    sumsUrl: null,
  );

  /// Windows: download the setup executable, verify its SHA-256 against the release's checksum
  /// file, hand off to the installer silently (Inno Setup closes the running app itself), and
  /// exit. Throws on any mismatch or failure — the caller shows the fallback copy.
  /// Windows:下载安装器,对照 release 的校验文件核 SHA-256,静默交给安装器(Inno Setup 自己关掉
  /// 运行中的 app),然后退出。任何不符或失败都抛出——调用方显示兜底文案。
  Future<void> installUpdate(UpdateStatus s) async {
    final installer = s.installerUrl;
    final sums = s.sumsUrl;
    if (!Platform.isWindows || installer == null || sums == null) {
      throw StateError('no installer for this platform');
    }
    final dio = ref.read(updateCheckDioProvider);
    final dir = await Directory(
      '${Directory.systemTemp.path}${Platform.pathSeparator}anselm-update',
    ).create(recursive: true);
    final name = Uri.parse(installer).pathSegments.last;
    final file = File('${dir.path}${Platform.pathSeparator}$name');
    await dio.download(installer, file.path);
    final sumsText = (await dio.get<String>(sums)).data ?? '';
    final expected = sumsText
        .split('\n')
        .map((l) => l.trim().split(RegExp(r'\s+')))
        .where((p) => p.length == 2 && p[1].replaceFirst('*', '') == name)
        .map((p) => p[0].toLowerCase())
        .firstOrNull;
    if (expected == null) throw StateError('no checksum published for $name');
    final actual = sha256.convert(await file.readAsBytes()).toString();
    if (actual != expected) {
      await file.delete();
      throw StateError('checksum mismatch for $name');
    }
    await Process.start(file.path, const [
      '/SILENT',
      '/CLOSEAPPLICATIONS',
      '/RESTARTAPPLICATIONS',
    ], mode: ProcessStartMode.detached);
    exit(0);
  }
}

/// Pure semver-ish compare: is [remoteTag] (with or without a leading v) newer than [local]?
/// Non-numeric segments compare as 0 — unknown formats never claim "newer". 纯比较;怪格式绝不称新。
bool isNewerVersion(String remoteTag, String local) {
  List<int> parse(String v) => v
      .replaceFirst(RegExp(r'^v'), '')
      .split(RegExp(r'[.+-]'))
      .take(3)
      .map((s) => int.tryParse(s) ?? 0)
      .toList();
  final r = parse(remoteTag), l = parse(local);
  for (var i = 0; i < 3; i++) {
    final rv = i < r.length ? r[i] : 0, lv = i < l.length ? l[i] : 0;
    if (rv != lv) return rv > lv;
  }
  return false;
}

/// Seam for tests (mock adapter). 测试缝。
final updateCheckDioProvider = Provider<Dio>((ref) => Dio());

final updateCheckProvider =
    AsyncNotifierProvider<UpdateCheckController, UpdateStatus?>(
      UpdateCheckController.new,
    );
