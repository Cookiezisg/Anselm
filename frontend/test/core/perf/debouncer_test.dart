import 'package:anselm/core/perf/debouncer.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only the last call within the quiet window fires', () {
    fakeAsync((async) {
      final d = Debouncer(const Duration(milliseconds: 250));
      var fired = 0;
      String? last;
      d.run(() {
        fired++;
        last = 'a';
      });
      async.elapse(const Duration(milliseconds: 100));
      d.run(() {
        fired++;
        last = 'b';
      }); // supersedes 'a'
      async.elapse(const Duration(milliseconds: 249));
      expect(fired, 0); // not yet
      async.elapse(const Duration(milliseconds: 1));
      expect(fired, 1); // only once
      expect(last, 'b'); // the latest
      d.dispose();
    });
  });

  test('dispose cancels a pending call', () {
    fakeAsync((async) {
      final d = Debouncer(const Duration(milliseconds: 250));
      var fired = 0;
      d.run(() => fired++);
      d.dispose();
      async.elapse(const Duration(milliseconds: 300));
      expect(fired, 0);
    });
  });
}
