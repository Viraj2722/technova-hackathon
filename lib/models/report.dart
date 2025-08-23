class Report {
  final int reportId;
  final String imageUrl;
  final double? gpsLatitude;
  final double? gpsLongitude;
  final DateTime timestamp;
  final String status;
  final String issue;
  final String? userId;

  Report({
    required this.reportId,
    required this.imageUrl,
    this.gpsLatitude,
    this.gpsLongitude,
    required this.timestamp,
    required this.status,
    required this.issue,
    this.userId,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      reportId: json['report_id'],
      imageUrl: json['image_url'] ?? '',
      gpsLatitude: json['gps_latitude']?.toDouble(),
      gpsLongitude: json['gps_longitude']?.toDouble(),
      timestamp: DateTime.parse(json['timestamp']),
      status: json['status'] ?? 'unknown',
      issue: json['issue'] ?? 'No description',
      userId: json['user_id'],
    );
  }
}