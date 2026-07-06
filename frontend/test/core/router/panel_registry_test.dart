import 'package:anselm/core/router/panel_registry.dart';
import 'package:flutter_test/flutter_test.dart';

// The panel-nav registry (WRK-056 #8) — pins the FULL navigable set so a route change in
// app/router.dart that isn't mirrored here fails the gate (single source of truth for tappability).
// 面板注册表:钉全可导航集,路由改动未同步即挂门禁。

void main() {
  group('panelLocationFor — the navigable set (mirrors app/router.dart)', () {
    test('seven entities-rail kinds → /entities/<kind>/<id>', () {
      for (final k in ['function', 'handler', 'agent', 'workflow', 'control', 'approval', 'trigger']) {
        expect(panelLocationFor(k, 'x_1'), '/entities/$k/x_1', reason: k);
        expect(hasPanelFor(k), isTrue, reason: k);
      }
    });

    test('conversation → /chat/<id>', () {
      expect(panelLocationFor('conversation', 'cv_1'), '/chat/cv_1');
      expect(hasPanelFor('conversation'), isTrue);
    });

    test('document (+ doc alias) → /documents/<id>', () {
      expect(panelLocationFor('document', 'doc_1'), '/documents/doc_1');
      expect(panelLocationFor('doc', 'doc_1'), '/documents/doc_1'); // demo alias
    });

    test('skill → /documents/skill/<name> (the id IS the slug)', () {
      expect(panelLocationFor('skill', 'invoice-triage'), '/documents/skill/invoice-triage');
      expect(hasPanelFor('skill'), isTrue);
    });

    test('case-insensitive on the wire kind', () {
      expect(panelLocationFor('Function', 'x'), '/entities/function/x');
      expect(panelLocationFor('CONVERSATION', 'x'), '/chat/x');
    });
  });

  group('no-panel kinds are inert (never a dead link)', () {
    test('mcp / memory / relation / block / message / node / firing / unknown → null', () {
      for (final k in ['mcp', 'memory', 'relation', 'block', 'message', 'node', 'firing', 'quantum', '']) {
        expect(panelLocationFor(k, 'x'), isNull, reason: k);
        expect(hasPanelFor(k), isFalse, reason: k);
      }
    });
  });
}
