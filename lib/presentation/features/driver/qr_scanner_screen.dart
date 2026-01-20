import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../providers/di_providers.dart';
import '../../../core/config/api_endpoints.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  bool _isProcessing = false;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _checkCameraPermission();
  }

  Future<void> _checkCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) {
      setState(() => _hasPermission = true);
    } else {
      final result = await Permission.camera.request();
      setState(() => _hasPermission = result.isGranted);
      if (!result.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Camera permission is required to scan QR codes'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  Future<void> _handleBarcodeCapture(BarcodeCapture barcodeCapture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = barcodeCapture.barcodes;
    if (barcodes.isEmpty) return;

    final Barcode barcode = barcodes.first;
    if (barcode.rawValue == null) return;

    final String qrCode = barcode.rawValue!;
    debugPrint('📷 Scanned QR Code: $qrCode');

    setState(() => _isProcessing = true);

    // Stop scanning while processing
    await _controller.stop();

    try {
      // Call the backend API with the scanned QR code
      final dio = ref.read(dioProvider);
      final response = await dio.get(
        BasoodEndpoints.order.qrCodes(qrCode),
      );

      debugPrint('✅ QR Code API Response: ${response.data}');

      if (mounted) {
        Navigator.of(context).pop(qrCode);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('QR Code scanned successfully: $qrCode'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error processing QR code: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing QR code: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        // Resume scanning on error
        await _controller.start();
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      body: !_hasPermission
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.camera_alt_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Camera permission required',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () async {
                      await openAppSettings();
                    },
                    child: const Text('Open Settings'),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _handleBarcodeCapture,
                ),
                // Overlay with scanning area indicator
                Container(
                  decoration: ShapeDecoration(
                    shape: QrScannerOverlayShape(
                      borderColor: Colors.white,
                      borderRadius: 16,
                      borderLength: 30,
                      borderWidth: 4,
                      cutOutSize: 250,
                    ),
                  ),
                ),
                // Instructions
                Positioned(
                  bottom: 100,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _isProcessing
                          ? const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Processing...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            )
                          : const Text(
                              'Position QR code within the frame',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// Custom overlay shape for QR scanner
class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  const QrScannerOverlayShape({
    this.borderColor = Colors.white,
    this.borderWidth = 2.0,
    this.overlayColor = const Color.fromRGBO(0, 0, 0, 80),
    this.borderRadius = 0,
    this.borderLength = 40,
    this.cutOutSize = 250,
  });

  @override
  EdgeInsetsGeometry get dimensions => const EdgeInsets.all(10);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addPath(getOuterPath(rect), Offset.zero);
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final height = rect.height;
    final borderOffset = borderWidth / 2;
    final cutOutSize = this.cutOutSize < width || this.cutOutSize < height
        ? this.cutOutSize
        : width - borderOffset;

    final left = (width / 2) - (cutOutSize / 2);
    final top = (height / 2) - (cutOutSize / 2);
    final right = left + cutOutSize;
    final bottom = top + cutOutSize;

    final cutOutRect = Rect.fromLTRB(left, top, right, bottom);
    final cutOutRRect = RRect.fromRectAndRadius(
      cutOutRect,
      Radius.circular(borderRadius),
    );

    return Path()
      ..addRRect(cutOutRRect)
      ..addRect(Rect.fromLTWH(0, 0, width, height))
      ..fillType = PathFillType.evenOdd;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final width = rect.width;
    final height = rect.height;
    final borderOffset = borderWidth / 2;
    final cutOutSize = this.cutOutSize < width || this.cutOutSize < height
        ? this.cutOutSize
        : width - borderOffset;

    final left = (width / 2) - (cutOutSize / 2);
    final top = (height / 2) - (cutOutSize / 2);
    final right = left + cutOutSize;
    final bottom = top + cutOutSize;

    final cutOutRect = Rect.fromLTRB(left, top, right, bottom);

    // Draw overlay
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, width, height));

    final cutOutRRect = RRect.fromRectAndRadius(
      cutOutRect,
      Radius.circular(borderRadius),
    );

    final cutOutPath = Path()..addRRect(cutOutRRect);

    final backgroundPaint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        backgroundPath,
        cutOutPath,
      ),
      backgroundPaint,
    );

    // Draw border
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final path = Path()
      ..moveTo(left, top + borderRadius)
      ..lineTo(left, top + borderLength)
      ..moveTo(left, top)
      ..lineTo(left + borderLength, top)
      ..moveTo(right - borderLength, top)
      ..lineTo(right, top)
      ..lineTo(right, top + borderRadius)
      ..moveTo(right, top + borderLength)
      ..lineTo(right, bottom - borderLength)
      ..moveTo(right, bottom - borderRadius)
      ..lineTo(right, bottom)
      ..lineTo(right - borderLength, bottom)
      ..moveTo(left + borderLength, bottom)
      ..lineTo(left, bottom)
      ..lineTo(left, bottom - borderRadius)
      ..moveTo(left, bottom - borderLength)
      ..lineTo(left, top + borderLength);

    canvas.drawPath(path, borderPaint);
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth,
      overlayColor: overlayColor,
    );
  }
}
