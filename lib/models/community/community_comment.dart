import 'package:cloud_firestore/cloud_firestore.dart';

class CommunityComment {
  const CommunityComment({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String content;
  final DateTime createdAt;

  factory CommunityComment.fromFirestore(DocumentSnapshot document) {
    final data = document.data() as Map<String, dynamic>? ?? const {};
    final created = data['createdAt'];
    return CommunityComment(
      id: document.id,
      authorId: data['authorId'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '사용자',
      content: data['content'] as String? ?? '',
      createdAt: created is Timestamp ? created.toDate() : DateTime.now(),
    );
  }
}
