import 'package:anselm/features/settings/data/settings_demo_fixture.dart';
import 'package:flutter_test/flutter_test.dart';

// D-032/033/034 — the `make demo` settings fixture must SEED memories / MCP servers / sandbox
// runtimes+envs, so every settings panel shows a populated state instead of an empty placeholder.
// 每个设置面板都有数据态而非空占位。
void main() {
  final repo = demoSettingsRepository();

  test('D-034 memories: a pinned row + user + AI notes (each source/pin state)', () async {
    final mems = await repo.listMemories();
    expect(mems, isNotEmpty);
    expect(mems.any((m) => m.pinned), isTrue, reason: '金色 pin 行');
    expect(mems.any((m) => m.source == 'user'), isTrue);
    expect(mems.any((m) => m.source == 'ai'), isTrue);
    // The pinned filter projects. 固定过滤生效。
    expect((await repo.listMemories(pinned: true)).every((m) => m.pinned), isTrue);
  });

  test('D-032 MCP: a ready server (with tools) + a failed server + registry entries', () async {
    final servers = await repo.listMcpServers();
    expect(servers.any((s) => s.status == 'ready' && s.tools.isNotEmpty), isTrue, reason: '就绪+工具');
    expect(servers.any((s) => s.status == 'failed' && (s.lastError ?? '').isNotEmpty), isTrue, reason: '失败+诚实错误');
    expect(await repo.listMcpRegistry(), isNotEmpty, reason: '市场候选');
  });

  test('D-033 sandbox: installed runtimes + a ready env under a function owner', () async {
    final runtimes = await repo.sandboxRuntimes();
    expect(runtimes, isNotEmpty);
    expect(runtimes.any((r) => r.kind == 'python'), isTrue);
    final envs = await repo.sandboxEnvs('function');
    expect(envs, isNotEmpty);
    expect(envs.first.status, 'ready');
  });
}
