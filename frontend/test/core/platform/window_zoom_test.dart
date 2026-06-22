import 'package:anselm/core/platform/window_zoom.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Step + cap logic for the in-app zoom. `nextUp/nextDown` are pure (no scaling side effects);
/// `maxFactor` (screen-aware) and the binding relayout only run in the real app, so here we test
/// the stepping + the cap behavior directly. 应内缩放的步进 + 上限逻辑(纯函数,无副作用)。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    WindowZoom.factor.value = WindowZoom.defaultFactor;
  });

  test('default is 100% and the stops include it', () {
    expect(WindowZoom.factor.value, 1.0);
    expect(WindowZoom.steps, contains(1.0));
  });

  test('nextUp climbs the stops but NEVER past the cap (zoom-in is controlled)', () {
    WindowZoom.factor.value = 1.0;
    expect(WindowZoom.nextUp(99), 1.1); // plenty of room → step up
    expect(WindowZoom.nextUp(1.05), 1.0); // cap below next stop → stays (won't break the layout)
    WindowZoom.factor.value = WindowZoom.steps.last;
    expect(WindowZoom.nextUp(99), WindowZoom.steps.last); // at the top stop → stays
  });

  test('nextDown steps down and clamps at the minimum stop', () {
    WindowZoom.factor.value = 1.0;
    expect(WindowZoom.nextDown(), 0.9);
    WindowZoom.factor.value = WindowZoom.steps.first;
    expect(WindowZoom.nextDown(), WindowZoom.steps.first); // at the bottom → stays
  });

  test('reset returns to 100%', () {
    WindowZoom.factor.value = 1.25;
    WindowZoom.reset();
    expect(WindowZoom.factor.value, 1.0);
  });
}
