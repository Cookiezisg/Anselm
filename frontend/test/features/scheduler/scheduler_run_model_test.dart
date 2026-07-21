import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/core/contract/entities/workflow.dart';
import 'package:anselm/core/graph/flowrun_timeline.dart';
import 'package:anselm/features/scheduler/ui/scheduler_run_model.dart';
import 'package:flutter_test/flutter_test.dart';

// S4 · the run flagship's PURE projections (WRK-069 §5) — the shared truths behind the three
// altitudes. These are the tests that make «一份文案三处投影» and «形状跟着数据可得性走» structural
// rather than aspirational: if the error sentence, the queue/exec split or the ledger fold could
// drift per surface, they would drift here first. S4 纯投影电池:三海拔共享真相的锁。

final _t = DateTime.utc(2026, 7, 16, 9, 12);

FlowrunNode _node(
  String nodeId,
  String status, {
  String kind = 'action',
  int iteration = 0,
  int readySec = 0,
  int? startSec,
  int? endSec,
  String? error,
  Map<String, Object?> result = const {},
}) => FlowrunNode(
  id: 'frn_${nodeId}_$iteration',
  flowrunId: 'fr_1',
  nodeId: nodeId,
  iteration: iteration,
  kind: kind,
  status: status,
  result: result,
  error: error,
  readyAt: startSec == null ? null : _t.add(Duration(seconds: readySec)),
  startedAt: startSec == null ? null : _t.add(Duration(seconds: startSec)),
  // createdAt is the row's WRITE time = the terminal / park moment (backend flowrun.go). 行写入时刻。
  createdAt: _t.add(Duration(seconds: endSec ?? startSec ?? readySec)),
  completedAt: endSec == null ? null : _t.add(Duration(seconds: endSec)),
  updatedAt: _t,
);

FlowrunActivityRow _act(
  String nodeId, {
  int iteration = 0,
  int elapsedMs = 5000,
  int startSec = 1,
}) => FlowrunActivityRow(
  nodeId: nodeId,
  iteration: iteration,
  kind: 'agent',
  execId: 'agx_$nodeId',
  status: 'ok',
  startedAt: _t.add(Duration(seconds: startSec)),
  endedAt: _t.add(Duration(seconds: startSec, milliseconds: elapsedMs)),
  elapsedMs: elapsedMs,
);

FlowrunComposite _comp(
  List<FlowrunNode> nodes, {
  String status = 'completed',
}) => FlowrunComposite(
  flowrun: Flowrun(
    id: 'fr_1',
    workflowId: 'wf_1',
    status: status,
    startedAt: _t,
    updatedAt: _t,
  ),
  nodes: nodes,
);

const _graph = Graph(
  nodes: [
    Node(id: 'fetch', kind: NodeKind.action, ref: 'fn_fetch'),
    Node(id: 'gate', kind: NodeKind.control, ref: 'ctl_gate'),
    Node(id: 'analyze', kind: NodeKind.agent, ref: 'ag_analyze'),
    Node(id: 'notify', kind: NodeKind.action, ref: 'fn_notify'),
  ],
  edges: [
    Edge(id: 'e1', from: 'fetch', to: 'gate'),
    Edge(id: 'e2', from: 'gate', fromPort: 'high', to: 'analyze'),
    Edge(id: 'e3', from: 'analyze', to: 'notify'),
  ],
);

