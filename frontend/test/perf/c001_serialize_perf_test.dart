import 'package:anselm/core/editor/an_editor_markdown.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:super_editor/super_editor.dart';

/// P5 · C-001 — measure the REAL wall-clock cost of `markdownFromDocument`, which `AnEditorState.
/// _onDocumentChanged` (an_editor.dart:230) runs on EVERY keystroke. The number decides the ledger:
/// a large per-keystroke serialize cost ⇒ implement the lazy-serialize fix (serialize only when the
/// 250/600ms debouncers fire); negligible ⇒ refute (the microtask-coalesce alone is cosmetic).
///
/// CAVEAT — `flutter test` runs debug-JIT, ~2–5× slower than the release-AOT the user ships. So the
/// numbers below are a PESSIMISTIC upper bound: a small debug number is a safe refute; a large one, once
/// divided by ~3, is the release estimate. Stopwatch uses the real wall clock (not the fake test clock).
/// C-001:测整篇序列化真实耗时(每键跑)。注:debug JIT ~2–5× 慢于 release,数字是上界(除 3 估 release)。
void main() {
  String buildDoc(int paragraphs) {
    final sb = StringBuffer();
    for (var i = 0; i < paragraphs; i++) {
      if (i % 20 == 0) sb.writeln('## Section $i — a heading that anchors the outline\n');
      sb.writeln('Paragraph $i carries a realistic amount of prose — several sentences of real content '
          'so the block is worth serializing, with the occasional number like ${i * 37} and a '
          '[[ent_${i}0000000000000] mention-ish token, continuing long enough to matter.\n');
      if (i % 10 == 0) {
        for (var j = 0; j < 5; j++) {
          sb.writeln('- list item $i.$j — a bullet with a sentence of text to serialize');
        }
        sb.writeln();
      }
    }
    return sb.toString();
  }

  ({double medianMs, double p90Ms, int chars}) measure(MutableDocument doc) {
    for (var i = 0; i < 5; i++) {
      markdownFromDocument(doc); // warm up JIT 预热
    }
    final us = <int>[];
    for (var i = 0; i < 40; i++) {
      final sw = Stopwatch()..start();
      markdownFromDocument(doc);
      us.add(sw.elapsedMicroseconds);
    }
    us.sort();
    return (
      medianMs: us[us.length ~/ 2] / 1000.0,
      p90Ms: us[(us.length * 9) ~/ 10] / 1000.0,
      chars: markdownFromDocument(doc).length,
    );
  }

  for (final paragraphs in const [100, 400, 1000]) {
    test('C-001: markdownFromDocument cost — $paragraphs-paragraph doc', () {
      final doc = documentFromMarkdown(buildDoc(paragraphs));
      final r = measure(doc);
      debugPrint('P5-C001  nodes=${doc.nodeCount}  chars=${r.chars}  '
          'serialize median=${r.medianMs.toStringAsFixed(2)}ms  p90=${r.p90Ms.toStringAsFixed(2)}ms  '
          '(release≈${(r.medianMs / 3).toStringAsFixed(2)}ms)');
      expect(r.medianMs, greaterThan(0)); // measurement, not a threshold gate 测量,非阈值门
    });
  }
}
