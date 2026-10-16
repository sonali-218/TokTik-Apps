import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toktok/config/helpers/human_formats.dart';
import 'package:toktok/domain/entities/video_post.dart';
import 'package:toktok/domain/repositories/posts_repository.dart';
import 'package:toktok/presentation/providers/discover_provider.dart';
import 'package:toktok/presentation/widgets/shared/top_toast.dart';

class VideoButtons extends StatelessWidget {
  final VideoPost video;
  final bool isLiked;
  final bool isMine;

  const VideoButtons({
    super.key,
    required this.video,
    this.isLiked = false,
    this.isMine = false,
  });

  Future<void> _confirmDelete(BuildContext context) async {
    final provider = context.read<DiscoverProvider>();
    // Se toma el Overlay ahora: al borrar, el post (y este botón) salen del
    // feed al instante, y después del await este context ya no existe.
    final overlay = Overlay.of(context, rootOverlay: true);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar publicación'),
        content: const Text('Se borrará para todos. ¿Continuar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await provider.delete(video);
      showTopToastIn(overlay, 'Publicación eliminada',
          icon: Icons.delete_outline, iconColor: Colors.redAccent);
    } on PostsFailure catch (e) {
      showTopToastIn(overlay, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Corazón rojo y lleno solo si TÚ le diste like; tocar otra vez lo quita.
        _CustomIconButton(
          value: video.likes,
          iconColor: isLiked ? Colors.red : Colors.white,
          iconData: isLiked ? Icons.favorite : Icons.favorite_border,
          onPressed: () => context.read<DiscoverProvider>().toggleLike(video),
        ),
        const SizedBox(height: 20),
        _CustomIconButton(
          value: video.views,
          iconData: Icons.remove_red_eye_outlined,
        ),
        if (isMine) ...[
          const SizedBox(height: 20),
          _CustomIconButton(
            value: 0,
            iconData: Icons.delete_outline,
            onPressed: () => _confirmDelete(context),
          ),
        ],
        const SizedBox(height: 20),
        SpinPerfect(
          infinite: true,
          duration: const Duration(seconds: 5),
          child: _CustomIconButton(
            value: 0,
            iconData: video.isPhoto
                ? Icons.photo_outlined
                : Icons.play_circle_outline,
          ),
        ),
      ],
    );
  }
}

class _CustomIconButton extends StatelessWidget {
  final int value;
  final IconData iconData;
  final Color color;
  final VoidCallback? onPressed;

  const _CustomIconButton({
    required this.value,
    required this.iconData,
    Color? iconColor,
    this.onPressed,
  }) : color = iconColor ?? Colors.white;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton(
          onPressed: onPressed ?? () {},
          icon: Icon(iconData, color: color, size: 30),
        ),
        if (value > 0) Text(HumanFormats.humanReadbleNumber(value.toDouble())),
      ],
    );
  }
}
