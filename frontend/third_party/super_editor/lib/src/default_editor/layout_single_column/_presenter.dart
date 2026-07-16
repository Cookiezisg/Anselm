import 'package:attributed_text/attributed_text.dart';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:super_editor/src/core/document.dart';
import 'package:super_editor/src/core/document_layout.dart';
import 'package:super_editor/src/core/styles.dart';
// ANSELM PATCH (ADR 0009): needed by the incremental presenter — list-run dirty walk + the debug
// style-probe. Dart tolerates the resulting import cycle. 增量 presenter 所需:列表段脏扫+样式探针;
// 由此产生的循环导入 Dart 允许。
import 'package:super_editor/src/default_editor/list_items.dart' show ListItemNode;
import 'package:super_editor/src/default_editor/text.dart' show TextComponentViewModel;
import 'package:super_editor/src/infrastructure/_logging.dart';

/// Information that is provided to a [ComponentBuilder] to
/// construct an appropriate [DocumentComponent] widget.
class SingleColumnDocumentComponentContext {
  /// Creates a component context.
  const SingleColumnDocumentComponentContext({
    required this.context,
    required this.componentKey,
  });

  /// The [BuildContext] for the parent of the [DocumentComponent]
  /// that needs to be built.
  final BuildContext context;

  /// A [GlobalKey] that must be assigned to the [DocumentComponent]
  /// widget returned by a [ComponentBuilder].
  ///
  /// The [componentKey] is used by the [DocumentLayout] to query for
  /// node-specific information, like node positions and selections.
  final GlobalKey componentKey;
}

/// Produces [SingleColumnLayoutViewModel]s to be displayed by a
/// [SingleColumnDocumentLayout].
///
/// A [SingleColumnLayoutComponentViewModel] is created for every [DocumentNode]
/// in the given [document], using the [ComponentBuilder]s. These component
/// view models are assembled into a [SingleColumnLayoutViewModel].
///
/// The view model is styled by passing it through a series of "style phases",
/// known as a [pipeline]. The final, styled, [SingleColumnLayoutViewModel] is
/// available via the [viewModel] property.
///
/// When the [document] changes, the entire pipeline is re-run to produce
/// a new [SingleColumnLayoutViewModel].
///
/// The output from each phase of the pipeline is cached so that when
/// something other than the document changes, like the user's selection,
/// only some of the pipeline phases are re-run. For this reason, the most
/// volatile phases should be placed at the end of the [pipeline].
// ═══ ANSELM PATCH (ADR 0009) ═════════════════════════════════════════════════════════════════════
// Global defaults for the presenter's Anselm extensions. SuperEditor hard-constructs the presenter
// (super_editor.dart:620) and passes no extra arguments, so instances it creates read these defaults;
// tests construct presenters directly and pass explicit values.
// presenter 的 Anselm 扩展全局默认值:SuperEditor 硬构造 presenter、不传额外参数,其实例读这里;
// 测试直接构造、显式传参。
class AnPresenterFlags {
  /// Kill-switch for node-level incremental view-model updates. `false` restores upstream's exact
  /// full-rebuild behaviour. 节点级增量的总闸;false=恢复上游原样全量重建。
  static bool incrementalDefault = true;

  /// When true, every incremental pass re-runs the FULL rebuild in an assert and compares field-by-field
  /// (including a textStyleBuilder style-probe) — turning every mounted editor into a differential test.
  /// Debug-only (assert-stripped in release). 自校验:每次增量后在 assert 里全量重算并逐字段比对(含样式
  /// 探针)——每个挂载的编辑器都变成差分测试。仅 debug(release 剥除)。
  static bool debugVerifyDefault = false;
}

/// Test-only counters proving the incremental presenter's work is O(change), not O(document) — the
/// guard test types a key into a large document and asserts hard upper bounds on these.
/// 测试用计数器,证明增量 presenter 的工作量是 O(变更) 而非 O(文档)——守卫测在大文档打一键并对
/// 这些计数断言硬上界。
class AnPresenterMetrics {
  /// How many base component view models were built (builder.createViewModel calls, one per node
  /// rebuilt). 建了多少个基底 vm。
  static int baseVmCreates = 0;

  /// How many view models were fed through styling phases (summed across phases). 五相合计喂入了
  /// 多少个 vm。
  static int phaseVmStyled = 0;

  static void reset() {
    baseVmCreates = 0;
    phaseVmStyled = 0;
  }
}

/// Per-phase dirt consumed from a phase's pending channel. 相内脏账。
class _AnPhaseDirt {
  bool whole = false;
  final Set<String> nodes = <String>{};
}
// ═══ END ANSELM PATCH ════════════════════════════════════════════════════════════════════════════

class SingleColumnLayoutPresenter {
  SingleColumnLayoutPresenter({
    required Document document,
    required List<ComponentBuilder> componentBuilders,
    required List<SingleColumnLayoutStylePhase> pipeline,
    // ANSELM PATCH (ADR 0009): see [AnPresenterFlags]. null → the global defaults.
    bool? incremental,
    bool? debugVerifyAgainstFullRebuild,
  })  : _document = document,
        _componentBuilders = componentBuilders,
        _pipeline = pipeline,
        _incremental = incremental ?? AnPresenterFlags.incrementalDefault,
        _debugVerify = debugVerifyAgainstFullRebuild ?? AnPresenterFlags.debugVerifyDefault {
    _assemblePipeline();
    _viewModel = _createNewViewModel();
    _document.addListener(_onDocumentChange);
  }

