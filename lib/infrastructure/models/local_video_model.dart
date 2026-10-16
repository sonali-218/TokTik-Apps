import 'package:toktok/domain/entities/video_post.dart';

/// Modelo de los videos locales (assets) del proyecto original.
class LocalVideoModel {
  final String name;
  final String videoUrl;
  final int likes;
  final int views;

  LocalVideoModel({
    required this.name,
    required this.videoUrl,
    this.likes = 0,
    this.views = 0,
  });

  factory LocalVideoModel.fromJson(Map<String, dynamic> json) => LocalVideoModel(
        name: json['name'] ?? 'No name',
        videoUrl: json['videoUrl'],
        likes: json['likes'] ?? 0,
        views: json['views'] ?? 0,
      );

  VideoPost toVideoPostEntity() => VideoPost(
        id: videoUrl,
        caption: name,
        videoUrl: videoUrl,
        likes: likes,
        views: views,
      );
}