void main() {
  group('errorSentence — the ONE red string (§5.1 同句同源)', () {
    test('takes the first non-empty line of a multi-line blob', () {
      expect(
        errorSentence('timeout: LLM 30s no answer\n  at analyze step\nstack…'),
        'timeout: LLM 30s no answer',
      );
    });

    test('skips leading blank lines rather than returning emptiness', () {
      expect(
        errorSentence('\n\n  real problem here  \nmore'),
        'real problem here',
      );
    });

    test('null in → null out; an all-blank blob is NOT an error sentence', () {
      // An empty string would render an empty red line — a lie about there being an error.
      // 空串会渲出「有错误」的空红行,是撒谎。
      expect(errorSentence(null), isNull);
      expect(errorSentence('   \n\n  '), isNull);
    });
  });

  group('nodeTiming — the queue/exec split (§5.3 判决⑤)', () {
    test(
      '⑫ stamps → the grey queue leg; ⑤ audit row → the exec leg is the AUDIT\'s own elapsed',
      () {
        final n = _node(
          'analyze',
          'completed',
          kind: 'agent',
          readySec: 0,
          startSec: 2,
          endSec: 9,
        );
        final t = nodeTiming(
          n,
          activity: _act('analyze', elapsedMs: 5000, startSec: 2),
        );
        expect(t.queue, const Duration(seconds: 2)); // readyAt→startedAt
        expect(
          t.exec,
          const Duration(milliseconds: 5000),
        ); // the audit row's self-report 审计自报
        expect(t.hasSplit, isTrue);
      },
    );

    test(
      'no audit row (control evaluates inline) → exec falls back to the row\'s own stamps',
      () {
        // This is control/approval's NORMAL path, not a degraded one — they never leave audit rows.
        // 这是 control/approval 的正常路径而非降级:它们从不留审计行。
        final n = _node(
          'gate',
          'completed',
          kind: 'control',
          readySec: 0,
          startSec: 1,
          endSec: 4,
        );
        final t = nodeTiming(n);
        expect(t.queue, const Duration(seconds: 1));
        expect(t.exec, const Duration(seconds: 3));
      },
    );

    test('a pre-⑫ row has NO split — null, never a fabricated zero', () {
      final n = _node('fetch', 'completed'); // startSec null → no stamps 旧行无戳
      final t = nodeTiming(n);
      expect(t.queue, isNull);
      expect(t.hasSplit, isFalse);
    });

    test(
      'an approval\'s exec ends at the PARK write; the wait is the amber parked leg',
      () {
        // createdAt = park time, completedAt = the decision. The human wait must never be counted as
        // execution. createdAt=停车时刻、completedAt=决断时刻;人等的时间绝不能算成执行。
        final n = FlowrunNode(
          id: 'frn_ap',
          flowrunId: 'fr_1',
          nodeId: 'approve',
          kind: 'approval',
          status:
              'completed', // decided — the status flipped off 'parked' 已决,状态已翻
          readyAt: _t,
          startedAt: _t.add(const Duration(seconds: 1)),
          createdAt: _t.add(const Duration(seconds: 2)), // parked here 停在这
          completedAt: _t.add(
            const Duration(minutes: 18),
          ), // a human answered 18m later 人 18 分钟后答
          updatedAt: _t,
        );
        final t = nodeTiming(n);
        expect(
          t.exec,
          const Duration(seconds: 1),
          reason: '执行段=渲染 prompt 到停车,不含人等',
        );
        // The wait starts at the PARK WRITE (+2s), not at the node's start — 18m − 2s. 人等自停车写入起算。
        expect(
          t.parked,
          const Duration(minutes: 17, seconds: 58),
          reason: '人等是琥珀段,自停车时刻起算',
        );
      },
    );

    test(
      'a negative span (replay\'s stale audit row / clock skew) clamps to zero, never renders < 0',
      () {
        final n = FlowrunNode(
          id: 'frn_x',
          flowrunId: 'fr_1',
          nodeId: 'x',
          status: 'completed',
          readyAt: _t.add(
            const Duration(seconds: 5),
          ), // AFTER startedAt — api.md ⑤ warns of this 反序
          startedAt: _t,
          createdAt: _t,
          completedAt: _t,
          updatedAt: _t,
        );
        expect(nodeTiming(n).queue, Duration.zero);
      },
    );
  });

  group('runTiming — the head IS the ledger\'s total (§5.3 双数同源)', () {
    test('sums its rows\' splits, so head and ledger can never disagree', () {
      final nodes = [
        _node('fetch', 'completed', readySec: 0, startSec: 1, endSec: 3),
        _node(
          'analyze',
          'completed',
          kind: 'agent',
          readySec: 3,
          startSec: 5,
          endSec: 10,
        ),
      ];
      final t = runTiming(nodes, const []);
      expect(t.queue, const Duration(seconds: 3)); // 1 + 2
      expect(t.exec, const Duration(seconds: 7)); // 2 + 5
    });

    test(
      'rows with no stamps contribute nothing rather than zeroing the total',
      () {
        final t = runTiming([_node('legacy', 'completed')], const []);
        expect(t.queue, isNull);
        expect(t.exec, isNull);
      },
    );
  });

  group('foldNodeLedger — ×N fold + diagnostic ordering (§5.4)', () {
    test(
      'a loop folds to ONE line carrying every turn, newest as its face',
      () {
        final nodes = [
          for (var i = 0; i < 3; i++)
            _node(
              'analyze',
              'completed',
              kind: 'agent',
              iteration: i,
              startSec: i,
              endSec: i + 1,
            ),
        ];
        final out = foldNodeLedger(_graph, nodes);
        expect(out, hasLength(1));
        expect(out.first.iterations, 3);
        expect(out.first.rows.map((r) => r.iteration), [
          0,
          1,
          2,
        ], reason: '逐轮升序,供迭代切换器');
        expect(out.first.latest!.iteration, 2);
      },
    );

    test(
      'failed → parked → the live front → the rest; graph order holds WITHIN a rank',
      () {
        final nodes = [
          _node('fetch', 'completed', startSec: 0, endSec: 1),
          _node('gate', 'parked', kind: 'control', startSec: 1),
          _node(
            'analyze',
            'failed',
            kind: 'agent',
            startSec: 2,
            endSec: 3,
            error: 'boom',
          ),
        ];
        final out = foldNodeLedger(_graph, nodes, inferredRunning: {'notify'});
        expect(out.map((e) => e.nodeId), [
          'analyze',
          'gate',
          'notify',
          'fetch',
        ]);
        expect(out.first.failed, isTrue);
        expect(out[2].inferred, isTrue, reason: '活前沿在诊断行之后、其余之前');
      },
    );

    test(
      'a graph node that never ran is NOT a ledger row (the ledger records what HAPPENED)',
      () {
        final out = foldNodeLedger(_graph, [
          _node('fetch', 'completed', startSec: 0, endSec: 1),
        ]);
        expect(out.map((e) => e.nodeId), ['fetch']);
      },
    );

    test(
      'an orphan row (renamed/removed node) keeps its place instead of vanishing',
      () {
        final out = foldNodeLedger(_graph, [
          _node('fetch', 'completed', startSec: 0, endSec: 1),
          _node('ghost', 'completed', startSec: 1, endSec: 2),
        ]);
        expect(out.map((e) => e.nodeId), ['fetch', 'ghost']);
      },
    );
  });

  group('inferredRunningNodes — the speculative front (§5.5 冷打开推测态)', () {
    test(
      'a live run with settled predecessors infers the front from the PINNED graph',
      () {
        final comp = _comp([
          _node('fetch', 'completed', startSec: 0, endSec: 1),
          _node(
            'gate',
            'completed',
            kind: 'control',
            startSec: 1,
            endSec: 2,
            result: const {'__port': 'high'},
          ),
        ], status: 'running');
        expect(inferredRunningNodes(_graph, comp), {'analyze'});
      },
    );

    test('a SETTLED run infers nothing — history has no speculation', () {
      final comp = _comp([
        _node('fetch', 'completed', startSec: 0, endSec: 1),
      ], status: 'completed');
      expect(inferredRunningNodes(_graph, comp), isEmpty);
    });

    test(
      'a live run with NO rows at all infers nothing (and must not crash) — the cold-open floor',
      () {
        // The page then renders the graph's stubs + an honest empty ledger: not blank, not authority.
        // 页面此时渲图占位 + 诚实空台账:不空白,也不装权威。
        expect(
          inferredRunningNodes(_graph, _comp(const [], status: 'running')),
          isEmpty,
        );
      },
    );
  });

  group('graphOfVersion', () {
    test(
      'graphParsed wins; a bad blob is null so the caller says «no graph» honestly',
      () {
        final now = DateTime.utc(2026);
        final bad = WorkflowVersion(
          id: 'wfv_1',
          workflowId: 'wf_1',
          version: 1,
          graph: '{not json',
          createdAt: now,
          updatedAt: now,
        );
        expect(graphOfVersion(bad), isNull);
        expect(graphOfVersion(null), isNull);
        final parsed = WorkflowVersion(
          id: 'wfv_1',
          workflowId: 'wf_1',
          version: 1,
          createdAt: now,
          updatedAt: now,
          graphParsed: _graph,
        );
        expect(graphOfVersion(parsed)!.nodes, hasLength(4));
      },
    );
  });

  group('flowrunChart — three-part bars follow DATA AVAILABILITY (§5.3)', () {
    test(
      '⑫ stamps + ⑤ audit → queue + exec parts, positioned on a real time axis',
      () {
        final chart = flowrunChart(
          _graph,
          _comp([
            _node(
              'analyze',
              'completed',
              kind: 'agent',
              readySec: 0,
              startSec: 2,
              endSec: 9,
            ),
          ]),
          activity: [_act('analyze', startSec: 2, elapsedMs: 7000)],
        );
        expect(chart.timeMode, isTrue);
        final row = chart.rows.firstWhere((r) => r.nodeId == 'analyze');
        final seg = row.segments.single;
        expect(seg.queueW, greaterThan(0), reason: '排队灰段');
        expect(seg.w, greaterThan(0), reason: '执行段');
        expect(seg.execId, 'agx_analyze', reason: '执行日志深链坐标随条带出');
        expect(
          seg.at + seg.queueW + seg.w + seg.parkedW,
          lessThanOrEqualTo(1.0001),
        );
      },
    );

    test(
      'a PRE-⑫ row degrades to a single-part bar — no invented queue leg',
      () {
        final chart = flowrunChart(
          _graph,
          _comp([_node('fetch', 'completed')]),
        );
        final row = chart.rows.firstWhere((r) => r.nodeId == 'fetch');
        expect(row.segments.single.queueW, 0);
      },
    );

    test(
      'a still-parked node grows its amber leg toward NOW on a live surface',
      () {
        final now = _t.add(const Duration(minutes: 18));
        final chart = flowrunChart(
          _graph,
          _comp([
            _node('fetch', 'completed', readySec: 0, startSec: 0, endSec: 1),
            _node('gate', 'parked', kind: 'approval', readySec: 1, startSec: 1),
          ], status: 'running'),
          now: now,
        );
        final gate = chart.rows.firstWhere((r) => r.nodeId == 'gate');
        expect(gate.parked, isTrue);
        expect(
          gate.segments.single.parkedW,
          greaterThan(0.5),
          reason: '18m 的人等应占满轴的绝大部分',
        );
        expect(chart.nowAt, isNotNull, reason: '活面有 now 线');
      },
    );

    test(
      'a SETTLED run gets no now-line (its axis is history, there is no «now» on it)',
      () {
        final chart = flowrunChart(
          _graph,
          _comp([
            _node('fetch', 'completed', readySec: 0, startSec: 0, endSec: 1),
          ]),
          now: _t.add(const Duration(hours: 5)),
        );
        expect(chart.nowAt, isNull);
      },
    );

    test(
      'a collapsed span falls back to equal slots AND says so via timeMode=false',
      () {
        // Every stamp coincident (the sub-ms local-sidecar run): equal widths must not be read as
        // equal durations, so the renderer is told to draw no ruler. 全重合:等宽不得被读成等时长。
        final chart = flowrunChart(
          _graph,
          _comp([
            _node('fetch', 'completed'),
            _node('gate', 'completed', kind: 'control'),
          ]),
        );
        expect(chart.timeMode, isFalse);
        expect(chart.nowAt, isNull);
        final positions = [
          for (final id in ['fetch', 'gate'])
            chart.rows.firstWhere((r) => r.nodeId == id).segments.first.at,
        ];
        expect(positions[0], lessThan(positions[1]), reason: '仍读左→右');
      },
    );

    test(
      'the speculative front claims a POSITION, never a measured duration',
      () {
        final now = _t.add(const Duration(seconds: 30));
        final chart = flowrunChart(
          _graph,
          _comp([
            _node('fetch', 'completed', readySec: 0, startSec: 0, endSec: 1),
            _node(
              'gate',
              'completed',
              kind: 'control',
              readySec: 1,
              startSec: 1,
              endSec: 2,
              result: const {'__port': 'high'},
            ),
          ], status: 'running'),
          now: now,
          inferredRunning: {'analyze'},
        );
        final analyze = chart.rows.firstWhere((r) => r.nodeId == 'analyze');
        expect(analyze.inferred, isTrue);
        expect(analyze.segments, hasLength(1));
        // It starts at the last PROVABLE moment and runs to now — an honest «somewhere in here».
        // 自「已知最后发生的事」画到当下——诚实的「就在这段里」。
        expect(analyze.segments.single.to, now);
        final notify = chart.rows.firstWhere((r) => r.nodeId == 'notify');
        expect(notify.inferred, isFalse);
        expect(notify.segments, isEmpty, reason: '未及的节点仍是占位,不被推测污染');
      },
    );
  });
}
