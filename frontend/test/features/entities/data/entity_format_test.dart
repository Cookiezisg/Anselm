import 'package:anselm/core/contract/entities/handler.dart';
import 'package:anselm/core/contract/entities/values.dart';
import 'package:anselm/features/entities/data/entity_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final timestamp = DateTime.utc(2026, 8, 19);

  test(
    'handlerSourceOf preserves method input parameters in the source view',
    () {
      final version = HandlerVersion(
        id: 'hdv_1',
        handlerId: 'hd_1',
        version: 1,
        methods: [
          const MethodSpec(
            name: 'inspect',
            inputs: [Field(name: 'label', type: 'string')],
            body: "return {'label': label}",
          ),
          const MethodSpec(name: 'health', body: 'return True'),
        ],
        createdAt: timestamp,
        updatedAt: timestamp,
      );

      expect(
        handlerSourceOf(version),
        contains("def inspect(self, label):\n    return {'label': label}"),
      );
      expect(
        handlerSourceOf(version),
        contains('def health(self):\n    return True'),
      );
    },
  );
}