  void dispose() {
    _listeners.clear();
    _document.removeListener(_onDocumentChange);
    _disassemblePipeline();
  }

  final Document _document;
  final List<ComponentBuilder> _componentBuilders;
  final List<SingleColumnLayoutStylePhase> _pipeline;
  final List<SingleColumnLayoutViewModel?> _phaseViewModels = [];
  int _earliestDirtyPhase = 0;

  // ═══ ANSELM PATCH (ADR 0009): node-level incremental state ═══════════════════════════════════════
  final bool _incremental;
  final bool _debugVerify;

  // Document-change accounting since the last consumed pass. `_docWholeDirty` is the fail-safe: any
  // change log we can't attribute to specific nodes (empty log, unknown event type, e.g.
  // MutableDocument.reset()) falls back to a full rebuild — correctness never depends on event
  // coverage. 自上次消费以来的文档变更台账;_docWholeDirty 是 fail-safe:凡无法归到具体节点的变更
  // (空 log/未知事件,如 reset())一律全量重建——正确性绝不押在事件覆盖上。
  bool _docWholeDirty = true;
  bool _docStructural = false;
  final Set<String> _docChangedIds = <String>{};
  final Set<String> _docRemovedOrMovedIds = <String>{};

  // Node order + caches from the last consumed pass. Cached instances are safe to share because every
  // pipeline phase copies before mutating (verified per phase, see ADR 0009). 上次消费后的节点序与
  // 缓存;五相均先 copy 再改(逐相核实),缓存实例可安全共享。
  List<String> _lastOrder = const [];
  Map<String, int> _lastOrderIndex = const {};
  Map<String, SingleColumnLayoutComponentViewModel> _baseVmCache = {};
  final List<List<SingleColumnLayoutComponentViewModel>?> _phaseVmList = [];
  final List<Map<String, SingleColumnLayoutComponentViewModel>?> _phaseVmMap = [];
  final List<EdgeInsetsGeometry?> _phasePadding = [];

  // Per-phase dirt consumed from the phases' pending channels (see SingleColumnLayoutStylePhase).
  // 从各相 pending 通道消费下来的相内脏账。
  final List<_AnPhaseDirt> _phaseDirt = [];
  // ═══ END ANSELM PATCH ════════════════════════════════════════════════════════════════════════════

  bool get isDirty => _earliestDirtyPhase < _pipeline.length;

  late SingleColumnLayoutViewModel _viewModel;
  SingleColumnLayoutViewModel get viewModel => _viewModel;

  final _listeners = <SingleColumnLayoutPresenterChangeListener>{};

  void addChangeListener(SingleColumnLayoutPresenterChangeListener listener) {
    _listeners.add(listener);
  }

  void removeChangeListener(SingleColumnLayoutPresenterChangeListener listener) {
    _listeners.remove(listener);
  }

  void _onDocumentChange(DocumentChangeLog changeLog) {
    editorLayoutLog.info("The document changed. Marking the presenter dirty.");
    final wasDirty = isDirty;

    _earliestDirtyPhase = 0;

    // ═══ ANSELM PATCH (ADR 0009): attribute the change to specific nodes when possible ═════════════
    // 尽量把变更归到具体节点;归不了的一律 fail-safe 全量。
    if (_incremental && !_docWholeDirty) {
      if (changeLog.changes.isEmpty) {
        // e.g. MutableDocument.reset() — no per-node attribution possible. reset() 之类,无从归账。
        _docWholeDirty = true;
      } else {
        for (final event in changeLog.changes) {
          if (event is NodeChangeEvent) {
            _docChangedIds.add(event.nodeId);
          } else if (event is NodeInsertedEvent) {
            _docChangedIds.add(event.nodeId);
            _docStructural = true;
          } else if (event is NodeRemovedEvent) {
            _docRemovedOrMovedIds.add(event.nodeId);
            _docStructural = true;
          } else if (event is NodeMovedEvent) {
            // A move is a removal from the old position plus an insertion at the new one — both the
            // old and new successors gain a new predecessor. 移动=旧位删除+新位插入,新旧后继都换前驱。
            _docChangedIds.add(event.nodeId);
            _docRemovedOrMovedIds.add(event.nodeId);
            _docStructural = true;
          } else {
            // Unknown event type — cannot attribute. 未知事件,无从归账。
            _docWholeDirty = true;
            break;
          }
        }
      }
    }
    // ═══ END ANSELM PATCH ══════════════════════════════════════════════════════════════════════════

    if (!wasDirty) {
      // The presenter just went from clean to dirty. Notify listeners.
      for (final listener in _listeners) {
        listener.onPresenterMarkedDirty();
      }
    }
  }

