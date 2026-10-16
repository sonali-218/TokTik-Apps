import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:toktok/domain/entities/video_post.dart';

/// Traduce un documento de la colección "posts" de Firestore a la entidad
/// VideoPost del dominio (y viceversa para crear uno nuevo).
class FirestorePostModel {
  static const collection = 'posts';

  static VideoPost fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final createdAt = data['createdAt'] as Timestamp?;
    return VideoPost(
      id: doc.id,
      caption: data['caption'] as String? ?? '',
      videoUrl: data['mediaUrl'] as String? ?? '',
      type: data['type'] == 'photo' ? PostType.photo : PostType.video,
      likes: (data['likes'] as num?)?.toInt() ?? 0,
      views: (data['views'] as num?)?.toInt() ?? 0,
      likedBy: List<String>.from(data['likedBy'] as List? ?? const []),
      authorUid: data['authorUid'] as String? ?? '',
      authorEmail: data['authorEmail'] as String? ?? '',
      storagePath: data['storagePath'] as String? ?? '',
      createdAt: createdAt?.toDate(),
    );
  }

  static Map<String, dynamic> toNewDoc({
    required String caption,
    required String mediaUrl,
    required PostType type,
    required String storagePath,
    required String authorUid,
    required String authorEmail,
    required int sizeBytes,
  }) =>
      {
        'caption': caption,
        'mediaUrl': mediaUrl,
        'type': type == PostType.photo ? 'photo' : 'video',
        'storagePath': storagePath,
        'authorUid': authorUid,
        'authorEmail': authorEmail,
        'sizeBytes': sizeBytes,
        'likes': 0,
        'views': 0,
        'likedBy': <String>[],
        // Hora del servidor, no del teléfono: el orden es consistente.
        'createdAt': FieldValue.serverTimestamp(),
      };
}
