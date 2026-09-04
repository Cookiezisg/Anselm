import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/contract/api_key.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/perf/frame_safe.dart';
import '../../../../core/runtime.dart';
import '../../../../core/ui/an_button.dart';
import '../../../../core/ui/an_card.dart';
import '../../../../core/ui/an_expand_reveal.dart';
import '../../../../core/ui/an_row.dart';
import '../../../../core/ui/an_state.dart';
import '../../../../core/ui/an_type_to_confirm.dart';
import '../../../../core/model/status_state.dart';
import '../../../../core/notice/notice_center.dart';
import '../../../../i18n/strings.g.dart';
import '../../state/api_keys_provider.dart';

/// The cloned-voice inventory card (WRK-082 H9), sitting under the free-tier card because that is
/// what it belongs to: enrolling a voice spends managed allowance, and cloning exists only there.
///
/// **The whole card is built around one distinction that the word「quota」would destroy.** An
/// inventory slot is not a daily allowance: nothing frees it with the passage of time, creating a
/// voice cost real money once, and deleting one reclaims the SLOT but never the fee. So the full
/// state says「delete one to make room」and never「try again tomorrow」— a user told to wait would
/// wait forever.
///
/// 克隆音色库存卡(H9)。它坐在免费档卡下面,因为它就属于那里:登记一个音色花的是受管额度,而克隆**只
/// 存在于**那里。
///
/// **整张卡是围绕一个区别造的,而「配额」这个词会把它毁掉。** 库存位不是日额度:时间流逝不腾位、创建
/// 它花过一次真钱、删除收回的是**位置**、从来不是费用。故满的时候说的是「删一个腾地方」、绝不是
/// 「明天再试」——一个被告知去等的用户,会等到天荒地老。
class VoicesCard extends ConsumerStatefulWidget {
  const VoicesCard({super.key});

  @override
  ConsumerState<VoicesCard> createState() => _VoicesCardState();
}

class _VoicesCardState extends ConsumerState<VoicesCard> {
  String? _deleting;
  String? _confirming;
  String? _deleteErrorId;
  int _workspaceGeneration = 0;

  void _toggleConfirmation(String id) {
    if (_deleting != null) return;
    setState(() {
      _confirming = _confirming == id ? null : id;
      _deleteErrorId = null;
    });
  }