  void _assemblePipeline() {
    // Add all the phases that were provided by the client.
    for (int i = 0; i < _pipeline.length; i += 1) {
      // Create an empty placeholder for cached view models for this phase.
      _phaseViewModels.add(null);
      // ANSELM PATCH (ADR 0009): incremental per-phase slots. 增量的相内槽位。
      _phaseVmList.add(null);
      _phaseVmMap.add(null);
      _phasePadding.add(null);
      _phaseDirt.add(_AnPhaseDirt());

      // Listen for all dirty phase notifications.
      _pipeline[i].dirtyCallback = () {
        final phaseIndex = i;
        if (phaseIndex < 0) {
          throw Exception("A phase marked itself as dirty, but that phase isn't in the pipeline. Index: $phaseIndex");
        }

        // ═══ ANSELM PATCH (ADR 0009): consume the phase's pending dirt ═══════════════════════════════
        // Always consume (even in full mode) so the phase-side pending set can't grow unboundedly.
        // Whole-phase dirt subsumes node-scoped dirt. 永远消费(全量模式也消费),防相内 pending 无界增长;
        // 全相脏吞并节点级。
        final phase = _pipeline[phaseIndex];
        final dirt = _phaseDirt[phaseIndex];
        if (phase._pendingWholePhaseDirty) {
          dirt.whole = true;
          dirt.nodes.clear();
        } else if (!dirt.whole) {
          dirt.nodes.addAll(phase._pendingDirtyNodeIds);
        }
        phase._pendingWholePhaseDirty = false;
        phase._pendingDirtyNodeIds.clear();
        // ═══ END ANSELM PATCH ════════════════════════════════════════════════════════════════════════

        final wasDirty = isDirty;
        if (phaseIndex < _earliestDirtyPhase) {
          _earliestDirtyPhase = phaseIndex;
        }

        editorLayoutLog.info("Presenter phase ($phaseIndex) is dirty.");

        if (!wasDirty) {
          // The presenter just went from clean to dirty. Notify listeners.
          for (final listener in _listeners) {
            listener.onPresenterMarkedDirty();
          }
        }
      };
    }
  }

  void _disassemblePipeline() {
    for (final phase in _pipeline) {
      phase.dispose();
    }
  }

  void updateViewModel() {
    editorLayoutLog.info("Calculating an updated view model for document layout.");
    if (_earliestDirtyPhase == _pipeline.length) {
      editorLayoutLog.fine("The presenter is already up to date");
      return;
    }

    editorLayoutLog.fine("Earliest dirty phase is: $_earliestDirtyPhase. Phase count: ${_pipeline.length}");

    final oldViewModel = _viewModel;
    _viewModel = _createNewViewModel();

    editorLayoutLog.info("Done calculating new document layout view model");

    _notifyListenersOfChanges(
      oldViewModel: oldViewModel,
      newViewModel: _viewModel,
    );
  }

  SingleColumnLayoutViewModel _createNewViewModel() {
    // ANSELM PATCH (ADR 0009): dispatch. The upstream body is preserved verbatim below as the
    // kill-switch path. 分派;上游原体保留在下作总闸路径。
    if (_incremental) {
      return _createIncrementalOrFullViewModel();
    }

    editorLayoutLog.fine("Running layout presenter pipeline");
    // (Re)generate all dirty phases.
    SingleColumnLayoutViewModel? newViewModel = _getCleanCachedViewModel();

    if (newViewModel == null) {
      // The document changed. All view models were invalidated. Create a
      // new base document view model.
      final viewModels = <SingleColumnLayoutComponentViewModel>[];
      for (final node in _document) {
        SingleColumnLayoutComponentViewModel? viewModel;
        for (final builder in _componentBuilders) {
          viewModel = builder.createViewModel(_document, node);
          if (viewModel != null) {
            break;
          }
        }
        if (viewModel == null) {
          throw Exception("Couldn't find styler to create component for document node: ${node.runtimeType}");
        }
        viewModels.add(viewModel);
      }

      newViewModel = SingleColumnLayoutViewModel(
        componentViewModels: viewModels,
      );
    }

    // Style the document view model.
    for (int i = _earliestDirtyPhase; i < _pipeline.length; i += 1) {
      editorLayoutLog.fine("Running phase $i: ${_pipeline[i]}");
      newViewModel = _pipeline[i].style(_document, newViewModel!);
      editorLayoutLog.fine("Storing phase $i view model");
      _phaseViewModels[i] = newViewModel;
    }
    // We're all clean.
    _earliestDirtyPhase = _pipeline.length;

    // ANSELM PATCH (ADR 0009): the kill-switch path must still drain per-pass dirt accounting, so a
    // runtime flip back to incremental (via remount) never consumes stale accumulation. 总闸路径也要
    // 清账,防陈账。
    _resetDirtAccounting();

    return newViewModel!;
  }

  // ═══ ANSELM PATCH (ADR 0009): node-level incremental pipeline ════════════════════════════════════

  SingleColumnLayoutViewModel _createIncrementalOrFullViewModel() {
    SingleColumnLayoutViewModel? result;
    if (!_docWholeDirty && _baseVmCache.isNotEmpty) {
      // `null` result = a mid-pass contract violation (a phase reshaped the list, or a cache went
      // missing) → fall through to the fail-safe full pass. null=中途契约违约→落回全量。
      result = _runIncrementalPass();
      if (result == null) {
        editorLayoutLog.warning("Incremental layout pass hit a contract violation — falling back to a full rebuild.");
      }
    }
    result ??= _runFullPass();

    // Settle accounting for the next pass. 为下一趟清账。
    _lastOrder = List<String>.unmodifiable([for (final node in _document) node.id]);
    _lastOrderIndex = {for (var k = 0; k < _lastOrder.length; k++) _lastOrder[k]: k};
    _resetDirtAccounting();
    _earliestDirtyPhase = _pipeline.length;

    assert(() {
      if (_debugVerify) {
        _verifyAgainstFullRebuild(result!);
      }
      return true;
    }());

    return result;
  }

