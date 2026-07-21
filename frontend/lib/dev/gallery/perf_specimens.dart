import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/design/colors.dart';
import '../../core/design/tokens.dart';
import '../../core/design/typography.dart';
import '../../core/messages/block_tree_reducer.dart';
import '../../core/sse/frame.dart';
import '../../features/chat/ui/chat_tool_card.dart';
import 'specimen.dart';

// WRK-061 W0 perf specimens — THE GATE before any stage work: the three streaming pressure beds
// (1MB content 流入 / 50 op每秒 / 5000 词 prompt) rendered through the REAL ChatToolCard pipeline
// (reducer → revision memo → incremental args session → live window), with a frame-timing HUD that
// must stay green (<16ms) while streaming. Specimens start PAUSED (▶ to run) so the widget-test
// matrix renders them without timers.
//
// W0 性能 specimen——开工舞台前的门禁:三张流式压力床走**真** ChatToolCard 管线(reducer→revision
// 记忆化→增量 args 会话→活窗),帧时 HUD 流入期必须全绿(<16ms)。默认暂停(▶ 启动),矩阵测试零计时器。

const _scope = StreamScope(kind: 'conversation', id: 'cv_perf');

// ── the three scripted streams 三条脚本流 ──────────────────────────────────────────────────────────

typedef _Script = ({
  String tool,
  String open,
  List<String> chunks,
  int tickMs,
  String label,
});

/// 1MB document content in 4KB deltas (~30/s ≈ 8.5s of streaming). 1MB 内容,4KB×256 片。
_Script _mbContent() {
  final line =
      '${'x' * 61}\\n'; // 64 chars of JSON-string payload per line 每行 64 字符
  final chunk = line * 64; // ~4KB per delta
  return (
    tool: 'create_document',
    open: '{"name":"war-and-peace.md","content":"',
    chunks: List.filled(256, chunk),
    tickMs: 33,
    label: '1MB content 流入(4KB×256 delta)',
  );
}

/// 50 complete ops per second for ~8s (400 ops). 50 op/s×8s。
_Script _opsFirehose() {
  final chunks = <String>[];
  for (var i = 0; i < 400; i++) {
    final op = i.isEven
        ? '{"op":"add_node","node":{"id":"n$i","kind":"action","ref":"fn_$i","input":{"x":"input.x"}}}'
        : '{"op":"add_edge","edge":{"id":"e$i","from":"n${i - 1}","to":"n$i"}}';
    chunks.add(i == 0 ? op : ',$op');
  }
  return (
    tool: 'create_workflow',
    open: '{"name":"firehose","ops":[',
    chunks: chunks,
    tickMs: 20,
    label: '50 op 每秒(400 ops)',
  );
}

/// A 5000-word agent prompt, ~12 words per delta (~35/s). 5000 词 prompt。
_Script _prompt5k() {
  const words = [
    'analyse',
    'the',
    'quarterly',
    'invoices',
    'and',
    'reconcile',
    'every',
    'ledger',
    'entry',
    'against',
    'its',
    'source',
  ];
  final chunks = <String>[];
  for (var i = 0; i < 5000 ~/ words.length + 1; i++) {
    chunks.add('${words.join(' ')} ');
  }
  return (
    tool: 'create_agent',
    open: '{"name":"auditor","prompt":"',
    chunks: chunks,
    tickMs: 28,
    label: '5000 词 prompt',
  );
}

// ── the rig 台架 ───────────────────────────────────────────────────────────────────────────────────

class _PerfRig extends StatefulWidget {
  const _PerfRig(this.script, {this.autoplayIndex = 0});
  final _Script script;

  /// Staggers PERF_AUTOPLAY runs so the beds stream ONE AT A TIME (frame timings are process-global —
  /// concurrent beds would bill each other). 错峰自动开跑:帧时是全局的,同跑互相计费。
  final int autoplayIndex;

  @override
  State<_PerfRig> createState() => _PerfRigState();
}

class _PerfRigState extends State<_PerfRig> {
  final _reducer = BlockTreeReducer();
  Timer? _timer;
  int _fed = 0;
  BlockNode? _node;

  // frame HUD (worst/last build+raster over the run) 帧时 HUD
  double _lastMs = 0, _worstMs = 0;
  int _over16 = 0, _frames = 0;
  int _warmupFrames =
      0; // first frames after play exempt (shader/first-layout jank) 起跑豁免帧
  TimingsCallback? _timings;

