import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// WRK-083 L7 law: whoever keeps state fresh from a stream's SIGNALS must also refetch on that same
// stream's RESYNC.
//
// Four repositories derive lifecycle signals from the notifications stream (chat conversations,
// entities, library pages, notifications themselves). A 410 `SEQ_TOO_OLD` on that stream means the
// client's cursor fell out of the 256-frame replay ring — every signal in the gap is gone forever, by
// design: the contract is "drop the cursor, tell consumers to refetch, reconnect at a fresh head". A
// consumer that listens to the signals but not to the resync therefore keeps whatever it had at the
// moment of the gap and never learns otherwise — for the rest of the session, because these providers
// live in the keep-alive rail/ocean stacks and are not rebuilt by navigation.
//
// The mistake is invisible in every other way: the subscription compiles, the stream is the right one,
// live updates work perfectly in every normal session. Only a client that was away long enough
// (asleep, wedged, a busy workspace) diverges — silently, with no error anywhere. The chat rail even
// HAD a resync subscription, on `transcriptResync()` — the MESSAGES stream, which carries its activity
// dots but none of its lifecycle: so it re-paged for the half it could not miss and stayed stale on the
// half it could.
//
// So the pairing is guarded at the SOURCE: a file that subscribes to `lifecycleSignals(` must also
// subscribe to `lifecycleResync(`. A behavioural test proves one consumer refetches; it says nothing
// about the NEXT provider someone wires to lifecycle signals, and that one will be written by copying
// an existing subscription — which is exactly how this spread to four places.
//
// WRK-083 L7 军规:凡靠某条流的**信号**保鲜的,必须也在那条流的 **resync** 上补取。
//
// 四个仓从 notifications 流派生生命周期信号(chat 对话 / 实体 / library 页 / 通知自身)。该流上的 410
// `SEQ_TOO_OLD` 意味着客户端游标掉出了 256 帧的 replay 环——缺口里的每一条信号都**永远**没了,这是设计:契约就是
// 「丢游标、通知消费方重取、从新 head 重连」。只听信号、不听 resync 的消费方,于是把缺口发生那一刻手里的东西一直
// 攥到会话结束——因为这些 provider 住在保活的 rail/海洋栈里,导航并不会重建它们。
//
// 这个错在别的任何方面都看不出来:订阅编译得过、流也是对的、正常会话里实时更新完美。只有离开得够久的客户端
// (睡眠、卡住、繁忙 workspace)会静默偏离,且哪儿都没有报错。chat rail 甚至**本来就有**一条 resync 订阅——挂在
// `transcriptResync()` 即 **messages** 流上,那条流载着它的活态点、却不载它的生命周期:于是它为**漏不掉**的那一半
// 重翻了整列,却在**会漏的**那一半上保持陈旧。
//
// 故这对配对在**源码层**守:订阅了 `lifecycleSignals(` 的文件必须也订阅 `lifecycleResync(`。行为测试能证明某一个
// 消费方会补取,却对**下一个**被接到生命周期信号上的 provider 一无所知,而那一个会是照着既有订阅抄出来的——这正是
// 它蔓延到四处的方式。

void main() {
  test('every lifecycleSignals consumer also listens to lifecycleResync', () {
    final offenders = <String>[];

    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      // The repositories DECLARE and IMPLEMENT both; only CONSUMERS are under test here, and a consumer
      // is a file that subscribes. 仓**声明并实现**两者;此处只考**消费方**,而消费方=去订阅的那个文件。
      if (!src.contains('lifecycleSignals(')) continue;
      if (f.path.contains('/data/')) continue; // repositories + fixtures 仓与夹具
      if (src.contains('lifecycleResync(')) continue;
      offenders.add(f.path);
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'these subscribe to notifications-stream lifecycle signals but never refetch on that '
          "stream's 410 resync — after one gap they stay stale for the rest of the session "
          '(WRK-083 L7):\n  ${offenders.join("\n  ")}',
    );
  });
}
