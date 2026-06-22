import 'package:anselm/core/ui/icons.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

// The semantic registry is the single icon source — a wrong/missing binding must degrade to the
// visible fallback, never crash. 语义注册表是图标单源:错/缺绑定降级成可见 fallback、绝不崩。
void main() {
  test('byKey resolves domain keys + falls back on unknown', () {
    expect(AnIcons.byKey('agent'), LucideIcons.bot);
    expect(AnIcons.byKey('workflow'), LucideIcons.workflow);
    expect(AnIcons.byKey('conversation'), AnIcons.chat); // alias to chat
    expect(AnIcons.byKey('definitely-not-a-key'), AnIcons.fallback);
  });

  test('toolIcon: exact override, then keyword inference, then default', () {
    expect(AnIcons.toolIcon('read_file'), AnIcons.doc); // exact
    expect(AnIcons.toolIcon('invoke_agent'), AnIcons.agent); // exact
    expect(AnIcons.toolIcon('run_bash_thing'), AnIcons.tool); // shell/bash regex
    expect(AnIcons.toolIcon('vector_search_x'), AnIcons.search); // search keyword
    expect(AnIcons.toolIcon('mystery'), AnIcons.tool); // default
  });

  test('node: the 5 graph kinds + fallback', () {
    expect(AnIcons.node('trigger'), AnIcons.trigger);
    expect(AnIcons.node('approval'), AnIcons.approval);
    expect(AnIcons.node('bogus'), AnIcons.fallback);
  });
}
