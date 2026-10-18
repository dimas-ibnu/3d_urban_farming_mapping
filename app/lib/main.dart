import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'bridge/web3d_bridge.dart';
import 'l10n/gen/app_localizations.dart';
import 'scene_page.dart';

void main() {
  runApp(const KebunkuApp());
}

class KebunkuApp extends StatelessWidget {
  const KebunkuApp({super.key, this.bridge, this.locale});

  /// Injected by widget tests; production builds pick the platform transport.
  final Web3dBridge? bridge;

  /// Overrides the device locale. `null` means "follow the device", which is
  /// what the app does in production.
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Bahasa Indonesia first: Flutter falls back to the first supported
      // locale when the device locale matches none of them.
      supportedLocales: const [Locale('id'), Locale('en')],
      locale: locale,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF4E8C3A)),
      ),
      home: ScenePage(bridge: bridge),
    );
  }
}
