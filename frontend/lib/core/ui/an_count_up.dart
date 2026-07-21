import 'package:flutter/widgets.dart';

import '../design/tokens.dart';
import '../design/typography.dart';

/// A COUNT-UP number (WRK-056 #9) — a tabular figure that rolls 0 → [value] once on first mount (the
/// settle-only search families' «计数揭示»: the hit count animating up is the whole drama). Tabular
/// figures keep the width stable so the row never jitters as digits change. [animate] false / reduced
/// motion → the final value appears instantly (history reads static). 计数滚动:0→value 一次(检索族的
/// 计数揭示);tabular 稳宽不抖;reduced/非亲历即显。
class AnCountUp extends StatefulWidget {
  const AnCountUp(
    this.value, {
    this.animate = true,
    this.style,
    this.suffix,
    super.key,
  });

  final int value;

  /// Play the roll on first mount (host sets false on history reload). 首挂载滚动。
  final bool animate;

  /// The text style (defaults to the tabular value style). 文字样式。
  final TextStyle? style;

  /// An optional suffix rendered after the number (e.g. a unit word, non-tabular). 数字后缀。
  final String? suffix;

  @override
  State<AnCountUp> createState() => _AnCountUpState();
}

class _AnCountUpState extends State<AnCountUp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    // Duration scales gently with magnitude, capped. 时长随量级微增、封顶。
    final ms = (200 + widget.value * 6).clamp(200, 900);
    _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: ms),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.animate || AnMotionPref.reducedOrAssistive(context)) {
      _c.value = 1.0;
    } else {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = (widget.style ?? AnText.value()).copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final shown = (widget.value * AnMotion.easeOut.transform(_c.value))
            .round();
        return Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '$shown', style: style),
              if (widget.suffix != null)
                TextSpan(
                  text: widget.suffix,
                  style: widget.style ?? AnText.value(),
                ),
            ],
          ),
        );
      },
    );
  }
}
