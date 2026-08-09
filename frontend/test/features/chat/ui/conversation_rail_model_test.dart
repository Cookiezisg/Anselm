import 'package:anselm/core/contract/conversation.dart';
import 'package:anselm/core/model/sidebar_model.dart';
import 'package:anselm/core/model/status_state.dart';
import 'package:anselm/features/chat/state/conversation_list_state.dart';
import 'package:anselm/features/chat/ui/conversation_rail_model.dart';
import 'package:flutter_test/flutter_test.dart';

// Local (not UTC) timestamps so toLocal() is identity → bucket/time tests are TZ-deterministic.
Conversation _cAt(
  String id,
  DateTime at, {
  bool pinned = false,
  String workDir = '',
}) => Conversation(
  id: id,
  title: id,
  pinned: pinned,
  workDir: workDir,
  createdAt: at,
  updatedAt: at,
  lastMessageAt: at,
);

final _now = DateTime(2026, 6, 26, 12);

final _timeStrings = ConvTimeStrings(
  justNow: 'now',
  yesterday: 'yest',
  minutesAgo: (n) => '${n}m',
  hoursAgo: (n) => '${n}h',
  daysAgo: (n) => '${n}d',
);

const _labels = ConvRailLabels(
  newLabel: 'New',
  filter: 'Filter',
  pinned: 'PINNED',
  recents: 'RECENTS',
  time: ConvTimeStrings(
    justNow: 'now',
    yesterday: 'yest',
    minutesAgo: _m,
    hoursAgo: _h,
    daysAgo: _d,
  ),
);
String _m(int n) => '${n}m';
String _h(int n) => '${n}h';
String _d(int n) => '${n}d';

// STEP 3 gate — the conversation-row lead-dot mapping. The row itself is a plain AnRow (verified
// visually in the gallery's Chat category); this pins the precedence that picks WHICH dot:
// generating > awaiting > unread > archived > none.

Conversation _c({
  bool generating = false,
  bool awaiting = false,
  bool unread = false,
  bool archived = false,
}) {
  final t = DateTime.utc(2026, 6, 26);
  return Conversation(
    id: 'cv_1',
    title: 't',
    createdAt: t,
    updatedAt: t,
    lastMessageAt: t,
    isGenerating: generating,
    awaitingInput: awaiting,
    hasUnread: unread,
    archived: archived,
  );
}

