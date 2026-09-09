import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/api.dart';
import '../services/attendance_outcome.dart';
import '../theme/app_theme.dart';
import '../utils/qr_content.dart';
import '../widgets/app_icon_button.dart';

/// Full-screen QR scanner for student check-in.
///
/// Students scan the printed training-centre poster (`TC-XXXXXXXX`);
/// the screen validates the payload locally and only reports success
/// after POST /Attendance/Add returns 2xx. Pops with `true` when an
/// attendance record was created so callers can refresh.
class QRScanScreen extends StatefulWidget {
  const QRScanScreen({super.key});
  @override
  State<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen> with SingleTickerProviderStateMixin {
  late final MobileScannerController _controller;
  late final AnimationController _laser;
  bool _scanned = false;
  String _scannedCode = '';
  bool _attendancePosted = false;
  bool _attendanceFailed = false;
  String? _serverMessage;
  bool _cameraFailed = false;
  String? _invalidHint;
  Timer? _hintTimer;
  bool _generateMode = false;
  final _genCtrl = TextEditingController();
  Uint8List? _genBytes;
  bool _generating = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );
    _laser = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _laser.dispose();
    _controller.dispose();
    _genCtrl.dispose();
    super.dispose();
  }

  Future<void> _generateQR() async {
    final text = _genCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _generating = true;
      _genBytes = null;
    });
    try {
      _genBytes = await Api.utilitiesQRCodeBytes(
          width: 300, height: 300, content: text);
    } catch (e) {
      debugPrint('QRCode generate failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanned) return;
    final code = capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (code == null || !mounted) return;
    final payload = QrContent.parse(code);
    if (payload == null) {
      _showInvalidHint('Not a D-Clix attendance code');
      return;
    }
    if (payload.type == QrType.student) {
      // Students check in against the venue poster, not each other's IDs.
      _showInvalidHint('Scan the training centre code at your venue');
      return;
    }
    setState(() {
      _scanned = true;
      _scannedCode = payload.label;
      _invalidHint = null;
    });
    _postAttendance(payload.code);
  }

  void _showInvalidHint(String msg) {
    if (_invalidHint == msg) return;
    _hintTimer?.cancel();
    setState(() => _invalidHint = msg);
    _hintTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _invalidHint = null);
    });
  }

  Future<void> _postAttendance(String qrCode, {int tTimeId = 0}) async {
    try {
      final resp = await Api.attendanceAdd(<String, dynamic>{
        'qrCode': qrCode,
        'attendanceType': 1,
        'tTimeId': tTimeId,
      });
      if (!mounted) return;
      final outcome = AttendanceOutcome.parse(resp);
      if (outcome.success) {
        setState(() {
          _attendancePosted = true;
          _serverMessage = outcome.message;
        });
        return;
      }
      if (outcome.needsClassTime) {
        // Server wants the class time — offer the sessions it returned
        // and re-POST with the chosen id.
        final picked = await _pickClassTime(outcome.sessions);
        if (!mounted) return;
        if (picked != null) {
          await _postAttendance(qrCode, tTimeId: picked.id);
          return;
        }
      }
      setState(() {
        _attendanceFailed = true;
        _serverMessage = outcome.message ??
            (outcome.needsClassTime ? 'No class time selected' : 'Rejected');
      });
    } catch (e) {
      debugPrint('AttendanceAdd failed: $e');
      if (!mounted) return;
      setState(() {
        _attendanceFailed = true;
        _serverMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<AttendanceSession?> _pickClassTime(
      List<AttendanceSession> sessions) {
    if (sessions.length == 1) {
      return Future.value(sessions.first);
    }
    return showModalBottomSheet<AttendanceSession>(
      context: context,
      builder: (ctx) {
        final c = ctx.appColors;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: c.border, borderRadius: BorderRadius.circular(99)),
              ),
              const SizedBox(height: 14),
              Text('Select your training class time',
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              ...sessions.map((s) => ListTile(
                    leading: Icon(Icons.schedule, color: c.primary, size: 20),
                    title: Text(s.text,
                        style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    onTap: () => Navigator.pop(ctx, s),
                  )),
            ]),
          ),
        );
      },
    );
  }

  void _rescan() {
    setState(() {
      _scanned = false;
      _scannedCode = '';
      _attendancePosted = false;
      _attendanceFailed = false;
      _serverMessage = null;
    });
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
                AppIconButton(
                  icon: Icons.close,
                  onPressed: () => context.pop(_attendancePosted),
                  backgroundColor: Colors.white.withOpacity(0.12),
                  foregroundColor: Colors.white,
                ),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  _tabBtn('Scan', !_generateMode, () => setState(() => _generateMode = false)),
                  const SizedBox(width: 6),
                  _tabBtn('Generate', _generateMode, () => setState(() => _generateMode = true)),
                ]),
                AppIconButton(
                  icon: Icons.flash_on,
                  onPressed: () => _controller.toggleTorch(),
                  backgroundColor: Colors.white.withOpacity(0.12),
                  foregroundColor: Colors.white,
                ),
              ]),
            ),
          ),
        ),

        // Center area
        if (_generateMode)
          _buildGeneratePanel(c)
        else
        Align(
          alignment: Alignment.center,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                _scanned
                    ? (_attendancePosted
                        ? 'Check-in Successful!'
                        : _attendanceFailed
                            ? 'Check-in failed'
                            : 'Recording attendance…')
                    : (_cameraFailed
                        ? 'Camera unavailable'
                        : 'Align the QR within the frame'),
                style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 14, fontWeight: FontWeight.w500),
              ),
              if (_invalidHint != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: c.danger.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(_invalidHint!,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ],
              const SizedBox(height: 28),
              SizedBox(
                width: 240, height: 240,
                child: Stack(children: [
                  _corner(c, top: 0, left: 0, borders: const [_Side.top, _Side.left]),
                  _corner(c, top: 0, right: 0, borders: const [_Side.top, _Side.right]),
                  _corner(c, bottom: 0, left: 0, borders: const [_Side.bottom, _Side.left]),
                  _corner(c, bottom: 0, right: 0, borders: const [_Side.bottom, _Side.right]),
                  if (!_scanned && !_cameraFailed)
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
                  if (_cameraFailed && !_scanned)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Use a device with a camera to check in by QR.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 13),
                        ),
                      ),
                    ),
                  if (_scanned)
                    Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(
                          _attendancePosted
                              ? Icons.check_circle
                              : _attendanceFailed
                                  ? Icons.error_outline
                                  : Icons.hourglass_top,
                          size: 70,
                          color: _attendancePosted
                              ? c.success
                              : _attendanceFailed
                                  ? c.danger
                                  : Colors.white70,
                        ),
                        const SizedBox(height: 12),
                        Text(_scannedCode, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        if (_attendancePosted)
                          Text(_serverMessage ?? 'Attendance recorded ✓',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFF86EFAC), fontSize: 12, fontWeight: FontWeight.w700))
                        else if (_attendanceFailed)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(_serverMessage ?? 'Attendance sync failed',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12)),
                          )
                        else
                          const Text('Recording attendance…', style: TextStyle(color: Color(0xB3FFFFFF), fontSize: 12)),
                      ]),
                    ),
                ]),
              ),
              const SizedBox(height: 26),
              Text(
                _scanned
                    ? (_attendancePosted ? 'Attendance marked for today' : '')
                    : 'Make sure camera has good lighting',
                style: const TextStyle(color: Color(0x99FFFFFF), fontSize: 12),
                textAlign: TextAlign.center,
              ),
              if (_scanned && (_attendancePosted || _attendanceFailed)) ...[
                const SizedBox(height: 28),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  if (_attendanceFailed) ...[
                    InkWell(
                      onTap: _rescan,
                      borderRadius: BorderRadius.circular(Radii.md),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(Radii.md),
                        ),
                        child: const Text('Rescan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  InkWell(
                    onTap: () => context.pop(_attendancePosted),
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
                ]),
              ],
              if (_cameraFailed && !_scanned) ...[
                const SizedBox(height: 28),
                InkWell(
                  onTap: () => context.pop(false),
                  borderRadius: BorderRadius.circular(Radii.md),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(Radii.md),
                    ),
                    child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
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
        // Camera init failed (common on web without HTTPS / permission
        // denied). No simulated scan: a check-in must come from a real code.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_cameraFailed) setState(() => _cameraFailed = true);
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

  Widget _tabBtn(String label, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label,
            style: TextStyle(
                color: active ? Colors.black : Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800)),
      ),
    );
  }

  Widget _buildGeneratePanel(AppColors c) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Generate QR', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(Radii.md),
            child: TextField(
              controller: _genCtrl,
              decoration: const InputDecoration(
                hintText: 'Enter text to encode',
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _generating ? null : _generateQR,
            borderRadius: BorderRadius.circular(Radii.md),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: c.gradient),
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Text(_generating ? 'Generating…' : 'Generate',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Center(
              child: _genBytes != null
                  ? Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(Radii.md)),
                      child: Image.memory(_genBytes!, width: 240, height: 240, fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Text('Cannot render image')),
                    )
                  : const Text('No QR generated yet', style: TextStyle(color: Color(0x99FFFFFF))),
            ),
          ),
        ]),
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
