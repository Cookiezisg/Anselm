import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/contract/model_capability.dart';
import '../../../core/design/colors.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/ui/ui.dart';
import '../../../i18n/strings.g.dart';
import '../../../core/model/model_capabilities.dart';
import '../state/conversation_header.dart';
import '../state/fork_conversation.dart';
import '../state/selected_conversation.dart';
import '../state/title_reveals.dart';
import 'chat_work_dir_button.dart';

/// The chat ocean's floating-head content. On a THREAD: the title (in-place renameable — the same PATCH
/// as the rail's ⋯ rename) then the per-thread MODEL picker nudged right by it. On the LANDING: the
/// model picker alone sits at the far left — the choice is sticky ([landingModelProvider]) and the first
/// send stamps it onto the new thread, so the picker never disappears between the two states. Auto-title
/// lands here LIVE via the header controller's lifecycle re-read.
///
/// chat 海洋浮层头。线程态:标题(就地改名,同 rail PATCH)+ 被标题挤到右侧一点的线程级**模型选择器**。
/// landing 态:模型选择器独占最左——选择粘性(landingModelProvider),首发盖章到新线程,两态之间选择器
/// 不消失。自动命名经头部控制器的生命周期重读**活着**落进来。
class ChatHead extends ConsumerWidget {
  const ChatHead({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedConversationProvider);
    final t = Translations.of(context);
    final caps = ref.watch(modelCapabilitiesProvider).value ?? const [];

    // Landing: the sticky next-thread choice, far left. landing:粘性选择,最左。
    if (selected == null) {
      final choice = ref.watch(landingModelProvider);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          chatModelMenu(
            t: t,
            caps: caps,
            current: choice,
            onSelect: (v) => ref.read(landingModelProvider.notifier).set(v),
          ),
        ],
      );
    }

    final id = selected.id;
    final header = ref.watch(conversationHeaderProvider(id));
    final conv = header.value;
    if (conv == null) return const SizedBox.shrink();

    // A FRESH auto-title lands as a one-shot typewriter (the rail row plays the same title in sync);
    // done → back to the renameable title. 新自动命名以一次性打字机落地(rail 行同播);完→可改名标题。
    final revealing =
        ref.watch(titleRevealsProvider).contains(id) &&
        conv.title.trim().isNotEmpty;

    final override = conv.modelOverride;
    // The compact head title is READ-ONLY and 1:1 with every OTHER ocean's floating head (OceanBreadcrumb):
    // the 12/w400/inkMuted chrome rung, NOT a 15/ink content heading. Renaming a thread goes through the
    // LEFT-ISLAND rail's ⋯ → rename (same PATCH) — the head no longer inline-edits. The reveal typewriter
    // MUST ride this same style or the auto-title finish flashes. 紧凑头标题=只读、1:1 其他海洋浮层头(12/w400/inkMuted
    // chrome,非 15/ink 内容标题);改名走左岛 rail 的 ⋯→改名;打字机揭示必须同式否则收尾闪号。
    final titleStyle = AnText.meta
        .weight(AnText.emphasisWeight)
        .copyWith(color: context.colors.inkMuted);
    return Row(
      // min: the head hugs its content (title + model) at the left; the scene/outline nav moved to the
      // shell's head-trailing slot so it sits beside the panel-right toggle. min:头收紧到内容(题+模型)靠左;场次钮已挪到 shell 头尾槽。
      mainAxisSize: MainAxisSize.min,
      children: [
        // The RESIDENCY button leads the breadcrumb, BEFORE the name: "where we are" reads left of "what this
        // is", the same order a file path has. It is always this row's first child (it renders its own
        // unmounted state rather than disappearing), so the title / lineage / model slots never shift.
        // 驻地按钮领着面包屑、在名字**之前**:「我们在哪」读在「这是什么」左边,与一条文件路径同序。它**恒是**本行
        // 第一个 child(它自己渲未挂态、而不是消失),故标题 / 血缘 / 模型三个槽位从不移位。
        ChatWorkDirButton(conversationId: id),
        const SizedBox(width: AnSpace.s4),
        Flexible(
          child: revealing
              ? SizedBox(
                  height: AnSize
                      .control, // stable footprint — reveal→resting never jumps 定高,揭示→静止不跳
                  child: Center(
                    widthFactor: 1,
                    child: AnTypewriter(
                      [conv.title],
                      loop: false,
                      // No caret — matched with the rail's twin player. 与 rail 同款无 caret。
                      showCaret: false,
                      textStyle: titleStyle,
                      onDone: () =>
                          ref.read(titleRevealsProvider.notifier).remove(id),
                    ),
                  ),
                )
              : Text(
                  conv.title.isEmpty ? t.chat.kNew : conv.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
                ),
        ),
        const SizedBox(width: AnSpace.s8),
        // The lineage line rides INSIDE the head row rather than becoming a second line: the head is a
        // fixed-height band (AnSize.titlebar), so a stacked line would change the band's height
        // contract for every ocean. It is ALWAYS this row's child (it collapses to a zero-width box on
        // an ordinary thread) so the model menu's slot index never moves — the same reason the
        // transcript's action row returns a shrink box instead of being omitted.
        // 血缘行骑在头部行**内**、不另起一行:头部是定高带(AnSize.titlebar),叠一行会改动所有海洋的带高契约。
        // 它**恒为**本行的 child(普通线程上收成零宽盒),故模型菜单的槽位下标从不移动——与 transcript 动作排
        // 返回零高盒而非省略是同一个理由。
        _ForkLineage(sourceId: conv.forkedFromConversationId),
        chatModelMenu(
          t: t,
          caps: caps,
          current: override == null
              ? null
              : (apiKeyId: override.apiKeyId, modelId: override.modelId),
          onSelect: (v) =>
              ref.read(conversationHeaderProvider(id).notifier).setModel(v),
        ),
      ],
    );
  }
}

