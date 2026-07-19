import 'package:anselm/core/contract/entities/function.dart';
import 'package:anselm/core/contract/entities/handler.dart';
import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/features/entities/data/entity_kind.dart';
import 'package:anselm/features/entities/state/detail/entity_detail.dart';
import 'package:anselm/features/entities/state/run/run_fields.dart';
import 'package:anselm/features/entities/state/selected_entity.dart';
import 'package:flutter_test/flutter_test.dart';

// runInputFields is the SINGLE source the form renders and the controller coerces from — these lock the
// per-kind field selection (and, for handlers, the per-method switch) so the two can never drift apart.
void main() {
  final t = DateTime.utc(2026);

  EntityDetail fnDetail(List<Field> inputs) => EntityDetail(
        ref: const EntityRef(EntityKind.function, 'fn_1'),
        function: FunctionEntity(
          id: 'fn_1',
          name: 'f',
          createdAt: t,
          updatedAt: t,
          activeVersion: FunctionVersion(
            id: 'v1',
            functionId: 'fn_1',
            version: 1,
            inputs: inputs,
            createdAt: t,
            updatedAt: t,
          ),
        ),
      );

  EntityDetail hdDetail(List<MethodSpec> methods) => EntityDetail(
        ref: const EntityRef(EntityKind.handler, 'hd_1'),
        handler: HandlerEntity(
          id: 'hd_1',
          name: 'h',
          createdAt: t,
          updatedAt: t,
          activeVersion: HandlerVersion(
            id: 'v1',
            handlerId: 'hd_1',
            version: 1,
            methods: methods,
            createdAt: t,
            updatedAt: t,
          ),
        ),
      );

  test('null detail (not loaded) → no fields, no methods', () {
    expect(runInputFields(EntityKind.function, null), isEmpty);
    expect(runMethods(null), isEmpty);
  });

  test('function/agent → the active version inputs', () {
    final d = fnDetail(const [Field(name: 'cfg', type: 'object')]);
    expect(runInputFields(EntityKind.function, d).map((f) => f.name), ['cfg']);
  });

  test('workflow → never per-field (one JSON payload)', () {
    expect(runInputFields(EntityKind.workflow, fnDetail(const [Field(name: 'x', type: 'string')])), isEmpty);
  });

  test('handler → the SELECTED method inputs; a different/absent method → its own/empty set', () {
    final d = hdDetail(const [
      MethodSpec(name: 'a', inputs: [Field(name: 'p', type: 'string')]),
      MethodSpec(name: 'b', inputs: [Field(name: 'q', type: 'number'), Field(name: 'r', type: 'boolean')]),
    ]);
    expect(runInputFields(EntityKind.handler, d, method: 'a').map((f) => f.name), ['p']);
    expect(runInputFields(EntityKind.handler, d, method: 'b').map((f) => f.name), ['q', 'r']);
    expect(runInputFields(EntityKind.handler, d, method: 'nope'), isEmpty);
    expect(runInputFields(EntityKind.handler, d), isEmpty); // no method selected yet
    expect(runMethods(d).map((m) => m.name), ['a', 'b']);
  });
}
