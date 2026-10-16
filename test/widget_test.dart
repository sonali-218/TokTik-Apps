// Pruebas que no necesitan Firebase.

import 'package:flutter_test/flutter_test.dart';
import 'package:toktok/config/helpers/human_formats.dart';
import 'package:toktok/domain/entities/video_post.dart';
import 'package:toktok/infrastructure/repositories/local_posts_repository.dart';

void main() {
  test('HumanFormats abrevia números grandes', () {
    expect(HumanFormats.humanReadbleNumber(1500), contains('K'));
  });

  test('LocalPostsRepository entrega los 8 videos de assets', () async {
    final posts = await LocalPostsRepository().watchPosts().first;
    expect(posts.length, 8);
    expect(posts.first.type, PostType.video);
    expect(posts.first.isNetwork, isFalse);
  });
}
