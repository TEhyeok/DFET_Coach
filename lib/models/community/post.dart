import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorProfileImage;
  final String content;
  final List<String> imageUrls;
  final int likeCount;
  final int commentCount;
  final DateTime createdAt;
  final bool isLikedByMe; // UI state

  Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorProfileImage,
    required this.content,
    this.imageUrls = const [],
    this.likeCount = 0,
    this.commentCount = 0,
    required this.createdAt,
    this.isLikedByMe = false,
  });

  factory Post.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Post(
      id: doc.id,
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Unknown',
      authorProfileImage: data['authorProfileImage'],
      content: data['content'] ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      likeCount: data['likeCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isLikedByMe: false, // Needs separate check
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'authorId': authorId,
      'authorName': authorName,
      'authorProfileImage': authorProfileImage,
      'content': content,
      'imageUrls': imageUrls,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Post copyWith({
    String? id,
    String? authorId,
    String? authorName,
    String? authorProfileImage,
    String? content,
    List<String>? imageUrls,
    int? likeCount,
    int? commentCount,
    DateTime? createdAt,
    bool? isLikedByMe,
  }) {
    return Post(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorProfileImage: authorProfileImage ?? this.authorProfileImage,
      content: content ?? this.content,
      imageUrls: imageUrls ?? this.imageUrls,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      createdAt: createdAt ?? this.createdAt,
      isLikedByMe: isLikedByMe ?? this.isLikedByMe,
    );
  }
}
