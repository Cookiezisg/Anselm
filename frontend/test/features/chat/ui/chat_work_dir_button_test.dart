import 'package:anselm/core/contract/conversation.dart';
import 'package:anselm/core/design/theme.dart';
import 'package:anselm/core/settings/settings_prefs.dart';
import 'package:anselm/core/ui/an_button.dart';
import 'package:anselm/features/chat/data/chat_fixtures.dart';
import 'package:anselm/features/chat/data/chat_providers.dart';
import 'package:anselm/features/chat/state/work_dir.dart';
import 'package:anselm/features/chat/ui/chat_work_dir_button.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// The residency button (WRK-077 WD1) — the breadcrumb folder that is the whole user-facing surface of "we are
// zoomed in HERE". Covered: the THREE button states, the THREE menu sections, the recency list (machine-level,
// zero backend), and the two-state pair (mounted / unmounted) that the batch's whole premise rests on —
// mounting must be OPTIONAL, so the unmounted thread has to be a first-class, fully usable state.
//
// 驻地按钮(WRK-077 WD1)——面包屑里那个文件夹,即「我们 zoom 到**这里**了」面向用户的全部表面。覆盖:按钮**三态**、
// 菜单**三段**、最近目录(机器级、零后端),以及本批全部前提所压着的**两态对**(挂 / 不挂)——挂载必须是**可选**的,
// 故未挂线程必须是一等且完全可用的状态。

const _root = '/Users/you/code/anselm';
const _other = '/Users/you/code/other';

Conversation _conv(String id, {String workDir = ''}) {
  final at = DateTime.utc(2026, 7, 25, 9);
  return Conversation(
    id: id,
    title: 'thread',
    createdAt: at,
    updatedAt: at,
    lastMessageAt: at,
    workDir: workDir,
  );
}

/// The host mounts the button ALONE so a rebuild count / a menu tap is unambiguous. [picked] scripts the
/// directory picker (null = the user cancelled); [prefs] carries the machine-level recency list so its
/// persistence is exercised through the real seam rather than a stub.
///
/// 宿主**单独**挂这个按钮,使一次重建计数 / 一次菜单点击含义明确。[picked] 脚本化目录选择器(null=用户取消);
/// [prefs] 承载机器级最近列表,使它的持久化走**真接缝**、而非某个 stub。
({Widget widget, ProviderContainer container, FixtureChatRepository repo})
_host({
  String workDir = '',
  String? picked,
  SettingsPrefs? prefs,
  Map<String, WorkDirInfo> projections = const {},
}) {
  final repo = FixtureChatRepository(
    conversations: [_conv('cv_1', workDir: workDir)],
  )..workDirInfos.addAll(projections);
  final container = ProviderContainer(
    overrides: [
      chatRepositoryProvider.overrideWithValue(repo),
      if (prefs != null) settingsPrefsProvider.overrideWithValue(prefs),
      directoryPickerProvider.overrideWithValue(() async => picked),
    ],
  );
  addTearDown(container.dispose);
  return (
    widget: UncontrolledProviderScope(
      container: container,
      child: TranslationProvider(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AnTheme.light(),
          home: const Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: ChatWorkDirButton(conversationId: 'cv_1'),
            ),
          ),
        ),
      ),
    ),
    container: container,
    repo: repo,
  );
}

