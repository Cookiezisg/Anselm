/// Top-band live notices for the story dataset. The default demo's tour (`demo_notice_showcase.dart`)
/// names workflows that do not exist in the story, so screenshots would show a band contradicting the
/// ledger. These beats use the bible's ids: the approval band for the parked digest run lands early and
/// stays (approval notices persist until decided), which is the hero moment for the website. It is
/// the only beat: every other surface is captured with the band dismissed, so nothing else may queue.
///
/// story 数据集的顶带即时通知。默认 demo 的巡演用了故事里不存在的工作流名，截图会和账本矛盾。这里全部
/// 取总纲 id：停在审批的周报 run 的审批带早早出现并常驻（审批通知直到决定前不消失），这是官网首屏。
/// 只保留这一拍：其它面都在关掉审批带后截图，因此不能再排队别的通知。
library;

import '../../core/model/status_state.dart';
import '../../core/notice/notice_center.dart';
import '../../core/ui/icons.dart';
import '../../i18n/strings.g.dart';
import '../demo_notice_showcase.dart' show DemoNoticeBeat;
import 'story_bible.dart';

List<DemoNoticeBeat> storyTopBandShowcase(Translations t) {
  String event(String workflow, String verb) =>
      '${t.ref.workflow} ${t.notifications.nameQuoted(name: workflow)} $verb';
  return <DemoNoticeBeat>[
    DemoNoticeBeat(
      at: const Duration(seconds: 3),
      message: NoticeMessage(
        text: event(wfDigestName, t.notifications.verb.waitingApproval),
        icon: AnIcons.approval,
        tone: AnTone.warn,
        kind: NoticeKind.approval,
        origin: NoticeOrigin.event,
        title: apfDigestName,
        flowrunId: frDigestParked,
        nodeId: 'review',
        location: '/scheduler/w/$wfDigest/runs/$frDigestParked',
      ),
      priority: NoticePriority.priority,
    ),
  ];
}
