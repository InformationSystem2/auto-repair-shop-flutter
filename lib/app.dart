import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_notifier.dart';
import 'features/splash/splash_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/register/register_screen.dart';
import 'features/home/home_screen.dart';

class AutoRepairApp extends StatelessWidget {
  const AutoRepairApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (_, notifier, __) => MaterialApp(
        title: 'AutoRepair',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: notifier.themeMode,
        initialRoute: '/splash',
        routes: {
          '/splash':   (_) => const SplashScreen(),
          '/login':    (_) => const LoginScreen(),
          '/register': (_) => const RegisterScreen(),
          '/home':     (_) => const HomeScreen(),
        },
      ),
    );
  }
}
