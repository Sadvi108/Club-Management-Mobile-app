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

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    setState(() => _loading = true);
    final out = <String, dynamic>{};
    try {
      // Pull a few endpoints in parallel; ignore individual failures.
      final results = await Future.wait([
        _safe(Api.reportsActivity),
        _safe(Api.reportsContribution),
        _safe(Api.reportsGradingSchedule),
      ]);
      for (final r in results) {
        if (r is Map) out.addAll(Map<String, dynamic>.from(r));
        if (r is List && r.isNotEmpty && r.first is Map) {
          out.addAll(Map<String, dynamic>.from(r.first as Map));
        }
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

    // Live numbers (with falls-back used until /Reports/Activity returns).
    final fitness = _num(['fitness', 'fitnessScore', 'overallScore'], 82).toInt();
    final deltaThisMonth = _num(['monthlyDelta', 'thisMonth', 'pointsThisMonth'], 12).toInt();
    final nextBelt = _str(['nextBelt', 'nextGrade'],
        session.currentGrade.isNotEmpty ? 'next' : 'Purple Belt');

    final skills = [
      _Skill('Speed',      _num(['speed', 'skillSpeed'], 78).toInt(),      const Color(0xFFF59E0B)),
      _Skill('Power',      _num(['power', 'skillPower'], 72).toInt(),      const Color(0xFFEF4444)),
      _Skill('Technique',  _num(['technique', 'skillTechnique'], 85).toInt(), const Color(0xFFF97316)),
      _Skill('Agility',    _num(['agility', 'skillAgility'], 80).toInt(),    const Color(0xFF10B981)),
      _Skill('Endurance',  _num(['endurance', 'skillEndurance'], 75).toInt(), const Color(0xFF0EA5E9)),
    ];

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: c.primary,
          onRefresh: _loadProgress,
          child: ResponsiveBody(child: ListView(
            padding: const EdgeInsets.fromLTRB(Gaps.xl, 14, Gaps.xl, 140),
            children: [
              _buildHeader(c, deltaThisMonth, context),
              const SizedBox(height: 18),
              _buildOverallCard(c, fitness, deltaThisMonth, nextBelt, compact: compact),
              const SizedBox(height: 22),
              Text(
                'Skill breakdown',
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3),
              ),
              const SizedBox(height: 12),
              ...skills.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildSkillCard(c, s),
                  )),
              const SizedBox(height: 14),
              if (_loading)
                Center(
                    child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: CircularProgressIndicator(color: c.primary),
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
                      ? 'Up $delta points this month — keep that streak going for the $nextBelt evaluation.'
                      : 'Every session counts — pull up to the $nextBelt mark by training consistently.',
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

  // ─── Skill row card ────────────────────────────────────────────────────
  Widget _buildSkillCard(AppColors c, _Skill s) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: c.isDark ? Border.all(color: c.border) : null,
        boxShadow: Shadows.card(c),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                s.name,
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              '${s.value}',
              style: TextStyle(
                  color: s.color, fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(children: [
              Container(height: 8, color: c.borderLight),
              FractionallySizedBox(
                widthFactor: (s.value / 100).clamp(0.0, 1.0),
                child: Container(height: 8, color: s.color),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Skill {
  final String name;
  final int value;
  final Color color;
  const _Skill(this.name, this.value, this.color);
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
