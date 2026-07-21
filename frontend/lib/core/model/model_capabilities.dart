import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../contract/model_capability.dart';
import '../runtime.dart';

/// The (key, model) capability catalog — moved to core (WRK-062 S-15) because BOTH the chat model
/// picker and the settings models-and-keys panel consume it, and features must not import each
/// other. Fetched once per session by default; key create/rotate/test/delete flows INVALIDATE it so
/// the pickers refresh without a restart. Tests/demo override the provider directly.
///
/// (key,model) 能力目录——上移 core(S-15):chat 模型选择器与 settings 模型密钥面板都消费,而 features
/// 互不依赖。默认会话期取一次;key 增/旋/测/删流程 invalidate 它,选择器免重启刷新。测试/demo 直接
/// override 本 provider。
final modelCapabilitiesProvider = FutureProvider<List<ModelCapability>>((
  ref,
) async {
  final api = ref.watch(apiClientProvider);
  final page = await api.getPage(
    '/api/v1/model-capabilities',
    ModelCapability.fromJson,
  );
  return page.items;
});