  void _resetDirtAccounting() {
    _docWholeDirty = false;
    _docStructural = false;
    _docChangedIds.clear();
    _docRemovedOrMovedIds.clear();
    for (final dirt in _phaseDirt) {
      dirt.whole = false;
      dirt.nodes.clear();
    }
  }

  SingleColumnLayoutComponentViewModel _buildBaseViewModel(DocumentNode node, {bool countMetrics = true}) {
    if (countMetrics) {
      AnPresenterMetrics.baseVmCreates += 1;
    }
    for (final builder in _componentBuilders) {
      final viewModel = builder.createViewModel(_document, node);
      if (viewModel != null) {
        return viewModel;
      }
    }
    throw Exception("Couldn't find styler to create component for document node: ${node.runtimeType}");
  }

  /// The full pass: fresh base view models for every node, every phase styled over the full list —
  /// exactly upstream's per-keystroke behaviour — and every incremental cache reseeded from it.
  /// 全量趟:全节点新建基底 vm、五相全列表重跑(上游逐键行为原样),并借机重播所有增量缓存。
  SingleColumnLayoutViewModel _runFullPass() {
    editorLayoutLog.fine("Running a FULL layout presenter pass (incremental mode)");
    final baseList = <SingleColumnLayoutComponentViewModel>[];
    final baseCache = <String, SingleColumnLayoutComponentViewModel>{};
    for (final node in _document) {
      final vm = _buildBaseViewModel(node);
      baseList.add(vm);
      baseCache[node.id] = vm;
    }
    _baseVmCache = baseCache;

    var prevList = baseList;
    EdgeInsetsGeometry prevPadding = EdgeInsets.zero;
    for (var i = 0; i < _pipeline.length; i += 1) {
      AnPresenterMetrics.phaseVmStyled += prevList.length;
      final output = _pipeline[i].style(
        _document,
        SingleColumnLayoutViewModel(padding: prevPadding, componentViewModels: prevList),
      );
      prevList = output.componentViewModels;
      prevPadding = output.padding;
      _phaseVmList[i] = prevList;
      _phaseVmMap[i] = {for (final vm in prevList) vm.nodeId: vm};
      _phasePadding[i] = prevPadding;
    }

    return SingleColumnLayoutViewModel(padding: prevPadding, componentViewModels: prevList);
  }

  /// The incremental pass. Returns `null` on any contract violation so the caller can fall back to
  /// [_runFullPass]. 增量趟;任何契约违约返回 null 由调用方落回全量。
  SingleColumnLayoutViewModel? _runIncrementalPass() {
    editorLayoutLog.fine("Running an INCREMENTAL layout presenter pass");
    final baseDirty = _expandDirtyRadius();

    // 1. Base view models: reuse cached instances for clean nodes, rebuild dirty ones.
    //    基底 vm:干净节点复用缓存实例,脏节点重建。
    final order = <String>[];
    final baseList = <SingleColumnLayoutComponentViewModel>[];
    final baseCache = <String, SingleColumnLayoutComponentViewModel>{};
    for (final node in _document) {
      order.add(node.id);
      var vm = baseDirty.contains(node.id) ? null : _baseVmCache[node.id];
      vm ??= _buildBaseViewModel(node);
      baseList.add(vm);
      baseCache[node.id] = vm;
    }
    _baseVmCache = baseCache;

    // 2. Phases. `carry` = the nodes that must be restyled from this phase on (grows with each
    //    phase's own dirt); `null` = all nodes. carry=从本相起必须重刷的节点集(随相内脏增长);null=全部。
    Set<String>? carry = <String>{
      for (final id in baseDirty)
        if (baseCache.containsKey(id)) id,
    };
    var prevList = baseList;
    EdgeInsetsGeometry prevPadding = EdgeInsets.zero;

    for (var i = 0; i < _pipeline.length; i += 1) {
      final dirt = _phaseDirt[i];
      if (dirt.whole) {
        carry = null;
      } else if (carry != null && dirt.nodes.isNotEmpty) {
        carry.addAll(dirt.nodes);
      }

      final cachedList = _phaseVmList[i];
      final cachedMap = _phaseVmMap[i];
      final cachedPadding = _phasePadding[i];

      if (carry == null || cachedList == null || cachedMap == null || cachedPadding == null) {
        // Whole-phase dirt (or no cache yet): style the full list — upstream behaviour for this phase.
        // Later phases can still go incremental: their caches were derived from value-equal inputs.
        // 全相脏(或无缓存):本相全列表重跑;后续相仍可增量(其缓存来自值相等的输入)。
        AnPresenterMetrics.phaseVmStyled += prevList.length;
        final output = _pipeline[i].style(
          _document,
          SingleColumnLayoutViewModel(padding: prevPadding, componentViewModels: prevList),
        );
        prevList = output.componentViewModels;
        prevPadding = output.padding;
        _phaseVmList[i] = prevList;
        _phaseVmMap[i] = {for (final vm in prevList) vm.nodeId: vm};
        _phasePadding[i] = prevPadding;
        continue;
      }

      if (carry.isEmpty) {
        // Nothing dirty at or before this phase — its cached output is the truth. Cache hit implies
        // the node order is unchanged (any structural change would have seeded `carry`).
        // 本相及之前无脏——缓存即真相;能走到这说明节点序未变(结构变更必已入 carry)。
        prevList = cachedList;
        prevPadding = cachedPadding;
        continue;
      }

      // Subset feed: style ONLY the carry nodes, then merge with the cached clean outputs.
      // 子集喂入:只把 carry 节点交给本相,再与缓存的干净产出合并。
      final subset = <SingleColumnLayoutComponentViewModel>[
        for (final vm in prevList)
          if (carry.contains(vm.nodeId)) vm,
      ];
      AnPresenterMetrics.phaseVmStyled += subset.length;
      final output = _pipeline[i].style(
        _document,
        SingleColumnLayoutViewModel(padding: prevPadding, componentViewModels: subset),
      );
      final styledSubset = output.componentViewModels;
      if (styledSubset.length != subset.length) {
        // A phase added/dropped view models under subset feeding — contract violation. 相在子集下
        // 增删了 vm——契约违约。
        return null;
      }
      final styledById = <String, SingleColumnLayoutComponentViewModel>{
        for (final vm in styledSubset) vm.nodeId: vm,
      };

      final merged = <SingleColumnLayoutComponentViewModel>[];
      for (final id in order) {
        final vm = carry.contains(id) ? styledById[id] : cachedMap[id];
        if (vm == null) {
          // A clean node missing from this phase's cache (or a styled node missing from the subset
          // output) — contract violation. 干净节点缺缓存(或子集产出缺节点)——契约违约。
          return null;
        }
        merged.add(vm);
      }
      prevList = merged;
      prevPadding = output.padding;
      _phaseVmList[i] = merged;
      _phaseVmMap[i] = styledById.length == merged.length
          ? styledById
          : {for (final vm in merged) vm.nodeId: vm};
      _phasePadding[i] = prevPadding;
    }

    return SingleColumnLayoutViewModel(padding: prevPadding, componentViewModels: prevList);
  }

