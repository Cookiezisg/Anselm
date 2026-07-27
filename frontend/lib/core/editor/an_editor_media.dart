import 'package:flutter/widgets.dart';
import 'package:super_editor/super_editor.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../media/media_cards.dart';
import '../media/media_ref.dart';
import '../media/media_uri.dart';

/// The document editor's media component (WRK-082 批F). super_editor's own image component fetches
/// with `Image.network`, which cannot resolve `anselm://media/<id>` — so a document that stored a
/// generated chart would render a broken box. This builder recognizes that scheme and resolves it
/// through the SAME attachment pipeline every other surface uses (不变量②/④); an image URL it does
/// not own is left to the default component, because a document may legitimately contain ordinary
/// web images and those must keep rendering as themselves.
///
/// 文档编辑器的媒体组件(批F)。super_editor 自带的图像组件用 `Image.network` 取图,解析不了
/// `anselm://media/<id>`——于是一份存了生成图表的文档会渲出一个破框。本 builder 认这个 scheme,并经
/// **与其余每个面同一条**附件管线解析它(不变量②/④);**不属于**它的图像 URL 交回默认组件,因为文档
/// 里完全可以有普通网图,那些必须继续以自己的样子渲染。
///
/// **一个 markdown 形,三种媒体**。markdown 只有一个「这里有个媒体」的槽——`![alt](url)`——所以音频与
/// 视频也走它,由 [AnMediaRefCard] 按**附件行的 mime** 分发成图/音/文件卡。发明一种 markdown 之外的
/// 语法会让文档不再是 markdown(别处打不开、codec 三保真也保不住);而按 **url 猜**类型会在一个改了
/// 扩展名的文件上撒谎。行说了算,这与聊天、节点检查器、approval 门用的是同一条规矩。
class AnMediaImageComponentBuilder extends ImageComponentBuilder {
  const AnMediaImageComponentBuilder(this.colors);

  final AnColors colors;

  @override
  Widget? createComponent(
    SingleColumnDocumentComponentContext componentContext,
    SingleColumnLayoutComponentViewModel componentViewModel,
  ) {
    if (componentViewModel is! ImageComponentViewModel) return null;
    final attachmentId = attachmentIdFromMediaUri(componentViewModel.imageUrl);
    if (attachmentId == null) {
      return null; // not ours — the default builder answers / 不是我们的,交回默认组件
    }
    return _AnMediaImageComponent(
      componentKey: componentContext.componentKey,
      attachmentId: attachmentId,
      colors: colors,
    );
  }
}

/// The rendered attachment — delegated to the ONE card family (`AnMediaRefCard`), which dispatches
/// on the attachment row's mime. The editor therefore shows an image as an image, a voice note as
/// an audio card and a clip as a file card, without knowing any of that itself.
///
/// 渲出来的附件——交给**一族卡**(`AnMediaRefCard`),它按附件行的 mime 分发。编辑器因此把图渲成图、
/// 把语音渲成音频卡、把片子渲成文件卡,而它自己对这些一无所知。
class _AnMediaImageComponent extends StatelessWidget {
  const _AnMediaImageComponent({
    required this.attachmentId,
    required this.colors,
    required this.componentKey,
  });

  final String attachmentId;
  final AnColors colors;

  /// super_editor's per-component GlobalKey, carried as a FIELD and mounted on exactly one widget:
  /// the BoxComponent below, which is what the layout addresses.
  ///
  /// It used to be this wrapper's own `key` AND be passed down to BoxComponent — the same GlobalKey
  /// on two widgets at once, which Flutter rejects. Nothing caught it because no test had ever
  /// inserted a media node into a LIVE editor; the codec tests round-trip markdown and never build
  /// a component (WRK-082 H6 found it by adding `/media`).
  ///
  /// super_editor 的逐组件 GlobalKey,作为**字段**携带、并且只挂在**一个** widget 上:下面那个
  /// BoxComponent——布局寻址的正是它。
  ///
  /// 它过去**既是**本包装件自己的 `key`、**又**被传给 BoxComponent——同一个 GlobalKey 同时挂在两个
  /// widget 上,Flutter 直接拒绝。没有任何东西抓到它,因为从来没有测试往**活**编辑器里插过媒体节点;
  /// codec 测试往返 markdown、从不构建组件(H6 加 `/media` 时撞出来的)。
  final GlobalKey componentKey;

  @override
  Widget build(BuildContext context) => BoxComponent(
    key: componentKey,
    child: AnMediaRefCard(
      mediaRef: AnMediaRef(attachmentId: attachmentId),
      maxWidth: AnSize.content,
    ),
  );
}
