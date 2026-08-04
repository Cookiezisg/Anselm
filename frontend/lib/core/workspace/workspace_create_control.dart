import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../i18n/strings.g.dart';
import '../contract/api_error.dart';
import '../contract/workspace.dart';
import '../design/colors.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../ui/an_button.dart';
import '../ui/an_composer.dart';
import '../ui/icons.dart';
import 'workspace_journey.dart';

typedef WorkspaceCreate = Future<Workspace> Function(String name);

/// The one workspace-creation behaviour host shared by first-run onboarding and Settings. Its chrome
/// is the real [AnComposer], deliberately without mention, attachment, or voice actions: typing reveals
/// the same blue enter affordance as Chat; wrapping produces the same pill→card reflow. It owns trim,
/// single-flight, Enter/Shift+Enter/IME handling, and stable wire-code → localized error mapping.
///
/// onboarding 与设置共用的 workspace 创建行为宿主。壳就是正式 [AnComposer]，只是没有提及、附件与语音：
/// 输入后浮出同一枚蓝色回车钮，换行走同一套药丸→卡片形变。trim、单飞、Enter/Shift+Enter/IME 与
/// 稳定 wire code→本地化错误均由此自持。
class WorkspaceCreateControl extends StatefulWidget {
  const WorkspaceCreateControl({
    required this.onCreate,
    this.onCreated,
    this.autofocus = false,
    this.floating = false,
    this.surfaceKey,
    super.key,
  });

  final WorkspaceCreate onCreate;
  final ValueChanged<Workspace>? onCreated;
  final bool autofocus;
  final bool floating;
  final Key? surfaceKey;

  @override
  State<WorkspaceCreateControl> createState() => _WorkspaceCreateControlState();
}

class _WorkspaceCreateControlState extends State<WorkspaceCreateControl> {
  late final TextEditingController _name;
  late final FocusNode _focus;
  bool _hasName = false;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController()..addListener(_onChanged);
    _focus = FocusNode(debugLabel: 'workspace-name', onKeyEvent: _onKey);
    if (widget.autofocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  void _onChanged() {
    final hasName = _name.text.trim().isNotEmpty;
    if (hasName == _hasName && _error == null) return;
    setState(() {
      _hasName = hasName;
      _error = null;
    });
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final composing = _name.value.composing;
    if (composing.isValid && !composing.isCollapsed) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key != LogicalKeyboardKey.enter &&
        key != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent || HardwareKeyboard.instance.isShiftPressed) {
      return KeyEventResult.ignored;
    }
    _submit();
    return KeyEventResult.handled;
  }

  @override
  void dispose() {
    _name
      ..removeListener(_onChanged)
      ..dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (_saving || name.isEmpty) return;
    final journey = WorkspaceJourneyScope.maybeOf(context);
    if (journey != null) journey.committedName = name;
    setState(() {
      _saving = true;
      _error = null;
    });

    late Workspace workspace;
    try {
      workspace = await widget.onCreate(name);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.code == AnselmErr.workspaceNameConflict
            ? context.t.coldStart.alreadyExists
            : e.message;
      });
      return;
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = context.t.coldStart.createFailed;
      });
      return;
    }

    if (!mounted) return;
    widget.onCreated?.call(workspace);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.t;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnComposer(
          key: widget.surfaceKey,
          controller: _name,
          focusNode: _focus,
          placeholder: t.coldStart.nameLabel,
          floating: widget.floating,
          readOnly: _saving,
          focusHalo: false,
          accentHalo: _saving,
          trailing: _hasName
              ? AnButton.iconOnly(
                  AnIcons.send,
                  key: const ValueKey('create-workspace'),
                  variant: AnButtonVariant.primary,
                  round: true,
                  size: AnButtonSize.md,
                  semanticLabel: t.coldStart.createWorkspace,
                  onPressed: _saving ? null : _submit,
                )
              : null,
        ),
        SizedBox(
          height: AnSize.controlSm,
          child: Semantics(
            liveRegion: true,
            child: AnimatedOpacity(
              opacity: _error == null ? 0 : 1,
              duration: AnMotionPref.reduced(context)
                  ? Duration.zero
                  : AnMotion.fast,
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  _error ?? (_saving ? t.coldStart.connecting : ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AnText.meta.copyWith(color: c.inkMuted),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
