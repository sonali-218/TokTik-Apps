// Contrato del repositorio de publicaciones (patrón repository, Clase 22).
// La UI y el provider solo conocen esta interfaz. Hay dos implementaciones:
//   - FirebasePostsRepository: Firestore (datos) + Storage (archivos).
//   - LocalPostsRepository: los 8 videos de assets del proyecto original.

import 'package:image_picker/image_picker.dart';

import '../entities/video_post.dart';

/// Error con un mensaje listo para mostrar al usuario.
class PostsFailure implements Exception {
  final String message;
  PostsFailure(this.message);

  @override
  String toString() => message;
}

abstract class PostsRepository {
  /// Todas las publicaciones, más recientes primero, en tiempo real.
  Stream<List<VideoPost>> watchPosts();

  /// Sube el archivo y registra la publicación.
  /// [onProgress] recibe valores de 0.0 a 1.0.
  Future<void> uploadPost({
    required XFile file,
    required PostType type,
    required String caption,
    required String authorUid,
    required String authorEmail,
    void Function(double progress)? onProgress,
  });

  /// Deja el like de [uid] en el estado [like] (true = con like). Un like
  /// por usuario, como en una red social real. Es idempotente: pedir
  /// "like" dos veces no suma dos.
  Future<void> setLike({
    required String postId,
    required String uid,
    required bool like,
  });

  /// Suma 1 vista de forma atómica.
  Future<void> addView(String postId);

  /// Elimina la publicación y su archivo (solo el autor, por reglas).
  Future<void> deletePost(VideoPost post);
}
