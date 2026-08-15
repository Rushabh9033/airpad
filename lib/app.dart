import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:go_router/go_router.dart';

import 'core/transport/tcp_transport.dart';
import 'features/connection/controllers/connection_controller.dart';
import 'features/connection/pages/connection_page.dart';
import 'features/settings/pages/settings_page.dart';
import 'features/trackpad/pages/trackpad_page.dart';

class AirpadApp extends StatefulWidget {
  const AirpadApp({super.key});

  @override
  State<AirpadApp> createState() => _AirpadAppState();
}

class _AirpadAppState extends State<AirpadApp> {
  late final TcpTransport _transport;
  late final SettingsStore _settings;
  late final ConnectionController _connection;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _transport = TcpTransport();
    _settings = SettingsStore();
    _connection = ConnectionController(
      transport: _transport,
      clientName: Platform.operatingSystem,
      screenW: () => _surfaceW,
      screenH: () => _surfaceH,
    );
    _router = _buildRouter();
    _settings.load();
  }

  int _surfaceW = 0;
  int _surfaceH = 0;

  void _updateSurface(Size s) {
    _surfaceW = s.width.round();
    _surfaceH = s.height.round();
  }

  GoRouter _buildRouter() {
    return GoRouter(
      initialLocation: '/connection',
      routes: [
        GoRoute(
          path: '/connection',
          builder: (ctx, st) => ConnectionPage(controller: _connection),
        ),
        GoRoute(
          path: '/trackpad',
          builder: (ctx, st) => Observer(
            builder: (_) {
              if (_connection.status.value != ConnectionStatus.connected) {
                // Bounce back if disconnected mid-session.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ctx.go('/connection');
                });
                return const SizedBox.shrink();
              }
              return LayoutBuilder(
                builder: (ctx, c) {
                  _updateSurface(c.biggest);
                  return TrackpadPage(
                    connection: _connection,
                    settings: _settings,
                  );
                },
              );
            },
          ),
        ),
        GoRoute(
          path: '/settings',
          builder: (ctx, st) => SettingsPage(store: _settings),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _connection.dispose();
    _transport.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Airpad',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0B0B0D),
        colorScheme: const ColorScheme.dark(
          surface: Color(0xFF141418),
          primary: Color(0xFF3D7CFF),
        ),
      ),
      routerConfig: _router,
    );
  }
}
