import '../model/entity.dart';
import 'entity_fixtures.dart';

/// The Entities data port — the only thing the feature's state layer talks to. A real impl
/// (typed calls over core/net to GET /functions, /agents, … + the entities SSE stream)
/// lands later behind this same interface; for now a fixture impl powers zero-backend dev.
/// Entities 数据端口——feature 状态层唯一对话对象。真实现(经 core/net 打各 List 端点 + entities SSE)
/// 日后循此接口落地;现以 fixture 实现支撑零后端开发。
abstract interface class EntitiesRepository {
  Future<List<EntitySummary>> list();
  Future<EntityDetail> detail(String id);
}

class FixtureEntitiesRepository implements EntitiesRepository {
  const FixtureEntitiesRepository();

  @override
  Future<List<EntitySummary>> list() async =>
      fixtureEntities.map((e) => e.summary).toList();

  @override
  Future<EntityDetail> detail(String id) async =>
      fixtureEntities.firstWhere((e) => e.summary.id == id);
}
