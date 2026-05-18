import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../services/api.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_body.dart';

/// Progress / Performance screen — D-Clix 2026 design.
///
/// Layout (top → bottom):
///   • Header — back chevron · eyebrow `YOUR PROGRESS` · `Performance` title
///     · trailing `+N this mo` pill
///   • Overall score card — large fitness ring on the left, headline +
///     body copy on the right
///   • Skill breakdown — one card per skill (Speed, Power, Technique,
///     Agility, Endurance) with a coloured bar
///   • Trainer feedback — chat-bubble card per comment
///
/// All numeric inputs (fitness score, skill values, monthly delta) come
/// from /Reports/Activity if available; otherwise we render reasonable
/// defaults so the UI never breaks on accounts without progress data yet.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  bool _loading = false;
  Map<String, dynamic>? _live; // merged map of skill/fitness fields
  List<dynamic> _attendance = const [];
  List<dynamic> _grading = const [];

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    setState(() => _loading = true);
    final out = <String, dynamic>{};
    try {
      // Real, per-student sources: attendance records + grading history.
      final results = await Future.wait([
        _safe(() => Api.reportsAttendance(const {})),
        _safe(() => Api.reportsGradingSchedule(const {})),
        _safe(Api.reportsActivity),
      ]);
      _attendance = results[0] is List ? results[0] as List : const [];
      _grading = results[1] is List ? results[1] as List : const [];
      final activity = results[2];
      if (activity is Map) out.addAll(Map<String, dynamic>.from(activity));
      if (activity is List && activity.isNotEmpty && activity.first is Map) {
        out.addAll(Map<String, dynamic>.from(activity.first as Map));
      }
    } catch (e) {
      debugPrint('progress load failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _live = out.isEmpty ? null : out;
          _loading = false;
        });
      }
    }
  }

  /// Attendance rows scoped to the active student (guardian accounts).
  List<Map> get _scopedAttendance => UserSession.instance
      .filterByActiveStudent(_attendance)
      .whereType<Map>()
      .toList();

  List<Map> get _scopedGrading => UserSession.instance
      .filterByActiveStudent(_grading)
      .whereType<Map>()
      .toList();

  bool _isPresent(Map r) {
    final s = (r['attendanceType'] ?? r['status'] ?? r['value'] ?? '')
        .toString()
        .toLowerCase();
    return s.contains('present') || s == '1' || s == 'p' || s == 'yes';
  }

  /// {attendancePct, classes, classesThisMonth, gradesPassed, gradesTotal}.
  Map<String, int> _realStats() {
    final att = _scopedAttendance;
    final present = att.where(_isPresent).toList();
    final pct =
        att.isEmpty ? 0 : ((present.length / att.length) * 100).round();
    final now = DateTime.now();
    int thisMonth = 0;
    for (final r in present) {
      final d = DateTime.tryParse(
          (r['recordedTime'] ?? r['date'] ?? '').toString());
      if (d != null && d.year == now.year && d.month == now.month) {
        thisMonth++;
      }
    }
    final grading = _scopedGrading;
    final passed = grading.where((g) {
      final s = (g['examStatus'] ?? g['remarks'] ?? '')
          .toString()
          .toLowerCase();
      return s.contains('pass');
    }).length;
    return {
      'attendancePct': pct,
      'classes': present.length,
      'classesThisMonth': thisMonth,
      'gradesPassed': passed,
      'gradesTotal': grading.length,
    };
  }

  Future<dynamic> _safe(Future<dynamic> Function() fn) async {
    try {
      final r = await fn();
      if (r is Map && r.containsKey('data')) return r['data'];
      return r;
    } catch (_) {
      return null;
    }
  }

  // ─── Derived values ────────────────────────────────────────────────────
  /// Best-effort live read of a numeric stat, with a sensible fallback.
  num _num(List<String> keys, num fallback) {
    for (final m in [_live, UserSession.instance.myInfo, UserSession.instance.studentAddtnlInfo]) {
      if (m == null) continue;
      for (final k in keys) {
        final v = m[k];
        if (v is num) return v;
        if (v is String) {
          final n = num.tryParse(v.replaceAll(RegExp(r'[^\d.\-]'), ''));
          if (n != null) return n;
        }
      }
    }
    return fallback;
  }

  String _str(List<String> keys, String fallback) {
    for (final m in [_live, UserSession.instance.myInfo, UserSession.instance.studentAddtnlInfo]) {
      if (m == null) continue;
      for (final k in keys) {
        final v = m[k];
        if (v != null && v.toString().trim().isNotEmpty) return v.toString();
      }
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final session = context.watch<UserSession>();
    final w = MediaQuery.of(context).size.width;
    final compact = w < 380;

    final stats = _realStats();
    final fitness = stats['attendancePct']!;
    final deltaThisMonth = stats['classesThisMonth']!;
    final nextBelt = _str(['nextBelt', 'nextGrade'],
        session.currentGrade.isNotEmpty ? session.currentGrade : '');
    final gradingRows = _scopedGrading;

    // Clear a hardware notch when the OS reports no inset (web/preview).
    final topPad =
        (MediaQuery.of(context).padding.top > 0 ? 0.0 : 44.0) + 14;
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: c.primary,
          onRefresh: _loadProgress,
          child: ResponsiveBody(child: ListView(
            padding: EdgeInsets.fromLTRB(Gaps.xl, topPad, Gaps.xl, 140),
            children: [
              _buildHeader(c, deltaThisMonth, context),
              const SizedBox(height: 18),
              _buildOverallCard(c, fitness, deltaThisMonth, nextBelt, compact: compact),
              const SizedBox(height: 14),
              _buildMetricRow(c, stats),
              const SizedBox(height: 22),
              Text(
                'Grading history',
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3),
              ),
              const SizedBox(height: 12),
              if (_loading)
                Center(
                    child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(color: c.primary),
                ))
              else if (gradingRows.isEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.surface,
                    borderRadius: BorderRadius.circular(Radii.lg),
                    border: c.isDark ? Border.all(color: c.border) : null,
                    boxShadow: Shadows.card(c),
                  ),
                  child: Row(children: [
                    Icon(Icons.school_outlined,
                        size: 20, color: c.textMuted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No grading records yet. They appear here after your first belt evaluation.',
                        style: TextStyle(
                            color: c.textSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            height: 1.4),
                      ),
                    ),
                  ]),
                )
              else
                ...gradingRows.map((g) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildGradingCard(c, g),
                    )),
            ],
          )),
        ),
      ),
    );
  }

  // ─── Header (back chevron, eyebrow, title, +N pill) ───────────────────
  Widget _buildHeader(AppColors c, int delta, BuildContext ctx) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        InkWell(
          onTap: ctx.canPop() ? () => ctx.pop() : null,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: c.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.arrow_back, color: c.primary, size: 20),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YOUR PROGRESS',
                style: TextStyle(
                    color: c.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.5),
              ),
              const SizedBox(height: 2),
              Text(
                'Performance',
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: c.gradient),
            borderRadius: BorderRadius.circular(999),
            boxShadow: Shadows.strong(c),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.arrow_upward, color: Colors.white, size: 12),
            const SizedBox(width: 4),
            Text(
              '$delta this mo',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800),
            ),
          ]),
        ),
      ],
    );
  }

  // ─── Overall score card (ring + headline) ─────────────────────────────
  Widget _buildOverallCard(
    AppColors c,
    int fitness,
    int delta,
    String nextBelt, {
    required bool compact,
  }) {
    final ringSize = compact ? 100.0 : 120.0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.xl),
        border: c.isDark ? Border.all(color: c.border) : null,
        boxShadow: Shadows.card(c),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _FitnessRing(value: fitness, size: ringSize, gradient: c.gradient),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OVERALL SCORE',
                  style: TextStyle(
                      color: c.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5),
                ),
                const SizedBox(height: 4),
                Text(
                  delta > 0 ? "You're on fire" : 'Keep going',
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3),
                ),
                const SizedBox(height: 4),
                if (delta > 0)
                  const Text('🔥', style: TextStyle(fontSize: 16)),
                const SizedBox(height: 6),
                Text(
                  delta > 0
                      ? 'Attended $delta ${delta == 1 ? "class" : "classes"} this month. ${nextBelt.isNotEmpty ? "Keep it up for the $nextBelt evaluation." : "Keep the consistency going."}'
                      : 'No classes logged this month yet. Attend a session to lift your attendance score.',
                  style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Real-metric summary row (3 tiles from live data) ──────────────────
  Widget _buildMetricRow(AppColors c, Map<String, int> stats) {
    Widget tile(IconData icon, String value, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(Radii.lg),
              border: c.isDark ? Border.all(color: c.border) : null,
              boxShadow: Shadows.card(c),
            ),
            child: Column(children: [
              Icon(icon, color: c.primary, size: 20),
              const SizedBox(height: 6),
              Text(value,
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        );
    return Row(children: [
      tile(Icons.event_available, '${stats['classes']}', 'Classes\nattended'),
      const SizedBox(width: 10),
      tile(Icons.calendar_month, '${stats['classesThisMonth']}',
          'This\nmonth'),
      const SizedBox(width: 10),
      tile(Icons.workspace_premium,
          '${stats['gradesPassed']}/${stats['gradesTotal']}',
          'Gradings\npassed'),
    ]);
  }

  // ─── Grading history card (one real /Reports/GradingSchedule row) ──────
  Widget _buildGradingCard(AppColors c, Map g) {
    final current = (g['currentGrade'] ?? '').toString();
    final next = (g['nextGrade'] ?? '').toString();
    final examDateRaw = (g['examDate'] ?? '').toString();
    final examDate =
        examDateRaw.length >= 10 ? examDateRaw.substring(0, 10) : examDateRaw;
    final status = (g['examStatus'] ?? g['remarks'] ?? '').toString().trim();
    final payStatus = (g['paymentStatus'] ?? '').toString().trim();
    final passed = status.toLowerCase().contains('pass');
    final statusColor = passed
        ? c.success
        : (status.isEmpty ? c.textMuted : c.danger);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: c.isDark ? Border.all(color: c.border) : null,
        boxShadow: Shadows.card(c),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(
                passed ? Icons.check_circle : Icons.school_outlined,
                color: statusColor, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  next.isNotEmpty && next != current
                      ? '$current → $next'
                      : (current.isNotEmpty ? current : 'Grading'),
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800),
                ),
                if (examDate.isNotEmpty)
                  Text('Exam: $examDate',
                      style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          if (status.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(status,
                  style: TextStyle(
                      color: statusColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800)),
            ),
        ]),
        if (payStatus.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.payments_outlined, size: 13, color: c.textMuted),
            const SizedBox(width: 5),
            Text('Payment: $payStatus',
                style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ]),
        ],
      ]),
    );
  }
}

