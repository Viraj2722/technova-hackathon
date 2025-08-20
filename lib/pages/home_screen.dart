import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:io';
import '../widgets/app_header.dart';


// HomeScreen Widget
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
                onPressed: () {
                  // TODO: Implement report flow
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
            _buildReportItem('Marine Drive', 'Aug 15, 2025', 'Resolved', Colors.green),
            const SizedBox(height: 12),
            _buildReportItem('Bandra West', 'Aug 12, 2025', 'Under Review', Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _buildReportItem(String location, String date, String status, Color statusColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.ad_units,
              color: Colors.grey,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Report Confirmation Sheet Widget
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
