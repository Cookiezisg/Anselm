import 'package:anselm/core/design/tokens.dart';
import 'package:flutter_test/flutter_test.dart';

// The macOS window's OUTER corner is CONCENTRIC with the shell's left island: the island (corner [chip]=12)
// is inset from the window edge by [shellPad]=8, so the concentric outer corner = chip + shellPad = 20. The
// native MainFlutterWindow.swift swizzles NSThemeFrame's radius getters to this value; its
// `kANWindowCornerRadius` DEFAULT must equal it (Dart pushes the live token over `app/window_chrome`, but the
// default paints the pre-channel hidden first frame). If this guard fails after retuning chip/shellPad, update
// that native default too. 窗外圆角与左岛同心(chip 12 内缩 shellPad 8 → 外角 20);原生 kANWindowCornerRadius 默认须等于此值。
void main() {
  test('AnRadius.window is concentric with the island (chip + shellPad) and equals the native default 20', () {
    expect(AnRadius.window, AnRadius.chip + AnSize.shellPad);
    expect(
      AnRadius.window,
      20.0,
      reason: 'window corner changed — update MainFlutterWindow.swift kANWindowCornerRadius default to match',
    );
  });
}
