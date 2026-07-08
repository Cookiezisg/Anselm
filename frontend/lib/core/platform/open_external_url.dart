import 'package:url_launcher/url_launcher.dart' as launcher;

/// Open a URL in the OS browser/mail client — the ONE outbound gate (WRK-056 palette #8): a
/// strict scheme whitelist (http/https/mailto, byte-for-byte the AnMarkdown link gate's set) so a
/// crafted `file:`/`javascript:` in tool output can never be launched. Returns false — never
/// throws — on a refused scheme or a launcher failure (callers surface nothing: a dead link is a
/// no-op, not a crash).
///
/// 在系统浏览器/邮件客户端打开 URL——唯一外链闸(WRK-056 缺口 #8):严格 scheme 白名单
/// (http/https/mailto,与 AnMarkdown 链接闸逐字同集),工具输出里构造的 `file:`/`javascript:`
/// 永远点不着。拒绝或失败返 false、绝不抛(死链=no-op,不是崩溃)。
Future<bool> openExternalUrl(String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return false;
  const allowed = {'http', 'https', 'mailto'};
  if (!allowed.contains(uri.scheme.toLowerCase())) return false;
  try {
    return await launcher.launchUrl(uri, mode: launcher.LaunchMode.externalApplication);
  } catch (_) {
    return false;
  }
}
