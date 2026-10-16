import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:toktok/domain/entities/video_post.dart';
import 'package:toktok/presentation/providers/discover_provider.dart';
import 'package:toktok/presentation/widgets/shared/video_buttons.dart';
import 'package:toktok/presentation/widgets/video/fullscreen_image.dart';
import 'package:toktok/presentation/widgets/video/fullscreen_player.dart';

class VideoScrollableView extends StatefulWidget {
  final List<VideoPost> videos;
  final String currentUid;

  const VideoScrollableView({
    super.key,
    required this.videos,
    required this.currentUid,
  });

  @override
  State<VideoScrollableView> createState() => _VideoScrollableViewState();
}

class _VideoScrollableViewState extends State<VideoScrollableView> {
  @override
  void initState() {
    super.initState();
    // Cuenta la vista de la primera publicación que se muestra.
    if (widget.videos.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<DiscoverProvider>().registerView(widget.videos.first);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final videos = widget.videos;

    return PageView.builder(
      scrollDirection: Axis.vertical,
      physics: const BouncingScrollPhysics(),
      itemCount: videos.length,
      findChildIndexCallback: (key) {
        final i = videos.indexWhere((v) => ValueKey(v.id) == key);
        return i < 0 ? null : i;
      },
      onPageChanged: (index) =>
          context.read<DiscoverProvider>().registerView(videos[index]),
      itemBuilder: (context, index) {
        final VideoPost videoPost = videos[index];

        return Stack(
          // La key por id hace que, si llega un post nuevo arriba, cada
          // reproductor siga asociado a SU video y no al de otra posición.
          key: ValueKey(videoPost.id),
          children: [
            // Video Player (o foto) + gradiente
            SizedBox.expand(
              child: videoPost.isPhoto
                  ? FullScreenImage(
                      imageUrl: videoPost.videoUrl,
                      caption: videoPost.caption,
                      author: videoPost.authorHandle,
                    )
                  : FullScreenPlayer(
                      caption: videoPost.caption,
                      videoUrl: videoPost.videoUrl,
                      author: videoPost.authorHandle,
                    ),
            ),

            // Botones
            Positioned(
              bottom: 40,
              right: 20,
              child: VideoButtons(
                video: videoPost,
                isLiked: videoPost.isLikedBy(widget.currentUid),
                isMine: videoPost.authorUid.isNotEmpty &&
                    videoPost.authorUid == widget.currentUid,
              ),
            ),
          ],
        );
      },
    );
  }
}
