import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../utils/app_colors.dart';

class QRScannerPage extends StatefulWidget {
  const QRScannerPage({super.key});

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  MobileScannerController cameraController = MobileScannerController();
  String? result;
  bool flashOn = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text(
          'Scan QR Code',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontFamily: 'CascadiaCode',
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _toggleFlash,
            icon: Icon(
              flashOn ? Icons.flash_on : Icons.flash_off,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: MobileScanner(
                  controller: cameraController,
                  onDetect: _onDetect,
                ),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.qr_code_scanner,
                      color: AppColors.primary,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Scan QR Code',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'CascadiaCode',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Point your camera at a Vibra QR code\nto connect to a music device',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontFamily: 'CascadiaCode',
                      ),
                    ),
                    if (result != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                        ),
                        child: Text(
                          'Found: $result',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontFamily: 'CascadiaCode',
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null && barcode.rawValue!.startsWith('vibra://')) {
        setState(() {
          result = barcode.rawValue;
        });
        
        // Parse the connection info
        final uri = Uri.parse(barcode.rawValue!);
        final host = uri.host;
        final port = uri.port;
        
        // Return the connection info to the previous screen
        Navigator.pop(context, {
          'host': host,
          'port': port,
          'connectionString': barcode.rawValue,
        });
        break;
      }
    }
  }

  void _toggleFlash() async {
    await cameraController.toggleTorch();
    setState(() {
      flashOn = !flashOn;
    });
  }

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }
}
