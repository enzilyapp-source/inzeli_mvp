// lib/pages/scan_page.dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// صفحة مسح QR للانضمام إلى روم.
/// تعيد كود الروم عبر Navigator.pop(code) عند أول قراءة صالحة.
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  bool _handled = false;

  String? _extractCode(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    // لو لينك فيه /room/<code> أو query code=
    final uri = Uri.tryParse(text);
    if (uri != null) {
      final qCode = uri.queryParameters['code'];
      if (qCode != null && qCode.isNotEmpty) return qCode.trim();
      if (uri.pathSegments.isNotEmpty) {
        final last = uri.pathSegments.last;
        if (last.length >= 4 && last.length <= 12) return last;
      }
    }

    // fallback: النص كامل لو شكله كود مختصر
    if (text.length >= 4 && text.length <= 12) return text;
    return null;
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final code in capture.barcodes) {
      final raw = code.rawValue;
      if (raw == null) continue;
      final roomCode = _extractCode(raw);
      if (roomCode != null) {
        _handled = true;
        Navigator.of(context).pop(roomCode);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('مسح QR للانضمام'),
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: _onDetect,
            controller: MobileScannerController(
              torchEnabled: false,
              facing: CameraFacing.back,
              detectionSpeed: DetectionSpeed.normal,
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'وجّه الكاميرا نحو QR الخاص بالروم',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
