import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/community/post.dart';
import '../services/community_service.dart';

final communityServiceProvider = Provider((ref) => CommunityService());

final communityPostsProvider = StreamProvider<List<Post>>((ref) {
  final service = ref.watch(communityServiceProvider);
  return service.getPostsStream();
});
