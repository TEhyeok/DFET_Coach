import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/community/post.dart';

class CommunityService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection Reference
  CollectionReference get _postsRef => _firestore.collection('posts');

  // Create Post
  Future<void> createPost(String content, List<File> images) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    List<String> imageUrls = [];

    // Upload images
    for (var image in images) {
      final ref = _storage.ref().child(
          'posts/${DateTime.now().millisecondsSinceEpoch}_${user.uid}.jpg');
      await ref.putFile(image);
      final url = await ref.getDownloadURL();
      imageUrls.add(url);
    }

    // Save to Firestore
    final post = Post(
      id: '', // Will be generated
      authorId: user.uid,
      authorName: user.displayName ?? 'Anonymous',
      authorProfileImage: user.photoURL,
      content: content,
      imageUrls: imageUrls,
      createdAt: DateTime.now(),
      likeCount: 0,
      commentCount: 0,
    );

    await _postsRef.add(post.toMap());
  }

  // Get Posts (Realtime)
  // Get Posts (Mock Data for Demo)
  Stream<List<Post>> getPostsStream() {
    // Return a stream that emits mock data immediately
    return Stream.value([
      Post(
        id: '1',
        authorId: 'user1',
        authorName: '김철수',
        authorProfileImage: null,
        content: '오늘도 오운완! 등 운동 제대로 먹었네요 🔥',
        imageUrls: ['assets/images/ounwan_1.png'],
        likeCount: 12,
        commentCount: 3,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        isLikedByMe: true,
      ),
      Post(
        id: '2',
        authorId: 'user2',
        authorName: '이영희',
        authorProfileImage: null,
        content: '식단 관리 3일차... 샐러드도 맛있게 먹으면 0칼로리겠죠? 🥗',
        imageUrls: ['assets/images/meal_1.png'],
        likeCount: 8,
        commentCount: 5,
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        isLikedByMe: false,
      ),
      Post(
        id: '3',
        authorId: 'user3',
        authorName: '박지성',
        authorProfileImage: null,
        content: '새로 산 러닝화 개시! 가볍고 좋네요 🏃‍♂️',
        imageUrls: ['assets/images/ounwan_2.png'],
        likeCount: 25,
        commentCount: 10,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        isLikedByMe: false,
      ),
    ]);
    /*
    return _postsRef
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Post.fromFirestore(doc)).toList();
    });
    */
  }

  // Toggle Like
  Future<void> toggleLike(String postId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final postRef = _postsRef.doc(postId);
    final likeRef = postRef.collection('likes').doc(user.uid);

    final likeDoc = await likeRef.get();

    if (likeDoc.exists) {
      // Unlike
      await likeRef.delete();
      await postRef.update({'likeCount': FieldValue.increment(-1)});
    } else {
      // Like
      await likeRef.set({'createdAt': FieldValue.serverTimestamp()});
      await postRef.update({'likeCount': FieldValue.increment(1)});
    }
  }
}
