import 'package:image_picker/image_picker.dart';
import 'package:toktok/domain/entities/video_post.dart';
import 'package:toktok/domain/repositories/posts_repository.dart';
import 'package:toktok/infrastructure/models/local_video_model.dart';
import 'package:toktok/shared/data/local_video_posts.dart';

/// Implementación "fake" con los 8 videos de assets del proyecto original.
/// Sirve para probar la UI sin Firebase: en main.dart basta con cambiar
/// FirebasePostsRepository() por LocalPostsRepository().
class LocalPostsRepository implements PostsRepository {
  @override
  Stream<List<VideoPost>> watchPosts() => Stream.value(
        videoPosts
            .map((v) => LocalVideoModel.fromJson(v).toVideoPostEntity())
            .toList(),
      );

  @override
  Future<void> uploadPost({
    required XFile file,
    required PostType type,
    required String caption,
    required String authorUid,
    required String authorEmail,
    void Function(double progress)? onProgress,
  }) async =>
      throw PostsFailure('La fuente local no permite subir archivos.');

  @override
  Future<void> setLike({
    required String postId,
    required String uid,
    required bool like,
  }) async {}

  @override
  Future<void> addView(String postId) async {}

  @override
  Future<void> deletePost(VideoPost post) async {}
}
