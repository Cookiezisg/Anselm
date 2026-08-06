import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/contract/api_key.dart';
import '../../../../core/design/colors.dart';
import '../../../../core/design/tokens.dart';
import '../../../../core/design/typography.dart';
import '../../../../core/ui/an_button.dart';
import '../../../../core/ui/an_card.dart';
import '../../../../core/ui/an_row.dart';
import '../../../../core/ui/an_state.dart';
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

  Future<void> _remove(String id) async {
    if (_deleting != null) return;
    setState(() => _deleting = id);
    try {
      await ref.read(voicesProvider.notifier).remove(id);
    } catch (_) {
      if (!mounted) return;
      // The backend deletes the UPSTREAM registration first and keeps the row when that fails, so a
      // failure here means the voice is still real and still usable. Saying so beats a bare error:
      // the user's next move is「retry」, not「it is gone, re-enroll」.
      // 后端**先删上游登记**、那一步失败就保留行,故这里的失败意味着音色**仍然是真的、仍然可用**。
      // 说清楚这一点胜过一句光秃秃的报错:用户的下一步是「重试」,不是「没了,重新登记」。
      ref
          .read(noticeCenterProvider.notifier)
          .show(
            Translations.of(context).settings.keys.voicesDeleteFailed,
            tone: AnTone.warn,
          );
    } finally {
      if (mounted) setState(() => _deleting = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Translations.of(context);
    final c = context.colors;
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
            AsyncError() => AnState(
              kind: AnStateKind.error,
              title: t.settings.keys.voicesLoadFailed,
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
      return AnState(
        kind: AnStateKind.empty,
        size: AnStateSize.inset,
        title: t.settings.keys.voicesEmpty,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final v in inv.items)
          AnRow(
            label: v.name,
            actions: [
              AnButton(
                label: t.settings.keys.voicesDelete,
                size: AnButtonSize.sm,
                outline: true,
                onPressed: _deleting == v.id ? null : () => _remove(v.id),
              ),
            ],
          ),
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
