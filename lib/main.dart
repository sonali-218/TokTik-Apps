import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:toktok/config/theme/app_theme.dart';
import 'package:toktok/firebase_options.dart';
import 'package:toktok/infrastructure/repositories/firebase_posts_repository.dart';
import 'package:toktok/infrastructure/services/auth_service.dart';
import 'package:toktok/presentation/screens/auth/auth_gate.dart';

Future<void> main() async {
  // 1) Bindings de Flutter listos antes de cualquier llamada de plataforma.
  WidgetsFlutterBinding.ensureInitialized();

  // 2) Inicializar Firebase (firebase_options.dart lo genera
  //    `flutterfire configure`) antes de runApp().
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 3) Ahora sí, la app.
  runApp(const MyApp());
}

// Una sola instancia para toda la app (se crea al primer uso, ya con
// Firebase inicializado).
final _authService = AuthService();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TokTik',
      debugShowCheckedModeBanner: false,
      theme: AppTheme().getTheme(),
      home: AuthGate(
        authService: _authService,
        // Para probar sin Firebase con los videos de assets:
        // repositoryBuilder: () => LocalPostsRepository(),
        repositoryBuilder: () => FirebasePostsRepository(),
      ),
    );
  }
}
