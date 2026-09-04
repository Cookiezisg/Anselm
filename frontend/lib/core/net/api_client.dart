import 'dart:convert';

import 'package:dio/dio.dart';

import '../contract/api_error.dart';
import '../contract/page.dart';

/// The HTTP boundary to the local Go backend. Encodes the standardized contract
/// (ADR 0003) exactly ONCE so no feature hand-rolls envelope/error/pagination handling:
///
///  - success  → `{"data": <bare entity>}`            → [getEntity] / [postEntity]
///  - list     → `{data:[…], nextCursor?, hasMore}`   → [getPage]
///  - async    → `202 {"data":{"id": …}}`             → [postForId]
///  - 204      → no body                              → [delete] / [postNoContent]
///  - error    → `{"error":{code,message,details}}`   → thrown as [ApiException]
///
/// Workspace isolation rides the `X-Anselm-Workspace-ID` header on every request
/// (backend middleware.HeaderWorkspaceID); the client never sends/reads workspace_id in
/// bodies. The id source is injected as a callback so this layer stays Riverpod-free.
///
/// 到本地 Go 后端的 HTTP 边界。把标准化契约(ADR 0003)**只编码一次**,使无 feature 手搓
/// envelope/error/分页。workspace 隔离经每请求的 `X-Anselm-Workspace-ID` header;客户端
/// 体内绝不带 workspace_id。id 来源以回调注入,使本层不沾 Riverpod。
class ApiClient {
  ApiClient({
    required Dio dio,
    required String? Function() workspaceId,
    required String? Function() authToken,
    void Function()? onWorkspaceUnauthorized,
  }) : _dio = dio,
       _workspaceId = workspaceId,
       _authToken = authToken,
       _onWorkspaceUnauthorized = onWorkspaceUnauthorized {
    _dio.interceptors.add(InterceptorsWrapper(onRequest: _onRequest));
  }

  final Dio _dio;
  final String? Function() _workspaceId;

  /// The per-launch loopback bearer token (`ANSELM_AUTH_TOKEN`), injected as a callback so
  /// this layer stays Riverpod-free. Attached as `Authorization: Bearer …` on every request
  /// (loopback hardening — the backend RequireBearerToken middleware rejects requests without
  /// it, incl. /health and the SSE GETs). Null until the sidecar supervisor has minted it.
  ///
  /// 每次启动的 loopback bearer token(`ANSELM_AUTH_TOKEN`),回调注入(本层不沾 Riverpod)。
  /// 每请求挂 `Authorization: Bearer …`(loopback 加固——后端 RequireBearerToken 中间件拒绝无它的
  /// 请求,含 /health 与 SSE GET)。sidecar supervisor 铸出前为 null。
  final String? Function() _authToken;
  final void Function()? _onWorkspaceUnauthorized;

  static const _workspaceOverrideKey = 'anselm.workspaceOverride';

