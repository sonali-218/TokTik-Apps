import 'package:flutter/material.dart';
import 'package:toktok/presentation/widgets/video/video_background.dart';
import 'package:video_player/video_player.dart';

class FullScreenPlayer extends StatefulWidget {
  final String videoUrl;
  final String caption;
  final String author;

  const FullScreenPlayer({
    super.key,
    required this.videoUrl,
    required this.caption,
    this.author = '',
  });

  @override
  State<FullScreenPlayer> createState() => _FullScreenPlayerState();
}

class _FullScreenPlayerState extends State<FullScreenPlayer> {
  late final VideoPlayerController controller;
  late final Future<void> _initialization;

  @override
  void initState() {
    super.initState();

    // Videos de Firebase vienen por URL; los del proyecto original, de assets.
    controller = widget.videoUrl.startsWith('http')
        ? VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
        : VideoPlayerController.asset(widget.videoUrl);

    // Se inicializa UNA vez aquí (antes se llamaba initialize() dentro de
    // build, y cada actualización del feed —un like, una vista— reiniciaba
    // el video).
    _initialization = controller.initialize().then((_) {
      // Si el usuario ya deslizó a otro video, el controller fue liberado.
      if (!mounted) return;
      controller
        ..setVolume(0)
        ..setLooping(true)
        ..play();
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }
        if (snapshot.hasError) {
          return const Center(child: Text('No se pudo cargar el video'));
        }

        return GestureDetector(
          onTap: () {
            if (controller.value.isPlaying) {
              controller.pause();
              return;
            }
            controller.play();
          },
          child: Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: Stack(
                children: [
                  VideoPlayer(controller),

                  // Gradiente
                  VideoBackground(stops: const [0.8, 1.0]),

                  // Texto
                  Positioned(
                    bottom: 50,
                    left: 20,
                    child: VideoCaption(
                        caption: widget.caption, author: widget.author),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class VideoCaption extends StatelessWidget {
  final String caption;
  final String author;

  const VideoCaption({super.key, required this.caption, this.author = ''});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final textTheme = Theme.of(context).textTheme;
    const shadow = [Shadow(color: Colors.black54, blurRadius: 6)];

    return SizedBox(
      width: size.width * 0.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (author.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  shadows: shadow,
                ),
              ),
            ),
          Text(
            caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodyLarge?.copyWith(shadows: shadow),
          ),
        ],
      ),
    );
  }
}