/// Custom-painted fitness ring (no extra dep needed). Renders a gradient
/// stroke from primary-light → primary-dark along the progress arc.
class _FitnessRing extends StatelessWidget {
  final int value; // 0..100
  final double size;
  final List<Color> gradient;
  const _FitnessRing({
    required this.value,
    required this.size,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _RingPainter(
              progress: value / 100,
              gradient: gradient,
              trackColor: c.borderLight,
              strokeWidth: size * 0.075,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$value',
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: size * 0.32,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    height: 1.0),
              ),
              const SizedBox(height: 2),
              Text(
                'FITNESS',
                style: TextStyle(
                    color: c.textSecondary,
                    fontSize: size * 0.085,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final List<Color> gradient;
  final Color trackColor;
  final double strokeWidth;

  const _RingPainter({
    required this.progress,
    required this.gradient,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc with sweep gradient — start from top (−π/2)
    final sweep = 2 * math.pi * progress.clamp(0.0, 1.0);
    final shader = SweepGradient(
      startAngle: -math.pi / 2,
      endAngle: -math.pi / 2 + 2 * math.pi,
      colors: gradient,
      stops: const [0.0, 0.5, 1.0],
    ).createShader(rect);
    final progressPaint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, sweep, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress ||
      old.gradient != gradient ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}
