import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/app_header.dart';
import './camera-screen.dart';
import '../services/user_service.dart';
import 'report_detail_screen.dart'; // <-- Add this import at the top
import '../models/report.dart';


// HomeScreen Widget - Now accepts userId as a parameter
class HomeScreen extends StatefulWidget {
  final String? userId; // Add userId as a parameter

  const HomeScreen({super.key, this.userId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Report> _recentReports = [];
  bool _isLoadingReports = false;

  @override
  void initState() {
    super.initState();
    _fetchRecentReports();
  }

  Future<void> _fetchRecentReports() async {
    try {
      setState(() {
        _isLoadingReports = true;
      });

      // Get the current user's ID
      String? userId = widget.userId ?? await UserService.getCurrentSupabaseUserId();
      if (userId == null) {
        setState(() {
          _recentReports = [];
        });
        return;
      }

      // Fetch only 2 most recent reports for this user
      final response = await http.get(
        Uri.parse('http://192.168.0.103:8000/reports/user/$userId'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> reportsJson = data['reports'] ?? [];

        List<Report> allReports =
            reportsJson.map((json) => Report.fromJson(json)).toList();

        // Sort by timestamp (newest first) and take only latest 2
        allReports.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        setState(() {
          _recentReports = allReports.take(2).toList();
        });
      }
    } catch (e) {
      print('Failed to load recent reports: $e');
    } finally {
      setState(() {
        _isLoadingReports = false;
      });
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
    // Simple location format for recent reports
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
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with logo and title
            const AppHeader(),
            const SizedBox(height: 24),
            // Hero Card (white background)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Report Non-Compliant Billboards',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Help keep our city safe and beautiful. Tap the button below to report a billboard in seconds.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.blue[700],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Report Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final supabaseUserId = await UserService.getCurrentSupabaseUserId();
                  if (supabaseUserId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CameraScreen(userId: supabaseUserId),
                      ),
                    );
                  } else {
                    // Handle user not logged in
                    Navigator.pushNamed(context, '/login');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt, size: 24),
                    SizedBox(width: 12),
                    Text(
                      'Report a Billboard',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            // Recent Reports Section
            const Text(
              'Recent Reports',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            // Recent Reports List
            if (_isLoadingReports) ...[
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
            ] else if (_recentReports.isEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Text(
                  'No recent reports found',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ] else ...[
              // Display recent reports
              for (int i = 0; i < _recentReports.length; i++) ...[
                _buildReportItem(_recentReports[i]),
                if (i < _recentReports.length - 1) const SizedBox(height: 12),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReportItem(Report report) {
    // Minimalistic: Only location, date, status
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ReportDetailScreen(report: report),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.location_on, color: Colors.blue[400], size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatLocation(report.gpsLatitude, report.gpsLongitude),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _formatDate(report.timestamp),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(report.status).withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
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
      ),
    );
  }
}

// Report Confirmation Sheet Widget (unchanged)
class ReportConfirmationSheet extends StatefulWidget {
  final File imageFile;
  final Position? position;
  const ReportConfirmationSheet(
      {super.key, required this.imageFile, this.position});

  @override
  State<ReportConfirmationSheet> createState() =>
      _ReportConfirmationSheetState();
}

class _ReportConfirmationSheetState extends State<ReportConfirmationSheet> {
  String? selectedReason;
  final List<String> reasons = [
    'No Permit / Unauthorized Billboard',
    'Expired License / Permit',
    'Wrong Location (Non-designated Area)',
    'Oversized Billboard (Exceeds Allowed Dimensions)',
    'Obstructing Traffic Signs / View',
    'Obstructing Pedestrian Path / Public Property',
    'Dangerous Placement (Weak Structure / Risk of Falling)',
    'Lighting Violation (Too Bright / Flashing / Hazardous at Night)',
    'Illegal Content (Offensive / Adult / Prohibited Ads)',
    'Too Close to Residential Area / School / Religious Place',
    'Environmental Violation (On Trees / Natural Reserve / Green Zone)',
    'Multiple Boards in Same Spot (Overcrowding)',
    'Damaged / Broken Billboard (Safety Hazard)',
    'Violation of City Zoning Rules',
  ];

  @override
  Widget build(BuildContext context) {
    final pos = widget.position;
    String locationText = 'Location unavailable';
    if (pos != null) {
      locationText =
          '${pos.latitude.toStringAsFixed(4)}° N, ${pos.longitude.toStringAsFixed(4)}° E (Mumbai)';
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Confirm Report',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.blueGrey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: widget.imageFile.existsSync()
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(widget.imageFile, fit: BoxFit.cover),
                  )
                : const Center(
                    child: Text(
                      'Captured Billboard',
                      style: TextStyle(
                        color: Colors.blueGrey,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Location (Geotagged)',
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Colors.blue, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    locationText,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Violation Reason',
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: selectedReason,
            items: reasons
                .map((reason) => DropdownMenuItem(
                      value: reason,
                      child: Text(reason, style: const TextStyle(fontSize: 14)),
                    ))
                .toList(),
            onChanged: (val) => setState(() => selectedReason = val),
            decoration: InputDecoration(
              hintText: 'Select a reason',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: selectedReason == null
                  ? null
                  : () {
                      // TODO: Submit report logic
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Report submitted!')),
                      );
                    },
              icon: const Icon(Icons.send, color: Colors.white),
              label: const Text(
                'Submit Report',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
