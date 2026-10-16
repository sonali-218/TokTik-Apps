import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toktok/infrastructure/services/auth_service.dart';
import 'package:toktok/presentation/providers/discover_provider.dart';
import 'package:toktok/presentation/screens/upload/upload_screen.dart';
import 'package:toktok/presentation/widgets/shared/video_scrollable_view.dart';

/// Home: lista TODAS las publicaciones (videos y fotos) en el feed vertical.
class DiscoverScreen extends StatelessWidget {
  final User user;
  final AuthService authService;

  const DiscoverScreen({super.key, required this.user, required this.authService});

  void _openUpload(BuildContext context) {
    final provider = context.read<DiscoverProvider>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UploadScreen(user: user, repository: provider.repository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final discoverProvider = context.watch<DiscoverProvider>();

    Widget body;
    if (discoverProvider.initialLoading) {
      body = const Center(child: CircularProgressIndicator(strokeWidth: 2));
    } else if (discoverProvider.errorMessage != null) {
      body = _Message(
        icon: Icons.cloud_off,
        text: discoverProvider.errorMessage!,
      );
    } else if (discoverProvider.videos.isEmpty) {
      body = _Message(
        icon: Icons.video_library_outlined,
        text: 'Todavía no hay publicaciones.\nSube el primer video o foto.',
        action: FilledButton.icon(
          onPressed: () => _openUpload(context),
          icon: const Icon(Icons.add),
          label: const Text('Subir'),
        ),
      );
    } else {
      body = VideoScrollableView(
        videos: discoverProvider.videos,
        currentUid: user.uid,
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          SizedBox.expand(child: body),

          // Barra superior flotante: subir y cerrar sesión.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Text('TokTik',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton.filledTonal(
                    tooltip: 'Subir video o foto',
                    onPressed: () => _openUpload(context),
                    icon: const Icon(Icons.add),
                  ),
                  IconButton(
                    tooltip: 'Cerrar sesión (${user.email ?? ''})',
                    onPressed: () => authService.signOut(),
                    icon: const Icon(Icons.logout),
                  ),
                ],
              ),
            ),
          ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;

  const _Message({required this.icon, required this.text, this.action});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