  /// Expands the raw changed-node ids to the full set of nodes whose BASE view model or styling may
  /// have changed, covering every known cross-node dependency edge (all of which propagate downward):
  ///
  ///  1. successor of a changed node — `.after()` stylesheet selectors, heading-top spacing and quote
  ///     continuation all read the predecessor;
  ///  2. the node now sitting where a removed/moved node used to be — it too gained a new predecessor;
  ///  3. the contiguous list-item run below any dirty node — ordered-list ordinals count the items
  ///     above them;
  ///  4. on any structural change: the old and new first/last nodes — `.first()`/`.last()` selectors
  ///     and the single-node hint (which reads nodeCount).
  ///
  /// 把原始变更节点扩成「基底 vm 或样式可能变化」的完整集合,覆盖全部已知跨节点依赖边(全部向下传播):
  /// ①变更节点的后继(.after() 选择器/标题上距/引用延续都读前驱)②删除/移动节点旧位上的现任(它也换了
  /// 前驱)③任何脏节点下方的连续列表段(有序列表序号数上方的项)④结构变更时新旧首末节点(.first()/.last()
  /// 选择器+单节点 hint 读 nodeCount)。
  Set<String> _expandDirtyRadius() {
    final dirty = <String>{..._docChangedIds, ..._docRemovedOrMovedIds};

    // Edge 1: current successors of changed nodes. 边1:变更节点的现后继。
    for (final id in _docChangedIds) {
      final next = _document.getNodeAfterById(id);
      if (next != null) {
        dirty.add(next.id);
      }
    }

    // Edge 2: the first still-existing node after each removed/moved node's OLD position (from the
    // previous pass's order snapshot). 边2:删除/移动节点旧位之后第一个仍存活的节点(取上趟序快照)。
    for (final id in _docRemovedOrMovedIds) {
      final oldIdx = _lastOrderIndex[id];
      if (oldIdx == null) {
        continue; // Inserted and removed within one pass — never had an old position. 同趟生灭,无旧位。
      }
      for (var j = oldIdx + 1; j < _lastOrder.length; j += 1) {
        if (_document.getNodeById(_lastOrder[j]) != null) {
          dirty.add(_lastOrder[j]);
          break;
        }
      }
    }

    // Edge 3: walk DOWN the contiguous list-item run below every dirty node. 边3:沿每个脏节点向下扫
    // 连续列表段。
    for (final id in dirty.toList()) {
      var next = _document.getNodeById(id) != null ? _document.getNodeAfterById(id) : null;
      while (next is ListItemNode) {
        if (!dirty.add(next.id)) {
          break; // Already covered — the run below it was walked before. 已覆盖,其下已扫过。
        }
        next = _document.getNodeAfterById(next.id);
      }
    }

    // Edge 4: old + new first/last on structural change. 边4:结构变更时新旧首末。
    if (_docStructural) {
      if (_lastOrder.isNotEmpty) {
        dirty.add(_lastOrder.first);
        dirty.add(_lastOrder.last);
      }
      if (_document.nodeCount > 0) {
        dirty.add(_document.getNodeAt(0)!.id);
        dirty.add(_document.getNodeAt(_document.nodeCount - 1)!.id);
      }
    }

    return dirty;
  }

