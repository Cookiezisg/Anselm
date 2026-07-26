import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_editor/super_editor.dart';

import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../media/attachment_image_provider.dart';
import '../media/media_source.dart';
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
      key: componentContext.componentKey,
      attachmentId: attachmentId,
      colors: colors,
    );
  }
}

/// The rendered attachment. It implements [DocumentComponent] via [ImageComponent]'s own contract
/// by delegating to a plain image widget wrapped in a [BoxComponent] — the editor needs the
/// component to report its own bounds for selection, and BoxComponent is the package's answer for
/// any non-text block.
///
/// 渲出来的附件。它经 [BoxComponent] 满足编辑器对「非文本块」的组件契约——编辑器需要组件自报边界以
/// 支持选区,而 BoxComponent 正是本包对任何非文本块给出的答案。
class _AnMediaImageComponent extends StatelessWidget {
  const _AnMediaImageComponent({
    required this.attachmentId,
    required this.colors,
    super.key,
  });

  final String attachmentId;
  final AnColors colors;

  // A Consumer rather than a WidgetRef parameter: the editor's component builders are plain
  // objects with no Riverpod scope of their own, and threading a ref down from the host would
  // force AnEditor itself to become a ConsumerWidget — subscribing the WHOLE editor to a provider
  // that concerns one image. The Consumer keeps the subscription on the image.
  //
  // 用 Consumer 而非 WidgetRef 参数:编辑器的组件 builder 是没有自己 Riverpod 作用域的普通对象,从宿主
  // 把 ref 穿下来会逼 AnEditor 自己变成 ConsumerWidget——把**整个编辑器**订阅到一个只关乎一张图的
  // provider 上。Consumer 让订阅留在这张图身上。
  @override
  Widget build(BuildContext context) => Consumer(builder: _build);

  Widget _build(BuildContext context, WidgetRef wref, Widget? _) {
    final meta = wref.watch(mediaMetaProvider(attachmentId));
    // hasError, not the AsyncError class pattern (Riverpod auto-retries — same reasoning as the
    // chat cards). A row we cannot read is said out loud; a document never shows a broken box.
    // 用 hasError 而非类模式(Riverpod 自动重试,与聊天卡同理)。读不到的行明说;文档里绝不出现破框。
    if (meta.hasError) {
      return BoxComponent(
        key: key,
        child: Text(
          attachmentId,
          style: AnText.label.copyWith(color: colors.inkFaint),
        ),
      );
    }
    return BoxComponent(
      key: key,
      child: switch (meta) {
        AsyncData() => ClipRRect(
          borderRadius: BorderRadius.circular(AnRadius.button),
          child: Image(
            image: AttachmentImageProvider(
              attachmentId,
              fetch: () => wref.read(mediaSourceProvider).bytes(attachmentId),
              targetWidth:
                  (AnSize.content * MediaQuery.devicePixelRatioOf(context))
                      .round(),
            ),
            fit: BoxFit.contain,
            errorBuilder: (context, _, _) => Text(
              attachmentId,
              style: AnText.label.copyWith(color: colors.inkMuted),
            ),
          ),
        ),
        // Hold the line's height while the row resolves so the reading position never jumps.
        // 行在解析时先占住高度,阅读位置绝不跳。
        _ => SizedBox(
          height: AnSize.control,
          child: ColoredBox(color: colors.surfaceSubtle),
        ),
      },
    );
  }
}
