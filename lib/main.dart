import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'core/services/notification_service.dart';
import 'core/providers/vehicles_provider.dart';
import 'core/theme/theme_notifier.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  // Inicializar Firebase (requiere google-services.json en android/app/)
  try {
    await Firebase.initializeApp();
    // Inicializar servicio de notificaciones (FCM + permisos)
    await NotificationService().initialize();
  } catch (e) {
    // Si Firebase no está configurado (google-services.json faltante),
    // la app sigue funcionando sin notificaciones push.
    debugPrint('[Firebase] No inicializado: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
        ChangeNotifierProvider(create: (_) => VehiclesProvider()),
      ],
      child: const AutoRepairApp(),
    ),
  );
}
