import 'package:cloud_firestore/cloud_firestore.dart';

enum RequestType {
  postureCheck,
  dietFeedback,
  generalInquiry,
}

enum RequestStatus {
  newRequest,
  inProgress,
  completed,
  rejected,
}

class RequestItem {
  final String id;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final RequestType type;
  final RequestStatus status;
  final String title;
  final String description;
  final List<String> attachmentUrls;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? adminFeedback;
  final String? adminId;

  RequestItem({
    required this.id,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    required this.type,
    required this.status,
    required this.title,
    required this.description,
    this.attachmentUrls = const [],
    required this.createdAt,
    this.updatedAt,
    this.adminFeedback,
    this.adminId,
  });

  factory RequestItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RequestItem(
      id: doc.id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Unknown',
      userPhotoUrl: data['userPhotoUrl'],
      type: RequestType.values.firstWhere(
        (e) => e.name == (data['type'] ?? 'generalInquiry'),
        orElse: () => RequestType.generalInquiry,
      ),
      status: RequestStatus.values.firstWhere(
        (e) => e.name == (data['status'] ?? 'newRequest'),
        orElse: () => RequestStatus.newRequest,
      ),
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      attachmentUrls: List<String>.from(data['attachmentUrls'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      adminFeedback: data['adminFeedback'],
      adminId: data['adminId'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'userPhotoUrl': userPhotoUrl,
      'type': type.name,
      'status': status.name,
      'title': title,
      'description': description,
      'attachmentUrls': attachmentUrls,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'adminFeedback': adminFeedback,
      'adminId': adminId,
    };
  }

  RequestItem copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userPhotoUrl,
    RequestType? type,
    RequestStatus? status,
    String? title,
    String? description,
    List<String>? attachmentUrls,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? adminFeedback,
    String? adminId,
  }) {
    return RequestItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userPhotoUrl: userPhotoUrl ?? this.userPhotoUrl,
      type: type ?? this.type,
      status: status ?? this.status,
      title: title ?? this.title,
      description: description ?? this.description,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      adminFeedback: adminFeedback ?? this.adminFeedback,
      adminId: adminId ?? this.adminId,
    );
  }
}
