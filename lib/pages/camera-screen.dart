import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:http/http.dart' as http;

// Camera Screen Widget
class CameraScreen extends StatefulWidget {
  final String? userId; // Accept userId as parameter

  const CameraScreen({super.key, this.userId});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _requestPermissions().then((_) {
      _captureImage();
    });
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.camera,
      Permission.location,
    ].request();
  }

  Future<void> _captureImage() async {
    try {
      final cameraStatus = await Permission.camera.status;
      if (!cameraStatus.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera permission is required to take photos'),
          ),
        );
        return;
      }

      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (image != null) {
        Position? position;
        try {
          final locationStatus = await Permission.location.status;
          if (locationStatus.isGranted) {
            position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
            );
          }
        } catch (e) {
          print('Location error: $e');
        }

        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => ReportConfirmationScreen(
                imageFile: File(image.path),
                position: position,
                userId: widget.userId ?? 'anonymous',
                timestamp: DateTime.now(),
              ),
            ),
          );
        }
      } else {
        // Optionally, pop the screen if user cancels camera
        if (mounted) Navigator.of(context).pop();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error capturing image: $e')),
      );
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Return an empty container, so nothing is shown
    return const Scaffold(
      backgroundColor: Color(0xFF2C3E50),
      body: SizedBox.shrink(),
    );
  }
}

// Updated Report Confirmation Screen
class ReportConfirmationScreen extends StatefulWidget {
  final File imageFile;
  final Position? position;
  final String userId;
  final DateTime timestamp; // Add this

  const ReportConfirmationScreen({
    super.key,
    required this.imageFile,
    this.position,
    required this.userId,
    required this.timestamp, // Add this
  });

  @override
  State<ReportConfirmationScreen> createState() =>
      _ReportConfirmationScreenState();
}

class _ReportConfirmationScreenState extends State<ReportConfirmationScreen> {
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

    // Format timestamp
    final String formattedTimestamp =
        '${widget.timestamp.year}-${widget.timestamp.month.toString().padLeft(2, '0')}-${widget.timestamp.day.toString().padLeft(2, '0')} '
        '${widget.timestamp.hour.toString().padLeft(2, '0')}:${widget.timestamp.minute.toString().padLeft(2, '0')}:${widget.timestamp.second.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Confirm Report',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image preview
            Container(
              width: double.infinity,
              height: 240,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: widget.imageFile.existsSync()
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        widget.imageFile,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Center(
                      child: Text(
                        'Captured Billboard',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 24),

            // Location section
            const Text(
              'Location (Geotagged)',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      locationText,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Timestamp section
            const Text(
              'Timestamp',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      formattedTimestamp,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Violation reason dropdown
            const Text(
              'Violation Reason',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: selectedReason,
              hint: const Text('Select a violation reason'),
              items: reasons.map((reason) {
                return DropdownMenuItem<String>(
                  value: reason,
                  child: Text(
                    reason,
                    style: const TextStyle(fontSize: 14),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedReason = value;
                });
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 32),

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: selectedReason == null
                    ? null
                    : () {
                        _submitReport();
                      },
                icon: const Icon(Icons.send, color: Colors.white),
                label: const Text(
                  'Submit Report',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      selectedReason == null ? Colors.grey : Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: selectedReason == null ? 0 : 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submitReport() async {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Submitting report...'),
            ],
          ),
        );
      },
    );

    try {
      final uri = Uri.parse('http://192.168.6.99:8000/analyze-image/');
      final request = http.MultipartRequest('POST', uri);

      // Attach image file
      request.files.add(
        await http.MultipartFile.fromPath('image', widget.imageFile.path),
      );

      // Attach location
      if (widget.position != null) {
        request.fields['gps_latitude'] = widget.position!.latitude.toString();
        request.fields['gps_longitude'] = widget.position!.longitude.toString();
      } else {
        request.fields['gps_latitude'] = '';
        request.fields['gps_longitude'] = '';
      }

      // Attach violation reason
      request.fields['violation_reason'] = selectedReason ?? '';

      // Attach user_id
      request.fields['user_id'] = widget.userId;

      // Send request
      final response = await request.send();

      if (mounted) Navigator.of(context).pop(); // Close loading dialog

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report submitted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Failed to submit report. Status: ${response.statusCode}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // Close loading dialog
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