void main() {
  test('a plain active thread has no dot', () {
    expect(conversationDot(_c()), isNull);
  });

  test(
    'awaiting input → wait (amber), the HIGHEST precedence (over generating too)',
    () {
      expect(conversationDot(_c(awaiting: true)), AnStatus.wait);
      // A gate-blocked turn keeps isGenerating true AND awaitingInput true — the "needs you" amber must
      // win over the blue, else it is unreachable in production. 等你优先于生成中(被闸回合两者同真)。
      expect(
        conversationDot(
          _c(generating: true, awaiting: true, unread: true, archived: true),
        ),
        AnStatus.wait,
      );
    },
  );

  test(
    'generating → run (blue), over unread + archived (but under awaiting)',
    () {
      expect(conversationDot(_c(generating: true)), AnStatus.run);
      expect(
        conversationDot(_c(generating: true, unread: true, archived: true)),
        AnStatus.run,
      );
    },
  );

  test('unread → done (green), over archived', () {
    expect(conversationDot(_c(unread: true)), AnStatus.done);
    expect(conversationDot(_c(unread: true, archived: true)), AnStatus.done);
  });

  test('archived → idle (gray marker), the lowest', () {
    expect(conversationDot(_c(archived: true)), AnStatus.idle);
  });

  group('conversationTimeLabel', () {
    String label(DateTime at) => conversationTimeLabel(at, _now, _timeStrings);
    test('< 1 min → just now', () => expect(label(_now), 'now'));
    test(
      '< 60 min → N min',
      () => expect(label(_now.subtract(const Duration(minutes: 5))), '5m'),
    );
    test(
      'same day, hours → N hr',
      () => expect(label(DateTime(2026, 6, 26, 9)), '3h'),
    );
    test(
      'previous day → yesterday',
      () => expect(label(DateTime(2026, 6, 25, 9)), 'yest'),
    );
    test(
      '2–7 days → N days',
      () => expect(label(DateTime(2026, 6, 23, 9)), '3d'),
    );
    test(
      '> 7 days → numeric y/m/d',
      () => expect(label(DateTime(2026, 5, 27, 9)), '2026/5/27'),
    );
  });

  group('buildConversationRailModel', () {
    // The rail is FOUR sections now (WD1.5): Pinned, one per residency, Recents. Everything below pins one
    // rule of that structure — and the load-bearing ones are the head COUNT (it comes from the server's
    // projection, so it cannot drift as the user scrolls a group) and NO DUPLICATION (a pinned thread with a
    // residency renders under 置顶 and nowhere else).
    // rail 现在是**四段**(WD1.5):置顶、每驻地一段、最近。下面每条钉住该结构的一条规则——承重的两条是组头**计数**
    // (它来自服务端投影,故不随用户滚动某个组而漂移)与**不重复**(一条带驻地的置顶线程渲在「置顶」下、别处没有)。

    test('four sections in order: Pinned · residency groups · Recents', () {
      final types = _types(
        _state(
          pinned: [_cAt('cv_pin', DateTime(2026, 6, 20, 9), pinned: true)],
          recents: [_cAt('cv_home', DateTime(2026, 6, 26, 9))],
          groups: [
            _g('/w/alpha', DateTime(2026, 6, 26, 11), active: 2),
            _g('/w/beta', DateTime(2026, 6, 24, 11), active: 1),
          ],
          groupRows: {
            '/w/alpha': [
              _cAt('cv_a1', DateTime(2026, 6, 26, 11), workDir: '/w/alpha'),
              _cAt('cv_a2', DateTime(2026, 6, 26, 10), workDir: '/w/alpha'),
            ],
          },
        ),
      );
      expect(types.map((t) => t.label), ['PINNED', 'alpha', 'beta', 'RECENTS']);
      // Group order is the server's (most recently active first) and Recents is always last — the user asked
      // for exactly this shape. 组序是服务端的(最近活跃在前),「最近」恒在最后——用户要的正是这个形状。
      expect(types[1].rows.map((r) => r.id), ['cv_a1', 'cv_a2']);
      expect(types.last.rows.single.id, 'cv_home');
    });

    test(
      'a group head counts the SERVER projection, not the rows loaded so far — the anti-drift rule',
      () {
        // Nine threads in the residency, one page of two loaded. A client-side groupBy would say «2» here and
        // then «4» after a scroll — a number that moves while nothing moved.
        // 驻地里九条、已加载一页两条。客户端 groupBy 会在此说「2」、滚一下再说「4」——一个在什么都没动时自己在动的数。
        final types = _types(
          _state(
            groups: [_g('/w/alpha', DateTime(2026, 6, 26, 11), active: 9)],
            groupRows: {
              '/w/alpha': [
                _cAt('cv_a1', DateTime(2026, 6, 26, 11), workDir: '/w/alpha'),
                _cAt('cv_a2', DateTime(2026, 6, 26, 10), workDir: '/w/alpha'),
              ],
            },
          ),
        );
        expect(types.single.count, 9);
        expect(types.single.rows.length, 2);
      },
    );

    test('flat heads use the exact axis total, not the loaded window', () {
      final types = _types(
        _state(
          pinned: [
            _cAt('cv_pin_1', DateTime(2026, 6, 26, 11), pinned: true),
            _cAt('cv_pin_2', DateTime(2026, 6, 26, 10), pinned: true),
          ],
          pinnedTotal: 32,
        ),
      );
      expect(types.single.count, 32);
      expect(types.single.rows.length, 2);
    });

    test(
      'show-archived sums the two counts; otherwise the head counts only the active ones',
      () {
        state() => _state(
          groups: [
            _g('/w/alpha', DateTime(2026, 6, 26, 11), active: 4, archived: 3),
          ],
        );
        expect(_types(state()).single.count, 4);
        expect(_types(state(), showArchived: true).single.count, 7);
      },
    );

    test(
      'a PINNED residency thread renders under Pinned and NOT in its group — exactly once',
      () {
        final pin = _cAt(
          'cv_pin',
          DateTime(2026, 6, 26, 11),
          pinned: true,
          workDir: '/w/alpha',
        );
        final types = _types(
          _state(
            pinned: [pin],
            groups: [_g('/w/alpha', DateTime(2026, 6, 26, 11), active: 1)],
            groupRows: {
              '/w/alpha': [
                _cAt('cv_a1', DateTime(2026, 6, 26, 10), workDir: '/w/alpha'),
              ],
            },
          ),
        );
        final ids = types.expand((t) => t.rows).map((r) => r.id).toList();
        expect(ids.where((id) => id == 'cv_pin').length, 1);
        expect(types.first.label, 'PINNED');
        expect(types.first.rows.single.id, 'cv_pin');
        expect(types[1].rows.map((r) => r.id), ['cv_a1']);
      },
    );

    test(
      'only the FIRST (most recently active) group starts open — the rest are folded',
      () {
        // Folding keeps «Recents» reachable without scrolling past every folder, and a folded section fetches
        // nothing at all; the group you were just working in stays open.
        // 收起使「最近」不必翻过每个文件夹才够得着,且收起的段什么都不取;你刚在里面干活的那个组保持打开。
        final types = _types(
          _state(
            groups: [
              _g('/w/alpha', DateTime(2026, 6, 26, 11)),
              _g('/w/beta', DateTime(2026, 6, 25, 11)),
              _g('/w/gamma', DateTime(2026, 6, 24, 11)),
            ],
          ),
        );
        expect(types.map((t) => t.initiallyFolded), [false, true, true]);
      },
    );

    test(
      'a group whose rows were never fetched still offers a tail — that is how its first page loads',
      () {
        final types = _types(
          _state(
            groups: [_g('/w/alpha', DateTime(2026, 6, 26, 11), active: 5)],
          ),
        );
        expect(types.single.rows, isEmpty);
        expect(types.single.hasMore, isTrue);
        // The pageKey IS the notifier's axis key, so the sentinel that fires can name the residency.
        // pageKey **就是** notifier 的轴键,故触发的那个哨兵能点出是哪个驻地。
        expect(types.single.pageKey, 'wd:/w/alpha');
      },
    );

    test('every section is a paginated axis keyed by its own axis id', () {
      final types = _types(
        _state(
          pinned: [_cAt('cv_pin', _now, pinned: true)],
          recents: [_cAt('cv_home', _now)],
          groups: [_g('/w/alpha', _now)],
        ),
      );
      expect(types.map((t) => t.pageKey), ['pinned', 'wd:/w/alpha', 'recents']);
    });

    test(
      'an un-titled thread falls back to the New-chat label — a row never renders blank',
      () {
        final at = DateTime(2026, 6, 26, 9);
        final untitled = Conversation(
          id: 'cv_u',
          title: '  ',
          createdAt: at,
          updatedAt: at,
          lastMessageAt: at,
        );
        final types = _types(_state(recents: [untitled]));
        expect(types.single.rows.single.label, 'New'); // labels.newLabel
      },
    );

    test('no pinned → only the Recents section', () {
      final types = _types(_state(recents: [_cAt('cv_a', _now)]));
      expect(types.map((t) => t.label), ['RECENTS']);
    });

    // 用户 0718 拍板 — 空态=满态收起的形状: zero conversations render BOTH flat heads (empty), teaching the
    // structure; a "0" count is noise so an empty head carries no count. And NO residency group is invented:
    // a group is a projection, so a group with nothing in it does not exist.
    // 零对话渲两个平段头(空)、不显「0」。且**不**凭空造驻地组:组是投影,什么都没装的组并不存在。
    test(
      'zero conversations → both flat heads render (empty), no counts, no invented group',
      () {
        final types = _types(_state());
        expect(types.map((t) => t.label), ['PINNED', 'RECENTS']);
        expect(types.every((t) => t.rows.isEmpty), isTrue);
        expect(types.every((t) => t.count == null), isTrue);
      },
    );

    test(
      'showCount/showTime off → section counts and row time meta are null (⚙ toggles)',
      () {
        final types = _types(
          _state(
            pinned: [_cAt('cv_pin', _now, pinned: true)],
            recents: [_cAt('cv_a', _now)],
            groups: [_g('/w/alpha', _now, active: 3)],
          ),
          showCount: false,
          showTime: false,
        );
        expect(types.every((t) => t.count == null), isTrue);
        expect(
          types.expand((t) => t.rows).every((r) => r.meta == null),
          isTrue,
        );
      },
    );

    // ── the five batteries (空/单组/海量组/超长目录名/极值计数) 五电池 ──

    test('battery · a single group and nothing else', () {
      final types = _types(_state(groups: [_g('/w/only', _now, active: 1)]));
      expect(types.map((t) => t.label), ['only']);
      expect(types.single.initiallyFolded, isFalse);
    });

    test('battery · 200 groups: all rendered, only the first open', () {
      final types = _types(
        _state(
          groups: [
            for (var i = 0; i < 200; i++)
              _g('/w/p$i', _now.subtract(Duration(minutes: i)), active: i + 1),
          ],
        ),
      );
      expect(types.length, 200);
      expect(types.first.initiallyFolded, isFalse);
      expect(types.skip(1).every((t) => t.initiallyFolded), isTrue);
      // Distinct fold/paging keys throughout — a collision would fuse two folders' fold state.
      // 全程互不相同的折叠/分页键——撞键会把两个文件夹的折叠态融在一起。
      expect(types.map((t) => t.pageKey).toSet().length, 200);
    });

    test('battery · an absurdly long directory name survives as a label', () {
      final long = '/w/${'x' * 500}';
      final types = _types(_state(groups: [_g(long, _now)]));
      expect(types.single.label, 'x' * 500);
    });

    test('battery · extreme counts pass through unmangled', () {
      final types = _types(
        _state(groups: [_g('/w/huge', _now, active: 999999, archived: 999)]),
      );
      expect(types.single.count, 999999);
      expect(
        _types(
          _state(groups: [_g('/w/huge', _now, active: 999999, archived: 999)]),
          showArchived: true,
        ).single.count,
        1000998,
      );
    });

    test(
      'a folder whose last thread was ARCHIVED disappears — until «show archived» brings it back',
      () {
        // Archiving a folder's last thread must make the folder go away exactly as deleting it does: a group
        // is a projection, it exists only while something is in it. The projection still REPORTS the group
        // (its archived threads are still there), so the rule lives in the rail, and «show archived» restores
        // the whole folder rather than stranding its rows somewhere.
        // 归档一个文件夹最后一条线程必须让它像被删掉一样消失:组是投影、只在里面还有东西时存在。投影仍**报告**该组
        // (它的归档线程还在),故规则住在 rail 里,而「显示已归档」会把整个文件夹恢复、而不是把它的行搁在某处。
        final state = _state(
          groups: [_g('/w/alpha', _now, active: 0, archived: 3)],
        );
        expect(_types(state), isEmpty);
        final shown = _types(state, showArchived: true);
        expect(shown.single.label, 'alpha');
        expect(shown.single.count, 3);
      },
    );
  });

  group('workDirGroupLabels', () {
    test('no collision → each directory is named by its own last segment', () {
      expect(workDirGroupLabels(['/a/anselm', '/b/notes']), {
        '/a/anselm': 'anselm',
        '/b/notes': 'notes',
      });
    });

    test('a collision grows LEFTWARD, and only for the paths that collide', () {
      expect(workDirGroupLabels(['/work/anselm', '/fork/anselm', '/x/notes']), {
        '/work/anselm': 'work/anselm',
        '/fork/anselm': 'fork/anselm',
        '/x/notes': 'notes', // untouched — it never collided
      });
    });

    test('one extra segment need not settle it — growth repeats', () {
      expect(workDirGroupLabels(['/a/x/anselm', '/b/x/anselm']), {
        '/a/x/anselm': 'a/x/anselm',
        '/b/x/anselm': 'b/x/anselm',
      });
    });

    test('a path that runs out of segments stops growing', () {
      // «anselm» at the filesystem root cannot grow further; it keeps its shortest honest name.
      // 文件系统根下的「anselm」无从再长;它保留自己最短的诚实名字。
      expect(workDirGroupLabels(['/anselm', '/deep/nest/anselm']), {
        '/anselm': 'anselm',
        '/deep/nest/anselm': 'nest/anselm',
      });
    });

    test(
      'a bare root degrades to its own spelling rather than an empty head',
      () {
        expect(workDirGroupLabels(['/']), {'/': '/'});
      },
    );

    test('Windows separators are segments too', () {
      expect(workDirGroupLabels([r'C:\work\anselm', r'C:\fork\anselm']), {
        r'C:\work\anselm': 'work/anselm',
        r'C:\fork\anselm': 'fork/anselm',
      });
    });
  });
}

// ── helpers 助手 ──

List<SidebarType> _types(
  ConversationListState state, {
  bool showCount = true,
  bool showTime = true,
  bool showArchived = false,
}) => buildConversationRailModel(
  state,
  now: _now,
  labels: _labels,
  showCount: showCount,
  showTime: showTime,
  showArchived: showArchived,
).groups.single.types;

ConversationListState _state({
  List<Conversation> pinned = const [],
  List<Conversation> recents = const [],
  int? pinnedTotal,
  int? recentsTotal,
  List<WorkDirGroup> groups = const [],
  Map<String, List<Conversation>> groupRows = const {},
}) => ConversationListState(
  pinned: ConvAxis(rows: pinned, total: pinnedTotal, loaded: true),
  recents: ConvAxis(rows: recents, total: recentsTotal, loaded: true),
  groups: groups,
  groupAxes: {
    for (final e in groupRows.entries)
      e.key: ConvAxis(rows: e.value, loaded: true),
  },
);

WorkDirGroup _g(String dir, DateTime at, {int active = 1, int archived = 0}) =>
    WorkDirGroup(
      workDir: dir,
      activeCount: active,
      archivedCount: archived,
      lastMessageAt: at,
    );
