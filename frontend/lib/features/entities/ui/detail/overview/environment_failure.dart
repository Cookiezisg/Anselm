import 'package:flutter/material.dart';

import '../../../../../core/design/colors.dart';
import '../../../../../core/design/tokens.dart';
import '../../../../../core/design/typography.dart';
import '../../../../../core/ui/an_callout.dart';
import '../../../../../core/ui/an_disclosure.dart';
import '../../../../../core/ui/icons.dart';
import '../../../../../i18n/strings.g.dart';
import '../../../data/entity_format.dart';

/// Compact, actionable environment failure with an opt-in technical payload. The summary is shared
/// by Function and Handler so an SDK traceback can never become the primary product copy in one of
/// the two sibling surfaces. 共享 Function/Handler 的紧凑失败面：主文案可行动，原始技术载荷按需展开。
class EnvironmentFailure extends StatefulWidget {
  const EnvironmentFailure({required this.error, super.key});

  final String error;

  @override
  State<EnvironmentFailure> createState() => _EnvironmentFailureState();
}

class _EnvironmentFailureState extends State<EnvironmentFailure> {
  bool _open = false;

  String _summary(Translations t, EnvironmentErrorKind kind) => switch (kind) {
    EnvironmentErrorKind.cancelled => t.entities.detail.environment.cancelled,
    EnvironmentErrorKind.runtime => t.entities.detail.environment.runtimeFailed,
    EnvironmentErrorKind.dependencies =>
      t.entities.detail.environment.dependenciesFailed,
    EnvironmentErrorKind.generic => t.entities.detail.environment.genericFailed,
  };

  @override
  Widget build(BuildContext context) {
    final d = context.t.entities.detail.environment;
    final details = prettyJsonCapped(widget.error, maxChars: 4000);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnCallout(
          _summary(context.t, environmentErrorKind(widget.error)),
          title: d.buildFailed,
          severity: AnCalloutSeverity.danger,
        ),
        const SizedBox(height: AnSpace.s8),
        AnDisclosure(
          label: d.technicalDetails,
          icon: AnIcons.byKey('code'),
          open: _open,
          onToggle: () => setState(() => _open = !_open),
          child: SelectableText(
            details,
            style: AnText.code.copyWith(color: context.colors.inkMuted),
          ),
        ),
      ],
    );
  }
}