  void _onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final override = options.extra[_workspaceOverrideKey];
    final ws = override is String ? override : _workspaceId();
    if (ws != null && ws.isNotEmpty) {
      options.headers['X-Anselm-Workspace-ID'] = ws;
    }
    final token = _authToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  /// GET a single entity: unwrap `{data:<obj>}` → [parse].
  ///
  /// GET 单实体:拆 `{data:<obj>}` → [parse]。
  Future<T> getEntity<T>(
    String path,
    T Function(Map<String, dynamic>) parse, {
    Map<String, dynamic>? query,
  }) => _send(() async {
    final r = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: query,
    );
    return parse(_data(r.data));
  });

  /// GET a keyset page: `{data:[…], nextCursor?, hasMore}` → [Page]. Entity list endpoints may also
  /// provide the exact filtered total in `X-Anselm-Total-Count`; it stays out of the N4 body.
  ///
  /// GET 一页 keyset → [Page]。
  Future<Page<T>> getPage<T>(
    String path,
    T Function(Map<String, dynamic>) item, {
    Map<String, dynamic>? query,
  }) => _send(() async {
    final r = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: query,
    );
    final total = int.tryParse(r.headers.value('X-Anselm-Total-Count') ?? '');
    return Page.fromBody(r.data ?? const {}, item, total: total);
  });

  /// GET an OFFSET page: `{data:[…], total, hasMore}` → [OffsetPage] (WRK-070 B4, flowruns only).
  ///
  /// GET 一页 offset → [OffsetPage](仅 flowruns)。
  Future<OffsetPage<T>> getOffsetPage<T>(
    String path,
    T Function(Map<String, dynamic>) item, {
    Map<String, dynamic>? query,
  }) => _send(() async {
    final r = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: query,
    );
    return OffsetPage.fromBody(r.data ?? const {}, item);
  });

  /// GET a log page whose `data` is an object carrying a list + an aggregate sidecar:
  /// `{data:{<listKey>:[…], aggregates:{…}}, nextCursor?, hasMore}` → [PageWithAggregate].
  /// The execution / call log endpoints (MD2); [listKey] is `executions`/`calls`, and the
  /// aggregate decoder reads the nested `aggregates` object (see callers).
  ///
  /// GET `data` 为对象(列表 + 聚合旁挂)的日志页 → [PageWithAggregate]。执行/调用日志端点(MD2);
  /// [listKey] 为 `executions`/`calls`,聚合解码读嵌套的 `aggregates` 对象(见调用方)。
  Future<PageWithAggregate<T, A>> getPageWithAggregate<T, A>(
    String path,
    String listKey,
    T Function(Map<String, dynamic>) item,
    A Function(Map<String, dynamic>) aggregate, {
    Map<String, dynamic>? query,
  }) => _send(() async {
    final r = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: query,
    );
    return PageWithAggregate.fromBody(
      r.data ?? const {},
      listKey,
      item,
      aggregate,
    );
  });

  /// GET a raw envelope body (for composite reads like `{flowrun, nodes}` whose `data`
  /// is a multi-key object the caller destructures itself).
  ///
  /// GET 原始信封体(供 `{flowrun, nodes}` 这类 `data` 为多 key 对象、调用方自解的复合读)。
  /// GET raw bytes (non-envelope endpoints — attachment content). 裸字节 GET(非 envelope,附件内容)。
  /// The absolute URL + the headers this client would attach, for handing a path to a NATIVE
  /// consumer that does its own fetching (WRK-082 H5.5: libmpv streams video itself).
  ///
  /// It exists because a sandboxed macOS app cannot hand a native player an arbitrary file path —
  /// the entitlements grant only user-selected files, and libmpv answers "Operation not permitted"
  /// for anything else (observed, not assumed). Loopback HTTP is the one channel already open
  /// (`com.apple.security.network.client`, granted for the sidecar), and it streams: a 20MB clip
  /// starts playing before it has finished downloading, and nothing is written to disk twice.
  ///
  /// 绝对 URL + 本 client 会挂的头,用于把一条路径交给**自己去取**的原生消费方(H5.5:libmpv 自己流式
  /// 拉视频)。
  ///
  /// 它存在,是因为沙箱化的 macOS app **不能**把任意文件路径交给原生播放器——entitlements 只授权用户
  /// 亲选的文件,其余一律被 libmpv 答「Operation not permitted」(**实测所得**,非假设)。loopback HTTP
  /// 是唯一已经开着的通道(`com.apple.security.network.client`,为 sidecar 授的),而且它是**流式**的:
  /// 一段 20MB 的片子在下完之前就能开播,且没有任何字节被写两遍盘。
  NativeFetchTarget nativeFetchTarget(String path) {
    final base = _dio.options.baseUrl.replaceAll(RegExp(r'/$'), '');
    final headers = <String, String>{};
    final ws = _workspaceId();
    if (ws != null && ws.isNotEmpty) headers['X-Anselm-Workspace-ID'] = ws;
    final token = _authToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return NativeFetchTarget(uri: '$base$path', headers: headers);
  }

  Future<List<int>> getBytes(String path) => _send(() async {
    final r = await _dio.get<List<int>>(
      path,
      options: Options(responseType: ResponseType.bytes),
    );
    return r.data ?? const <int>[];
  });

  /// PUT raw bytes (non-envelope endpoints — the skill files surface speaks bytes both ways;
  /// success is a 204 with no body). 裸字节 PUT(非 envelope,skill files 面双向裸字节;成功 204 空体)。
  Future<void> putBytes(
    String path,
    List<int> body, {
    String contentType = 'application/octet-stream',
  }) => _send(() async {
    await _dio.put<void>(
      path,
      data: Stream.fromIterable([body]),
      options: Options(
        contentType: contentType,
        headers: {'Content-Length': body.length},
      ),
    );
  });

  Future<Map<String, dynamic>> getData(
    String path, {
    Map<String, dynamic>? query,

    /// Internal workspace pin for a request that must not follow a hot switch.
    /// 内部 workspace pin,用于请求不可随热切换漂移。
    String? workspaceId,
  }) => _send(() async {
    final r = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: query,
      options: _workspaceOptions(workspaceId),
    );
    return _data(r.data);
  });

  /// GET the WHOLE envelope body — for reads whose coordinates ride top-level BESIDE `data`
  /// (the `?around=` window envelope `{data, targetId, olderCursor?, newerCursor?, hasOlder,
  /// hasNewer}`). [getData] strips to `data` and would drop them.
  ///
  /// GET **整个** envelope 体——供坐标在顶层与 `data` 并列的读(`?around=` 窗 envelope)。
  /// [getData] 只剥 `data`、会丢坐标。
  Future<Map<String, dynamic>> getEnvelope(
    String path, {
    Map<String, dynamic>? query,
  }) => _send(() async {
    final r = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: query,
    );
    return r.data ?? const {};
  });

  /// POST returning a created/edited entity: `{data:<obj>}` → [parse]. Covers Create
  /// (201) and state-change actions (`:activate` … return the post-action snapshot).
  ///
  /// POST 返回创建/编辑后实体 → [parse]。覆盖 Create(201)与状态变更动作的后置快照。
  Future<T> postEntity<T>(
    String path,
    T Function(Map<String, dynamic>) parse, {
    Object? body,
  }) => _send(() async {
    final r = await _dio.post<Map<String, dynamic>>(path, data: body);
    return parse(_data(r.data));
  });

  /// POST returning a bounded item list `{data:[…]}` (an action that computes a set — e.g.
  /// skills:inspect-source previews). POST 返回有界列表(计算出集合的动作,如安装预览)。
  Future<Page<T>> postPage<T>(
    String path,
    T Function(Map<String, dynamic>) item, {
    Object? body,
  }) => _send(() async {
    final r = await _dio.post<Map<String, dynamic>>(path, data: body);
    return Page.fromBody(r.data ?? const {}, item);
  });

  /// PATCH/PUT returning the updated entity snapshot.
  ///
  /// PATCH/PUT 返回更新后实体快照。
  Future<T> patchEntity<T>(
    String path,
    T Function(Map<String, dynamic>) parse, {
    Object? body,
    bool put = false,
  }) => _send(() async {
    final r = put
        ? await _dio.put<Map<String, dynamic>>(path, data: body)
        : await _dio.patch<Map<String, dynamic>>(path, data: body);
    return parse(_data(r.data));
  });

  /// POST an async action that returns a single new resource id: `202 {data:{id}}` →
  /// the id string (MD3). E.g. send-message, `:trigger`, `:fire`, `:iterate`.
  ///
  /// POST 返单产物 id 的异步动作 → id 字符串(MD3)。如发消息、`:trigger`、`:fire`、`:iterate`。
  Future<String> postForId(String path, {Object? body}) => _send(() async {
    final r = await _dio.post<Map<String, dynamic>>(path, data: body);
    // Validate rather than bare-cast: a malformed 202 (missing/non-string id) must surface as a typed
    // ApiException, not a raw TypeError escaping the typed-error contract. 校验非裸 cast,守 typed-error 契约。
    final id = _data(r.data)['id'];
    if (id is! String || id.isEmpty) {
      throw ApiException(
        code: AnselmErr.unknown,
        message: 'response data had no id string',
        httpStatus: 200,
      );
    }
    return id;
  });

  /// POST a fire-and-forget action with no product (204) — e.g. `:reindex`, resolve.
  ///
  /// POST 无产物的 fire-and-forget(204)——如 `:reindex`、resolve。
  Future<void> postNoContent(String path, {Object? body}) =>
      _send(() async => _dio.post<void>(path, data: body));

  /// POST returning a `{data:<obj>}` map (an action whose product is a small ad-hoc object, e.g.
  /// `:provision` → `{provisioned}`). POST 返 data 对象(小型即席产物动作)。
  Future<Map<String, dynamic>> postData(String path, {Object? body}) =>
      _send(() async {
        final r = await _dio.post<Map<String, dynamic>>(path, data: body);
        return _data(r.data);
      });

  /// PUT returning the updated entity snapshot (sugar over [patchEntity] put:true). PUT 返实体快照。
  Future<T> putEntity<T>(
    String path,
    T Function(Map<String, dynamic>) parse, {
    Object? body,
  }) => patchEntity(path, parse, body: body, put: true);

  /// DELETE returning the post-delete entity snapshot (e.g. clearing a workspace default returns
  /// the fresh workspace row). DELETE 返删后实体快照(如清默认返新 workspace 行)。
  Future<T> deleteEntity<T>(
    String path,
    T Function(Map<String, dynamic>) parse,
  ) => _send(() async {
    final r = await _dio.delete<Map<String, dynamic>>(path);
    return parse(_data(r.data));
  });

  /// DELETE (204). [workspaceId] pins the isolation header for a long-lived destructive operation.
  /// DELETE(204)。workspaceId 为长生命周期破坏性动作固定隔离 header。
  Future<void> delete(String path, {String? workspaceId}) => _send(
    () async =>
        _dio.delete<void>(path, options: _workspaceOptions(workspaceId)),
  );

  Options? _workspaceOptions(String? workspaceId) {
    if (workspaceId == null || workspaceId.isEmpty) return null;
    return Options(extra: {_workspaceOverrideKey: workspaceId});
  }

  /// Unwrap the `data` object from an envelope, or throw if absent/wrong shape.
  ///
  /// 从信封拆出 `data` 对象,缺失/形状不对则抛。
  Map<String, dynamic> _data(Map<String, dynamic>? body) {
    final data = body?['data'];
    if (data is Map<String, dynamic>) return data;
    throw ApiException(
      code: AnselmErr.unknown,
      message: 'response had no data object',
      httpStatus: 200,
    );
  }

  /// Run a Dio call, translating every DioException into a typed [ApiException]: a
  /// response carrying `{error:{…}}` → [ApiException.fromEnvelope]; a transport failure
  /// (no response) → [ApiException.transport]. The single place HTTP plumbing becomes a
  /// domain error.
  ///
  /// 跑一次 Dio 调用,把每个 DioException 译成 typed [ApiException]:带 `{error:{…}}` 的响应
  /// → fromEnvelope;无响应的传输失败 → transport。HTTP 管道化为 domain 错误的唯一处。
  Future<T> _send<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      final resp = e.response;
      if (resp != null) {
        final error = _errorEnvelope(resp.data);
        final exception = ApiException.fromEnvelope(
          error,
          resp.statusCode ?? 0,
        );
        if (exception.code == AnselmErr.unauthNoWorkspace) {
          // Workspace auth is a recoverable runtime-axis failure: clear the stale selection and let
          // the shell re-resolve it from the server roster. 原始错误仍留在日志,不扩散到 feature。
          _onWorkspaceUnauthorized?.call();
        }
        throw exception;
      }
      throw ApiException.transport(e.message ?? 'transport failure');
    }
  }

  /// Raw-byte endpoints still use the N1 JSON error envelope on failure. Dio returns that body
  /// as bytes because the request asked for [ResponseType.bytes], so decode it before falling back
  /// to CLIENT_UNKNOWN. 裸字节端点失败时仍答 N1 JSON;ResponseType.bytes 会让 Dio 把信封交成字节,
  /// 必须先解码,否则后端稳定错误码会被错误降级成 CLIENT_UNKNOWN。
  static Map<String, dynamic>? _errorEnvelope(Object? body) {
    Object? decoded = body;
    if (body is List<int>) {
      try {
        decoded = jsonDecode(utf8.decode(body));
      } catch (_) {
        return null;
      }
    } else if (body is String) {
      try {
        decoded = jsonDecode(body);
      } catch (_) {
        return null;
      }
    }
    if (decoded is! Map) return null;
    final raw = decoded['error'];
    return raw is Map ? Map<String, dynamic>.from(raw) : null;
  }
}

/// What a native consumer needs to fetch one resource itself: the absolute URL and the headers
/// this app's interceptor would have attached. Kept as a value type so the media port can pass it
/// around without anyone downstream reaching for a Dio.
///
/// 一个原生消费方自行取一份资源所需之物:绝对 URL,与本应用拦截器本会挂上的那些头。做成值类型,使媒体
/// 端口可以传递它、而下游任何人都不必去碰 Dio。
class NativeFetchTarget {
  const NativeFetchTarget({required this.uri, required this.headers});

  final String uri;
  final Map<String, String> headers;
}