  Future<void> _remove(String id) async {
    if (_deleting != null) return;
    final operationGeneration = _workspaceGeneration;
    setState(() => _deleting = id);
    try {
      await ref.read(voicesProvider.notifier).remove(id);
    } catch (error) {
      if (!mounted || operationGeneration != _workspaceGeneration) return;
      // The backend deletes the UPSTREAM registration first and keeps the row when that fails, so a
      // a failure before reconciliation means the voice is still real and still usable. A committed
      // delete is different: the old row is no longer safe to present, so the provider enters its
      // explicit refresh error state and the notice must not tell the user to delete again.
      // 后端**先删上游登记**、那一步失败意味着音色仍可用;但删除已提交而重读失败是另一种状态:
      // 旧行不再安全,provider 进入明确的重读错误态,通知也不能诱导用户再删一次。
      final committed = error is VoiceDeleteCommittedRefreshException;
      if (!committed) {
        setState(() => _deleteErrorId = id);
      }
      ref
          .read(noticeCenterProvider.notifier)
          .show(
            committed
                ? Translations.of(context).settings.keys.voicesDeleteCommitted
                : Translations.of(context).settings.keys.voicesDeleteFailed,
            tone: AnTone.warn,
          );
    } finally {
      // Keep the single-flight lock truthful until the original request settles, even if the user
      // switched away. Clearing it only for the old generation leaves a stale id disabled forever
      // when the user switches back before the request finishes.
      // 即使用户已经切走,原请求未结算前也要保持单飞锁真实。只在旧代际清理会导致用户切回时 id 永久禁用。
      if (mounted && _deleting == id) {
        setState(() => _deleting = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
    ref.listen<String?>(activeWorkspaceProvider, (previous, next) {
      if (previous == next) return;
      _workspaceGeneration++;
      // Settings remains mounted in the lazy IndexedStack. A confirmation is a destructive intent
      // in one workspace, never a reusable UI selection in another; clear only that intent at the
      // switch boundary. An in-flight delete remains single-flight until it settles, while its
      // generation guard prevents stale errors from painting in the new workspace.
      // 设置海洋在懒 IndexedStack 中常驻。确认是**某个 workspace 的破坏性意图**,不是可跨空间复用的选区;
      // 切换边界只清这个意图。在途删除直到结算前仍保持单飞,代际守卫阻止旧错误在新 workspace 涂回界面。
      runFrameSafe(() {
        if (!mounted) return;
        setState(() {
          _confirming = null;
          _deleteErrorId = null;
        });
      });
    });
    final inv = ref.watch(voicesProvider);

    return AnCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.settings.keys.voices,
            style: AnText.label.copyWith(color: c.inkMuted),
          ),
          const SizedBox(height: AnSpace.s8),
          // Same shape as the free-tier card it sits under — the two are read as one block, so they
          // must not disagree about how a load or a failure looks.
          // 与它坐在下面的那张免费档卡**同一形状**——两张卡被当作一块来读,故它们对「加载中」与「失败」
          // 长什么样不能有分歧。
          switch (inv) {
            AsyncData(:final value) => _body(t, c, value),
            AsyncError(:final error) => AnState(
              kind: AnStateKind.error,
              title: error is VoiceDeleteCommittedRefreshException
                  ? t.settings.keys.voicesDeleteCommitted
                  : t.settings.keys.voicesLoadFailed,
              hint: error is VoiceDeleteCommittedRefreshException
                  ? t.settings.keys.voicesDeleteCommittedHint
                  : null,
              size: AnStateSize.inset,
              action: AnButton(
                label: t.settings.keys.voicesRetry,
                outline: true,
                onPressed: () => ref.invalidate(voicesProvider),
              ),
            ),
            _ => const SizedBox(height: AnSpace.s16),
          },
        ],
      ),
    );
  }

  Widget _body(Translations t, AnColors c, VoiceInventory inv) {
    if (inv.items.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnState(
            kind: AnStateKind.empty,
            size: AnStateSize.inset,
            title: t.settings.keys.voicesEmpty,
          ),
          const SizedBox(height: AnSpace.s8),
          // Empty is still a settled inventory: show the same authoritative arithmetic as the
          // populated state, so a user can tell that both slots are available rather than merely
          // seeing that no rows exist.
          // 空也是已落定的库存:与有行态展示同一份权威算术,让用户知道两个位置都可用,而不是只看到没有行。
          Text(
            t.settings.keys.voicesRemaining(
              n: inv.remaining,
              cap: inv.capacity,
            ),
            style: AnText.label.copyWith(color: c.inkMuted),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final v in inv.items) ...[
          AnRow(
            label: v.name,
            actions: [
              AnButton(
                label: t.settings.keys.voicesDelete,
                size: AnButtonSize.sm,
                outline: true,
                onPressed: _deleting == v.id
                    ? null
                    : () => _toggleConfirmation(v.id),
              ),
            ],
          ),
          AnExpandReveal(
            open: _confirming == v.id,
            child: Padding(
              padding: const EdgeInsets.only(top: AnSpace.s8),
              child: AnTypeToConfirm(
                title: t.settings.keys.voicesDeleteTitle,
                warning: _deleteErrorId == v.id
                    ? t.settings.keys.voicesDeleteFailed
                    : null,
                body: Text(
                  t.settings.keys.voicesDeleteBody(name: v.name),
                  style: AnText.label.copyWith(color: c.inkMuted),
                ),
                expected: v.name,
                inputHint: t.settings.keys.voicesDeleteHint(name: v.name),
                cancelLabel: t.action.cancel,
                onCancel: () => _toggleConfirmation(v.id),
                confirmLabel: t.settings.keys.voicesDeleteConfirm,
                busy: _deleting == v.id,
                onConfirm: () => _remove(v.id),
              ),
            ),
          ),
        ],
        const SizedBox(height: AnSpace.s8),
        // The arithmetic IS the point of this card: two rows with no cap line leave the next
        // enrollment's refusal unexplained. When full, the sentence names the remedy — deletion —
        // because time will not provide one.
        // **算术就是这张卡的意义**:两行而不说上限,会让下一次登记的拒绝无从解释。满的时候,那句话点名
        // 补救办法——**删除**——因为时间不会给出一个。
        Text(
          inv.remaining == 0
              ? t.settings.keys.voicesFull
              : t.settings.keys.voicesRemaining(
                  n: inv.remaining,
                  cap: inv.capacity,
                ),
          style: AnText.label.copyWith(color: c.inkMuted),
        ),
      ],
    );
  }
}
