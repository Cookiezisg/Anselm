import 'dart:async';

import 'package:anselm/core/contract/api_error.dart';
import 'package:anselm/core/contract/attachment.dart';
import 'package:anselm/core/contract/model_capability.dart';
import 'package:anselm/core/model/model_capabilities.dart';
import 'package:anselm/core/contract/conversation.dart';
import 'package:anselm/core/contract/messages/chat_message.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/media/media_source.dart';
import 'package:anselm/core/net/api_client.dart';
import 'package:anselm/core/router/navigation.dart';
import 'package:anselm/core/sse/frame.dart';
import 'package:anselm/core/ui/ui.dart';
import 'package:anselm/features/chat/data/chat_fixtures.dart';
import 'package:anselm/features/chat/data/chat_repository.dart';
import 'package:anselm/features/chat/data/chat_providers.dart';
import 'package:anselm/features/chat/state/attachment_audio_player.dart';
import 'package:anselm/features/chat/state/chat_drafts.dart';
import 'package:anselm/features/chat/state/conversation_stream_provider.dart';
import 'package:anselm/features/chat/state/selected_conversation.dart';
import 'package:anselm/features/chat/model/conversation_transcript.dart';
import 'package:anselm/features/chat/ui/chat_thinking.dart';
import 'package:anselm/features/chat/ui/chat_transcript.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// The transcript view. Pins: phase surfaces, block dispatch to the locked modules (markdown /
// thinking / tool placeholder / cancelled banner), LIVE streaming reaching the leaf, the BuildSpy
// gate (streaming rebuilds ONLY the live leaf — page 0 / settled rows 0), the center-sliver
// prepend (pixels do not move), and the bottom pin (follows while pinned, holds while scrolled up).
// transcript 视图钉:相位面、块派发、流式到叶、BuildSpy 门禁(流式只重建 live 叶——页 0/settled 行 0)、
// center-sliver prepend 零位移、贴底跟随(钉住跟、上翻不动)。

const _scope = StreamScope(kind: 'conversation', id: 'cv_1');

StreamEnvelope _open(
  String id,
  String type, {
  String? parentId,
  Map<String, dynamic>? content,
}) => StreamEnvelope(
  seq: 5,
  scope: _scope,
  id: id,
  frame: FrameOpen(
    parentId: parentId,
    node: StreamNode(type: type, content: content),
  ),
);

StreamEnvelope _delta(String id, String chunk) => StreamEnvelope(
  seq: 0,
  scope: _scope,
  id: id,
  frame: FrameDelta(chunk: chunk),
);

StreamEnvelope _close(
  String id,
  String type,
  Map<String, dynamic> result, {
  String status = 'completed',
}) => StreamEnvelope(
  seq: 6,
  scope: _scope,
  id: id,
  frame: FrameClose(
    status: status,
    result: StreamNode(type: type, content: result),
  ),
);

Conversation _conv(String id) {
  final at = DateTime.utc(2026, 7, 2, 9);
  return Conversation(
    id: id,
    title: 'T',
    createdAt: at,
    updatedAt: at,
    lastMessageAt: at,
  );
}

ChatMessage _turn(
  String id,
  String role, {
  String status = 'completed',
  String stopReason = '',
  int hour = 10,
  List<ChatBlock> blocks = const [],
}) => ChatMessage(
  id: id,
  conversationId: 'cv_1',
  role: role,
  status: status,
  stopReason: stopReason,
  blocks: blocks,
  createdAt: DateTime.utc(2026, 7, 2, hour),
);

ChatBlock _blk(
  String id,
  String type,
  String content, {
  Map<String, dynamic>? attrs,
}) => ChatBlock(
  id: id,
  type: type,
  content: content,
  status: 'completed',
  attrs: attrs,
);

/// The capability catalog every transcript host hands the retry menu (WRK-077 CH-c). Two entries so a test can
/// tell「换模型重试」picked the RIGHT one rather than merely picked something.
/// 每个 transcript 宿主交给重试菜单的能力目录(WRK-077 CH-c)。两项,使测试能分辨「换模型重试」挑对了、而不只是挑了个东西。
const _caps = [
  ModelCapability(
    apiKeyId: 'ak_1',
    modelId: 'gpt-4o',
    displayName: 'GPT-4o',
    provider: 'openai',
  ),
  ModelCapability(
    apiKeyId: 'ak_2',
    modelId: 'deepseek-chat',
    displayName: 'DeepSeek Chat',
    provider: 'deepseek',
  ),
];

class _FakeSelected extends SelectedConversation {
  @override
  ConversationRef? build() => const ConversationRef('cv_1');
}

Widget _host(
  FixtureChatRepository repo, {
  String conversationId = 'cv_1',
  List<Override> overrides = const [],
}) => ProviderScope(
  overrides: [
    chatRepositoryProvider.overrideWithValue(repo),
    selectedConversationProvider.overrideWith(_FakeSelected.new),
    // The tail assistant turn's action row offers「换模型重试」, so the transcript now reads the capability
    // catalog. Left un-overridden it reaches the real api client, fails, and Riverpod's default backoff leaves
    // a pending timer AFTER the tree is disposed — which the test binding rightly calls an error. Every other
    // suite that mounts a model picker overrides it the same way (chat_head_test / chat_composer_test).
    // 尾巴上 assistant 回合的动作排提供「换模型重试」,故 transcript 现在会读能力目录。不 override 它就会打到真 api
    // client、失败,而 Riverpod 默认退避会在树销毁**之后**留下一个 pending timer——测试 binding 理应把它判为错误。
    // 其余每个挂载模型选择器的套件都这样 override(chat_head_test / chat_composer_test)。
    modelCapabilitiesProvider.overrideWith((ref) async => _caps),
    ...overrides,
  ],
  child: TranslationProvider(
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AnTheme.light(),
      home: Scaffold(body: ChatTranscriptView(conversationId: conversationId)),
    ),
  ),
);

/// A ROUTED transcript host — the fork action navigates with `context.go`, which the bare-MaterialApp
/// [_host] cannot serve. Returns the container + router so a test can read the drafts store and the
/// landed path. 路由版 transcript 宿主——分叉动作用 context.go 导航,裸 MaterialApp 的 _host 服务不了。
(Widget, ProviderContainer, GoRouter) _hostRouted(FixtureChatRepository repo) {
  const view = Scaffold(body: ChatTranscriptView(conversationId: 'cv_1'));
  final router = GoRouter(
    initialLocation: '/chat/cv_1',
    routes: [
      GoRoute(path: '/', builder: (_, _) => view),
      GoRoute(path: '/chat/:id', builder: (_, _) => view),
    ],
  );
  addTearDown(router.dispose);
  final container = ProviderContainer(
    overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
      selectedConversationProvider.overrideWith(_FakeSelected.new),
      goRouterProvider.overrideWithValue(router),
      modelCapabilitiesProvider.overrideWith((ref) async => _caps),
    ],
  );
  addTearDown(container.dispose);
  final w = UncontrolledProviderScope(
    container: container,
    child: TranslationProvider(
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: AnTheme.light(),
        routerConfig: router,
      ),
    ),
  );
  return (w, container, router);
}

FixtureChatRepository _repo({Map<String, List<ChatMessage>>? messages}) =>
    FixtureChatRepository(
      conversations: [_conv('cv_1')],
      messages: messages ?? {'cv_1': []},
    );

/// Frames reach the leaf via stream-microtask → coalesced postFrame notify → next-frame build — three
/// pumps in the test binding (production frames run continuously). 帧到叶需 3 泵(生产帧连续、无此事)。
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

