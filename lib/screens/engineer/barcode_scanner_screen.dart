import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../services/api_service.dart';

const _kPrimary = Color(0xFF0D47A1);

class BarcodeScannerScreen extends StatefulWidget {
  final String ticketId;
  const BarcodeScannerScreen({super.key, required this.ticketId});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  // Controller gives us access to torch toggle
  final MobileScannerController _scannerController = MobileScannerController();

  bool _isProcessing = false;
  bool _torchOn = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.05, end: 0.90).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _toggleTorch() async {
    await _scannerController.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  Future<void> _processBarcode(String value) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      final res = await _apiService.post('/otp/send', {'request_id': widget.ticketId});
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final maskedEmail = data['data']?['masked_email'];
        Fluttertoast.showToast(msg: '✓ OTP Sent to Customer', backgroundColor: const Color(0xFF22C55E));
        if (mounted) context.go('/engineer/otp/${widget.ticketId}', extra: maskedEmail);
      } else {
        Fluttertoast.showToast(msg: 'Failed to send OTP', backgroundColor: const Color(0xFFEF4444));
        setState(() => _isProcessing = false);
      }
    } catch (_) {
      Fluttertoast.showToast(msg: 'Network error', backgroundColor: const Color(0xFFEF4444));
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.go('/engineer'),
        ),
        title: const Text('Scan Barcode',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        actions: [
          IconButton(
            icon: Icon(
              _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
              color: _torchOn ? Colors.yellow : Colors.white,
            ),
            onPressed: _toggleTorch,
            tooltip: 'Toggle Torch',
          ),
        ],
      ),
      body: Stack(children: [
        // Camera
        MobileScanner(
          controller: _scannerController,
          onDetect: (capture) {
            for (final barcode in capture.barcodes) {
              if (barcode.rawValue != null) {
                _processBarcode(barcode.rawValue!);
                break;
              }
            }
          },
        ),

        // Adaptive overlay
        isLandscape
            ? _LandscapeOverlay(pulseAnim: _pulseAnim, isProcessing: _isProcessing)
            : _PortraitOverlay(pulseAnim: _pulseAnim, isProcessing: _isProcessing),

        // Processing overlay
        if (_isProcessing)
          Container(
            color: Colors.black.withOpacity(0.6),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Sending OTP...',
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}

// ── Portrait Overlay ──────────────────────────────────────────────────────────
class _PortraitOverlay extends StatelessWidget {
  final Animation<double> pulseAnim;
  final bool isProcessing;
  const _PortraitOverlay({required this.pulseAnim, required this.isProcessing});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cutW = size.width * 0.78;
    final cutH = size.height * 0.26;

    return Stack(children: [
      CustomPaint(
        painter: _OverlayPainter(cutW: cutW, cutH: cutH),
        child: const SizedBox.expand(),
      ),
      // Animated scan line
      if (!isProcessing)
        AnimatedBuilder(
          animation: pulseAnim,
          builder: (_, __) {
            final top = (size.height - cutH) / 2;
            return Positioned(
              top: top + (cutH * pulseAnim.value),
              left: (size.width - cutW) / 2 + 4,
              child: Container(
                width: cutW - 8,
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.transparent,
                    Colors.cyanAccent.withOpacity(0.9),
                    Colors.transparent,
                  ]),
                ),
              ),
            );
          },
        ),
      CustomPaint(
        painter: _CornerPainter(cutW: cutW, cutH: cutH),
        child: const SizedBox.expand(),
      ),
      // Bottom info bar
      Positioned(
        bottom: 0, left: 0, right: 0,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 48),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter, end: Alignment.topCenter,
              colors: [Colors.black87, Colors.transparent],
            ),
          ),
          child: Column(children: [
            const Icon(Icons.qr_code_scanner_rounded, color: Color(0xB3FFFFFF), size: 30),
            const SizedBox(height: 8),
            const Text(
              'Align the product barcode within the frame',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            Text(
              'Make sure barcode is clear and well-lit',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
            ),
          ]),
        ),
      ),
    ]);
  }
}

// ── Landscape Overlay ─────────────────────────────────────────────────────────
class _LandscapeOverlay extends StatelessWidget {
  final Animation<double> pulseAnim;
  final bool isProcessing;
  const _LandscapeOverlay({required this.pulseAnim, required this.isProcessing});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final cutW = size.width * 0.50;
    final cutH = size.height * 0.55;

    return Stack(children: [
      CustomPaint(
        painter: _OverlayPainter(cutW: cutW, cutH: cutH),
        child: const SizedBox.expand(),
      ),
      if (!isProcessing)
        AnimatedBuilder(
          animation: pulseAnim,
          builder: (_, __) {
            final top = (size.height - cutH) / 2;
            return Positioned(
              top: top + (cutH * pulseAnim.value),
              left: (size.width - cutW) / 2 + 4,
              child: Container(
                width: cutW - 8,
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.transparent,
                    Colors.cyanAccent.withOpacity(0.9),
                    Colors.transparent,
                  ]),
                ),
              ),
            );
          },
        ),
      CustomPaint(
        painter: _CornerPainter(cutW: cutW, cutH: cutH),
        child: const SizedBox.expand(),
      ),
      Positioned(
        right: 20, top: 0, bottom: 0,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.qr_code_scanner_rounded, color: Color(0xB3FFFFFF), size: 22),
          const SizedBox(height: 8),
          const RotatedBox(
            quarterTurns: 1,
            child: Text('Align barcode in frame',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500)),
          ),
        ]),
      ),
    ]);
  }
}

// ── Painters ─────────────────────────────────────────────────────────────────
class _OverlayPainter extends CustomPainter {
  final double cutW, cutH;
  _OverlayPainter({required this.cutW, required this.cutH});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.65);
    final full = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final hole = Path()..addRRect(RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2), width: cutW, height: cutH),
      const Radius.circular(14),
    ));
    canvas.drawPath(Path.combine(PathOperation.difference, full, hole), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _CornerPainter extends CustomPainter {
  final double cutW, cutH;
  _CornerPainter({required this.cutW, required this.cutH});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2), width: cutW, height: cutH,
    );
    const len = 24.0;

    for (final corner in [
      [rect.topLeft,     const Offset(len, 0),   const Offset(0, len)],
      [rect.topRight,    const Offset(-len, 0),  const Offset(0, len)],
      [rect.bottomLeft,  const Offset(len, 0),   const Offset(0, -len)],
      [rect.bottomRight, const Offset(-len, 0),  const Offset(0, -len)],
    ]) {
      final pt = corner[0] as Offset;
      canvas.drawLine(pt, pt + (corner[1] as Offset), p);
      canvas.drawLine(pt, pt + (corner[2] as Offset), p);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
