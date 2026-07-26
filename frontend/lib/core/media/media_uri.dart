/// The `anselm://media/<attachmentId>` URI — how a MediaRef survives inside DOCUMENT TEXT
/// (WRK-082 批F 值形). Everywhere else in the system media travels as a JSON receipt carrying
/// `attachmentId`; a document is markdown, and markdown has exactly one slot for "a picture goes
/// here": `![alt](url)`. So the reference has to become a URL, and this is the grammar of that URL.
///
/// It is deliberately a CUSTOM SCHEME rather than an http URL to the local sidecar. A stored
/// `http://127.0.0.1:<port>/…` would bake a port number and a host into the user's document —
/// content that outlives the process that wrote it — and break the moment the sidecar picks a
/// different port. The scheme says "resolve this through the app", which is the only claim that
/// stays true.
///
/// `anselm://media/<attachmentId>` URI——MediaRef 在**文档正文**里的活法(批F 值形)。系统别处媒体以
/// 携 `attachmentId` 的 JSON receipt 流动;而文档是 markdown,markdown 里「这里有张图」只有一个槽:
/// `![alt](url)`。故引用必须变成一个 URL,而这就是那个 URL 的文法。
///
/// 刻意用**自定义 scheme** 而非指向本机 sidecar 的 http URL。存下 `http://127.0.0.1:<port>/…` 等于把
/// 一个端口号和主机名烤进**用户的文档**——一份比写它的进程活得更久的内容——而 sidecar 换个端口它就死。
/// scheme 说的是「经这个应用去解析它」,那是唯一一句一直为真的话。
library;

import 'media_ref.dart';

/// The scheme + host pair. `media` is a host, not a path segment, so the id is the whole path and
/// a future `anselm://document/<id>` can join without ambiguity.
///
/// scheme + host 对。`media` 是 **host** 而非路径段,故 id 就是整条路径;将来 `anselm://document/<id>`
/// 可以无歧义地并进来。
const String kMediaUriScheme = 'anselm';
const String kMediaUriHost = 'media';

/// Builds the document-text form of an attachment reference.
///
/// 构造附件引用的文档正文形。
String mediaUri(String attachmentId) =>
    '$kMediaUriScheme://$kMediaUriHost/$attachmentId';

/// Parses a document-text reference back to its attachment id, or null when [uri] is anything else
/// — an ordinary https image, a relative path, a typo. Null is the honest answer: a document may
/// legitimately contain images this app does not own, and those must keep rendering as themselves.
///
/// 把文档正文里的引用解析回附件 id;[uri] 是别的东西(普通 https 图、相对路径、拼错)则返 null。
/// null 是诚实答案:文档里完全可以有本应用并不拥有的图,那些必须继续以它们自己的样子渲染。
String? attachmentIdFromMediaUri(String? uri) {
  if (uri == null || uri.isEmpty) return null;
  final parsed = Uri.tryParse(uri);
  if (parsed == null) return null;
  if (parsed.scheme != kMediaUriScheme || parsed.host != kMediaUriHost) {
    return null;
  }
  final id = parsed.pathSegments.isEmpty ? '' : parsed.pathSegments.last;
  return isAttachmentId(id) ? id : null;
}
