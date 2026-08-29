import 'package:anselm/app/entity_mention_source.dart';
import 'package:anselm/core/contract/entities/agent.dart';
import 'package:anselm/core/contract/entities/function.dart';
import 'package:anselm/core/contract/entities/skill.dart';
import 'package:anselm/core/contract/page.dart';
import 'package:anselm/core/entity/mention_source.dart';
import 'package:anselm/features/entities/data/entity_row.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:anselm/features/entities/data/entity_providers.dart';
import 'package:anselm/features/entities/data/entity_fixtures.dart';
import 'package:anselm/features/entities/data/entity_repository.dart';
import 'package:anselm/features/library/data/library_fixtures.dart';
import 'package:anselm/features/library/data/library_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// CH-0 (WRK-077 §5.16) — the user reported "@ 没有出现那个选择页面。@ 不了东西了".
//
// The composer closes the @ picker when the search throws, and it is right to: leaving the PREVIOUS
// query's candidates on screen would let the reader pick a wrong mention. But `search` fanned out to the
// entity kinds with a bare `Future.wait`, which FAILS FAST — so one kind erroring took the whole panel
// down, silently, with no way for the reader to tell the difference between "nothing matched" and
// "something broke".
//
// NOT ESTABLISHED: that this was the cause of the user's report. Confirming that needs their machine (the
// panel has other ways to stay shut, listed in §5.16). What is established is the fault-isolation hole,
// and these tests pin it shut.
//
// CH-0(WRK-077 §5.16)——用户报「@ 没有出现那个选择页面。@ 不了东西了」。
//
// search 抛错时 composer 会关掉 @ 面板,而它没做错:留着**上一个** query 的候选会让读者插入错误的提及。但
// `search` 用一个裸 `Future.wait` 扇出到各类实体,而它是**快速失败**的——于是一类出错就把整个面板带走,且是
// 静默的,读者无从分辨「没匹配到」与「出故障了」。
//
// **尚未确证**:这是否就是用户那次报告的成因。确证需要他的机器(面板不开还有别的路径,§5.16 已列)。**已确证**
// 的是那个故障隔离缺口,而这些测试把它钉死。
void main() {
  // EntityMentionSource takes a `Ref`, so it is built inside a provider exactly as the app assembly does
  // — no hand-made Ref, no shortcut that would test a different wiring than production runs.
  // EntityMentionSource 要一个 `Ref`,故按 app 装配的原样在 provider 内构造——不手造 Ref、不走会测到与生产不同接线的捷径。
  final sourceProvider = Provider<MentionSource>(EntityMentionSource.new);

  // The fixture repository starts EMPTY, so a seeded one is required or every assertion would pass/fail for
  // the wrong reason. fixture 仓储开局是**空**的,故必须灌数据,否则每条断言都会因错误的理由通过或失败。
  FixtureEntityRepository seeded() => FixtureEntityRepository(
    functions: [
      FunctionEntity(id: 'fn_1', name: 'alpha', createdAt: _t, updatedAt: _t),
    ],
    agents: [
      AgentEntity(id: 'ag_1', name: 'beta', createdAt: _t, updatedAt: _t),
    ],
  );

  MentionSource hosting(EntityRepository repo, {LibraryRepository? library}) {
    final c = ProviderContainer(
      overrides: [
        entityRepositoryProvider.overrideWithValue(repo),
        libraryRepositoryProvider.overrideWithValue(
          library ?? FixtureLibraryRepository(),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c.read(sourceProvider);
  }

  test('a browse search returns candidates across the kinds', () {
    return hosting(seeded()).search('').then((found) {
      expect(found, isNotEmpty);
      expect(
        found.map((m) => m.type).toSet().length,
        greaterThan(1),
        reason: 'the panel lists more than one kind',
      );
    });
  });

  test('ONE failing kind costs only that kind — the panel still opens', () async {
    // The whole point: degrade to fewer rows, never to no panel. 要害:降级成少几行,绝不降级成没有面板。
    final repo = _OneKindFails(EntityKind.agent, seeded());
    final found = await hosting(repo).search('');

    expect(
      found,
      isNotEmpty,
      reason: 'a single kind erroring must not empty the picker',
    );
    expect(
      found.where((m) => m.type == EntityKind.agent.name),
      isEmpty,
      reason: 'the failing kind contributes nothing',
    );
    expect(
      found.where((m) => m.type == EntityKind.function.name),
      isNotEmpty,
      reason: 'the healthy kinds are unaffected',
    );
  });

  test('EVERY kind failing still resolves — empty, not thrown', () async {
    // An empty list closes the picker, which is the correct outcome for "nothing to show". A THROW is not:
    // it takes the same visible path but also leaves an error nobody handles.
    // 空列表会关掉面板,而那是「没东西可显」的正确结果。**抛错**不是:它走同样的可见路径,却还留下一个无人处理的错误。
    final found = await hosting(_AllKindsFail()).search('anything');
    expect(found, isEmpty);
  });

  test(
    'a skills-list hiccup does not break the entity candidates either',
    () async {
      final found = await hosting(seeded(), library: _SkillsFail()).search('');
      expect(found, isNotEmpty);
      expect(found.where((m) => m.type == 'skill'), isEmpty);
    },
  );

  test('@ candidates exclude fork skills while retaining inline skills', () async {
    final found = await hosting(
      seeded(),
      library: FixtureLibraryRepository(
        skills: [
          Skill(
            name: 'inline-one',
            description: 'shown in the mention picker',
            context: kSkillContextInline,
            updatedAt: _t,
          ),
          Skill(
            name: 'fork-one',
            description: 'dispatched as a subagent',
            context: kSkillContextFork,
            updatedAt: _t,
          ),
        ],
      ),
    ).search('');

    final skillNames = found
        .where((candidate) => candidate.type == 'skill')
        .map((candidate) => candidate.name)
        .toList();
    expect(skillNames, contains('inline-one'));
    expect(skillNames, isNot(contains('fork-one')));
  });
}

/// A repository where exactly one kind is having a bad day. 恰好一类不舒服的仓储。
/// A repository where exactly one kind is having a bad day, and it throws SYNCHRONOUSLY — which is the
/// harsher case: a bare call would blow up before any `.catchError` could attach.
/// 恰好一类不舒服的仓储,且它**同步**抛错——这是更狠的情形:裸调用会在任何 `.catchError` 挂上之前就炸掉。
class _OneKindFails implements EntityRepository {
  _OneKindFails(this.broken, this.inner);

  final EntityKind broken;
  final FixtureEntityRepository inner;

  @override
  Future<Page<EntityRow>> listEntities(
    EntityKind kind, {
    String? cursor,
    int? limit,
    String? search,
  }) {
    if (kind == broken) throw StateError('kind $kind is down');
    return inner.listEntities(
      kind,
      cursor: cursor,
      limit: limit,
      search: search,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('not used by the mention source');
}

class _AllKindsFail implements EntityRepository {
  @override
  Future<Page<EntityRow>> listEntities(
    EntityKind kind, {
    String? cursor,
    int? limit,
    String? search,
  }) => throw StateError('everything is down');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('not used by the mention source');
}

class _SkillsFail extends FixtureLibraryRepository {
  @override
  Future<List<Skill>> listSkills() => throw StateError('skills are down');
}

final _t = DateTime.utc(2026, 7, 25);
