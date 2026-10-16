import 'dart:async';

import 'package:flutter/material.dart';
import 'package:toktok/domain/entities/video_post.dart';
import 'package:toktok/domain/repositories/posts_repository.dart';

/// Estado del feed. Recibe el repositorio por constructor (inyección), así
/// el provider no sabe si los datos vienen de Firebase o de assets.
class DiscoverProvider extends ChangeNotifier {
  final PostsRepository repository;

  /// Usuario con sesión activa (para saber a qué posts les dio like).
  final String currentUid;

  DiscoverProvider({required this.repository, required this.currentUid});

  bool initialLoading = true;
  String? errorMessage;
  List<VideoPost> videos = [];

  StreamSubscription<List<VideoPost>>? _subscription;

  /// Vistas ya contadas en esta sesión (no se suma vista cada vez que el
  /// usuario regresa al mismo video).
  final Set<String> _viewed = {};

  /// Antes era loadNextPage() con la lista local; ahora se suscribe al
  /// stream del repositorio y el feed se actualiza solo.
  void listenPosts() {
    _subscription?.cancel();
    _subscription = repository.watchPosts().listen(
      (posts) {
        videos = posts;
        initialLoading = false;
        errorMessage = null;
        notifyListeners();
      },
      onError: (Object e) {
        initialLoading = false;
        errorMessage = 'No se pudo cargar el feed: $e';
        notifyListeners();
      },
    );
  }

  Future<void> toggleLike(VideoPost post) async {
    if (post.id.isEmpty) return;
    final wasLiked = post.isLikedBy(currentUid);
    final wantLike = !wasLiked;

    // Actualización optimista: el corazón cambia al instante y luego el
    // stream de Firestore trae el valor confirmado.
    _setLocalLike(post.id, wantLike);

    try {
      await repository.setLike(postId: post.id, uid: currentUid, like: wantLike);
    } catch (_) {
      // Si falla, se vuelve al estado que tenía antes de tocar.
      _setLocalLike(post.id, wasLiked);
    }
  }

  void _setLocalLike(String postId, bool liked) {
    final i = videos.indexWhere((v) => v.id == postId);
    if (i == -1 || videos[i].isLikedBy(currentUid) == liked) return;
    videos = [...videos]..[i] = videos[i].toggledLikeFor(currentUid);
    notifyListeners();
  }

  Future<void> registerView(VideoPost post) async {
    if (post.id.isEmpty || !_viewed.add(post.id)) return;
    try {
      await repository.addView(post.id);
    } catch (_) {
      // Una vista no contada no debe romper la experiencia.
    }
  }

  Future<void> delete(VideoPost post) => repository.deletePost(post);

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