/// The forked thread's ancestry, as light as it gets: one small「分叉自 ×××」button in the head that
/// navigates back to the source.
///
/// The source's NAME is not on the fork's own row (the wire carries only the id — lineage is
/// provenance, not an embedded copy that would go stale on a rename), so it is read fresh through
/// [forkSourceProvider]. Three states, all honest and all the SAME slot (the button is always this
/// row's child once a thread is a fork, so the head's children never shift): named once loaded, and a
/// generic "another conversation" while loading OR when the source is gone (a fork outlives its
/// parent by design — the ids simply dangle, nothing cascades, and the read never retries).
///
/// 分叉线程的来处,轻到极限:头部一个小小的「分叉自 ×××」钮,点回源头。
///
/// 源的**名字**不在分叉自己的行上(线缆只带 id——血缘是溯源、不是会随改名过期的内嵌副本),故经
/// forkSourceProvider 读时新鲜取。三种状态都诚实、且**同一个槽位**(线程一旦是分叉,钮恒为该行的 child,
/// 故头部 children 从不移位):加载好即具名,加载中**或**源已不在时用泛称「另一个对话」(分叉活得比父长是
/// 设计使然——id 只是悬空、不级联任何东西,且那次读不重试)。
class _ForkLineage extends ConsumerWidget {
  const _ForkLineage({required this.sourceId});

  final String sourceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (sourceId.isEmpty) return const SizedBox.shrink();
    final t = Translations.of(context);
    final src = ref.watch(forkSourceProvider(sourceId));
    final title = src.value?.title.trim() ?? '';
    final label = title.isEmpty
        ? t.chat.forkedFromUnknown
        : t.chat.forkedFrom(title: title);
    return Padding(
      padding: const EdgeInsets.only(right: AnSpace.s8),
      child: AnButton(
        label: label,
        icon: AnIcons.control,
        size: AnButtonSize.sm,
        onPressed: () => context.go(conversationLocation(sourceId)),
      ),
    );
  }
}

