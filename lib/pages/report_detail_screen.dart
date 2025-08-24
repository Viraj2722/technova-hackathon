import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// import 'my_reports_screen.dart';
import '../models/report.dart';

class ReportDetailScreen extends StatefulWidget {
  final Report report;

  const ReportDetailScreen({
    super.key,
    required this.report,
  });

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  String? _actionTaken;
  String? _reportType;
  String? _rejectReason;
  bool _isLoadingDetails = false;

  @override
  void initState() {
    super.initState();
    _fetchReportDetails();
  }

  Future<void> _fetchReportDetails() async {
    setState(() {
      _isLoadingDetails = true;
    });

    try {
      final response = await _supabase
          .from('reports')
          .select('action_taken, report_type')
          .eq('report_id', widget.report.reportId)
          .single();

      setState(() {
        _actionTaken = response['action_taken'];
        _reportType = response['report_type'];
      });
    } catch (e) {
      print('Error fetching report details: $e');
      setState(() {
        _actionTaken = 'Unable to load action details';
        _reportType = 'Unknown';
        _rejectReason = null;
      });
    } finally {
      setState(() {
        _isLoadingDetails = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];

    final day = date.day;
    final month = months[date.month - 1];
    final year = date.year;

    return '$month $day, $year';
  }

  String _formatLocation(double? lat, double? lng) {
    if (lat == null || lng == null) {
      return 'Location unavailable';
    }
    return '${lat.toStringAsFixed(6)}°N, ${lng.toStringAsFixed(6)}°E';
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

  Color _getReportTypeColor(String? reportType) {
    switch (reportType?.toLowerCase()) {
      case 'hazardous':
        return Colors.red;
      case 'illegal':
        return Colors.orange;
      case 'inappropriate':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getReportTypeIcon(String? reportType) {
    switch (reportType?.toLowerCase()) {
      case 'hazardous':
        return Icons.warning;
      case 'illegal':
        return Icons.gavel;
      case 'inappropriate':
        return Icons.report_problem;
      default:
        return Icons.info;
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

  Widget _buildInfoCard({
    required String title,
    required String content,
    IconData? icon,
    Color? contentColor,
    Widget? customContent,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: Colors.grey[600]),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (customContent != null)
            customContent
          else
            Text(
              content,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: contentColor ?? Colors.black87,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.image, size: 20, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'Report Image',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            height: 250,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: widget.report.imageUrl.isNotEmpty
                  ? Image.network(
                      widget.report.imageUrl,
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
                                  color: Colors.grey, size: 48),
                              SizedBox(height: 8),
                              Text(
                                'Image not available',
                                style:
                                    TextStyle(color: Colors.grey, fontSize: 14),
                              ),
                            ],
                          ),
                        );
                      },
                    )
                  : const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image, size: 48, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            'No image available',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportTypeSection() {
    if (_reportType == null) return const SizedBox.shrink();

    Color typeColor = _getReportTypeColor(_reportType);
    IconData typeIcon = _getReportTypeIcon(_reportType);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: typeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: typeColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(typeIcon, size: 20, color: typeColor),
              const SizedBox(width: 8),
              Text(
                'Report Type',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: typeColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: typeColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              _reportType!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTakenSection() {
    // Hide if status is "under review"
    if (widget.report.status.toLowerCase() == 'under review') {
      return const SizedBox.shrink();
    }

    // Show reject reason if rejected
    if (widget.report.status.toLowerCase() == 'rejected' &&
        _rejectReason != null &&
        _rejectReason!.isNotEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, size: 20, color: Colors.red[600]),
                const SizedBox(width: 8),
                Text(
                  'Rejection Reason',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.red[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _rejectReason!,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.red[700],
              ),
            ),
          ],
        ),
      );
    }

    // Otherwise, show action taken
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.description_outlined, size: 20, color: Colors.blue[600]),
              const SizedBox(width: 8),
              Text(
                'Action Description',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isLoadingDetails)
            const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Loading details...'),
              ],
            )
          else
            Text(
              _actionTaken ?? 'No action description available',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.blue[700],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRejectReasonSection() {
    if (widget.report.status.toLowerCase() != 'rejected' ||
        _rejectReason == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, size: 20, color: Colors.red[600]),
              const SizedBox(width: 8),
              Text(
                'Rejection Reason',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.red[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isLoadingDetails)
            const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Loading reason...'),
              ],
            )
          else
            Text(
              _rejectReason!,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.red[700],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Report ${widget.report.reportId}',
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _getStatusColor(widget.report.status).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _capitalizeStatus(widget.report.status),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _getStatusColor(widget.report.status),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            _buildImageSection(),

            // Report Type Section
            _buildReportTypeSection(),

            // Report ID and Date
            _buildInfoCard(
              title: 'Report Details',
              content:
                  '', // Provide an empty string since customContent is used
              icon: Icons.info_outline,
              customContent: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Report ID:',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${widget.report.reportId}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Submitted:',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _formatDate(widget.report.timestamp),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Location
            _buildInfoCard(
              title: 'Location',
              content: _formatLocation(
                  widget.report.gpsLatitude, widget.report.gpsLongitude),
              icon: Icons.location_on_outlined,
            ),

            // Violation Type
            _buildInfoCard(
              title: 'Violation Type',
              content: widget.report.issue,
              icon: Icons.report_problem_outlined,
            ),

            // Status
            _buildInfoCard(
              title: 'Current Status',
              content: _capitalizeStatus(widget.report.status),
              contentColor: _getStatusColor(widget.report.status),
              icon: Icons.track_changes_outlined,
            ),

            // Action Taken Section (shows action description)
            _buildActionTakenSection(),

            // Reject Reason Section (only shows if status is rejected and reject_reason exists)
            _buildRejectReasonSection(),
          ],
        ),
      ),
    );
  }
}
