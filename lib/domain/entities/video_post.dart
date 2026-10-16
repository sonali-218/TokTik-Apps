// Entidad del dominio: una publicación del feed (video o foto).
// No sabe nada de Firebase: así la UI no depende de la fuente de datos.

enum PostType { video, photo }

class VideoPost {
  final String id;
  final String caption;

  /// URL del archivo. Para la fuente local es una ruta de assets
  /// (assets/videos/1.mp4); para Firebase es la URL de descarga de Storage.
  final String videoUrl;
  final PostType type;
  final int likes;
  final int views;

  /// uid de los usuarios que le dieron like (uno por usuario).
  final List<String> likedBy;

  final String authorUid;
  final String authorEmail;
  final String storagePath;
  final DateTime? createdAt;

  VideoPost({
    this.id = '',
    required this.caption,
    required this.videoUrl,
    this.type = PostType.video,
    this.likes = 0,
    this.views = 0,
    this.likedBy = const [],
    this.authorUid = '',
    this.authorEmail = '',
    this.storagePath = '',
    this.createdAt,
  });

  bool get isPhoto => type == PostType.photo;

  bool isLikedBy(String uid) => likedBy.contains(uid);

  /// Nombre visible del autor: la parte del correo antes de la @
  /// (ana.perez@gmail.com → @ana.perez). Vacío en los videos locales.
  String get authorHandle {
    if (authorEmail.isEmpty) return '';
    return '@${authorEmail.split('@').first}';
  }

  /// Copia con el like de [uid] agregado o quitado (para actualizar la UI
  /// al instante, antes de que Firestore confirme).
  VideoPost toggledLikeFor(String uid) {
    final liked = isLikedBy(uid);
    return VideoPost(
      id: id,
      caption: caption,
      videoUrl: videoUrl,
      type: type,
      likes: liked ? likes - 1 : likes + 1,
      views: views,
      likedBy: liked
          ? likedBy.where((u) => u != uid).toList()
          : [...likedBy, uid],
      authorUid: authorUid,
      authorEmail: authorEmail,
      storagePath: storagePath,
      createdAt: createdAt,
    );
  }

  /// true si el archivo viene de internet (Firebase) y no de assets.
  bool get isNetwork => videoUrl.startsWith('http');
}
