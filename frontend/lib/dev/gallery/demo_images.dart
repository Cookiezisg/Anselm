import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

/// Dev-only stand-in "photos" for attachment specimens/captures: rasterize a gradient + a few shapes to
/// PNG bytes → [MemoryImage]. No assets, no network (specimens must never fetch). Engine-async (toImage),
/// so in the widget-test matrix the future stays pending and specimens render their resolving state — by
/// design; the live gallery and capture (runAsync) show the real picture.
///
/// dev 专用假「照片」:光栅化渐变+图形成 PNG 字节 → MemoryImage。零资产零网络(specimen 绝不取网)。引擎异步
/// (toImage)——matrix 测试里 future 不落地、specimen 渲 resolving 态(有意);真 gallery 与 capture(runAsync)显真图。
Future<MemoryImage> demoImage({
  int width = 560,
  int height = 420,
  int seed = 0,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final w = width.toDouble(), h = height.toDouble();
  final palettes = [
    [const Color(0xFF8EC5FC), const Color(0xFFE0C3FC)],
    [const Color(0xFFFAD0C4), const Color(0xFFFFD1FF)],
    [const Color(0xFFA1C4FD), const Color(0xFFC2E9FB)],
    [const Color(0xFFD4FC79), const Color(0xFF96E6A1)],
  ];
  final colors = palettes[seed % palettes.length];
  canvas.drawRect(
    Rect.fromLTWH(0, 0, w, h),
    Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(w, h), colors),
  );
  // A "horizon" band + a sun-ish disc so it reads as a photo, not a flat swatch. 一道地平线+一轮圆,像照片。
  canvas.drawCircle(
    Offset(w * 0.72, h * 0.3),
    h * 0.16,
    Paint()..color = const Color(0x66FFFFFF),
  );
  canvas.drawRect(
    Rect.fromLTWH(0, h * 0.72, w, h * 0.28),
    Paint()..color = const Color(0x22000000),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return MemoryImage(bytes!.buffer.asUint8List());
}

/// A specimen-side async holder: renders [builder] with the demo image once rasterized, else with null
/// (the thumb's resolving state). dev 异步壳:光栅化完成前 builder 收 null(瓦片渲 resolving 态)。
class DemoImageBuilder extends StatefulWidget {
  const DemoImageBuilder({
    required this.builder,
    this.seed = 0,
    this.width = 560,
    this.height = 420,
    super.key,
  });

  final Widget Function(BuildContext context, ImageProvider? image) builder;
  final int seed;
  final int width;
  final int height;

  @override
  State<DemoImageBuilder> createState() => _DemoImageBuilderState();
}

class _DemoImageBuilderState extends State<DemoImageBuilder> {
  ImageProvider? _image;

  @override
  void initState() {
    super.initState();
    demoImage(
      seed: widget.seed,
      width: widget.width,
      height: widget.height,
    ).then((img) {
      if (mounted) setState(() => _image = img);
    });
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _image);
}
