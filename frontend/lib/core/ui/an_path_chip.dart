import 'package:flutter/widgets.dart';

import 'an_chip.dart';

/// A PATH CHIP (WRK-056 #16) — since WRK-066 批5 a THIN PRESET over the chip family head: a long
/// file path shown as its BASENAME (the part you read), the FULL path at rest on hover, tap copies
/// the full path (✓/✗ flash, copy never truncates — all inherited from [AnChip]). Tolerant of a
/// partial/streaming path (shows whatever has arrived). The basename cut is this preset's only own
/// knowledge; [leadingIcon] is retired — the chip's permanent copy-affordance glyph owns the slot.
/// 路径芯片——批5 起为芯片族薄预设:显 basename、hover 全路径、点击复制全路径(✓/✗ 闪与 copy 语义全
/// 继承当家件);容忍流中半截路径;basename 切法是预设唯一自有知识;leadingIcon 退役(常驻复制示能
/// 字形占据字形槽)。
class AnPathChip extends StatelessWidget {
  const AnPathChip({required this.path, super.key});

  /// The full path (possibly still streaming). 全路径(可能流中)。
  final String path;

  @override
  Widget build(BuildContext context) => AnChip(
        _basename(path),
        look: AnChipLook.outlined,
        mono: true,
        copyValue: path,
        tooltip: path,
      );
}

/// The basename — the segment after the last `/` (or the whole thing if none). 末段(basename)。
String _basename(String p) {
  final trimmed = p.endsWith('/') ? p.substring(0, p.length - 1) : p;
  final slash = trimmed.lastIndexOf('/');
  final base = slash < 0 ? trimmed : trimmed.substring(slash + 1);
  return base.isEmpty ? p : base;
}
