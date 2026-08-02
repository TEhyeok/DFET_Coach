import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/request_item.dart';

class RequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'requests';

  /// 모든 요청 가져오기 (실시간 스트림)
  Stream<List<RequestItem>> getRequestsStream() {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => RequestItem.fromFirestore(doc))
          .toList();
    });
  }

  /// 특정 상태의 요청 가져오기
  Future<List<RequestItem>> getRequestsByStatus(RequestStatus status) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('status', isEqualTo: status.name)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => RequestItem.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error fetching requests by status: $e');
      return [];
    }
  }

  /// 요청 상태 업데이트
  Future<void> updateRequestStatus(
      String requestId, RequestStatus status) async {
    try {
      await _firestore.collection(_collection).doc(requestId).update({
        'status': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating request status: $e');
      rethrow;
    }
  }

  /// 피드백 전송 및 완료 처리
  Future<void> sendFeedback(
      String requestId, String feedback, String adminId) async {
    try {
      await _firestore.collection(_collection).doc(requestId).update({
        'status': RequestStatus.completed.name,
        'adminFeedback': feedback,
        'adminId': adminId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error sending feedback: $e');
      rethrow;
    }
  }

  /// Mock 데이터 생성 (테스트용)
  Future<void> createMockRequests() async {
    final mockRequests = [
      {
        'userId': 'mock_user_1',
        'userName': 'Kim Chulsoo',
        'type': 'postureCheck',
        'status': 'newRequest',
        'title': 'Squat Posture Check',
        'description': 'Please check my squat depth and back posture.',
        'createdAt': DateTime.now().subtract(const Duration(hours: 2)),
      },
      {
        'userId': 'mock_user_2',
        'userName': 'Lee Younghee',
        'type': 'dietFeedback',
        'status': 'inProgress',
        'title': 'Lunch Calorie Estimation',
        'description': 'Is this portion size okay for my cutting phase?',
        'createdAt': DateTime.now().subtract(const Duration(days: 1)),
      },
      {
        'userId': 'mock_user_3',
        'userName': 'Park Jimin',
        'type': 'generalInquiry',
        'status': 'completed',
        'title': 'Workout Plan Question',
        'description': 'Can I switch leg day with push day?',
        'createdAt': DateTime.now().subtract(const Duration(days: 3)),
        'adminFeedback': 'Yes, as long as you get enough rest.',
        'adminId': 'admin_1',
      },
    ];

    for (var data in mockRequests) {
      await _firestore.collection(_collection).add(data);
    }
  }
}
