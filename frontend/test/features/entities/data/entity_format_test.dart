import 'package:flutter_test/flutter_test.dart';

import 'package:anselm/features/entities/data/entity_format.dart';

void main() {
  test(
    'executionErrorSummary localizes missing Python input and hides traceback',
    () {
      const raw = '''Traceback (most recent call last):
  File "/tmp/main.py", line 11, in <module>
TypeError: f() missing 1 required positional argument: 'name'\n''';

      expect(
        executionErrorSummary(
          raw,
          fallback: 'Execution failed.',
          missingInput: 'Missing required input',
        ),
        'Missing required input: name',
      );
      expect(hasExecutionTraceback(raw), isTrue);
    },
  );

  test('executionErrorSummary preserves a human backend error', () {
    expect(
      executionErrorSummary(
        'FUNCTION_ENV_NOT_READY',
        fallback: 'Execution failed.',
        missingInput: 'Missing required input',
      ),
      'FUNCTION_ENV_NOT_READY',
    );
  });

  test('executionOutputForDisplay keeps stdout and hides traceback tail', () {
    const raw =
        'progress 1\nTraceback (most recent call last):\nValueError: boom';
    expect(executionOutputForDisplay(raw), 'progress 1');
    expect(executionOutputForDisplay('progress 1'), 'progress 1');
  });
}