  /// Debug-only self-check: recompute the whole view model the upstream way and compare field by
  /// field — including a textStyleBuilder style-probe, because view-model `==` deliberately skips
  /// closures and a stale-stylesheet closure would pass `==` while rendering wrong. Throws on any
  /// divergence. 仅 debug 自校验:按上游方式全量重算并逐字段比对——含样式探针(vm 的 == 刻意跳过闭包,
  /// 捕获陈旧样式表的闭包能过 == 但真机渲错)。有分歧即抛。
  void _verifyAgainstFullRebuild(SingleColumnLayoutViewModel actual) {
    final savedBaseCreates = AnPresenterMetrics.baseVmCreates;
    final savedPhaseStyled = AnPresenterMetrics.phaseVmStyled;

    var oracle = SingleColumnLayoutViewModel(
      componentViewModels: [
        for (final node in _document) _buildBaseViewModel(node, countMetrics: false),
      ],
    );
    for (final phase in _pipeline) {
      oracle = phase.style(_document, oracle);
    }

    AnPresenterMetrics.baseVmCreates = savedBaseCreates;
    AnPresenterMetrics.phaseVmStyled = savedPhaseStyled;

    if (oracle.componentViewModels.length != actual.componentViewModels.length) {
      throw StateError(
        "Incremental presenter divergence: node count ${actual.componentViewModels.length} != oracle ${oracle.componentViewModels.length}",
      );
    }
    if (oracle.padding != actual.padding) {
      throw StateError("Incremental presenter divergence: padding ${actual.padding} != oracle ${oracle.padding}");
    }
    final probes = <Set<Attribution>>[
      const <Attribution>{},
      {const NamedAttribution("bold")},
      {const NamedAttribution("code")},
    ];
    for (var i = 0; i < oracle.componentViewModels.length; i += 1) {
      final expected = oracle.componentViewModels[i];
      final got = actual.componentViewModels[i];
      if (expected.runtimeType != got.runtimeType || expected.nodeId != got.nodeId || expected != got) {
        throw StateError(
          "Incremental presenter divergence at #$i (${expected.nodeId}):\n"
          "  oracle:      ${_describeVm(expected)}\n"
          "  incremental: ${_describeVm(got)}",
        );
      }
      if (expected is TextComponentViewModel && got is TextComponentViewModel) {
        for (final probe in probes) {
          final expectedStyle = (expected as dynamic).textStyleBuilder(probe) as TextStyle;
          final gotStyle = (got as dynamic).textStyleBuilder(probe) as TextStyle;
          if (expectedStyle != gotStyle) {
            throw StateError(
              "Incremental presenter divergence at #$i (${expected.nodeId}): textStyleBuilder($probe) — "
              "a stale-stylesheet closure passed == but styles diverge.\n  oracle: $expectedStyle\n  incremental: $gotStyle",
            );
          }
        }
      }
    }
  }
  /// Field-level dump for divergence diagnostics (vm toString is uninformative). 字段级 dump。
  String _describeVm(SingleColumnLayoutComponentViewModel vm) {
    final buffer = StringBuffer("${vm.runtimeType}(nodeId: ${vm.nodeId}, padding: ${vm.padding}, "
        "maxWidth: ${vm.maxWidth}, opacity: ${vm.opacity}, createdAt: ${vm.createdAt}");
    if (vm is TextComponentViewModel) {
      final dynamic textVm = vm;
      buffer.write(", text: '${textVm.text.toPlainText()}'"
          ", textAlignment: ${textVm.textAlignment}"
          ", highlightWhenEmpty: ${textVm.highlightWhenEmpty}");
      try {
        buffer.write(", selection: ${textVm.selection}, selectionColor: ${textVm.selectionColor}");
      } catch (_) {}
      try {
        buffer.write(", composingRegion: ${textVm.composingRegion}"
            ", showComposingRegionUnderline: ${textVm.showComposingRegionUnderline}");
      } catch (_) {}
    }
    buffer.write(")");
    return buffer.toString();
  }
  // ═══ END ANSELM PATCH ════════════════════════════════════════════════════════════════════════════

  SingleColumnLayoutViewModel? _getCleanCachedViewModel() {
    return _earliestDirtyPhase > 0 && _earliestDirtyPhase < _phaseViewModels.length
        ? _phaseViewModels[_earliestDirtyPhase - 1]
        : null;
  }

