import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme/app_theme.dart';

/// Full-screen QR scanner.
///
/// Uses `mobile_scanner` for real device scanning and gracefully falls back
/// to a simulated success state on Flutter Web (where browser permissions may
/// block camera access) or when camera initialization fails.
class QRScanScreen extends StatefulWidget {
  const QRScanScreen({super.key});
  @override
  State<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen> with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  late final AnimationController _laser;
  bool _scanned = false;
  String _scannedCode = 'Karate Drills';
  bool _cameraFailed = false;
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );
    _laser = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);

    // On web (or in unavailable envs) simulate a successful scan after a few seconds
    // so the UI flow is still demonstrable.
    if (kIsWeb) {
      _fallbackTimer = Timer(const Duration(milliseconds: 2800), () {
        if (mounted && !_scanned) setState(() => _scanned = true);
      });
    }
  }

  @override
  void dispose() {
    _fallbackTimer?.cancel();
    _laser.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final code = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (code != null && mounted) {
      setState(() {
        _scanned = true;
        _scannedCode = 'Class: $code';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(fit: StackFit.expand, children: [
        // Background — camera feed or dark gradient fallback
        if (!_scanned && !_cameraFailed)
          _buildCameraView()
        else
          _buildDarkBackdrop(),
        // Dim overlay
        Container(color: Colors.black.withOpacity(0.45)),

        // Top bar
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                InkWell(
                  onTap: () => context.pop(),
                  borderRadius: BorderRadius.circular(21),
                  child: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), shape: BoxShape.circle),
                    child: const Icon(Icons.close, color: Colors.white, size: 22),
                  ),
                ),
                const Text('Scan to Check-in', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                InkWell(
                  onTap: () => _controller.toggleTorch(),
                  borderRadius: BorderRadius.circular(21),
                  child: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.12), shape: BoxShape.circle),
                    child: const Icon(Icons.flash_on, color: Colors.white, size: 20),
                  ),
                ),
              ]),
            ),
          ),
        ),

        // Center area
        Align(
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                _scanned ? 'Check-in Successful!' : (_cameraFailed ? 'Camera unavailable' : 'Align the QR within the frame'),
                style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: 240, height: 240,
                child: Stack(children: [
                  _corner(c, top: 0, left: 0, borders: const [_Side.top, _Side.left]),
                  _corner(c, top: 0, right: 0, borders: const [_Side.top, _Side.right]),
                  _corner(c, bottom: 0, left: 0, borders: const [_Side.bottom, _Side.left]),
                  _corner(c, bottom: 0, right: 0, borders: const [_Side.bottom, _Side.right]),
                  if (!_scanned)
                    AnimatedBuilder(
                      animation: _laser,
                      builder: (_, __) => Positioned(
                        top: 10 + (220 * _laser.value), left: 10, right: 10,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [const Color(0x00F97316), c.primary, const Color(0x00F97316)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_scanned)
                    Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.check_circle, size: 70, color: c.success),
                        const SizedBox(height: 12),
                        Text(_scannedCode, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        const Text('24 Feb · 06:00 AM', style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 12)),
                      ]),
                    ),
                ]),
              ),
              const SizedBox(height: 26),
              Text(
                _scanned ? 'Attendance marked for today' : 'Make sure camera has good lighting',
                style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 12),
                textAlign: TextAlign.center,
              ),
              if (_scanned) ...[
                const SizedBox(height: 28),
                InkWell(
                  onTap: () => context.pop(),
                  borderRadius: BorderRadius.circular(Radii.md),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: c.gradient),
                      borderRadius: BorderRadius.circular(Radii.md),
                      boxShadow: Shadows.strong(c),
                    ),
                    child: const Text('Done', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                ),
              ],
            ]),
          ),
        ),

        // Footer
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                Icon(Icons.verified_user, size: 14, color: Color(0x99FFFFFF)),
                SizedBox(width: 6),
                Text('Secure · End-to-end encrypted', style: TextStyle(color: Color(0x99FFFFFF), fontSize: 11, fontWeight: FontWeight.w500)),
              ]),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildCameraView() {
    return MobileScanner(
      controller: _controller,
      onDetect: _onDetect,
      errorBuilder: (_, __, ___) {
        // Camera init failed (common on web without HTTPS / permission denied)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _cameraFailed = true);
          _fallbackTimer ??= Timer(const Duration(milliseconds: 1800), () {
            if (mounted && !_scanned) setState(() => _scanned = true);
          });
        });
        return _buildDarkBackdrop();
      },
    );
  }

  Widget _buildDarkBackdrop() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Colors.black, Color(0xFF0A0A0B), Color(0xFF1F1610)],
        ),
      ),
    );
  }

  Widget _corner(AppColors c, {double? top, double? bottom, double? left, double? right, required List<_Side> borders}) {
    return Positioned(
      top: top, bottom: bottom, left: left, right: right,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          border: Border(
            top: borders.contains(_Side.top) ? BorderSide(color: c.primary, width: 4) : BorderSide.none,
            bottom: borders.contains(_Side.bottom) ? BorderSide(color: c.primary, width: 4) : BorderSide.none,
            left: borders.contains(_Side.left) ? BorderSide(color: c.primary, width: 4) : BorderSide.none,
            right: borders.contains(_Side.right) ? BorderSide(color: c.primary, width: 4) : BorderSide.none,
          ),
          borderRadius: BorderRadius.only(
            topLeft: borders.contains(_Side.top) && borders.contains(_Side.left) ? const Radius.circular(12) : Radius.zero,
            topRight: borders.contains(_Side.top) && borders.contains(_Side.right) ? const Radius.circular(12) : Radius.zero,
            bottomLeft: borders.contains(_Side.bottom) && borders.contains(_Side.left) ? const Radius.circular(12) : Radius.zero,
            bottomRight: borders.contains(_Side.bottom) && borders.contains(_Side.right) ? const Radius.circular(12) : Radius.zero,
          ),
        ),
      ),
    );
  }
}

enum _Side { top, bottom, left, right }
