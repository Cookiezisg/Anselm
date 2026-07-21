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

  // P5 (C-001 area) — flush() delivers the last pending action instead of dropping it, so an owner (e.g.
  // the doc autosave) can call it in dispose to avoid losing an edit made within the debounce window.
  test(
    'flush fires the pending action immediately (the LATEST one) and stops the timer',
    () {
      fakeAsync((async) {
        final d = Debouncer(const Duration(milliseconds: 600));
        var fired = 0;
        String? last;
        d.run(() {
          fired++;
          last = 'a';
        });
        d.run(() {
          fired++;
          last = 'b';
        }); // supersedes 'a'
        expect(fired, 0); // still pending
        d.flush();
        expect(fired, 1); // delivered now, not dropped
        expect(last, 'b'); // the latest edit
        async.elapse(const Duration(milliseconds: 700));
        expect(fired, 1); // timer was cancelled — no double fire
      });
    },
  );

  test(
    'flush with nothing pending is a no-op (and does not re-fire an already-fired action)',
    () {
      fakeAsync((async) {
        final d = Debouncer(const Duration(milliseconds: 250));
        var fired = 0;
        d.flush(); // nothing scheduled
        expect(fired, 0);
        d.run(() => fired++);
        async.elapse(const Duration(milliseconds: 300)); // fires normally
        expect(fired, 1);
        d.flush(); // pending was cleared when the timer fired
        expect(fired, 1);
      });
    },
  );
}
