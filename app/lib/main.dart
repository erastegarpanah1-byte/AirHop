import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';

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
      // زبان فارسی: جهت متن RTL و اعداد/تقویم فارسی می‌شوند.
      locale: const Locale('fa'),
      supportedLocales: const [Locale('fa'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // با Builder، Directionality کل درخت را RTL می‌کند
      // تا همه Row/Col/Alignها به‌صورت پیش‌فرض راست‌چین شوند.
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
      home: const HomeScreen(),
    );
  }
}