// Tap the ANCHOR, i.e. the button itself. Going through AnButton (not a raw InkWell / a text finder) keeps the
// test honest about the unmounted state, whose button has NO label to find.
// 点**锚**、即按钮本身。经 AnButton(而非裸 InkWell / 文本 finder)使测试对未挂态诚实——那一态的按钮**没有**标签可找。
Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byType(AnButton).first);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => LocaleSettings.setLocaleRaw('zh-CN'));

  group('button three states 按钮三态', () {
    // UNMOUNTED is a first-class state, not an absence: the button renders with no label (the laptop glyph
    // alone — the agent's reach IS the whole machine) and its tooltip says so.
    // 未挂是一等状态、不是缺席:按钮无标签地渲(只有电脑字形——agent 的活动范围**就是**整台机器),tooltip 说明之。
    testWidgets('unmounted: no label, and it still opens a menu', (
      tester,
    ) async {
      final h = _host();
      await tester.pumpWidget(h.widget);
      await tester.pumpAndSettle();

      final t = await _t();
      expect(
        find.text(t.chat.workDir.buttonNone),
        findsNothing,
        reason: 'the tooltip text is not painted until hover',
      );
      expect(find.byType(ChatWorkDirButton), findsOneWidget);
      // No directory name anywhere — the unmounted button is glyph-only. 任何地方都没有目录名——未挂按钮只有字形。
      expect(find.textContaining('anselm'), findsNothing);

      await _openMenu(tester);
      // The SMALL menu §3.1 specifies: choose + (recent, when there is any). No identity head, no "leave".
      // §3.1 指定的那个**小**菜单:选择 + (有的话)最近。无身份头、无「退出」。
      expect(find.text(t.chat.workDir.choose), findsOneWidget);
      expect(find.text(t.chat.workDir.kSwitch), findsNothing);
      expect(find.text(t.chat.workDir.leave), findsNothing);
      expect(find.text(t.chat.workDir.git), findsNothing);
    });

    // MOUNTED shows the directory's own NAME, not the whole path — the path is in the menu's identity head
    // where there is room. 已挂显示目录自己的**名字**、不是整条路径——路径在菜单身份头里,那里有地方。
    testWidgets('mounted: the basename labels the button', (tester) async {
      final h = _host(workDir: _root);
      await tester.pumpWidget(h.widget);
      await tester.pumpAndSettle();
      expect(find.text('anselm'), findsOneWidget);
      expect(
        find.text(_root),
        findsNothing,
        reason: 'the full path belongs in the menu, not the crumb',
      );
    });

    // MISSING: the row is still mounted (path non-empty) but the directory is gone. The menu SAYS so — this
    // is the one state where silence would let every relative path in the thread fail mysteriously.
    // 不存在:行仍是已挂(路径非空)但目录不在了。菜单**说出来**——这是唯一一个「沉默会让线程里每个相对路径神秘失败」
    // 的状态。
    testWidgets('missing: the menu names the absence', (tester) async {
      final h = _host(
        workDir: _root,
        projections: const {_root: WorkDirInfo(path: _root)},
      );
      await tester.pumpWidget(h.widget);
      await tester.pumpAndSettle();
      expect(
        find.text('anselm'),
        findsOneWidget,
        reason: 'a missing directory still names itself',
      );

      await _openMenu(tester);
      final t = await _t();
      expect(find.text(t.chat.workDir.missing), findsOneWidget);
      // Reveal / terminal are disabled: handing a vanished path to the OS does nothing but confuse.
      // 定位 / 终端被禁用:把一个已消失的路径交给系统,除了让人困惑什么也不会发生。
      expect(find.text(t.chat.workDir.revealFinder), findsOneWidget);
      expect(find.text(t.chat.workDir.openTerminal), findsOneWidget);
    });
  });

  group('menu three sections 菜单三段', () {
    testWidgets('identity head + residency actions + git, in that order', (
      tester,
    ) async {
      final h = _host(
        workDir: _root,
        projections: const {
          _root: WorkDirInfo(
            path: _root,
            exists: true,
            isGitRepo: true,
            branch: 'main',
            dirty: true,
          ),
        },
      );
      await tester.pumpWidget(h.widget);
      await tester.pumpAndSettle();
      await _openMenu(tester);

      final t = await _t();
      // ① identity head — the FULL path is the section label, plus the two OS exits.
      expect(find.text(_root), findsOneWidget);
      expect(find.text(t.chat.workDir.revealFinder), findsOneWidget);
      expect(find.text(t.chat.workDir.openTerminal), findsOneWidget);
      // ② residency actions.
      expect(find.text(t.chat.workDir.kSwitch), findsOneWidget);
      expect(find.text(t.chat.workDir.leave), findsOneWidget);
      // ③ git — READ-ONLY in WD1: the branch and the dirty state, and NO branch-switching row (that is WD2;
      // a disabled placeholder would promise a shape this batch does not have).
      // ③ git——WD1 **只读**:分支 + 脏态,且**没有**切分支那一行(那是 WD2;摆个禁用占位等于承诺本批没有的形状)。
      expect(find.text(t.chat.workDir.git), findsOneWidget);
      expect(find.text(t.chat.workDir.branch(name: 'main')), findsOneWidget);
      expect(find.text(t.chat.workDir.dirty), findsOneWidget);
    });

    // A plain (non-repo) directory has NO git section — showing an empty one would be chrome that says
    // nothing. 普通(非仓库)目录**没有** git 段——摆一个空的等于摆一块什么都不说的 chrome。
    testWidgets('a non-repo directory grows no git section', (tester) async {
      final h = _host(
        workDir: _root,
        projections: const {_root: WorkDirInfo(path: _root, exists: true)},
      );
      await tester.pumpWidget(h.widget);
      await tester.pumpAndSettle();
      await _openMenu(tester);

      final t = await _t();
      expect(find.text(_root), findsOneWidget);
      expect(find.text(t.chat.workDir.git), findsNothing);
      expect(find.text(t.chat.workDir.clean), findsNothing);
    });

    // A clean repo says CLEAN rather than staying silent: "no uncommitted changes" is information, and its
    // absence would read as "we didn't check". 干净仓库**说**干净、不沉默:「无未提交改动」是信息,而它的缺席
    // 会被读成「我们没查」。
    testWidgets('a clean repo says so', (tester) async {
      final h = _host(
        workDir: _root,
        projections: const {
          _root: WorkDirInfo(
            path: _root,
            exists: true,
            isGitRepo: true,
            branch: 'wt/wd1',
          ),
        },
      );
      await tester.pumpWidget(h.widget);
      await tester.pumpAndSettle();
      await _openMenu(tester);

      final t = await _t();
      expect(find.text(t.chat.workDir.clean), findsOneWidget);
      expect(find.text(t.chat.workDir.dirty), findsNothing);
      expect(find.text(t.chat.workDir.branch(name: 'wt/wd1')), findsOneWidget);
    });

    // A DETACHED head is not a branch called "HEAD": the backend normalizes both probes to the same word and
    // the menu must render the state, not the word. 游离 HEAD 不是一个叫 "HEAD" 的分支:后端把两个探针归一到同一个
    // 词,而菜单要渲那个**状态**、不是那个词。
    testWidgets('a detached head reads as detached, not as a branch', (
      tester,
    ) async {
      final h = _host(
        workDir: _root,
        projections: const {
          _root: WorkDirInfo(path: _root, exists: true, isGitRepo: true),
        },
      );
      await tester.pumpWidget(h.widget);
      await tester.pumpAndSettle();
      await _openMenu(tester);

      final t = await _t();
      expect(find.text(t.chat.workDir.detached), findsOneWidget);
    });
  });

  group('mount / switch / leave 挂·切换·退出', () {
    // Picking a directory PATCHes the row, and the button re-labels from the ECHOED value — never from the
    // string that was sent (the backend normalizes `~` and Cleans the path).
    // 挑一个目录会 PATCH 那一行,而按钮据**回显**值重新贴标签——绝不据发出去的那个字符串(后端会展开 `~`、Clean 路径)。
    testWidgets('choose mounts, and the crumb re-labels', (tester) async {
      final h = _host(picked: _root);
      await tester.pumpWidget(h.widget);
      await tester.pumpAndSettle();

      await _openMenu(tester);
      await tester.tap(find.text((await _t()).chat.workDir.choose));
      await tester.pumpAndSettle();

      expect(find.text('anselm'), findsOneWidget);
      final row = await h.repo.getConversation('cv_1');
      expect(row.workDir, _root);
    });

    // CANCELLING changes nothing — not the row, not the recency list. A picker that half-applies on cancel is
    // the classic way a directory switch becomes a surprise.
    // **取消**什么都不改——不改行、不改最近列表。一个取消时半生效的选择器,正是「切目录变成惊喜」的经典成因。
    testWidgets('cancelling the picker changes nothing', (tester) async {
      final prefs = SettingsPrefs.inMemory();
      final h = _host(picked: null, prefs: prefs);
      await tester.pumpWidget(h.widget);
      await tester.pumpAndSettle();

      await _openMenu(tester);
      await tester.tap(find.text((await _t()).chat.workDir.choose));
      await tester.pumpAndSettle();

      final row = await h.repo.getConversation('cv_1');
      expect(row.workDir, isEmpty);
      expect(h.container.read(recentWorkDirsProvider), isEmpty);
    });

    // LEAVING unmounts by sending the empty string — there is no third state, so `''` IS the clear.
    // **退出**靠发空串来卸载——没有第三种状态,故 `''` **就是**清除。
    testWidgets('leave unmounts the thread', (tester) async {
      final h = _host(
        workDir: _root,
        projections: const {_root: WorkDirInfo(path: _root, exists: true)},
      );
      await tester.pumpWidget(h.widget);
      await tester.pumpAndSettle();

      await _openMenu(tester);
      await tester.tap(find.text((await _t()).chat.workDir.leave));
      await tester.pumpAndSettle();

      final row = await h.repo.getConversation('cv_1');
      expect(row.workDir, isEmpty);
      expect(find.text('anselm'), findsNothing);
    });
  });

  group('recent directories 最近目录', () {
    // The recency list is MACHINE-level and persists through SettingsPrefs — zero backend by design. It is
    // seeded here through the real key, so a rename of that key breaks this test rather than silently
    // orphaning the user's list.
    // 最近列表是**机器级**、经 SettingsPrefs 持久化——按设计零后端。此处用**真键**播种,故改那个键名会让本测试挂掉、
    // 而不是静默把用户的列表变成孤儿。
    testWidgets('a seeded list is offered, and the current one is filtered out', (
      tester,
    ) async {
      final prefs = SettingsPrefs.inMemory({
        SettingsKeys.chatRecentWorkDirs.key: '["$_root","$_other"]',
      });
      final h = _host(
        workDir: _root,
        prefs: prefs,
        projections: const {_root: WorkDirInfo(path: _root, exists: true)},
      );
      await tester.pumpWidget(h.widget);
      await tester.pumpAndSettle();
      await _openMenu(tester);

      final t = await _t();
      expect(find.text(t.chat.workDir.recent), findsOneWidget);
      // The OTHER directory is offered by name; the CURRENT one is not repeated (switching to where you
      // already are is a row that does nothing). 另一个目录按名字提供;**当前**那个不重复出现(切到你已经在的地方
      // 是一行什么都不做的项)。
      expect(find.text('other'), findsOneWidget);
      expect(
        find.text('anselm'),
        findsOneWidget,
        reason: 'once — the button label, not a recency row',
      );
    });

    testWidgets('picking a recent entry switches to it', (tester) async {
      final prefs = SettingsPrefs.inMemory({
        SettingsKeys.chatRecentWorkDirs.key: '["$_other"]',
      });
      final h = _host(
        workDir: _root,
        prefs: prefs,
        projections: const {
          _root: WorkDirInfo(path: _root, exists: true),
          _other: WorkDirInfo(path: _other, exists: true),
        },
      );
      await tester.pumpWidget(h.widget);
      await tester.pumpAndSettle();
      await _openMenu(tester);
      await tester.tap(find.text('other'));
      await tester.pumpAndSettle();

      expect((await h.repo.getConversation('cv_1')).workDir, _other);
    });

    // A successful mount REMEMBERS the directory, most-recent-first, de-duplicated. A re-pick moves it up
    // rather than adding a second copy. 一次成功挂载会**记住**该目录、最近在前、去重。重复挑选是上移、不是加副本。
    testWidgets('mounting remembers, de-duplicates, and caps the list', (
      tester,
    ) async {
      final prefs = SettingsPrefs.inMemory();
      final h = _host(picked: _root, prefs: prefs);
      await tester.pumpWidget(h.widget);
      await tester.pumpAndSettle();

      final recents = h.container.read(recentWorkDirsProvider.notifier);
      recents.remember(_other);
      recents.remember(_root);
      recents.remember(_other); // a re-pick MOVES it, never duplicates
      expect(h.container.read(recentWorkDirsProvider), [_other, _root]);

      for (var i = 0; i < RecentWorkDirs.cap + 3; i++) {
        recents.remember('/tmp/dir$i');
      }
      final list = h.container.read(recentWorkDirsProvider);
      expect(list, hasLength(RecentWorkDirs.cap));
      expect(
        list.first,
        '/tmp/dir${RecentWorkDirs.cap + 2}',
        reason: 'newest first',
      );
      // It really persisted through the declared key (the machine-level axis, not in-memory state).
      // 它真的经**声明的键**持久化了(机器级轴、不是内存态)。
      expect(
        prefs.getString(SettingsKeys.chatRecentWorkDirs),
        contains('/tmp/dir'),
      );
    });

    // A corrupt preference degrades to an empty list rather than throwing: a convenience menu must never be
    // able to keep the app from starting. 坏偏好退化成空列表、不抛:一个便利菜单绝不该有能力让 app 起不来。
    testWidgets('a corrupt recency preference degrades to empty', (
      tester,
    ) async {
      final prefs = SettingsPrefs.inMemory({
        SettingsKeys.chatRecentWorkDirs.key: 'not json at all',
      });
      final h = _host(prefs: prefs);
      await tester.pumpWidget(h.widget);
      await tester.pumpAndSettle();
      expect(h.container.read(recentWorkDirsProvider), isEmpty);
      await _openMenu(tester);
      expect(find.text((await _t()).chat.workDir.recent), findsNothing);
    });
  });

  group('the in-line mark 行内标记', () {
    // The mark's three shapes come from the ATTRS pair, because both ends are meaningful: a first mount
    // (`from` empty), a switch, and leaving (`to` empty). The label is built client-side — the backend's block
    // content is empty by contract precisely so this text can be localized.
    // 标记的三种形状来自那对 **attrs**,因为两端都有意义:首次挂载(`from` 空)、切换、退出(`to` 空)。标签在客户端
    // 构造——后端那个块的 content 按契约为空,正是为了让这段文字能本地化。
    testWidgets('mounted / switched / left each read differently', (
      tester,
    ) async {
      final t = await _t();
      for (final (from, to, want) in [
        ('', _root, t.chat.workDir.markMounted(to: _root)),
        (_other, _root, t.chat.workDir.markSwitched(from: _other, to: _root)),
        (_other, '', t.chat.workDir.markLeft(from: _other)),
      ]) {
        await tester.pumpWidget(
          TranslationProvider(
            child: MaterialApp(
              theme: AnTheme.light(),
              home: Scaffold(
                body: ChatWorkDirMark(from: from, to: to),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(want), findsOneWidget, reason: 'from=$from to=$to');
      }
    });
  });
}

/// The translations for the active locale — read through the same accessor the widgets use, so a key that was
/// renamed in the JSON fails the test instead of silently comparing two absent strings.
///
/// 当前语言的文案——经**与组件相同**的访问器读取,故 JSON 里被改名的键会让测试挂掉、而不是静默比较两个不存在的串。
Future<Translations> _t() async => LocaleSettings.currentLocale.build();