class _FakeAudioDriver implements AttachmentAudioDriver {
  final positions = StreamController<Duration>.broadcast();
  final durations = StreamController<Duration>.broadcast();
  final statuses = StreamController<AttachmentAudioStatus>.broadcast();
  final playUrls = <String>[];
  final seeks = <Duration>[];
  var stopCalls = 0;
  var disposeCalls = 0;

  @override
  Stream<Duration> get positionStream => positions.stream;

  @override
  Stream<Duration> get durationStream => durations.stream;

  @override
  Stream<AttachmentAudioStatus> get statusStream => statuses.stream;

  @override
  Future<void> playUrl(String url, {String? mimeType}) async {
    playUrls.add(url);
    statuses.add(AttachmentAudioStatus.playing);
  }

  @override
  Future<void> seek(Duration position) async {
    seeks.add(position);
    positions.add(position);
  }

  @override
  Future<void> pause() async => statuses.add(AttachmentAudioStatus.paused);

  @override
  Future<void> resume() async => statuses.add(AttachmentAudioStatus.playing);

  @override
  Future<void> stop() async {
    stopCalls++;
    statuses.add(AttachmentAudioStatus.stopped);
  }

  @override
  Future<void> dispose() async {
    disposeCalls++;
    await positions.close();
    await durations.close();
    await statuses.close();
  }
}

class _DelayedReadAloudSource implements MediaSource {
  final pending = Completer<ReadAloudResult>();
  var readCalls = 0;

  @override
  Future<bool> readAloudAvailable() async => true;

  @override
  Future<ReadAloudResult> readAloud(String text, {String? voice}) {
    readCalls++;
    return pending.future;
  }

  @override
  Future<AttachmentMeta> meta(String id) => throw UnimplementedError();

  @override
  Future<List<int>> bytes(String id) => throw UnimplementedError();

  @override
  NativeFetchTarget nativeTarget(String id) => const NativeFetchTarget(
    uri: 'http://127.0.0.1/fixture-audio',
    headers: {},
  );

  @override
  Future<AttachmentMeta> upload({
    required List<int> bytes,
    required String filename,
    required String mimeType,
  }) => throw UnimplementedError();
}

class _OfflineAttachmentRepository extends FixtureChatRepository {
  _OfflineAttachmentRepository({
    required super.conversations,
    required super.messages,
    this.offlinePlaybackLeaseIds = const {},
    this.missingPlaybackLeaseIds = const {},
  });

  final Set<String> offlinePlaybackLeaseIds;
  final Set<String> missingPlaybackLeaseIds;

  @override
  Future<AttachmentPlaybackLease> createAttachmentPlaybackLease(
    String id,
  ) async {
    if (offlinePlaybackLeaseIds.contains(id)) {
      throw ApiException.transport('connection refused');
    }
    if (missingPlaybackLeaseIds.contains(id)) {
      throw const ApiException(
        code: 'ATTACHMENT_NOT_FOUND',
        message: 'attachment not found',
        httpStatus: 404,
      );
    }
    return super.createAttachmentPlaybackLease(id);
  }
}

