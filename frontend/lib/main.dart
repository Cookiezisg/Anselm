import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/backend_controller.dart';
import 'app/providers.dart';
import 'app/window_setup.dart';
import 'features/entities/data/entities_repository.dart';
import 'features/entities/state/entities_providers.dart';
import 'i18n/strings.g.dart';

/// Entry point. Initializes the desktop window, picks the UI locale, starts the Go
/// backend sidecar (non-blocking — the app shows a splash until it is healthy), and
/// mounts the composition root (ProviderScope) with the controller injected.
///
/// 入口。初始化桌面窗口、选 UI locale、启动 Go 后端 sidecar(非阻塞——健康前 app 显启动屏),
/// 挂载装配根(ProviderScope)并注入 controller。
Future<void> main() async {
  await initWindow();

  LocaleSettings.useDeviceLocale();

  final backend = BackendController();
  unawaited(backend.start());

  runApp(
    ProviderScope(
      overrides: [
        backendControllerProvider.overrideWithValue(backend),
        // TODO(increment-2): swap to the real repo over core/net + entities SSE stream.
        // 暂用 fixture,增量 2 换成走 core/net 的真实现 + entities SSE。
        entitiesRepositoryProvider.overrideWithValue(const FixtureEntitiesRepository()),
      ],
      child: TranslationProvider(child: const AnselmApp()),
    ),
  );
}
