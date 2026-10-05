import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'config/app_theme.dart';
import 'screens/auth/welcome_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialización de Firebase (intentar inicializar con opciones por defecto)
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase aún no inicializado con flutterfire configure: $e');
  }

  runApp(
    const ProviderScope(
      child: FavoresUscApp(),
    ),
  );
}

class FavoresUscApp extends StatelessWidget {
  const FavoresUscApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FAVORES USC',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const WelcomeScreen(),
    );
  }
}
