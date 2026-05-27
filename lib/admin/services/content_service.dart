import 'package:cloud_firestore/cloud_firestore.dart';

class ContentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- Workouts ---
  CollectionReference get _workoutsRef => _firestore.collection('content_workouts');

  Stream<List<Map<String, dynamic>>> getWorkoutsStream() {
    return _workoutsRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  Future<void> addWorkout(Map<String, dynamic> data) async {
    await _workoutsRef.add(data);
  }

  Future<void> updateWorkout(String id, Map<String, dynamic> data) async {
    await _workoutsRef.doc(id).update(data);
  }

  Future<void> deleteWorkout(String id) async {
    await _workoutsRef.doc(id).delete();
  }

  // --- Foods ---
  CollectionReference get _foodsRef => _firestore.collection('content_foods');

  Stream<List<Map<String, dynamic>>> getFoodsStream() {
    return _foodsRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  Future<void> addFood(Map<String, dynamic> data) async {
    await _foodsRef.add(data);
  }

  Future<void> updateFood(String id, Map<String, dynamic> data) async {
    await _foodsRef.doc(id).update(data);
  }

  Future<void> deleteFood(String id) async {
    await _foodsRef.doc(id).delete();
  }
}
