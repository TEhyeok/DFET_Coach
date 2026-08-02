import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../core/utils/app_logger.dart';

class DataManagementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Export Users to CSV (Web only)
  Future<void> exportUsersToCsv() async {
    try {
      // 1. Fetch all users
      final querySnapshot = await _firestore.collection('users').get();
      final users = querySnapshot.docs;

      if (users.isEmpty) {
        AppLogger.info('No users to export');
        return;
      }

      // 2. Prepare CSV data
      List<List<dynamic>> rows = [];

      // Header row
      rows.add([
        'UID',
        'Email',
        'Name',
        'Gender',
        'Age',
        'Height',
        'Weight',
        'Activity Level',
        'Role',
        'Joined Date',
        'Last Login'
      ]);

      // Data rows
      for (var userDoc in users) {
        final data = userDoc.data();
        rows.add([
          userDoc.id,
          data['email'] ?? '',
          data['displayName'] ?? '',
          data['gender'] ?? '',
          data['age'] ?? '',
          data['height'] ?? '',
          data['weight'] ?? '',
          data['activityLevel'] ?? '',
          data['role'] ?? 'user',
          _formatTimestamp(data['createdAt']),
          _formatTimestamp(data['lastLoginAt']),
        ]);
      }

      // 3. Convert to CSV string
      String csvData = const ListToCsvConverter().convert(rows);

      // 4. Trigger download (Web specific)
      if (kIsWeb) {
        final bytes = utf8.encode(csvData);
        final blob = html.Blob([bytes]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute("download",
              "users_export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv")
          ..click();
        html.Url.revokeObjectUrl(url);
        AppLogger.info('CSV export started');
      } else {
        AppLogger.warning('CSV export is only supported on Web');
      }
    } catch (e, stackTrace) {
      AppLogger.error('Failed to export users to CSV', e, stackTrace);
      rethrow;
    }
  }

  /// Import Users from CSV (Web only)
  Future<Map<String, dynamic>> importUsersFromCsv() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result != null) {
        final bytes = result.files.first.bytes;
        if (bytes == null) return {'success': 0, 'failed': 0, 'total': 0};

        final csvString = utf8.decode(bytes);
        final List<List<dynamic>> rows =
            const CsvToListConverter().convert(csvString);

        if (rows.isEmpty || rows.length < 2) {
          return {'success': 0, 'failed': 0, 'total': 0};
        }

        // Remove header
        rows.removeAt(0);

        int successCount = 0;
        int failCount = 0;

        for (var row in rows) {
          try {
            // Assuming CSV format matches export format:
            // UID(0), Email(1), Name(2), Gender(3), Age(4), Height(5), Weight(6), Activity(7), Role(8)...
            // If UID exists, we might update, or skip. Let's skip if exists for safety, or update if needed.
            // For this implementation, let's assume we are creating NEW users if they don't exist,
            // or updating if they do.

            // Note: We cannot create Auth users from here easily without Admin SDK.
            // So this will only create/update Firestore documents.

            String uid = row[0].toString();
            if (uid.isEmpty) {
              // Generate a new ID if empty? Or skip.
              // Firestore auto-id is better if we are creating new.
              // But for import, usually we want to restore data.
              failCount++;
              continue;
            }

            final userRef = _firestore.collection('users').doc(uid);
            final doc = await userRef.get();

            if (doc.exists) {
              AppLogger.info(
                  'User $uid already exists, skipping import for this user.');
              // Optional: Update logic here
            } else {
              await userRef.set({
                'email': row[1],
                'displayName': row[2],
                'gender': row[3],
                'age': row[4],
                'height': row[5],
                'weight': row[6],
                'activityLevel': row[7],
                'role': row[8],
                'createdAt': FieldValue
                    .serverTimestamp(), // Reset created at or parse from CSV
                'importedAt': FieldValue.serverTimestamp(),
              });
              successCount++;
            }
          } catch (e) {
            failCount++;
            AppLogger.error('Error importing row: $row', e);
          }
        }

        return {
          'success': successCount,
          'failed': failCount,
          'total': rows.length
        };
      }
      return {'success': 0, 'failed': 0, 'total': 0};
    } catch (e, stackTrace) {
      AppLogger.error('Failed to import users from CSV', e, stackTrace);
      rethrow;
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return '';
    if (timestamp is Timestamp) {
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp.toDate());
    }
    return timestamp.toString();
  }
}
