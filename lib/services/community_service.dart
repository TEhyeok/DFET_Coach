import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/community/community_comment.dart';
import '../models/community/post.dart';

class CommunityService {
  CommunityService({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _postsRef =>
      _firestore.collection('posts');

  Future<void> createPost(String content, List<File> images) async {
    final user = _auth.currentUser;
    final trimmed = content.trim();
    if (user == null) throw Exception('로그인이 필요합니다.');
    if (trimmed.isEmpty) throw Exception('내용을 입력해 주세요.');
    if (trimmed.length > 2000) throw Exception('게시글은 2,000자까지 입력할 수 있습니다.');

    final imageUrls = <String>[];
    for (var index = 0; index < images.length; index++) {
      final image = images[index];
      final reference = _storage.ref().child(
            'posts/${DateTime.now().microsecondsSinceEpoch}_${index}_${user.uid}.jpg',
          );
      await reference.putFile(image);
      imageUrls.add(await reference.getDownloadURL());
    }

    await _postsRef.add({
      'authorId': user.uid,
      'authorName': user.displayName ?? '사용자',
      'authorProfileImage': user.photoURL,
      'content': trimmed,
      'imageUrls': imageUrls,
      'likeCount': 0,
      'commentCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Post>> getPostsStream() {
    return _postsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final uid = _auth.currentUser?.uid;
      return Future.wait(snapshot.docs.map((document) async {
        final post = Post.fromFirestore(document);
        if (uid == null) return post;
        final like =
            await document.reference.collection('likes').doc(uid).get();
        return post.copyWith(isLikedByMe: like.exists);
      }));
    });
  }

  Stream<Post?> getPostStream(String postId) {
    return _postsRef.doc(postId).snapshots().asyncMap((document) async {
      if (!document.exists) return null;
      final post = Post.fromFirestore(document);
      final uid = _auth.currentUser?.uid;
      if (uid == null) return post;
      final like = await document.reference.collection('likes').doc(uid).get();
      return post.copyWith(isLikedByMe: like.exists);
    });
  }

  Stream<List<CommunityComment>> getCommentsStream(String postId) {
    return _postsRef
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map(CommunityComment.fromFirestore)
            .toList(growable: false));
  }

  Future<void> toggleLike(String postId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('로그인이 필요합니다.');
    await _functions
        .httpsCallable('toggleCommunityLike')
        .call<void>({'postId': postId});
  }

  Future<void> addComment(String postId, String content) async {
    final user = _auth.currentUser;
    final trimmed = content.trim();
    if (user == null) throw Exception('로그인이 필요합니다.');
    if (trimmed.isEmpty) return;
    if (trimmed.length > 500) throw Exception('댓글은 500자까지 입력할 수 있습니다.');

    await _functions.httpsCallable('addCommunityComment').call<void>({
      'postId': postId,
      'content': trimmed,
    });
  }
}
