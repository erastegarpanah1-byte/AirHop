import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/data/connectivity_service.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';
import 'features/offline/offline_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: AirhopApp()));
}

class AirhopApp extends StatelessWidget {
  const AirhopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Airhop',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      locale: const Locale('fa'),
      supportedLocales: const [Locale('fa'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: const _RootGate(),
    );
  }
}

class _RootGate extends ConsumerStatefulWidget {
  const _RootGate();

  @override
  ConsumerState<_RootGate> createState() => _RootGateState();
}

class _RootGateState extends ConsumerState<_RootGate> {
  bool _inside = false;

  @override
  void initState() {
    super.initState();
    final status = ref.read(connectivityProvider);
    if (status == ConnectivityStatus.online) {
      _inside = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(connectivityProvider);

    if (status == ConnectivityStatus.online) {
      if (!_inside) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _inside = true);
        });
      }
      if (_inside) return const HomeScreen();
    }

    return OfflineScreen(
      onConnected: () {
        if (mounted) setState(() => _inside = true);
      },
    );
  }
}
