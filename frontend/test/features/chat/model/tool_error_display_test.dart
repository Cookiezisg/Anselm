import 'package:anselm/features/chat/model/tool_receipts.dart';
import 'package:anselm/i18n/strings.g.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('validation wrapper becomes localized actionable copy', () {
    final en = AppLocale.en.buildSync();
    final zh = AppLocale.zhCn.buildSync();

    expect(
      toolErrorForDisplay(en, 'input validation failed: triggerId is required'),
      en.chat.tool.inputValidationError,
    );
    expect(
      toolErrorForDisplay(zh, 'input validation failed: triggerId is required'),
      zh.chat.tool.inputValidationError,
    );
  });

  test('unclassified tool errors remain truthful', () {
    final en = AppLocale.en.buildSync();
    expect(toolErrorForDisplay(en, 'connection refused'), 'connection refused');
  });
}
