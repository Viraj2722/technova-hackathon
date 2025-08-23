import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/app_header.dart';
import '../services/user_service.dart';
import 'report_detail_screen.dart';

class Report {
  final int reportId; // <-- Change from String to int
  final String imageUrl;
  final double? gpsLatitude;
  final double? gpsLongitude;
  final DateTime timestamp;
  final String status;
  final String issue;
  final String userId;

  Report({
    required this.reportId,
    required this.imageUrl,
    this.gpsLatitude,
    this.gpsLongitude,
    required this.timestamp,
    required this.status,
    required this.issue,
    required this.userId,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      reportId: json['report_id'],
      imageUrl: json['image_url'] ?? '',
      gpsLatitude: json['gps_latitude']?.toDouble(),
      gpsLongitude: json['gps_longitude']?.toDouble(),
      timestamp: DateTime.parse(json['timestamp']), // Remove the fallback to 'created_at'
      status: json['status'] ?? 'unknown',
      issue: json['issue'] ?? 'No description',
      userId: json['user_id'],
    );
  }
}

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Report> _reports = [];
  bool _isLoading = true;
  String? _error;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _initializeAndFetchReports();
  }

  Future<void> _initializeAndFetchReports() async {
    await _getCurrentUserId();
    await _fetchReports();
  }

  Future<void> _getCurrentUserId() async {
    try {
      final userId = await UserService.getCurrentSupabaseUserId();

      if (userId == null) {
        setState(() {
          _error = 'User not authenticated. Please log in again.';
          _isLoading = false;
        });
        return;
      }

      _currentUserId = userId;
      print('DEBUG: Current user ID: $_currentUserId');
    } catch (e) {
      setState(() {
        _error = 'Failed to get user information: $e';
        _isLoading = false;
      });
      print('Error getting current user ID: $e');
    }
  }

  Future<void> _fetchReports() async {
    if (_currentUserId == null) {
      setState(() {
        _error = 'User ID not available';
        _isLoading = false;
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      print('DEBUG: Fetching reports for user: $_currentUserId');

      // Fetch reports directly from Supabase
      final response = await _supabase
          .from('reports')
          .select('*')
          .eq('user_id', _currentUserId!)
          .order('timestamp', ascending: false); // Changed from 'created_at' to 'timestamp'

      print('DEBUG: Supabase response: $response');

      final List<Report> reports =
          (response as List).map((json) => Report.fromJson(json)).toList();

      setState(() {
        _reports = reports;
      });

      print('DEBUG: Loaded ${_reports.length} reports');
    } catch (e) {
      setState(() {
        _error = 'Failed to load reports: $e';
      });
      print('Error fetching reports: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showDeleteConfirmation(Report report) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Report'),
          content: const Text(
            'Are you sure you want to delete this report? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteReport(report.reportId); // <-- Use int directly
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteReport(int reportId) async { // <-- Accept int
    if (_currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not authenticated'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Delete from Supabase with user verification
      await _supabase.from('reports').delete().eq('report_id', reportId).eq(
          'user_id',
          _currentUserId!); // Ensure user can only delete their own reports

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh the list
      await _fetchReports();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete report: $e'),
          backgroundColor: Colors.red,
        ),
      );
      print('Error deleting report: $e');
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatLocation(double? lat, double? lng) {
    if (lat == null || lng == null) {
      return 'Location unavailable';
    }
    return '${lat.toStringAsFixed(4)}°N, ${lng.toStringAsFixed(4)}°E';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return Colors.green;
      case 'under review':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      case 'in progress':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _capitalizeStatus(String status) {
    return status
        .split(' ')
        .map((word) => word.isEmpty
            ? word
            : word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _fetchReports,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppHeader(),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'My Reports',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                if (!_isLoading && _reports.isNotEmpty)
                  Text(
                    '${_reports.length} report${_reports.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
              ],
            ),
            if (_currentUserId != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'User ID: ${_currentUserId!.substring(0, 8)}...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            if (_isLoading) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              ),
            ] else if (_error != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Column(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[600], size: 32),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(color: Colors.red[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _initializeAndFetchReports,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ] else if (_reports.isEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    Icon(Icons.report_off, color: Colors.grey[400], size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'No reports found',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Submit your first billboard report to see it here.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ] else ...[
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _reports.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final report = _reports[index];
                  return _buildReportCard(report);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(Report report) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ReportDetailScreen(report: report),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with delete button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Report ${report.reportId}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'delete') {
                      _showDeleteConfirmation(report);
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text(
                            'Delete',
                            style: TextStyle(color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      Icons.more_vert,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Image section
            Container(
              width: double.infinity,
              height: 128,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: report.imageUrl.isNotEmpty
                    ? Image.network(
                        report.imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image,
                                    color: Colors.grey, size: 32),
                                Text('Image not available',
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 12)),
                              ],
                            ),
                          );
                        },
                      )
                    : const Center(
                        child: Icon(Icons.image, size: 48, color: Colors.grey),
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // Location and Status row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _formatLocation(report.gpsLatitude, report.gpsLongitude),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(report.status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _capitalizeStatus(report.status),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(report.status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Date
            Text(
              _formatDate(report.timestamp),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),

            // Violation description
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
                children: [
                  const TextSpan(
                    text: 'Violation: ',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: report.issue),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
