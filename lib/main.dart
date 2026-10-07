import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'config/app_theme.dart';
import 'firebase_options.dart';
import 'screens/auth/welcome_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialización oficial de Firebase para el proyecto Favores USC
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Error inicializando Firebase: $e');
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
