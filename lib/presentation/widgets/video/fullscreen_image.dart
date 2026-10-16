import 'package:flutter/material.dart';
import 'package:toktok/presentation/widgets/video/fullscreen_player.dart';
import 'package:toktok/presentation/widgets/video/video_background.dart';

/// Equivalente de FullScreenPlayer para publicaciones de tipo foto.
class FullScreenImage extends StatelessWidget {
  final String imageUrl;
  final String caption;
  final String author;

  const FullScreenImage({
    super.key,
    required this.imageUrl,
    required this.caption,
    this.author = '',
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          imageUrl,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          errorBuilder: (context, error, stack) => const Center(
            child: Icon(Icons.broken_image_outlined, size: 64),
          ),
        ),
        // Gradiente para que el texto se lea sobre fotos claras.
        VideoBackground(stops: const [0.7, 1.0]),
        Positioned(
          bottom: 50,
          left: 20,
          child: VideoCaption(caption: caption, author: author),
        ),
      ],
    );
  }
}
