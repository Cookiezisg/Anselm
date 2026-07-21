import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/core/graph/node_ref.dart';
import 'package:flutter_test/flutter_test.dart';

// WRK-055 stage-2 — the pure NodeRef parse/format model behind the hierarchical ref picker.

void main() {
  group('NodeRef.parse — action families', () {
    test('function: fn_<id> → function family, no member', () {
      final r = NodeRef.parse(NodeKind.action, 'fn_abc123');
      expect(r.family, RefFamily.function);
      expect(r.target, 'fn_abc123');
      expect(r.member, isNull);
      expect(r.isResolved, isTrue);
      expect(r.hasMember, isFalse);
    });

    test('handler with method: hd_<id>.<method> → handler family + member', () {
      final r = NodeRef.parse(NodeKind.action, 'hd_db.query');
      expect(r.family, RefFamily.handler);
      expect(r.target, 'hd_db');
      expect(r.member, 'query');
      expect(r.hasMember, isTrue);
    });

    test('handler without a method yet: hd_<id> → target, member null', () {
      final r = NodeRef.parse(NodeKind.action, 'hd_db');
      expect(r.family, RefFamily.handler);
      expect(r.target, 'hd_db');
      expect(r.member, isNull);
    });

    test('mcp: mcp:server/tool → mcp family, server target, tool member', () {
      final r = NodeRef.parse(NodeKind.action, 'mcp:github/create_issue');
      expect(r.family, RefFamily.mcp);
      expect(r.target, 'github');
      expect(r.member, 'create_issue');
    });

    test('mcp without a tool yet: mcp:server → server target, member null', () {
      final r = NodeRef.parse(NodeKind.action, 'mcp:github');
      expect(r.family, RefFamily.mcp);
      expect(r.target, 'github');
      expect(r.member, isNull);
    });
  });

  group('NodeRef.parse — single-family kinds', () {
    test('agent / trigger / control / approval map 1:1 by kind', () {
      expect(NodeRef.parse(NodeKind.agent, 'ag_x').family, RefFamily.agent);
      expect(NodeRef.parse(NodeKind.agent, 'ag_x').target, 'ag_x');
      expect(
        NodeRef.parse(NodeKind.trigger, 'trg_x').family,
        RefFamily.trigger,
      );
      expect(
        NodeRef.parse(NodeKind.control, 'ctl_x').family,
        RefFamily.control,
      );
      expect(
        NodeRef.parse(NodeKind.approval, 'apf_x').family,
        RefFamily.approval,
      );
    });
  });

  group('NodeRef.parse — placeholders & malformed (five-battery)', () {
    test('fresh <prefix>_new placeholder → unselected (target null)', () {
      expect(NodeRef.parse(NodeKind.action, 'fn_new').isResolved, isFalse);
      expect(NodeRef.parse(NodeKind.agent, 'ag_new').target, isNull);
      expect(NodeRef.parse(NodeKind.control, 'ctl_new').target, isNull);
      expect(NodeRef.parse(NodeKind.approval, 'apf_new').target, isNull);
      expect(NodeRef.parse(NodeKind.trigger, 'trg_new').target, isNull);
    });

    test('empty / whitespace → unselected', () {
      expect(NodeRef.parse(NodeKind.action, '').isResolved, isFalse);
      expect(NodeRef.parse(NodeKind.action, '   ').isResolved, isFalse);
      expect(NodeRef.parse(NodeKind.agent, '').target, isNull);
    });

    test('malformed mcp / handler (missing member half) does not throw', () {
      expect(
        NodeRef.parse(NodeKind.action, 'mcp:').target,
        isNull,
      ); // no server
      expect(
        NodeRef.parse(NodeKind.action, 'mcp:s/').member,
        isNull,
      ); // trailing slash, no tool
      expect(
        NodeRef.parse(NodeKind.action, 'hd_x.').member,
        isNull,
      ); // trailing dot, no method
    });

    test('unknown kind keeps the raw ref as target', () {
      expect(
        NodeRef.parse(NodeKind.unknown, 'weird:thing').target,
        'weird:thing',
      );
    });
  });

  group('NodeRef.format — round-trips', () {
    for (final (kind, ref) in const [
      (NodeKind.action, 'fn_abc'),
      (NodeKind.action, 'hd_db.query'),
      (NodeKind.action, 'mcp:github/create_issue'),
      (NodeKind.agent, 'ag_x'),
      (NodeKind.trigger, 'trg_cron'),
      (NodeKind.control, 'ctl_gate'),
      (NodeKind.approval, 'apf_ok'),
    ]) {
      test('round-trip $ref', () {
        expect(NodeRef.parse(kind, ref).format(), ref);
      });
    }

    // Regression (stage-2 review, HIGH): a target-less ref must carry its family through format→parse,
    // else switching the picker to handler/mcp collapses to '' and reverts to function.
    test(
      'a target-less ref formats to a family-carrying placeholder that round-trips the family',
      () {
        expect(const NodeRef(family: RefFamily.function).format(), 'fn_new');
        expect(const NodeRef(family: RefFamily.handler).format(), 'hd_new');
        expect(const NodeRef(family: RefFamily.mcp).format(), 'mcp:');
        for (final f in const [
          RefFamily.function,
          RefFamily.handler,
          RefFamily.mcp,
        ]) {
          final rt = NodeRef.parse(
            NodeKind.action,
            NodeRef(family: f).format(),
          );
          expect(
            rt.family,
            f,
            reason: 'action family $f must survive the empty-target wire form',
          );
          expect(rt.target, isNull);
        }
      },
    );

    test(
      'handler/mcp target-only (no member) formats without the separator',
      () {
        expect(
          const NodeRef(family: RefFamily.handler, target: 'hd_db').format(),
          'hd_db',
        );
        expect(
          const NodeRef(family: RefFamily.mcp, target: 'github').format(),
          'mcp:github',
        );
      },
    );

    test('copyWith replaces the member (nullable clear)', () {
      const r = NodeRef(
        family: RefFamily.handler,
        target: 'hd_db',
        member: 'query',
      );
      expect(r.copyWith(member: 'insert').format(), 'hd_db.insert');
      expect(r.copyWith(member: null).format(), 'hd_db');
    });
  });

  group('NodeRef.familiesFor', () {
    test('action offers function/handler/mcp; others exactly one', () {
      expect(NodeRef.familiesFor(NodeKind.action), [
        RefFamily.function,
        RefFamily.handler,
        RefFamily.mcp,
      ]);
      expect(NodeRef.familiesFor(NodeKind.agent), [RefFamily.agent]);
      expect(NodeRef.familiesFor(NodeKind.approval), [RefFamily.approval]);
    });
  });
}
