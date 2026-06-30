import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/navigation.dart';

/// The selected conversation reference — just an id (single domain; no kind, unlike EntityRef). A
/// value object so the rail rebuilds only on a real selection change.
///
/// 选中对话引用——只是一个 id(单域;无 kind,不同于 EntityRef)。值对象,使 rail 仅在选区真变时重建。
class ConversationRef {
  const ConversationRef(this.id);

  final String id;

  @override
  bool operator ==(Object other) => other is ConversationRef && other.id == id;
  @override
  int get hashCode => id.hashCode;
  @override
  String toString() => 'ConversationRef($id)';
}

/// The selected conversation — a READ-ONLY shim derived ONE-WAY from the URL (mirrors SelectedEntity).
/// It listens to the router delegate and re-parses `/chat/:id` on every navigation; there is no
/// select()/clear() — the ONLY way to change selection is to navigate (the rail row does
/// `context.go(conversationLocation(id))`). URL is the single source of truth → refresh / deep-link /
/// back-forward all survive.
///
/// 选中对话——从 URL **单向**派生的只读 shim(镜像 SelectedEntity)。监听 router delegate、每次导航重解析 `/chat/:id`;
/// 无 select()/clear()——改选区的唯一途径是导航(rail 行 `context.go(conversationLocation(id))`)。URL 是唯一真相源 →
/// 刷新 / 深链 / 前进后退都不丢。
class SelectedConversation extends Notifier<ConversationRef?> {
  @override
  ConversationRef? build() {
    final delegate = ref.watch(goRouterProvider).routerDelegate;
    void onRoute() => state = _parse(delegate.currentConfiguration.uri);
    delegate.addListener(onRoute);
    ref.onDispose(() => delegate.removeListener(onRoute));
    return _parse(delegate.currentConfiguration.uri);
  }

  static ConversationRef? _parse(Uri uri) {
    final segs = uri.pathSegments;
    // No kind to validate (single domain) — any `/chat/<id>` is a selection. id existence is not
    // checkable at the route layer (same as entities). 无 kind 可校(单域)——任意 /chat/<id> 即选区;id 存在性路由层不可校。
    if (segs.length == 2 && segs[0] == 'chat') return ConversationRef(segs[1]);
    return null;
  }
}

final selectedConversationProvider =
    NotifierProvider<SelectedConversation, ConversationRef?>(SelectedConversation.new);

/// The route location for a conversation — the rail navigates here to select. Mirrors entityLocation.
///
/// 对话的路由位置——rail 导航至此以选中。镜像 entityLocation。
String conversationLocation(String id) => '/chat/$id';