/// The one model menu every chat surface shares — the head's landing/thread pickers, the
/// LLM_RESOLVE_ERROR banner's「重选模型」CTA (拍板 #16), AND the action row's retry-with-another-model
/// (WRK-077 CH-c): Auto (clear) + one entry per capability. [anchorBuilder] swaps the anchor face
/// (default: a button labeled with the current choice).
///
/// [leadingEntries] ride ABOVE the model list and [includeAuto] drops the Auto row. Both exist for the retry
/// menu, whose grammar differs in one honest way: its first row is「重试」(keep whatever this thread is set
/// to) and it has NO Auto, because a retry cannot CLEAR a thread's override — an absent per-turn model means
/// "use the thread's", not "use the workspace default". Showing Auto there would make the row lie about what
/// picking it does.
///
/// 各 chat 面共用的模型菜单(头部两态、解析失败横幅 CTA、**以及**动作排的「换模型重试」,WRK-077 CH-c):
/// Auto+每能力一项;anchorBuilder 换锚脸。
///
/// [leadingEntries] 骑在模型列表**上方**、[includeAuto] 去掉 Auto 行。两者为重试菜单而存在,它的文法有一处诚实的
/// 不同:首行是「重试」(用这条线程现有的设置)、且**没有** Auto,因为重试无法**清除**线程的 override——缺席的逐回合
/// 模型意为「用线程的」、不是「用 workspace 默认」。在那里显示 Auto 会让这一行对「点它会发生什么」撒谎。
Widget chatModelMenu({
  required Translations t,
  required List<ModelCapability> caps,
  required ({String apiKeyId, String modelId})? current,
  required ValueChanged<({String apiKeyId, String modelId})?> onSelect,
  Widget Function(BuildContext context, VoidCallback toggle, bool isOpen)?
  anchorBuilder,
  List<AnMenuEntry> leadingEntries = const [],
  bool includeAuto = true,
}) {
  // The anchor lives at the head's LEFT (landing: far left; thread: right after the title), so the
  // menu opens DOWN-RIGHT (start-aligned — AnMenu defaults to end); the popover flips on overflow.
  // The anchor shows the capability's DISPLAY NAME (same label the menu row shows — a picked
  // 'DeepSeek Chat' must not echo back as 'deepseek-chat'), falling back to the raw id for an
  // override whose capability is gone. md tier: the 13 label rung beside the 15 title (sm's meta
  // 12 sat a rung too low and a 24 box mis-centred in the 44 head band).
  // 锚在头部左区,菜单**右下**展开(start 对齐)、越界自翻。锚显 displayName(与菜单行同名——选了
  // 「DeepSeek Chat」不能回显 raw id;能力已失才回落 id)。md 档:15 标题旁的 13 标签档。
  final anchorLabel = current == null
      ? t.chat.modelAuto
      : caps
                .where(
                  (cap) =>
                      cap.modelId == current.modelId &&
                      cap.apiKeyId == current.apiKeyId,
                )
                .map(
                  (cap) =>
                      cap.displayName.isEmpty ? cap.modelId : cap.displayName,
                )
                .firstOrNull ??
            current.modelId;
  return AnMenu(
    alignEnd: false,
    anchorBuilder:
        anchorBuilder ??
        (context, toggle, isOpen) =>
            AnButton(label: anchorLabel, onPressed: toggle),
    entries: [
      ...leadingEntries,
      if (includeAuto)
        AnMenuItem(
          label: t.chat.modelAuto,
          checked: current == null,
          onTap: () => onSelect(null),
        ),
      for (final cap in caps)
        AnMenuItem(
          label: cap.displayName.isEmpty ? cap.modelId : cap.displayName,
          meta: cap.keyName.isEmpty ? cap.provider : cap.keyName,
          checked:
              current?.modelId == cap.modelId &&
              current?.apiKeyId == cap.apiKeyId,
          onTap: () => onSelect((apiKeyId: cap.apiKeyId, modelId: cap.modelId)),
        ),
    ],
  );
}