void main() {
  tearDown(() => TranscriptProbe.onBuild = null);

  testWidgets(
    'read-aloud synthesis exposes a stable preparation state and blocks repeats',
    (tester) async {
      final repo = _repo(
        messages: {
          'cv_1': [
            _turn(
              'msg_a',
              'assistant',
              blocks: [_blk('b_a', 'text', 'A reply worth hearing.')],
            ),
          ],
        },
      );
      final source = _DelayedReadAloudSource();
      final driver = _FakeAudioDriver();
      repo.attachmentMetas['att_read_aloud'] = const AttachmentMeta(
        id: 'att_read_aloud',
        filename: 'read-aloud.wav',
        mimeType: 'audio/wav',
        sizeBytes: 1,
        kind: 'audio',
      );
      await tester.pumpWidget(
        _host(
          repo,
          overrides: [
            mediaSourceProvider.overrideWithValue(source),
            attachmentAudioDriverFactoryProvider.overrideWithValue(
              () => driver,
            ),
          ],
        ),
      );
      await tester.pump();
      await _settle(tester);

      final t = Translations.of(
        tester.element(find.byType(ChatTranscriptView)),
      );
      final ready = find.byTooltip(t.chat.actions.readAloud);
      expect(ready, findsOneWidget);
      final restingSize = tester.getSize(ready);
      final restingCenter = tester.getCenter(ready);

      await tester.tap(ready);
      await tester.pump();

      final preparing = find.byTooltip(t.chat.actions.readAloudPreparing);
      expect(preparing, findsOneWidget);
      expect(find.byType(AnSpinner), findsOneWidget);
      expect(source.readCalls, 1);
      expect(tester.getSize(preparing), restingSize);
      expect(tester.getCenter(preparing), restingCenter);

      // The busy button is inert, so a second physical tap cannot start another synthesis.
      // 忙态按钮惰性，第二次真实点击不能再起一条合成请求。
      await tester.tap(preparing, warnIfMissed: false);
      expect(source.readCalls, 1);

      source.pending.complete(
        const ReadAloudResult(
          attachmentId: 'att_read_aloud',
          mimeType: 'audio/wav',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));
      expect(find.byTooltip(t.chat.actions.readAloudStop), findsOneWidget);
      expect(find.byType(AnSpinner), findsNothing);
    },
  );

  testWidgets('hydrated history dispatches blocks to the locked modules', (
    tester,
  ) async {
    final repo = _repo(
      messages: {
        'cv_1': [
          _turn(
            'msg_u',
            'user',
            hour: 10,
            blocks: [_blk('bu', 'text', '帮我看下这个')],
          ),
          _turn(
            'msg_a',
            'assistant',
            hour: 11,
            blocks: [
              _blk('br', 'reasoning', '想一想'),
              _blk('bt', 'text', '**答案**在这'),
              _blk('bc', 'tool_call', '{}', attrs: {'tool': 'web_search'}),
            ],
          ),
          _turn(
            'msg_c',
            'assistant',
            hour: 12,
            status: 'cancelled',
            stopReason: 'cancelled',
            blocks: [_blk('bt2', 'text', '半截')],
          ),
        ],
      },
    );
    await tester.pumpWidget(_host(repo));
    await tester.pump(); // hydration future 水化
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('帮我看下这个'), findsOneWidget); // user bubble 用户泡
    expect(
      find.byType(ChatThinking),
      findsOneWidget,
    ); // reasoning → thinking module
    expect(find.byType(AnMarkdown), findsWidgets); // text → markdown
    expect(find.text('web_search'), findsOneWidget); // tool placeholder V3 前占位
    final t = Translations.of(tester.element(find.byType(ChatTranscriptView)));
    expect(
      find.textContaining(t.chat.stoppedCancelled),
      findsOneWidget,
    ); // honest banner 诚实横幅
  });

  testWidgets(
    'live streaming: open → deltas grow the leaf → close settles; pinned view follows',
    (tester) async {
      final repo = _repo();
      await tester.pumpWidget(_host(repo));
      await tester.pump();

      repo.emitFrame(
        'cv_1',
        _open('msg_a', 'message', content: {'role': 'assistant'}),
      );
      repo.emitFrame(
        'cv_1',
        _open('b1', 'text', parentId: 'msg_a', content: {'content': ''}),
      );
      await _settle(tester);

      repo.emitFrame('cv_1', _delta('b1', '第一段'));
      await _settle(tester);
      expect(find.textContaining('第一段', findRichText: true), findsOneWidget);

      repo.emitFrame('cv_1', _delta('b1', ',更多'));
      await _settle(tester);
      expect(find.textContaining('第一段,更多', findRichText: true), findsOneWidget);

      repo.emitFrame('cv_1', _close('b1', 'text', {'content': '第一段,更多'}));
      repo.emitFrame(
        'cv_1',
        _close('msg_a', 'message', {
          'role': 'assistant',
          'status': 'completed',
          'stopReason': 'end_turn',
        }),
      );
      await _settle(tester);
      expect(find.textContaining('第一段,更多', findRichText: true), findsOneWidget);
    },
  );

  testWidgets(
    'pending bubble reconciliation cannot crash a lazy transcript child builder',
    (tester) async {
      final repo = _repo();
      await tester.pumpWidget(_host(repo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ChatTranscriptView)),
      );
      final controller = container.read(
        conversationStreamProvider('cv_1').notifier,
      );
      controller.transcript.mutate(
        (t) => t..addPending(PendingSend(localId: 'local_1', text: 'pending')),
      );
      await _settle(tester);

      // The durable echo clears the mutable source list while the sliver remains mounted. The
      // builder must use its build snapshot, not read a shorter list through an old index.
      // durable 回声在 sliver 仍挂载时清空可变源列表；builder 必须读本次 build 快照，不能用旧下标读短列表。
      repo.emitFrame(
        'cv_1',
        _open('msg_user', 'message', content: {'role': 'user'}),
      );
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(controller.transcript.value.pending, isEmpty);
    },
  );

  testWidgets(
    'a user bubble resolves attachment ids to filename cards (missing → tombstone)',
    (tester) async {
      final repo = _repo(
        messages: {
          'cv_1': [
            _turn('msg_u', 'user', blocks: [_blk('bu', 'text', '看这个文件')]),
          ],
        },
      );
      // attrs carry the id-only snapshot 纯 id 快照
      repo.attachmentMetas['att_ok'] = const AttachmentMeta(
        id: 'att_ok',
        filename: 'report.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 2048,
        kind: 'document',
      );
      final msgs = await repo.listMessages('cv_1');
      final withAtt = ChatMessage(
        id: 'msg_u',
        conversationId: 'cv_1',
        role: 'user',
        status: 'completed',
        attrs: {
          'attachments': ['att_ok', 'att_gone'],
        },
        blocks: msgs.items.single.blocks,
        createdAt: DateTime.utc(2026, 7, 2, 10),
      );
      repo.replaceMessage('cv_1', withAtt);

      await tester.pumpWidget(_host(repo));
      await tester.pump();
      await _settle(tester);
      await tester.pump(const Duration(milliseconds: 30)); // meta futures 元数据
      expect(find.text('report.pdf'), findsOneWidget); // resolved 解析成名
      expect(
        find.text('att_gone'),
        findsOneWidget,
      ); // missing keeps the honest id 缺失留 id
    },
  );

  testWidgets(
    'an image attachment renders a REAL thumbnail (bytes from the seam, cached by id)',
    (tester) async {
      // 1x1 transparent PNG 一像素透明图
      const png = [
        0x89,
        0x50,
        0x4E,
        0x47,
        0x0D,
        0x0A,
        0x1A,
        0x0A,
        0x00,
        0x00,
        0x00,
        0x0D,
        0x49,
        0x48,
        0x44,
        0x52,
        0x00,
        0x00,
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x01,
        0x08,
        0x06,
        0x00,
        0x00,
        0x00,
        0x1F,
        0x15,
        0xC4,
        0x89,
        0x00,
        0x00,
        0x00,
        0x0D,
        0x49,
        0x44,
        0x41,
        0x54,
        0x78,
        0x9C,
        0x63,
        0x00,
        0x01,
        0x00,
        0x00,
        0x05,
        0x00,
        0x01,
        0x0D,
        0x0A,
        0x2D,
        0xB4,
        0x00,
        0x00,
        0x00,
        0x00,
        0x49,
        0x45,
        0x4E,
        0x44,
        0xAE,
        0x42,
        0x60,
        0x82,
      ];
      final repo = _repo(
        messages: {
          'cv_1': [
            ChatMessage(
              id: 'msg_u',
              conversationId: 'cv_1',
              role: 'user',
              status: 'completed',
              attrs: {
                'attachments': ['att_img'],
              },
              blocks: [_blk('bu', 'text', '看图')],
              createdAt: DateTime.utc(2026, 7, 2, 10),
            ),
          ],
        },
      );
      repo.attachmentMetas['att_img'] = const AttachmentMeta(
        id: 'att_img',
        filename: 'shot.png',
        mimeType: 'image/png',
        sizeBytes: 68,
        kind: 'image',
      );
      repo.attachmentBytes['att_img'] = png;

      await tester.pumpWidget(_host(repo));
      await tester.pump();
      await _settle(tester);
      await tester.pump(
        const Duration(milliseconds: 50),
      ); // meta + bytes futures
      await tester.pump(const Duration(milliseconds: 50)); // decode frame 解码帧
      expect(
        find.byType(AnAttachmentThumb),
        findsOneWidget,
      ); // a thumb, not a file card 缩略非文件卡
      expect(find.byType(AnAttachmentCard), findsNothing);
    },
  );

  testWidgets(
    'an audio attachment in history is playable from a short loopback lease',
    (tester) async {
      final repo = _repo(
        messages: {
          'cv_1': [
            ChatMessage(
              id: 'msg_u',
              conversationId: 'cv_1',
              role: 'user',
              status: 'completed',
              attrs: {
                'attachments': ['att_audio'],
              },
              blocks: [_blk('bu', 'text', '听这个')],
              createdAt: DateTime.utc(2026, 7, 2, 10),
            ),
          ],
        },
      );
      repo.attachmentMetas['att_audio'] = const AttachmentMeta(
        id: 'att_audio',
        filename: 'voice.webm',
        mimeType: 'audio/webm',
        sizeBytes: 3,
        kind: 'audio',
      );
      final driver = _FakeAudioDriver();

      await tester.pumpWidget(
        _host(
          repo,
          overrides: [
            attachmentAudioDriverFactoryProvider.overrideWithValue(
              () => driver,
            ),
          ],
        ),
      );
      await tester.pump();
      await _settle(tester);
      await tester.pump(const Duration(milliseconds: 30)); // metadata future

      expect(find.text('voice.webm'), findsOneWidget);
      expect(find.bySemanticsLabel('Play audio'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Play audio'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(driver.playUrls, ['http://127.0.0.1/fixture-audio/att_audio']);
      expect(find.bySemanticsLabel('Pause audio'), findsOneWidget);
    },
  );

  testWidgets(
    'an audio attachment in history surfaces media preparation state',
    (tester) async {
      final repo = _repo(
        messages: {
          'cv_1': [
            ChatMessage(
              id: 'msg_u',
              conversationId: 'cv_1',
              role: 'user',
              status: 'completed',
              attrs: {
                'attachments': ['att_audio'],
              },
              blocks: [_blk('bu', 'text', '听这个')],
              createdAt: DateTime.utc(2026, 7, 2, 10),
            ),
          ],
        },
      );
      repo.attachmentMetas['att_audio'] = const AttachmentMeta(
        id: 'att_audio',
        filename: 'voice.webm',
        mimeType: 'audio/webm',
        sizeBytes: 3,
        kind: 'audio',
        preparation: AttachmentPreparation(phase: 'processing'),
      );
      repo.attachmentBytes['att_audio'] = [7, 8, 9];

      await tester.pumpWidget(_host(repo));
      await tester.pump();
      await _settle(tester);
      await tester.pump(const Duration(milliseconds: 30)); // metadata future

      expect(find.text('voice.webm'), findsOneWidget);
      expect(find.text('Preparing media…'), findsOneWidget);
      expect(find.bySemanticsLabel('Play audio'), findsOneWidget);
    },
  );

  testWidgets(
    'an audio attachment timestamp reference seeks the active player',
    (tester) async {
      final repo = _repo(
        messages: {
          'cv_1': [
            ChatMessage(
              id: 'msg_u',
              conversationId: 'cv_1',
              role: 'user',
              status: 'completed',
              attrs: {
                'attachments': ['att_audio'],
                'audioTimestamps': {'att_audio': 65000},
              },
              blocks: [_blk('bu', 'text', '听这个时间点')],
              createdAt: DateTime.utc(2026, 7, 2, 10),
            ),
          ],
        },
      );
      repo.attachmentMetas['att_audio'] = const AttachmentMeta(
        id: 'att_audio',
        filename: 'voice.webm',
        mimeType: 'audio/webm',
        sizeBytes: 3,
        kind: 'audio',
      );
      repo.attachmentBytes['att_audio'] = [7, 8, 9];
      final driver = _FakeAudioDriver();

      await tester.pumpWidget(
        _host(
          repo,
          overrides: [
            attachmentAudioDriverFactoryProvider.overrideWithValue(
              () => driver,
            ),
          ],
        ),
      );
      await tester.pump();
      await _settle(tester);
      await tester.pump(const Duration(milliseconds: 30)); // metadata future

      await tester.tap(find.bySemanticsLabel('Play audio'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(find.bySemanticsLabel('Jump to 1:05'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Jump to 1:05'));
      await tester.pump();

      expect(driver.seeks, [const Duration(seconds: 65)]);
    },
  );

  testWidgets(
    'an offline audio playback lease shows a retryable playback offline line',
    (tester) async {
      final repo = _OfflineAttachmentRepository(
        conversations: [_conv('cv_1')],
        messages: {
          'cv_1': [
            ChatMessage(
              id: 'msg_u',
              conversationId: 'cv_1',
              role: 'user',
              status: 'completed',
              attrs: {
                'attachments': ['att_audio'],
              },
              blocks: [_blk('bu', 'text', '听这个')],
              createdAt: DateTime.utc(2026, 7, 2, 10),
            ),
          ],
        },
        offlinePlaybackLeaseIds: {'att_audio'},
      );
      repo.attachmentMetas['att_audio'] = const AttachmentMeta(
        id: 'att_audio',
        filename: 'voice.webm',
        mimeType: 'audio/webm',
        sizeBytes: 3,
        kind: 'audio',
      );
      final driver = _FakeAudioDriver();

      await tester.pumpWidget(
        _host(
          repo,
          overrides: [
            attachmentAudioDriverFactoryProvider.overrideWithValue(
              () => driver,
            ),
          ],
        ),
      );
      await tester.pump();
      await _settle(tester);
      await tester.pump(const Duration(milliseconds: 30)); // metadata future

      await tester.tap(find.bySemanticsLabel('Play audio'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(driver.playUrls, isEmpty);
      expect(find.text('Offline — tap to retry playback'), findsOneWidget);
      expect(find.bySemanticsLabel('Play audio'), findsOneWidget);
    },
  );

  testWidgets(
    'an audio attachment whose original content is gone becomes an unavailable tombstone',
    (tester) async {
      final repo = _OfflineAttachmentRepository(
        conversations: [_conv('cv_1')],
        messages: {
          'cv_1': [
            ChatMessage(
              id: 'msg_u',
              conversationId: 'cv_1',
              role: 'user',
              status: 'completed',
              attrs: {
                'attachments': ['att_audio'],
              },
              blocks: [_blk('bu', 'text', '听这个')],
              createdAt: DateTime.utc(2026, 7, 2, 10),
            ),
          ],
        },
        missingPlaybackLeaseIds: {'att_audio'},
      );
      repo.attachmentMetas['att_audio'] = const AttachmentMeta(
        id: 'att_audio',
        filename: 'voice.webm',
        mimeType: 'audio/webm',
        sizeBytes: 3,
        kind: 'audio',
      );
      final driver = _FakeAudioDriver();

      await tester.pumpWidget(
        _host(
          repo,
          overrides: [
            attachmentAudioDriverFactoryProvider.overrideWithValue(
              () => driver,
            ),
          ],
        ),
      );
      await tester.pump();
      await _settle(tester);
      await tester.pump(const Duration(milliseconds: 30)); // metadata future

      await tester.tap(find.bySemanticsLabel('Play audio'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 20));

      expect(driver.playUrls, isEmpty);
      expect(find.text('Unavailable'), findsOneWidget);
      expect(find.bySemanticsLabel('Play audio'), findsNothing);
      expect(
        find.bySemanticsLabel('Playback not available yet'),
        findsOneWidget,
      );
    },
  );

  testWidgets('audio playback stops when switching transcript conversation', (
    tester,
  ) async {
    final repo = FixtureChatRepository(
      conversations: [_conv('cv_1'), _conv('cv_2')],
      messages: {
        'cv_1': [
          ChatMessage(
            id: 'msg_u',
            conversationId: 'cv_1',
            role: 'user',
            status: 'completed',
            attrs: {
              'attachments': ['att_audio'],
            },
            blocks: [_blk('bu', 'text', '听这个')],
            createdAt: DateTime.utc(2026, 7, 2, 10),
          ),
        ],
        'cv_2': [],
      },
    );
    repo.attachmentMetas['att_audio'] = const AttachmentMeta(
      id: 'att_audio',
      filename: 'voice.webm',
      mimeType: 'audio/webm',
      sizeBytes: 3,
      kind: 'audio',
    );
    repo.attachmentBytes['att_audio'] = [7, 8, 9];
    final driver = _FakeAudioDriver();
    final overrides = [
      attachmentAudioDriverFactoryProvider.overrideWithValue(() => driver),
    ];

    await tester.pumpWidget(_host(repo, overrides: overrides));
    await tester.pump();
    await _settle(tester);
    await tester.pump(const Duration(milliseconds: 30));
    await tester.tap(find.bySemanticsLabel('Play audio'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.bySemanticsLabel('Pause audio'), findsOneWidget);

    await tester.pumpWidget(
      _host(repo, conversationId: 'cv_2', overrides: overrides),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(driver.stopCalls, 1);
    expect(find.bySemanticsLabel('Pause audio'), findsNothing);
  });

  testWidgets('audio playback stops when transcript unmounts', (tester) async {
    final repo = _repo(
      messages: {
        'cv_1': [
          ChatMessage(
            id: 'msg_u',
            conversationId: 'cv_1',
            role: 'user',
            status: 'completed',
            attrs: {
              'attachments': ['att_audio'],
            },
            blocks: [_blk('bu', 'text', '听这个')],
            createdAt: DateTime.utc(2026, 7, 2, 10),
          ),
        ],
      },
    );
    repo.attachmentMetas['att_audio'] = const AttachmentMeta(
      id: 'att_audio',
      filename: 'voice.webm',
      mimeType: 'audio/webm',
      sizeBytes: 3,
      kind: 'audio',
    );
    repo.attachmentBytes['att_audio'] = [7, 8, 9];
    final driver = _FakeAudioDriver();

    await tester.pumpWidget(
      _host(
        repo,
        overrides: [
          attachmentAudioDriverFactoryProvider.overrideWithValue(() => driver),
        ],
      ),
    );
    await tester.pump();
    await _settle(tester);
    await tester.pump(const Duration(milliseconds: 30));
    await tester.tap(find.bySemanticsLabel('Play audio'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(driver.stopCalls, 1);
  });

  testWidgets(
    'shorter-than-a-screen content docks to MIN — the first row clears the floating head',
    (tester) async {
      // One short turn: the anchored list would park pixels at 0 (first row under the head); the dock
      // must land on minScrollExtent, revealing the head-clearing padding above the anchor.
      // 一条短回合:锚定列表默认停 0(首行被头盖);dock 应落 min、露出锚上让头 padding。
      final repo = _repo(
        messages: {
          'cv_1': [
            _turn('msg_u', 'user', blocks: [_blk('bu', 'text', '短问题')]),
          ],
        },
      );
      await tester.pumpWidget(_host(repo));
      await tester.pump();
      await _settle(tester);

      final pos = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      expect(pos.maxScrollExtent, 0); // not a screenful below the anchor 锚下未满屏
      expect(
        pos.minScrollExtent,
        lessThan(0),
      ); // the head-clearing padding 让头 padding
      expect(pos.pixels, pos.minScrollExtent); // docked to the top 钉顶
    },
  );

  testWidgets(
    'BuildSpy gate: 200 streamed deltas rebuild ONLY the live leaf (page 0, settled rows 0)',
    (tester) async {
      final repo = _repo(
        messages: {
          'cv_1': [
            for (var i = 0; i < 6; i++)
              _turn(
                'msg_$i',
                i.isEven ? 'user' : 'assistant',
                hour: 9,
                blocks: [_blk('b$i', 'text', '历史 $i')],
              ),
          ],
        },
      );
      await tester.pumpWidget(_host(repo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      // Open the streaming turn, then instrument. 开流式回合后再挂探针。
      repo.emitFrame(
        'cv_1',
        _open('msg_live', 'message', content: {'role': 'assistant'}),
      );
      repo.emitFrame(
        'cv_1',
        _open('bl', 'text', parentId: 'msg_live', content: {'content': ''}),
      );
      await _settle(tester);

      final hits = <String, int>{};
      TranscriptProbe.onBuild = (zone) => hits[zone] = (hits[zone] ?? 0) + 1;

      const batches = 4;
      for (var b = 0; b < batches; b++) {
        for (var i = 0; i < 50; i++) {
          repo.emitFrame('cv_1', _delta('bl', 'x'));
        }
        await _settle(tester);
      }

      expect(
        hits['page'] ?? 0,
        0,
        reason: 'the page must NEVER rebuild while streaming 页级零重建',
      );
      expect(
        hits['row-settled'] ?? 0,
        0,
        reason:
            'settled rows are identity-cached — zero rebuilds while streaming settled 行零重建',
      );
      expect(
        hits['leaf-stream'] ?? 0,
        lessThanOrEqualTo(batches * 3 + 2),
        reason: 'the live leaf ticks ≤1×/frame (coalesced) live 叶每帧≤1',
      );
      expect(hits['list'] ?? 0, lessThanOrEqualTo(batches * 3 + 2));
    },
  );

  testWidgets('C-023: a SETTLED text block in an OPEN turn is memoized — zero re-parses while the open '
      'block streams', (tester) async {
    final repo = _repo(
      messages: {
        'cv_1': [
          _turn('msg_0', 'user', hour: 9, blocks: [_blk('b0', 'text', 'hi')]),
        ],
      },
    );
    await tester.pumpWidget(_host(repo));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));

    // Open an assistant turn holding a SETTLED text block (b1, closed) followed by a still-OPEN one (b2).
    // The whole open turn rebuilds on every b2 delta, so b1 is re-visited each tick. 开回合:落定块 b1 + 开块 b2。
    repo.emitFrame(
      'cv_1',
      _open('msg_live', 'message', content: {'role': 'assistant'}),
    );
    repo.emitFrame(
      'cv_1',
      _open('b1', 'text', parentId: 'msg_live', content: {'content': ''}),
    );
    repo.emitFrame('cv_1', _delta('b1', '已落定的一段文字'));
    repo.emitFrame('cv_1', _close('b1', 'text', {'content': '已落定的一段文字'}));
    repo.emitFrame(
      'cv_1',
      _open('b2', 'text', parentId: 'msg_live', content: {'content': ''}),
    );
    await _settle(tester);

    // Instrument AFTER b1 has settled + been cached. 落定+缓存后再挂探针。
    final hits = <String, int>{};
    TranscriptProbe.onBuild = (zone) => hits[zone] = (hits[zone] ?? 0) + 1;

    for (var i = 0; i < 40; i++) {
      repo.emitFrame('cv_1', _delta('b2', 'x'));
    }
    await _settle(tester);

    // The settled block is served from the id cache — NEVER re-parsed while b2 streams (the C-023 win;
    // without the cache this would be ~40, one GptMarkdown re-parse per tick). 落定块全程零重解析。
    expect(
      hits['block-text-parse'] ?? 0,
      0,
      reason:
          'a settled text block must be memoized — zero re-parses while the open block streams',
    );
    // The open block DOES re-parse per tick — proof the turn genuinely rebuilds (the assertion above is
    // not vacuous). 开块逐 tick 重解析(证回合真在重建,上断言非空转)。
    expect(
      hits['block-text-live'] ?? 0,
      greaterThan(0),
      reason:
          'the open block re-parses per tick (the open turn is genuinely rebuilding)',
    );
  });

  testWidgets('center-sliver prepend: loading an older page does NOT move pixels', (
    tester,
  ) async {
    final repo = _repo(
      messages: {
        'cv_1': [
          for (var i = 0; i < 45; i++)
            _turn(
              'msg_$i',
              i.isEven ? 'user' : 'assistant',
              hour: 9,
              blocks: [_blk('b$i', 'text', '第 $i 条,加一点长度让行高稳定一些。')],
            ),
        ],
      },
    );
    await tester.pumpWidget(_host(repo));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 30));

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    // Scroll up into the older region to trigger loadOlder. 上翻进近顶带触发 loadOlder。
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 4000));
    await tester.pump();
    final before = scrollable.position.pixels;
    await tester.pump(const Duration(milliseconds: 60)); // page lands 页落
    await tester.pump(const Duration(milliseconds: 20));
    expect(
      scrollable.position.pixels,
      closeTo(before, 0.5),
      reason:
          'prepend grows ABOVE the center anchor — reader position never shifts prepend 零位移',
    );
    expect(
      scrollable.position.minScrollExtent,
      lessThan(-100),
      reason:
          'the older page mounted ABOVE the anchor (negative extent) 老页挂在锚上方(负延伸)',
    );
  });

  testWidgets(
    'scrolled-up reader is not pushed by streaming; pinned reader follows to max',
    (tester) async {
      final repo = _repo(
        messages: {
          'cv_1': [
            for (var i = 0; i < 20; i++)
              _turn(
                'msg_$i',
                i.isEven ? 'user' : 'assistant',
                hour: 9,
                blocks: [_blk('b$i', 'text', '历史消息 $i —— 撑高度的一行文字。')],
              ),
          ],
        },
      );
      await tester.pumpWidget(_host(repo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );

      // Pinned: at bottom, streaming keeps us at max. 钉住:流式后仍在 max。
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      repo.emitFrame(
        'cv_1',
        _open('msg_a', 'message', content: {'role': 'assistant'}),
      );
      repo.emitFrame(
        'cv_1',
        _open('bl', 'text', parentId: 'msg_a', content: {'content': ''}),
      );
      for (var i = 0; i < 30; i++) {
        repo.emitFrame('cv_1', _delta('bl', '流式内容让回合越长越高。'));
      }
      await _settle(tester);
      expect(scrollable.position.pixels, scrollable.position.maxScrollExtent);

      // Scrolled up: more streaming must NOT move pixels. 上翻:继续流式不动 pixels。
      await tester.drag(find.byType(CustomScrollView), const Offset(0, 600));
      await tester.pump();
      final held = scrollable.position.pixels;
      for (var i = 0; i < 30; i++) {
        repo.emitFrame('cv_1', _delta('bl', '继续流。'));
      }
      await _settle(tester);
      expect(
        scrollable.position.pixels,
        closeTo(held, 0.5),
        reason:
            'growth is at the max end — an upward reader holds position 上翻阅读者不被推',
      );
    },
  );

  testWidgets('failed optimistic bubble: retry re-posts, discard removes', (
    tester,
  ) async {
    final repo = _repo();
    await tester.pumpWidget(_host(repo));
    await tester.pump();
    final t = Translations.of(tester.element(find.byType(ChatTranscriptView)));

    repo.failNextSend = true;
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ChatTranscriptView)),
    );
    await container
        .read(conversationStreamProvider('cv_1').notifier)
        .send('会失败的');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text(t.chat.sendFailed), findsOneWidget);

    await tester.tap(find.text(t.chat.retrySend));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    expect(repo.lastSend?.content, '会失败的'); // re-posted 已重发
    expect(find.text(t.chat.sendFailed), findsNothing);
  });

  testWidgets(
    'LLM_RESOLVE_ERROR banner grows the repick-model CTA that PATCHes the override (拍板 #16)',
    (tester) async {
      final repo = FixtureChatRepository(
        conversations: [_conv('cv_1')],
        messages: {
          'cv_1': [
            ChatMessage(
              id: 'msg_e',
              conversationId: 'cv_1',
              role: 'assistant',
              status: 'error',
              stopReason: 'error',
              errorCode: 'LLM_RESOLVE_ERROR',
              errorMessage: 'api key gone',
              blocks: const [],
              createdAt: DateTime.utc(2026, 7, 2, 10),
            ),
          ],
        },
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatRepositoryProvider.overrideWithValue(repo),
            selectedConversationProvider.overrideWith(_FakeSelected.new),
            modelCapabilitiesProvider.overrideWith(
              (ref) async => const [
                ModelCapability(
                  apiKeyId: 'ak_2',
                  modelId: 'deepseek-chat',
                  displayName: 'DeepSeek Chat',
                  provider: 'deepseek',
                ),
              ],
            ),
          ],
          child: TranslationProvider(
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AnTheme.light(),
              home: const Scaffold(
                body: ChatTranscriptView(conversationId: 'cv_1'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final t = Translations.of(
        tester.element(find.byType(ChatTranscriptView)),
      );
      expect(
        find.textContaining('LLM_RESOLVE_ERROR'),
        findsOneWidget,
        reason: '诚实横幅带 code',
      );
      expect(
        find.text(t.chat.repickModel),
        findsOneWidget,
        reason: 'CTA 只长在解析失败横幅上',
      );

      await tester.tap(find.text(t.chat.repickModel));
      await tester.pumpAndSettle();
      await tester.tap(find.text('DeepSeek Chat'));
      await tester.pumpAndSettle();
      final conv = await repo.getConversation('cv_1');
      expect(
        conv.modelOverride?.modelId,
        'deepseek-chat',
        reason: '选中即 PATCH 线程覆写',
      );
    },
  );

  testWidgets('a plain error banner carries NO repick CTA', (tester) async {
    final repo = FixtureChatRepository(
      conversations: [_conv('cv_1')],
      messages: {
        'cv_1': [
          ChatMessage(
            id: 'msg_e2',
            conversationId: 'cv_1',
            role: 'assistant',
            status: 'error',
            stopReason: 'error',
            errorCode: 'HANDLER_RPC_TIMEOUT',
            blocks: const [],
            createdAt: DateTime.utc(2026, 7, 2, 10),
          ),
        ],
      },
    );
    await tester.pumpWidget(_host(repo));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    final t = Translations.of(tester.element(find.byType(ChatTranscriptView)));
    expect(find.text(t.chat.repickModel), findsNothing);
  });

  testWidgets(
    'provider failure uses actionable copy instead of gateway details',
    (tester) async {
      final repo = FixtureChatRepository(
        conversations: [_conv('cv_1')],
        messages: {
          'cv_1': [
            ChatMessage(
              id: 'msg_provider_error',
              conversationId: 'cv_1',
              role: 'assistant',
              status: 'error',
              stopReason: 'error',
              errorCode: 'LLM_PROVIDER_ERROR',
              errorMessage: 'llm: provider error (504)',
              blocks: const [],
              createdAt: DateTime.utc(2026, 7, 2, 10),
            ),
          ],
        },
      );
      await tester.pumpWidget(_host(repo));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final t = Translations.of(
        tester.element(find.byType(ChatTranscriptView)),
      );
      expect(find.text(t.chat.providerError), findsOneWidget);
      expect(find.textContaining('LLM_PROVIDER_ERROR'), findsNothing);
      expect(find.textContaining('provider error (504)'), findsNothing);
    },
  );

  testWidgets(
    'loop terminal boundaries use actionable copy instead of internal codes',
    (tester) async {
      for (final entry in [
        (
          stop: 'error',
          code: 'CHAT_TURN_TIMEOUT',
          raw: 'CHAT_TURN_TIMEOUT · this reply took too long and was stopped',
          copy: (Translations t) => t.chat.chatTurnTimeout,
        ),
        (
          stop: 'max_steps',
          code: 'MAX_STEPS_REACHED',
          raw: 'MAX_STEPS_REACHED · reached the step limit before finishing',
          copy: (Translations t) => t.chat.stoppedMaxSteps,
        ),
        (
          stop: 'error',
          code: 'TOOL_ERROR_STORM',
          raw: 'TOOL_ERROR_STORM · 3 consecutive tool turns failed',
          copy: (Translations t) => t.chat.toolErrorStorm,
        ),
        (
          stop: 'error',
          code: 'CONTEXT_INPUT_TOO_LARGE',
          raw:
              'CONTEXT_INPUT_TOO_LARGE · the current indivisible input still exceeds the model context',
          copy: (Translations t) => t.chat.contextInputTooLarge,
        ),
      ]) {
        final repo = FixtureChatRepository(
          conversations: [_conv('cv_1')],
          messages: {
            'cv_1': [
              ChatMessage(
                id: 'msg_${entry.code}',
                conversationId: 'cv_1',
                role: 'assistant',
                status: 'error',
                stopReason: entry.stop,
                errorCode: entry.code,
                errorMessage: entry.raw,
                blocks: const [],
                createdAt: DateTime.utc(2026, 7, 2, 10),
              ),
            ],
          },
        );
        await tester.pumpWidget(_host(repo));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final t = Translations.of(
          tester.element(find.byType(ChatTranscriptView)),
        );
        expect(find.text(entry.copy(t)), findsOneWidget);
        expect(find.textContaining(entry.code), findsNothing);
        expect(find.textContaining(entry.raw), findsNothing);
      }
    },
  );

  testWidgets('LLM_MODEL_NOT_FOUND banner offers the same repick CTA', (
    tester,
  ) async {
    final repo = FixtureChatRepository(
      conversations: [_conv('cv_1')],
      messages: {
        'cv_1': [
          ChatMessage(
            id: 'msg_model_missing',
            conversationId: 'cv_1',
            role: 'assistant',
            status: 'error',
            stopReason: 'error',
            errorCode: 'LLM_MODEL_NOT_FOUND',
            errorMessage: 'llm: model not found (404)',
            blocks: const [],
            createdAt: DateTime.utc(2026, 7, 2, 10),
          ),
        ],
      },
    );
    await tester.pumpWidget(_host(repo));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final t = Translations.of(tester.element(find.byType(ChatTranscriptView)));
    expect(find.textContaining('LLM_MODEL_NOT_FOUND'), findsOneWidget);
    expect(
      find.text(t.chat.repickModel),
      findsOneWidget,
      reason: '当前账号不可用的模型也必须有可操作的重选入口',
    );
  });

  // ── the message-level fork entry + the user-turn prefill variant (CH-b) ──

  testWidgets(
    'forking an ASSISTANT turn cuts AT it, opens the fork, and prefills nothing',
    (tester) async {
      final repo = _repo(
        messages: {
          'cv_1': [
            _turn('m1', 'user', blocks: [_blk('b1', 'text', 'ASK ONE')]),
            _turn('m2', 'assistant', blocks: [_blk('b2', 'text', 'REPLY ONE')]),
            _turn('m3', 'user', blocks: [_blk('b3', 'text', 'ASK TWO')]),
            _turn('m4', 'assistant', blocks: [_blk('b4', 'text', 'REPLY TWO')]),
          ],
        },
      );
      final (w, container, router) = _hostRouted(repo);
      await tester.pumpWidget(w);
      await tester.pumpAndSettle();
      final t = Translations.of(
        tester.element(find.byType(ChatTranscriptView)),
      );

      // The SECOND assistant turn is the last row, so its action row is always visible.
      await tester.tap(find.byTooltip(t.chat.actions.fork).last);
      await tester.pumpAndSettle();

      final path = router.routerDelegate.currentConfiguration.uri.path;
      expect(path, startsWith('/chat/'));
      final forkId = path.substring('/chat/'.length);
      expect(forkId, isNot('cv_1'));
      // Cut AT the assistant turn = all four rows travel; nothing is queued in the composer.
      // 切**在** assistant 回合 = 四行全部随行;composer 里什么都没排。
      final head = await repo.getConversation(forkId);
      expect(head.forkedFromConversationId, 'cv_1');
      expect(head.forkedFromMessageId, 'm4');
      expect((await repo.listMessages(forkId)).items.length, 4);
      expect(container.read(chatDraftsProvider).of(forkId), '');
    },
  );

  testWidgets(
    'forking a USER turn cuts at the PREVIOUS row and hands the sentence back as the fork\'s draft',
    (tester) async {
      final repo = _repo(
        messages: {
          'cv_1': [
            _turn('m1', 'user', blocks: [_blk('b1', 'text', 'ASK ONE')]),
            _turn('m2', 'assistant', blocks: [_blk('b2', 'text', 'REPLY ONE')]),
            _turn('m3', 'user', blocks: [_blk('b3', 'text', 'ASK TWO')]),
          ],
        },
      );
      final (w, container, router) = _hostRouted(repo);
      await tester.pumpWidget(w);
      await tester.pumpAndSettle();
      final t = Translations.of(
        tester.element(find.byType(ChatTranscriptView)),
      );

      // The last row is the SECOND user turn — its fork means "stop before I said this".
      await tester.tap(find.byTooltip(t.chat.actions.forkBefore).last);
      await tester.pumpAndSettle();

      final forkId = router.routerDelegate.currentConfiguration.uri.path
          .substring('/chat/'.length);
      expect(forkId, isNot('cv_1'));
      // The cut is the PREVIOUS row (the assistant reply), so the thread stops just short of the
      // sentence — and the sentence comes back as editable draft text on the NEW thread.
      // 切点是**上一行**(那条 assistant 回复),故线程停在这句话之前——而这句话作为可编辑草稿落在**新**线程上。
      final head = await repo.getConversation(forkId);
      expect(head.forkedFromMessageId, 'm2');
      expect((await repo.listMessages(forkId)).items.length, 2);
      expect(container.read(chatDraftsProvider).of(forkId), 'ASK TWO');
      // The source is untouched — all three rows still there.
      expect((await repo.listMessages('cv_1')).items.length, 3);
    },
  );

  testWidgets(
    'forking the FIRST user turn goes to the landing with the sentence prefilled — an empty twin would be a worse answer',
    (tester) async {
      final repo = _repo(
        messages: {
          'cv_1': [
            _turn(
              'm1',
              'user',
              blocks: [_blk('b1', 'text', 'THE FIRST THING')],
            ),
          ],
        },
      );
      final (w, container, router) = _hostRouted(repo);
      await tester.pumpWidget(w);
      await tester.pumpAndSettle();
      final t = Translations.of(
        tester.element(find.byType(ChatTranscriptView)),
      );

      await tester.tap(find.byTooltip(t.chat.actions.forkBefore).last);
      await tester.pumpAndSettle();

      expect(router.routerDelegate.currentConfiguration.uri.path, '/');
      expect(
        container.read(chatDraftsProvider).of(ChatDrafts.landingKey),
        'THE FIRST THING',
      );
      // Nothing was minted server-side: a thread where nothing has been said IS the landing.
      // 服务端什么都没铸:什么都没说过的线程**就是** landing。
      expect((await repo.listConversations()).items.length, 1);
    },
  );
  // ── CH-c: retry / edit-resend / version paging ──────────────────────────────

  /// Three rows, so「末轮」is a real claim and not the only row there is: the last assistant turn may be
  /// retried, the last user turn may be edited, and NEITHER affordance may appear on the history above them.
  /// 三行,使「末轮」是一个真主张、而不是「那里只有一行」:末条 assistant 可重试、末条 user 可编辑,而两个入口都不许出现在
  /// 它们上方的历史里。
  FixtureChatRepository retryRepo() => _repo(
    messages: {
      'cv_1': [
        _turn('m1', 'user', blocks: [_blk('b1', 'text', 'OLD ASK')]),
        _turn('m2', 'assistant', blocks: [_blk('b2', 'text', 'OLD REPLY')]),
        _turn('m3', 'user', blocks: [_blk('b3', 'text', 'LAST ASK')]),
        _turn('m4', 'assistant', blocks: [_blk('b4', 'text', 'LAST REPLY')]),
      ],
    },
  );

  testWidgets(
    'retry lives ONLY on the last assistant turn; edit-resend ONLY on the last user turn',
    (tester) async {
      final repo = retryRepo();
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();
      final t = Translations.of(
        tester.element(find.byType(ChatTranscriptView)),
      );

      // Four turns are on screen, and exactly ONE of each affordance exists. The count is the assertion:
      // a retry on every assistant row would say「重试」about answers the backend answers 409 for.
      // 屏上四个回合,而每种入口**恰好一个**。数量本身就是断言:每行 assistant 都给重试,等于对后端一律 409 的回答说「重试」。
      expect(find.text('LAST REPLY'), findsOneWidget);
      expect(find.byTooltip(t.chat.actions.retry), findsOneWidget);
      expect(find.byTooltip(t.chat.actions.editResend), findsOneWidget);
      // Copy is on every turn (CH-a), so the row itself is present on the history — only these two are not.
      // 复制在每个回合上(CH-a),故历史上动作排本身在——只有这两个不在。
      expect(
        find.byTooltip(t.action.copy),
        findsNWidgets(4),
        reason: 'the action row itself is unchanged on history rows',
      );
    },
  );

  testWidgets('the retry menu regenerates, and「换模型重试」picks the model', (
    tester,
  ) async {
    final repo = retryRepo();
    await tester.pumpWidget(_host(repo));
    await tester.pumpAndSettle();
    final t = Translations.of(tester.element(find.byType(ChatTranscriptView)));

    // The anchor opens a MENU (not an immediate retry): the plain row, then one row per model.
    await tester.tap(find.byTooltip(t.chat.actions.retry));
    await tester.pumpAndSettle();
    expect(find.text(t.chat.actions.retryWithModel), findsOneWidget);
    expect(find.text('DeepSeek Chat'), findsOneWidget);
    // No Auto row: a per-turn model cannot CLEAR the thread's override, so offering「Auto」would lie.
    // 没有 Auto 行:逐回合模型无法**清除**线程 override,给出「Auto」即撒谎。
    expect(find.text(t.chat.modelAuto), findsNothing);

    await tester.tap(find.text(t.chat.actions.retry).last);
    await tester.pumpAndSettle();
    expect(repo.lastRetry?.conversationId, 'cv_1');
    expect(
      repo.lastRetry?.content,
      '',
      reason: 'a plain retry regenerates — it does not re-ask',
    );
    expect(repo.lastRetry?.modelOverride, isNull);

    // And again, this time picking a model: the SAME endpoint, with a per-turn override.
    await tester.tap(find.byTooltip(t.chat.actions.retry));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DeepSeek Chat'));
    await tester.pumpAndSettle();
    expect(repo.lastRetry?.modelOverride?.modelId, 'deepseek-chat');
    expect(repo.lastRetry?.content, '');
  });

  testWidgets(
    'a newly streamed retry resets a stale pager choice to the current version',
    (tester) async {
      final repo = _repo(
        messages: {
          'cv_1': [
            _turn('m1', 'user', blocks: [_blk('b1', 'text', 'ASK')]),
            _turn('m2', 'assistant', blocks: [_blk('b2', 'text', 'V1')]),
          ],
        },
      );
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();
      final t = Translations.of(
        tester.element(find.byType(ChatTranscriptView)),
      );

      // Simulate a reader paging away from the current answer before asking for a retry. The action stores
      // the about-to-exist index, just as the real row does.
      // 模拟读者先离开当前答案再点重试;动作行会先记下「即将存在」的下标,与真 UI 一致。
      await tester.tap(find.byTooltip(t.chat.actions.retry));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.chat.actions.retry).last);
      await tester.pumpAndSettle();

      repo.emitFrame(
        'cv_1',
        _open('m3', 'message', content: {'role': 'assistant', 'retryOf': 'm2'}),
      );
      repo.emitFrame(
        'cv_1',
        _open('b3', 'text', parentId: 'm3', content: {'content': ''}),
      );
      await _settle(tester);
      repo.emitFrame('cv_1', _delta('b3', 'V2'));
      repo.emitFrame('cv_1', _close('b3', 'text', {'content': 'V2'}));
      repo.emitFrame(
        'cv_1',
        _close('m3', 'message', {
          'role': 'assistant',
          'status': 'completed',
          'stopReason': 'end_turn',
          'retryOf': 'm2',
        }),
      );
      await _settle(tester);

      expect(find.text('V2'), findsOneWidget);
      expect(find.text('V1'), findsNothing);
      expect(find.text('2/2'), findsOneWidget);
    },
  );

  testWidgets(
    'edit-resend puts the sentence back in place and resends it as a new version',
    (tester) async {
      final repo = retryRepo();
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();
      final t = Translations.of(
        tester.element(find.byType(ChatTranscriptView)),
      );

      await tester.tap(find.byTooltip(t.chat.actions.editResend));
      await tester.pumpAndSettle();
      // In place: the field is seeded with the ORIGINAL sentence, right where the bubble was.
      // 原地:输入框以**原句**为种子,就在气泡本来所在的位置。
      final field = find.byType(EditableText).last;
      expect(tester.widget<EditableText>(field).controller.text, 'LAST ASK');

      await tester.enterText(field, 'EDITED ASK');
      await tester.tap(find.text(t.chat.actions.editResendSubmit));
      await tester.pumpAndSettle();

      expect(repo.lastRetry?.content, 'EDITED ASK');
      // Zero deletion: the fixture mirrors the backend, so the OLD row is still there, superseded.
      // 零删除:夹具镜像后端,故**旧行仍在**、只是被取代。
      final rows = (await repo.listMessages('cv_1')).items;
      final old = rows.firstWhere((m) => m.id == 'm3');
      expect(old.supersededBy, isNotEmpty);
      expect(
        rows.where((m) => m.role == 'user').length,
        3,
        reason: 'two original questions + the edited one — the old row is kept',
      );
    },
  );

  testWidgets(
    'a retried turn renders ONE row with a pager, and paging back reveals the old version + says what the thread is based on',
    (tester) async {
      // A thread whose last answer has been retried twice: three versions, ONE of them current. Built as
      // durable rows (the shape a reload produces) rather than by driving the UI, because the pager's whole
      // job is to be right about history it did not witness.
      // 一条末答被重试过两次的线程:三个版本、其中**一个**现行。用耐久行搭(重载后的形状)、不靠驱动 UI,因为翻页的全部
      // 职责就是对它没亲眼见过的历史作出正确判断。
      final repo = _repo(
        messages: {
          'cv_1': [
            _turn('m1', 'user', blocks: [_blk('b1', 'text', 'ASK')]),
            _turn(
              'm2',
              'assistant',
              blocks: [_blk('b2', 'text', 'V1')],
            ).copyWith(supersededBy: 'm3'),
            _turn(
              'm3',
              'assistant',
              blocks: [_blk('b3', 'text', 'V2')],
            ).copyWith(supersededBy: 'm4', attrs: const {'retryOf': 'm2'}),
            _turn(
              'm4',
              'assistant',
              blocks: [_blk('b4', 'text', 'V3')],
            ).copyWith(attrs: const {'retryOf': 'm3'}),
          ],
        },
      );
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();
      final t = Translations.of(
        tester.element(find.byType(ChatTranscriptView)),
      );

      // ONE row, not three: the current version, with `3/3` beside it. Showing all three would be the
      // duplicate transcript the grouping exists to prevent.
      // **一行、不是三行**:现行版,旁边 `3/3`。三行全渲正是分组要防的重复 transcript。
      expect(find.text('V3'), findsOneWidget);
      expect(find.text('V1'), findsNothing);
      expect(find.text('V2'), findsNothing);
      expect(find.text('3/3'), findsOneWidget);
      // On the current version there is nothing to disclaim, so no note.
      expect(find.text(t.chat.actions.versionBasedOn(n: 3)), findsNothing);

      // Page back twice: the OLD versions are readable, and the note now says which version the thread
      // actually continued from — the one thing the pager must not leave unsaid.
      // 往回翻两次:旧版可读,且注记现在说出线程**实际**是从哪一版继续的——翻页绝不能不说的那件事。
      await tester.tap(find.byTooltip(t.chat.actions.versionPrev));
      await tester.pumpAndSettle();
      expect(find.text('V2'), findsOneWidget);
      expect(find.text('V3'), findsNothing);
      expect(find.text('2/3'), findsOneWidget);
      expect(find.text(t.chat.actions.versionBasedOn(n: 3)), findsOneWidget);

      await tester.tap(find.byTooltip(t.chat.actions.versionPrev));
      await tester.pumpAndSettle();
      expect(find.text('V1'), findsOneWidget);
      expect(find.text('1/3'), findsOneWidget);
      expect(find.text(t.chat.actions.versionBasedOn(n: 3)), findsOneWidget);

      // Forward again to the current version: the note goes away, because there is nothing left to disclaim.
      await tester.tap(find.byTooltip(t.chat.actions.versionNext));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip(t.chat.actions.versionNext));
      await tester.pumpAndSettle();
      expect(find.text('V3'), findsOneWidget);
      expect(find.text('3/3'), findsOneWidget);
      expect(find.text(t.chat.actions.versionBasedOn(n: 3)), findsNothing);
    },
  );

  testWidgets(
    'an un-retried transcript shows no pager at all — one version has nothing to page',
    (tester) async {
      final repo = retryRepo();
      await tester.pumpWidget(_host(repo));
      await tester.pumpAndSettle();
      final t = Translations.of(
        tester.element(find.byType(ChatTranscriptView)),
      );
      expect(find.byTooltip(t.chat.actions.versionPrev), findsNothing);
      expect(find.byTooltip(t.chat.actions.versionNext), findsNothing);
      expect(find.text('1/1'), findsNothing);
    },
  );
}
