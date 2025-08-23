
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_service.dart';

class ReportService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Create a new report with proper user association
  static Future<int?> createReport({  // Changed return type from String? to int?
    required String issue,
    required String imageUrl,
    required String status,
    double? gpsLatitude,
    double? gpsLongitude,
    String? reportType,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      // Get the current user's Supabase UUID
      final currentUserId = await UserService.getCurrentSupabaseUserId();

      if (currentUserId == null) {
        throw Exception('User not authenticated or not found in database');
      }

      print('DEBUG: Creating report for user: $currentUserId');

      // Create the report with the correct user_id (Supabase UUID)
      final response = await _supabase
          .from('reports')
          .insert({
            'user_id':
                currentUserId, // This is the Supabase UUID from users table
            'issue': issue,
            'image_url': imageUrl,
            'status': status,
            'gps_latitude': gpsLatitude,
            'gps_longitude': gpsLongitude,
            'report_type': reportType,
            'timestamp': DateTime.now().toIso8601String(), // Add timestamp
            // Add any additional fields you need
            ...?additionalData,
          })
          .select('report_id')
          .single();

      final reportId = response['report_id'] as int; // Changed from String to int
      print('DEBUG: Report created successfully with ID: $reportId');
      return reportId;
    } catch (e) {
      print('Error creating report: $e');
      return null;
    }
  }

  /// Get all reports for the current user
  static Future<List<Map<String, dynamic>>> getCurrentUserReports() async {
    try {
      final currentUserId = await UserService.getCurrentSupabaseUserId();

      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      print('DEBUG: Fetching reports for user: $currentUserId');

      final response = await _supabase
          .from('reports')
          .select('*')
          .eq('user_id', currentUserId)
          .order('timestamp', ascending: false); // Changed from 'created_at'

      print('DEBUG: Found ${response.length} reports');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching user reports: $e');
      return [];
    }
  }

  /// Get all reports for a specific user (admin function)
  static Future<List<Map<String, dynamic>>> getReportsForUser(
      String userId) async {
    try {
      final response = await _supabase
          .from('reports')
          .select('*')
          .eq('user_id', userId)
          .order('timestamp', ascending: false); // Changed from 'created_at'

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching reports for user $userId: $e');
      return [];
    }
  }

  /// Update report status
  static Future<bool> updateReportStatus({
    required String reportId,
    required String newStatus,
  }) async {
    try {
      await _supabase.from('reports').update({
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String()
      }).eq('report_id', reportId);

      print('Report $reportId status updated to $newStatus');
      return true;
    } catch (e) {
      print('Error updating report status: $e');
      return false;
    }
  }

  /// Delete a report (only if user owns it)
  static Future<bool> deleteReport(int reportId) async { // Changed from String to int
    try {
      final currentUserId = await UserService.getCurrentSupabaseUserId();

      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      // Delete with user verification to ensure users can only delete their own reports
      await _supabase
          .from('reports')
          .delete()
          .eq('report_id', reportId)
          .eq('user_id', currentUserId);

      print('Report $reportId deleted successfully');
      return true;
    } catch (e) {
      print('Error deleting report: $e');
      return false;
    }
  }

  /// Get report with user details (joins users table)
  static Future<Map<String, dynamic>?> getReportWithUserDetails(
      String reportId) async {
    try {
      final response = await _supabase.from('reports').select('''
            *,
            users!inner(
              username,
              full_name,
              email
            )
          ''').eq('report_id', reportId).maybeSingle();

      return response;
    } catch (e) {
      print('Error fetching report with user details: $e');
      return null;
    }
  }

  /// Get all reports with user details (admin view)
  static Future<List<Map<String, dynamic>>> getAllReportsWithUserDetails({
    String? statusFilter,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      var query = _supabase.from('reports').select('''
            *,
            users!inner(
              username,
              full_name,
              email
            )
          ''');

      if (statusFilter != null) {
        query = query.eq('status', statusFilter);
      }

      final response = await query
          .order('timestamp', ascending: false) // Changed from 'created_at'
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching all reports with user details: $e');
      return [];
    }
  }

  /// Get report statistics for current user
  static Future<Map<String, int>> getCurrentUserReportStats() async {
    try {
      final currentUserId = await UserService.getCurrentSupabaseUserId();

      if (currentUserId == null) {
        throw Exception('User not authenticated');
      }

      final response = await _supabase
          .from('reports')
          .select('status')
          .eq('user_id', currentUserId);

      Map<String, int> stats = {
        'total': 0,
        'under review': 0,
        'resolved': 0,
        'rejected': 0,
        'in progress': 0,
      };

      for (var report in response) {
        String status = report['status']?.toString().toLowerCase() ?? 'unknown';
        stats['total'] = (stats['total'] ?? 0) + 1;
        stats[status] = (stats[status] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      print('Error fetching user report stats: $e');
      return {'total': 0};
    }
  }

  /// Check if current user can edit/delete a specific report
  static Future<bool> canUserModifyReport(String reportId) async {
    try {
      final currentUserId = await UserService.getCurrentSupabaseUserId();

      if (currentUserId == null) {
        return false;
      }

      final response = await _supabase
          .from('reports')
          .select('user_id')
          .eq('report_id', reportId)
          .maybeSingle();

      return response != null && response['user_id'] == currentUserId;
    } catch (e) {
      print('Error checking user report permissions: $e');
      return false;
    }
  }
}
