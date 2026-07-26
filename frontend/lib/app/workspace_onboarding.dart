import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/design/colors.dart';
import '../core/design/tokens.dart';
import '../core/design/typography.dart';
import '../core/ui/an_brand_icon.dart';
import '../core/ui/an_editorial_spread.dart';
import '../core/ui/an_fade_rise_in.dart';
import '../core/ui/an_tooltip.dart';
import '../core/workspace/workspace_bootstrap.dart';
import '../core/workspace/workspace_create_control.dart';
import '../core/workspace/workspace_journey.dart';
import '../i18n/strings.g.dart';

const _artAsset = 'assets/art/christoffel-bisschop-heemskerck-barents-1862.jpg';
const _artAspectRatio = 2560 / 1970;

/// The zero-workspace first run: one quiet decision on a continuous white canvas. A real,
/// public-domain work scene gives the left side cultural weight; the right stays strictly neutral
/// and contains only identity, title, and the shared create control. No card, divider, carousel,
/// explainer, or durable first-run flag — the backend's empty workspace list is the whole condition.
///
/// 零 workspace 首启:一张连续白面上的唯一决策。左侧真实公版工作场景提供文化重量;右侧严格中性,
/// 只留身份、标题与共享创建控件。无卡、无分割线、无轮播、无解释文、无持久首启 flag——后端空名册
/// 就是全部条件。
class WorkspaceOnboarding extends ConsumerWidget {
  const WorkspaceOnboarding({this.onCreate, super.key});

  final WorkspaceCreate? onCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.t;
    final journey = WorkspaceJourneyScope.maybeOf(context);
    return Material(
      color: c.surface,
      // WorkspaceGate deliberately withholds the Router, including its Navigator Overlay. This
      // route-less gate surface therefore owns the temporary overlay needed by artwork/tooltips and
      // the composer's icon button; once creation releases the Router, this whole surface leaves.
      // WorkspaceGate 会连 Router 的 Navigator Overlay 一起扣住,故这张无路由门面自带临时 overlay,
      // 供馆签/tooltip/composer 图标钮使用；创建放行 Router 后整面一起退场。
      child: Overlay(
        initialEntries: [
          OverlayEntry(
            builder: (context) => AnEditorialSpread(
              artwork: _Artwork(
                index: t.coldStart.workIndex,
                credit: t.coldStart.artCredit,
                title: t.coldStart.artTitle,
              ),
              brand: _BrandLockup(name: t.appName.toUpperCase()),
              decision: AnFadeRiseIn(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        t.coldStart.createWorkspace,
                        textAlign: TextAlign.center,
                        style: AnText.h2.copyWith(color: c.ink),
                      ),
                    ),
                    const SizedBox(height: AnSpace.s24),
                    WorkspaceCreateControl(
                      surfaceKey: journey?.sourceComposerKey,
                      autofocus: true,
                      floating: true,
                      onCreate:
                          onCreate ??
                          (name) => ref
                              .read(workspaceBootstrapProvider.notifier)
                              .create(name),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({
    required this.index,
    required this.credit,
    required this.title,
  });

  final String index;
  final String credit;
  final String title;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Keep the museum label physically attached to the visible canvas. Letting Image.contain
        // expand into all remaining height centers the bitmap inside an oversized box and strands
        // the label at the page bottom on tall windows.
        // 让馆签物理贴着可见画布。若 Image.contain 吞掉全部余高,位图会在超高盒内居中、馆签却被
        // 遗在页底；这里按作品比例求真显示盒。
        final imageHeight = math.max(
          AnSpace.s0,
          math.min(
            constraints.maxHeight - AnSpace.s12 - AnSize.islandHead,
            constraints.maxWidth / _artAspectRatio,
          ),
        );
        final imageWidth = imageHeight * _artAspectRatio;
        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            width: imageWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: _artAspectRatio,
                  child: Image.asset(
                    _artAsset,
                    fit: BoxFit.contain,
                    alignment: Alignment.centerLeft,
                    semanticLabel: title,
                  ),
                ),
                const SizedBox(height: AnSpace.s12),
                AnTooltip(
                  message: title,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(index, style: AnText.meta.copyWith(color: c.ink)),
                      const SizedBox(height: AnSpace.s2),
                      Text(
                        credit,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AnText.meta.copyWith(color: c.inkFaint),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const AnBrandIcon.mark(size: AnBrandSize.md),
        const SizedBox(width: AnGap.inline),
        Text(
          name,
          style: AnText.meta
              .weight(AnText.emphasisWeight)
              .copyWith(color: c.ink),
        ),
      ],
    );
  }
}
