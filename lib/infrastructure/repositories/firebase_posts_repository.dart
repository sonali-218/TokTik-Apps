import 'dart:io' show File;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:toktok/domain/entities/video_post.dart';
import 'package:toktok/domain/repositories/posts_repository.dart';
import 'package:toktok/infrastructure/models/firestore_post_model.dart';

/// Implementación con Firebase: el archivo va a Cloud Storage y sus datos
/// (caption, URL, autor, likes, vistas) a la colección "posts" de Firestore.
/// Es la única clase del proyecto que toca FirebaseFirestore/FirebaseStorage.
class FirebasePostsRepository implements PostsRepository {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  /// Debe coincidir con el límite de storage.rules.
  static const int maxBytes = 100 * 1024 * 1024; // 100 MB

  FirebasePostsRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
      : _db = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _posts =>
      _db.collection(FirestorePostModel.collection);

  @override
  Stream<List<VideoPost>> watchPosts() {
    // StreamBuilder/listen: se actualiza solo cuando alguien sube algo,
    // da like o se suma una vista, en cualquier dispositivo.
    return _posts
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(FirestorePostModel.fromDoc).toList());
  }

  @override
  Future<void> uploadPost({
    required XFile file,
    required PostType type,
    required String caption,
    required String authorUid,
    required String authorEmail,
    void Function(double progress)? onProgress,
  }) async {
    final size = await file.length();
    if (size >= maxBytes) {
      throw PostsFailure(
        'El archivo pesa ${(size / (1024 * 1024)).toStringAsFixed(1)} MB; '
        'el máximo es 100 MB.',
      );
    }

    final cleanName = file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    // Cada usuario sube en su propia carpeta: storage.rules lo exige.
    final storagePath =
        'posts/$authorUid/${DateTime.now().millisecondsSinceEpoch}_$cleanName';
    final ref = _storage.ref(storagePath);
    final metadata = SettableMetadata(contentType: _contentType(file, type));

    // 1) Subir el archivo a Storage.
    final UploadTask task = kIsWeb
        ? ref.putData(await file.readAsBytes(), metadata)
        : ref.putFile(File(file.path), metadata);

    final subscription = task.snapshotEvents.listen(
      (snap) {
        if (snap.totalBytes > 0) {
          onProgress?.call(snap.bytesTransferred / snap.totalBytes);
        }
      },
      // El error real se maneja abajo, en `await task`.
      onError: (_) {},
    );

    late final String url;
    try {
      final result = await task;
      url = await result.ref.getDownloadURL();
    } on FirebaseException catch (e) {
      throw PostsFailure(_storageMessage(e.code));
    } finally {
      await subscription.cancel();
    }

    // 2) Registrar en Firestore. Si falla, se borra el archivo subido
    //    para no dejar archivos huérfanos en Storage.
    try {
      await _posts.add(FirestorePostModel.toNewDoc(
        caption: caption,
        mediaUrl: url,
        type: type,
        storagePath: storagePath,
        authorUid: authorUid,
        authorEmail: authorEmail,
        sizeBytes: size,
      ));
    } on FirebaseException catch (e) {
      try {
        await ref.delete();
      } catch (_) {}
      throw PostsFailure('El archivo se subió pero no se pudo registrar (${e.code}).');
    }
  }

  @override
  Future<void> setLike({
    required String postId,
    required String uid,
    required bool like,
  }) {
    final ref = _posts.doc(postId);
    // Transacción: lee el estado real en el servidor y solo escribe si hay
    // que cambiarlo. El contador usa FieldValue.increment para no perder
    // likes si dos personas tocan el corazón a la vez.
    return _db.runTransaction<void>((tx) async {
      final snap = await tx.get(ref);
      final likedBy = List<String>.from(
          (snap.data()?['likedBy'] as List?) ?? const []);
      if (likedBy.contains(uid) == like) return; // ya está como se pidió

      tx.update(ref, {
        'likedBy': like
            ? FieldValue.arrayUnion([uid])
            : FieldValue.arrayRemove([uid]),
        'likes': FieldValue.increment(like ? 1 : -1),
      });
    });
  }

  @override
  Future<void> addView(String postId) {
    return _posts.doc(postId).update({'views': FieldValue.increment(1)});
  }

  @override
  Future<void> deletePost(VideoPost post) async {
    try {
      await _posts.doc(post.id).delete();
      if (post.storagePath.isNotEmpty) {
        await _storage.ref(post.storagePath).delete();
      }
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return;
      throw PostsFailure('No se pudo eliminar (${e.code}).');
    }
  }

  String _contentType(XFile file, PostType type) {
    final mime = file.mimeType;
    if (mime != null && mime.isNotEmpty) return mime;
    const types = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'heic': 'image/heic',
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
      'm4v': 'video/x-m4v',
      'webm': 'video/webm',
    };
    final ext = file.name.split('.').last.toLowerCase();
    return types[ext] ?? (type == PostType.video ? 'video/mp4' : 'image/jpeg');
  }

  String _storageMessage(String code) {
    switch (code) {
      case 'unauthorized':
        return 'No tienes permiso para subir este archivo (revisa storage.rules).';
      case 'canceled':
        return 'La subida se canceló.';
      case 'quota-exceeded':
        return 'Se superó la cuota de almacenamiento del proyecto.';
      case 'retry-limit-exceeded':
        return 'La conexión falló demasiadas veces. Intenta de nuevo.';
      case 'unauthenticated':
        return 'Tu sesión expiró. Vuelve a iniciar sesión.';
      default:
        return 'No se pudo subir el archivo (código: $code).';
    }
  }
}