  void _notifyListenersOfChanges({
    required SingleColumnLayoutViewModel oldViewModel,
    required SingleColumnLayoutViewModel newViewModel,
  }) {
    editorLayoutLog.finer("Computing layout view model changes to notify listeners of those changes.");

    final addedComponents = <String>[];
    final movedComponents = <String>[];
    final removedComponents = <String>[];
    final changedComponents = <String>[];

    final nodeIdToComponentMap = <String, SingleColumnLayoutComponentViewModel>{};
    final nodeIdToPreviousOrderMap = <String, int>{};
    // Maps a component's node ID to a change code:
    //  -1 - the component was removed
    //   0 - the component is unchanged
    //   1 - the component changed
    //   2 - the component was moved
    //   3 - the component was added
    final changeMap = <String, int>{};

    // Catalog the components in the previous view model.
    for (int i = 0; i < oldViewModel.componentViewModels.length; i += 1) {
      final oldComponent = oldViewModel.componentViewModels[i];
      final nodeId = oldComponent.nodeId;

      nodeIdToComponentMap[nodeId] = oldComponent;
      nodeIdToPreviousOrderMap[nodeId] = i;

      changeMap[nodeId] = -1;
    }

    // Accumulate all changes that we can find between the old view model and the new one.
    for (int i = 0; i < newViewModel.componentViewModels.length; i += 1) {
      final newComponent = newViewModel.componentViewModels[i];
      final nodeId = newComponent.nodeId;

      if (!nodeIdToComponentMap.containsKey(nodeId)) {
        // This component is new.
        editorLayoutLog.fine("New component was added for node $nodeId");
        changeMap[nodeId] = 3;
        continue;
      }

      if (nodeIdToPreviousOrderMap[nodeId] != i) {
        // This component moved somewhere else. Mark this view model as changed.
        editorLayoutLog.fine(
            "Component for node $nodeId was at index ${nodeIdToPreviousOrderMap[nodeId]} but now it's at $i, marking the view model as changed");
        changeMap[nodeId] = 2;
        continue;
      }

      if (nodeIdToComponentMap[nodeId] == newComponent) {
        // The component hasn't changed.
        editorLayoutLog.fine("Component for node $nodeId didn't change at all");
        changeMap[nodeId] = 0;
        continue;
      }

      if (nodeIdToComponentMap[nodeId].runtimeType == newComponent.runtimeType) {
        // The component still exists, but it changed.
        editorLayoutLog
            .fine("Component for node $nodeId is the same runtime type, but changed content. Marking as changed.");
        changeMap[nodeId] = 1;
        continue;
      }

      // The component has changed type, e.g., from an Image to a
      // Paragraph. This can happen as a result of deletions. Treat
      // this as a component removal.
      editorLayoutLog.fine("Component for node $nodeId at index $i was removed");
      changeMap[nodeId] = -1;
    }

    // Convert the change map to lists of changes.
    for (final entry in changeMap.entries) {
      switch (entry.value) {
        case -1:
          removedComponents.add(entry.key);
          break;
        case 0:
          // Component was unchanged. Do nothing.
          break;
        case 1:
          changedComponents.add(entry.key);
          break;
        case 2:
          movedComponents.add(entry.key);
          break;
        case 3:
          addedComponents.add(entry.key);
          break;
        default:
          if (kDebugMode) {
            throw Exception("Unknown component change value: ${entry.value}");
          }
          break;
      }
    }

    if (addedComponents.isEmpty && movedComponents.isEmpty && changedComponents.isEmpty && removedComponents.isEmpty) {
      // No changes to report.
      editorLayoutLog.fine("Nothing has changed in the view model. Not notifying any listeners.");
      return;
    }

    editorLayoutLog.fine("Notifying layout presenter listeners of changes:");
    editorLayoutLog.fine(" - added: $addedComponents");
    editorLayoutLog.fine(" - added: $movedComponents");
    editorLayoutLog.fine(" - changed: $changedComponents");
    editorLayoutLog.fine(" - removed: $removedComponents");
    for (final listener in _listeners.toList()) {
      listener.onViewModelChange(
        addedComponents: addedComponents,
        movedComponents: movedComponents,
        changedComponents: changedComponents,
        removedComponents: removedComponents,
      );
    }
  }
}

class SingleColumnLayoutPresenterChangeListener {
  const SingleColumnLayoutPresenterChangeListener({
    VoidCallback? onPresenterMarkedDirty,
    ViewModelChangeCallback? onViewModelChange,
  })  : _onPresenterMarkedDirty = onPresenterMarkedDirty,
        _onViewModelChange = onViewModelChange;

  final VoidCallback? _onPresenterMarkedDirty;
  final ViewModelChangeCallback? _onViewModelChange;

  void onPresenterMarkedDirty() {
    _onPresenterMarkedDirty?.call();
  }

  void onViewModelChange({
    required List<String> addedComponents,
    required List<String> movedComponents,
    required List<String> changedComponents,
    required List<String> removedComponents,
  }) {
    _onViewModelChange?.call(
      addedComponents: addedComponents,
      movedComponents: movedComponents,
      changedComponents: changedComponents,
      removedComponents: removedComponents,
    );
  }
}

typedef ViewModelChangeCallback = void Function({
  required List<String> addedComponents,
  required List<String> movedComponents,
  required List<String> changedComponents,
  required List<String> removedComponents,
});

/// Creates view models and components to display various [DocumentNode]s
/// in a [Document].
abstract class ComponentBuilder {
  /// Produces a [SingleColumnLayoutComponentViewModel] with default styles for the given
  /// [node], or returns `null` if this builder doesn't apply to the given node.
  SingleColumnLayoutComponentViewModel? createViewModel(Document document, DocumentNode node);

  /// Creates a visual component that renders the given [viewModel],
  /// or returns `null` if this builder doesn't apply to the given [viewModel].
  ///
  /// Returned widgets should be [StatefulWidget]s that mix in [DocumentComponent].
  ///
  /// This method might be invoked with a type of [viewModel] that it
  /// doesn't know how to work with. When this happens, the method should
  /// return `null`, indicating that it doesn't know how to build a component
  /// for the given [viewModel].
  ///
  /// See [ComponentContext] for expectations about how to use the context
  /// to build a component widget.
  Widget? createComponent(
      SingleColumnDocumentComponentContext componentContext, SingleColumnLayoutComponentViewModel componentViewModel);
}

/// A single phase of style rules, which are applied in a pipeline to
/// a baseline [SingleColumnLayoutViewModel].
///
/// Each such phase takes an incoming layout view model, copies it,
/// makes any desired style changes, and then returns the new view model.
///
/// Example:
///
/// (baseline) --> (text styles) --> (selection styles) --> (layout)
abstract class SingleColumnLayoutStylePhase {
  void dispose() {
    _dirtyCallback = null;
  }

