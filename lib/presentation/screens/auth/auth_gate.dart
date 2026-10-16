import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toktok/domain/repositories/posts_repository.dart';
import 'package:toktok/infrastructure/services/auth_service.dart';
import 'package:toktok/presentation/providers/discover_provider.dart';
import 'package:toktok/presentation/screens/auth/login_screen.dart';
import 'package:toktok/presentation/screens/discover/discover_screen.dart';

/// Patrón snapshot.hasData: un `StreamBuilder<User?>` escucha
/// authStateChanges(). Sin usuario muestra el login; con usuario, el feed.
/// No hay navegación manual tras iniciar sesión: el cambio de estado la
/// dispara solo.
class AuthGate extends StatelessWidget {
  final AuthService authService;
  final PostsRepository Function() repositoryBuilder;

  const AuthGate({
    super.key,
    required this.authService,
    required this.repositoryBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        if (snapshot.hasData) {
          final user = snapshot.data!;
          // El provider se crea solo con sesión activa (las reglas de
          // Firestore exigen estar autenticado para leer) y se recrea si
          // cambia el usuario.
          return ChangeNotifierProvider(
            key: ValueKey(user.uid),
            create: (_) =>
                DiscoverProvider(
                  repository: repositoryBuilder(),
                  currentUid: user.uid,
                )..listenPosts(),
            child: DiscoverScreen(user: user, authService: authService),
          );
        }

        return LoginScreen(authService: authService);
      },
    );
  }
}
