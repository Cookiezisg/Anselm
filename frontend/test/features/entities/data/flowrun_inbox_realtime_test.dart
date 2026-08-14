import 'dart:async';

import 'package:anselm/core/net/api_client.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/core/sse/sse_connection.dart';
import 'package:anselm/core/sse/sse_gateway.dart';
import 'package:anselm/features/entities/data/entity_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSseConnection extends SseConnection {
  _FakeSseConnection()
    : super(
        streamPath: '/stream',
        baseUrl: 'http://127.0.0.1:9/',
        workspaceId: () => null,
        authToken: () => null,
      );

  final envelopesController = StreamController<StreamEnvelope>.broadcast();
  final resyncController = StreamController<void>.broadcast();

  @override
  Stream<StreamEnvelope> get envelopes => envelopesController.stream;

  @override
  Stream<void> get resync => resyncController.stream;

  @override
  void start() {}

  @override
  Future<void> stop() async {
    await envelopesController.close();
    await resyncController.close();
  }
}

StreamEnvelope _signal({
  required int seq,
  required StreamScope scope,
  required String id,
  required String type,
  Map<String, dynamic>? content,
}) => StreamEnvelope(
  seq: seq,
  scope: scope,
  id: id,
  frame: FrameSignal(
    node: StreamNode(type: type, content: content),
  ),
);

void main() {
  test(
    'flowrun inbox seam only emits durable parking/terminal pulses and pairs both resyncs',
    () async {
      final connections = {
        for (final name in StreamName.values) name: _FakeSseConnection(),
      };
      final gateway = SseGateway(
        baseUrl: 'http://127.0.0.1:9/',
        workspaceId: () => null,
        authToken: () => null,
        connectionFactory: (name) => connections[name]!,
      );
      final api = ApiClient(
        dio: Dio(BaseOptions(baseUrl: 'http://127.0.0.1:9/')),
        workspaceId: () => 'ws_1',
        authToken: () => 't',
      );
      final repo = LiveEntityRepository(api: api, sse: gateway);
      var pulses = 0;
      var resyncs = 0;
      final pulseSub = repo.flowrunInboxSignals().listen((_) => pulses++);
      final resyncSub = repo.flowrunInboxResync().listen((_) => resyncs++);

      connections[StreamName.notifications]!.envelopesController.add(
        _signal(
          seq: 0,
          scope: const StreamScope(kind: 'notification', id: 'n_ephemeral'),
          id: 'n_ephemeral',
          type: 'workflow.approval_pending',
        ),
      );
      connections[StreamName.notifications]!.envelopesController.add(
        _signal(
          seq: 1,
          scope: const StreamScope(kind: 'notification', id: 'n_other'),
          id: 'n_other',
          type: 'workflow.updated',
        ),
      );
      connections[StreamName.notifications]!.envelopesController.add(
        _signal(
          seq: 2,
          scope: const StreamScope(kind: 'notification', id: 'n_approval'),
          id: 'n_approval',
          type: 'workflow.approval_pending',
        ),
      );
      connections[StreamName.entities]!.envelopesController.add(
        _signal(
          seq: 3,
          scope: const StreamScope(kind: 'workflow', id: 'wf_1'),
          id: 'terminal',
          type: 'run_terminal',
        ),
      );
      connections[StreamName.entities]!.envelopesController.add(
        _signal(
          seq: 0,
          scope: const StreamScope(kind: 'workflow', id: 'wf_1'),
          id: 'tick',
          type: 'run_terminal',
        ),
      );
      await pumpEventQueue();
      expect(pulses, 2);

      connections[StreamName.notifications]!.resyncController.add(null);
      connections[StreamName.entities]!.resyncController.add(null);
      await pumpEventQueue();
      expect(resyncs, 2);

      await pulseSub.cancel();
      await resyncSub.cancel();
      await gateway.dispose();
    },
  );
}