  VoidCallback? _dirtyCallback;
  set dirtyCallback(VoidCallback? newCallback) => _dirtyCallback = newCallback;

  // ═══ ANSELM PATCH (ADR 0009): node-scoped dirt channel ═══════════════════════════════════════════
  // A phase that knows exactly WHICH nodes its restyle affects (e.g. the selection styler: old range ∪
  // new range) reports them here so an incremental presenter can restyle only those. `markDirty` keeps
  // its upstream meaning — "everything I produce is stale" — and always wins over node-scoped dirt.
  // The presenter (same library — Dart privacy is per-file) consumes and clears these on its
  // dirtyCallback. 知道自己这次到底影响哪些节点的相(如选区相:旧区∪新区)从这里上报,增量 presenter 只
  // 重刷这些;markDirty 保持上游语义「我产出的全部过期」且永远压过节点级。presenter(同库,Dart 私有按
  // 文件)在 dirtyCallback 里消费并清空。
  bool _pendingWholePhaseDirty = false;
  final Set<String> _pendingDirtyNodeIds = <String>{};

  /// Marks only [nodeIds] as needing this phase's recalculation. Empty input is a no-op — nothing
  /// was affected, so nothing must re-run. 只把这些节点标为需本相重算;空集=无影响,不触发。
  @protected
  void markDirtyNodes(Set<String> nodeIds) {
    if (nodeIds.isEmpty) {
      return;
    }
    editorLayoutLog.info("Marking ${nodeIds.length} node(s) dirty in layout phase: $runtimeType");
    _pendingDirtyNodeIds.addAll(nodeIds);
    _dirtyCallback?.call();
  }
  // ═══ END ANSELM PATCH ════════════════════════════════════════════════════════════════════════════

  /// Marks this phase as needing to re-run its view model calculations.
  @protected
  void markDirty() {
    editorLayoutLog.info("Marking a layout phase as dirty: $runtimeType");
    // ANSELM PATCH (ADR 0009): whole-phase dirt subsumes any node-scoped dirt. 全相脏吞并节点级脏。
    _pendingWholePhaseDirty = true;
    _dirtyCallback?.call();
  }

  /// Styles a [SingleColumnLayoutViewModel] by adjusting the given viewModel.
  SingleColumnLayoutViewModel style(Document document, SingleColumnLayoutViewModel viewModel);
}

/// [AttributionStyleBuilder] that returns a default `TextStyle`, for
/// use when creating baseline view models before the text styles are
/// configured.
TextStyle noStyleBuilder(Set<Attribution> attributions) {
  return const TextStyle(
    // Even though this a "no style" builder, we supply a font size
    // and line height because there are a number of places in the editor
    // where these details are needed for layout calculations.
    fontSize: 16,
    height: 1.0,
  );
}

/// View model for an entire [SingleColumnDocumentLayout].
class SingleColumnLayoutViewModel {
  SingleColumnLayoutViewModel({
    this.padding = EdgeInsets.zero,
    required List<SingleColumnLayoutComponentViewModel> componentViewModels,
  })  : _componentViewModels = componentViewModels,
        _viewModelsByNodeId = {} {
    for (final componentViewModel in _componentViewModels) {
      _viewModelsByNodeId[componentViewModel.nodeId] = componentViewModel;
    }
  }

  final EdgeInsetsGeometry padding;

  final List<SingleColumnLayoutComponentViewModel> _componentViewModels;
  List<SingleColumnLayoutComponentViewModel> get componentViewModels => _componentViewModels;

  final Map<String, SingleColumnLayoutComponentViewModel> _viewModelsByNodeId;
  SingleColumnLayoutComponentViewModel? getComponentViewModelByNodeId(String nodeId) => _viewModelsByNodeId[nodeId];
}

/// Base class for a component view model that appears within a
/// [SingleColumnDocumentLayout].
abstract class SingleColumnLayoutComponentViewModel {
  SingleColumnLayoutComponentViewModel({
    required this.nodeId,
    required this.createdAt,
    this.maxWidth,
    required this.padding,
    this.opacity = 1.0,
  });

  final String nodeId;

  /// When view model's corresponding node was created, which can be used for
  /// making decisions about animated invalidations.
  ///
  /// Reporting the creation time is optional. Stylers must handle cases where
  /// no creation timestamp is available.
  DateTime? createdAt;

  /// The maximum width of this component in the layout, or `null` to
  /// defer to the layout's preference.
  double? maxWidth;

  /// The padding applied around this component.
  EdgeInsetsGeometry padding;

  /// The opacity of this whole node.
  double opacity;

  void applyStyles(Map<String, dynamic> styles) {
    maxWidth = styles[Styles.maxWidth] ?? double.infinity;
    padding = (styles[Styles.padding] as CascadingPadding?)?.toEdgeInsets() ?? EdgeInsets.zero;
    opacity = styles[Styles.opacity] ?? 1.0;
  }

  SingleColumnLayoutComponentViewModel copy();

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SingleColumnLayoutComponentViewModel &&
          runtimeType == other.runtimeType &&
          nodeId == other.nodeId &&
          createdAt == other.createdAt &&
          maxWidth == other.maxWidth &&
          padding == other.padding &&
          opacity == other.opacity;

  @override
  int get hashCode => nodeId.hashCode ^ createdAt.hashCode ^ maxWidth.hashCode ^ padding.hashCode ^ opacity.hashCode;
}
