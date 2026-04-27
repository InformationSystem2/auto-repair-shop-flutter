import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_notifier.dart';
import 'features/splash/splash_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/register/register_screen.dart';
import 'features/home/home_screen.dart';
import 'features/incidents/incident_detail_screen.dart';
import 'features/incidents/rating_screen.dart';
import 'features/notifications/notification_screen.dart';

class AutoRepairApp extends StatelessWidget {
  const AutoRepairApp({super.key});

  static final navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeNotifier>(
      builder: (_, notifier, __) => MaterialApp(
        title: 'AutoRepair',
        navigatorKey: navigatorKey,
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
          '/notifications': (_) => const NotificationScreen(),
          '/incident-detail': (context) {
            final incidentId = ModalRoute.of(context)!.settings.arguments as String;
            return IncidentDetailScreen(incidentId: incidentId);
          },
          '/incidents/rating': (context) {
            final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
            return RatingScreen(incidentId: args['incidentId'] as String);
          },
        },
      ),
    );
  }
}
