import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String? authorProfileImage;
  final String content;
  final DateTime createdAt;

  Comment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    this.authorProfileImage,
    required this.content,
    required this.createdAt,
  });

  factory Comment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Comment(
      id: doc.id,
      postId: data['postId'] ?? '',
      authorId: data['authorId'] ?? '',
      authorName: data['authorName'] ?? 'Unknown',
      authorProfileImage: data['authorProfileImage'],
      content: data['content'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'postId': postId,
      'authorId': authorId,
      'authorName': authorName,
      'authorProfileImage': authorProfileImage,
      'content': content,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
