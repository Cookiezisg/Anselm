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

typedef UpdateStatus = ({UpdateOutcome outcome, String latest, String url});

/// The release feed of this product. 本产品的发行源。
const kReleasesApi =
    'https://api.github.com/repos/sunweilin/anselm/releases/latest';
const kReleasesPage = 'https://github.com/sunweilin/anselm/releases';

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
      if (tag.isEmpty) {
        return (outcome: UpdateOutcome.unknown, latest: '', url: kReleasesPage);
      }
      final local = (await PackageInfo.fromPlatform()).version;
      return (
        outcome: isNewerVersion(tag, local)
            ? UpdateOutcome.available
            : UpdateOutcome.upToDate,
        latest: tag,
        url: url,
      );
    } catch (_) {
      return (outcome: UpdateOutcome.unknown, latest: '', url: kReleasesPage);
    }
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