  @override
  void initState() {
    super.initState();
    // --dart-define=PERF_AUTOPLAY=true: start streaming ~1s after mount (real-machine verification
    // without UI scripting; const-folded off otherwise). 自动开跑缝(真机验证),默认编译期折掉。
    if (const bool.fromEnvironment('PERF_AUTOPLAY')) {
      Timer(Duration(seconds: 1 + widget.autoplayIndex * 14), () {
        if (mounted) _play();
      });
    }
    _timings = (List<FrameTiming> ts) {
      if (!mounted || _timer == null) return;
      var changed = false;
      for (final t in ts) {
        // The streaming-period gate: the first frames after play (first layout + shader warmup) are
        // exempt. 门禁看流入期稳态:起跑首帧(首布局+shader 预热)豁免。
        if (_warmupFrames > 0) {
          _warmupFrames--;
          continue;
        }
        final ms = t.totalSpan.inMicroseconds / 1000.0;
        _lastMs = ms;
        _frames++;
        if (ms > _worstMs) _worstMs = ms;
        if (ms > 16.7) _over16++;
        changed = true;
      }
      if (changed) setState(() {});
    };
    SchedulerBinding.instance.addTimingsCallback(_timings!);
  }

  @override
  void dispose() {
    if (_timings != null) {
      SchedulerBinding.instance.removeTimingsCallback(_timings!);
    }
    _timer?.cancel();
    super.dispose();
  }

  void _play() {
    if (_timer != null) return;
    _reducer.clear();
    _fed = 0;
    _worstMs = 0;
    _over16 = 0;
    _frames = 0;
    _warmupFrames = 5;
    _reducer.apply(
      StreamEnvelope(
        seq: 1,
        scope: _scope,
        id: 'tc_perf',
        frame: FrameOpen(
          node: StreamNode(
            type: 'tool_call',
            content: {'name': widget.script.tool},
          ),
        ),
      ),
    );
    _reducer.apply(
      StreamEnvelope(
        seq: 0,
        scope: _scope,
        id: 'tc_perf',
        frame: FrameDelta(chunk: widget.script.open),
      ),
    );
    _node = _reducer.nodeById('tc_perf');
    _timer = Timer.periodic(Duration(milliseconds: widget.script.tickMs), (t) {
      if (_fed >= widget.script.chunks.length) {
        t.cancel();
        _timer = null;
        setState(() {});
        return;
      }
      _reducer.apply(
        StreamEnvelope(
          seq: 0,
          scope: _scope,
          id: 'tc_perf',
          frame: FrameDelta(chunk: widget.script.chunks[_fed++]),
        ),
      );
      setState(() {});
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final running = _timer != null;
    final node = _node;
    final okShare = _frames == 0 ? 1.0 : 1 - _over16 / _frames;
    final hudColor = _worstMs <= 16.7
        ? c.ok
        : okShare > 0.97
        ? c.warn
        : c.danger;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: running ? null : _play,
              icon: Icon(
                running ? Icons.hourglass_top : Icons.play_arrow,
                size: AnSize.icon,
              ),
              tooltip: '播放',
            ),
            const SizedBox(width: AnSpace.s8),
            Expanded(
              child: Text(
                _frames == 0
                    ? '${widget.script.label} · ▶ 开跑后看帧时'
                    : '帧 ${_lastMs.toStringAsFixed(1)}ms · 最差 ${_worstMs.toStringAsFixed(1)}ms · '
                          '>16.7ms $_over16/$_frames帧 · 已喂 $_fed/${widget.script.chunks.length}',
                style: AnText.meta.copyWith(
                  color: _frames == 0 ? c.inkFaint : hudColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: AnSpace.s6),
        if (node != null)
          // Height-capped like a transcript viewport slice so all three beds' HUDs stay on screen —
          // the card lays out at full fidelity inside the scroll region. 限高如 transcript 视口切片,
          // 三床 HUD 同屏;卡在滚动区内全保真布局。
          SizedBox(
            height: 150,
            child: SingleChildScrollView(
              child: RepaintBoundary(child: ChatToolCard(node: node)),
            ),
          )
        else
          Text('未开始 — 点 ▶ 流入', style: AnText.meta.copyWith(color: c.inkFaint)),
      ],
    );
  }
}

/// The W0 gate specimens. W0 门禁 specimen。
final List<GallerySpecimen> perfSpecimens = [
  GallerySpecimen(
    '1MB content 流入 · create_document 活窗',
    (_) => _PerfRig(_mbContent()),
    span: true,
    stress: true,
  ),
  GallerySpecimen(
    '50 op/s · create_workflow op ticker',
    (_) => _PerfRig(_opsFirehose(), autoplayIndex: 1),
    span: true,
    stress: true,
  ),
  GallerySpecimen(
    '5000 词 prompt · create_agent 散文窗',
    (_) => _PerfRig(_prompt5k(), autoplayIndex: 2),
    span: true,
    stress: true,
  ),
];
