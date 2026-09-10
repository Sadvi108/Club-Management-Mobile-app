import 'package:flutter/material.dart';

import '../services/autopay.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/gradient_button.dart';
import 'payment/term_payment_screen.dart';

/// Auto Pay — a monthly reminder plus one-tap advance payment.
///
/// Read the header comment on [AutoPayPrefs] before changing anything here. The short
/// version: Club.Api has no mandate or standing-instruction route, so nothing can charge
/// a member on a timer. This screen schedules a reminder and pre-selects the months; the
/// member still confirms the payment. The UI says so, in the first card, unprompted.
class AutoPayScreen extends StatefulWidget {
  const AutoPayScreen({super.key});

  @override
  State<AutoPayScreen> createState() => _AutoPayScreenState();
}

class _AutoPayScreenState extends State<AutoPayScreen> {
  AutoPayPrefs _prefs = AutoPayPrefs.defaults;
  bool _loading = true;
  bool _saving = false;

  /// What the OS actually has armed, which is not always what the app asked for —
  /// Android 12+ can refuse to schedule.
  bool _armed = false;

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // Defence in depth. NotificationService.init() no longer throws, but a screen whose
    // only exit from the loading state is the happy path is one bad await away from
    // spinning forever — which is exactly what happened here.
    var p = AutoPayPrefs.defaults;
    var armed = false;
    try {
      p = await AutoPayStore.load();
      armed = await NotificationService.hasAutoPayReminder();
    } catch (e) {
      debugPrint('autopay load failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _prefs = p;
          _armed = armed;
          _loading = false;
        });
      }
    }
  }

  String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    return switch (n % 10) {
      1 => '${n}st',
      2 => '${n}nd',
      3 => '${n}rd',
      _ => '${n}th',
    };
  }

  String _fmt(DateTime d) =>
      '${_ordinal(d.day)} ${_months[d.month - 1]} ${d.year}, '
      '${d.hour.toString().padLeft(2, '0')}:00';

  /// Persist, then re-arm or cancel so the OS matches what the screen shows.
  Future<void> _apply(AutoPayPrefs next, {String? toast}) async {
    setState(() {
      _prefs = next;
      _saving = true;
    });
    await AutoPayStore.save(next);

    var armed = false;
    if (next.enabled) {
      final when = nextReminder(next, DateTime.now());
      final months = monthsToSettle(next, DateTime.now());
      final label = months.length == 1
          ? '${_months[months.first.month - 1]} ${months.first.year}'
          : '${months.length} months';
      armed = await NotificationService.scheduleAutoPayReminder(
          when, 'Time to settle $label. Tap to review and pay.');
    } else {
      await NotificationService.cancelAutoPayReminder();
    }

    if (!mounted) return;
    setState(() {
      _armed = armed;
      _saving = false;
    });
    if (toast != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(toast)));
    }
  }

  Future<void> _toggle(bool on) async {
    if (on) {
      // Ask before promising a reminder we cannot deliver.
      final granted = await NotificationService.hasPermission() ||
          await NotificationService.requestPermission();
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Notifications are off for D-CLIX, so the reminder cannot be shown. '
              'Turn them on in your phone settings.'),
          duration: Duration(seconds: 6),
        ));
        return;
      }
    }
    await _apply(_prefs.copyWith(enabled: on),
        toast: on ? 'Auto Pay reminder set.' : 'Auto Pay reminder turned off.');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    if (_loading) {
      return Scaffold(
        backgroundColor: c.background,
        body: const Column(children: [
          AppHeader(title: 'Auto Pay', showBack: true),
          Expanded(child: Center(child: CircularProgressIndicator())),
        ]),
      );
    }

    final now = DateTime.now();
    final next = nextReminder(_prefs, now);
    final months = monthsToSettle(_prefs, now);

    return Scaffold(
      backgroundColor: c.background,
      body: Column(children: [
        const AppHeader(
          title: 'Auto Pay',
          subtitle: 'Monthly reminder + one-tap payment',
          showBack: true,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Gaps.lg, Gaps.md, Gaps.lg, Gaps.xxxl),
            children: [
              _explainer(c),
              const SizedBox(height: Gaps.md),
              _toggleCard(c),
              if (_prefs.enabled) ...[
                const SizedBox(height: Gaps.md),
                if (!_armed) _notArmedWarning(c),
                _nextCard(c, next, months),
                const SizedBox(height: Gaps.md),
                _label(c, 'REMIND ME ON'),
                _dayPicker(c),
                const SizedBox(height: Gaps.md),
                _label(c, 'SETTLE HOW FAR AHEAD'),
                _monthsPicker(c),
                const SizedBox(height: Gaps.xl),
                GradientButton(
                  label: 'Pay these months now',
                  trailingIcon: Icons.arrow_forward,
                  // TermPaymentScreen has no route of its own — the payments screen
                  // pushes it directly, so do the same rather than invent a path.
                  onPressed: _saving
                      ? null
                      : () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const TermPaymentScreen())),
                ),
              ],
            ],
          ),
        ),
      ]),
    );
  }

  /// Up front, before the toggle: what this does and what it does not do.
  Widget _explainer(AppColors c) => Container(
        padding: const EdgeInsets.all(Gaps.md),
        decoration: BoxDecoration(
          color: c.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: c.primary.withValues(alpha: 0.25)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline, size: 20, color: c.primary),
          const SizedBox(width: Gaps.sm),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Your money is never taken automatically',
                  style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                  'The club system cannot hold a direct debit or keep your card on file. '
                  'Auto Pay reminds you each month and opens the payment with the right '
                  'months already ticked — you still tap Pay.',
                  style: TextStyle(
                      color: c.textSecondary, fontSize: 12.5, height: 1.5)),
            ]),
          ),
        ]),
      );

  Widget _toggleCard(AppColors c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: Gaps.md, vertical: 4),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: c.isDark ? Border.all(color: c.border) : null,
          boxShadow: Shadows.card(c),
        ),
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _prefs.enabled,
          onChanged: _saving ? null : _toggle,
          activeThumbColor: Colors.white,
          activeTrackColor: c.primary,
          title: Text('Monthly payment reminder',
              style: TextStyle(
                  color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
          subtitle: Text(
              _prefs.enabled
                  ? 'On — you will get one notification a month'
                  : 'Off — no reminders',
              style: TextStyle(color: c.textSecondary, fontSize: 12.5)),
        ),
      );

  /// The app asked the OS to schedule and the OS said no. Saying nothing here would leave
  /// the member believing a reminder is coming that never arrives.
  Widget _notArmedWarning(AppColors c) => Container(
        margin: const EdgeInsets.only(bottom: Gaps.md),
        padding: const EdgeInsets.all(Gaps.md),
        decoration: BoxDecoration(
          color: c.warning.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: c.warning.withValues(alpha: 0.35)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.warning_amber, size: 18, color: c.warning),
          const SizedBox(width: Gaps.sm),
          Expanded(
            child: Text(
                'Your phone did not accept the scheduled reminder, so it may not appear. '
                'D-CLIX will still prompt you the next time you open the app after the '
                'date passes.',
                style: TextStyle(
                    color: c.textPrimary, fontSize: 12.5, height: 1.45)),
          ),
        ]),
      );

  Widget _nextCard(AppColors c, DateTime next, List<TermMonth> months) => Container(
        padding: const EdgeInsets.all(Gaps.md),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: c.isDark ? Border.all(color: c.border) : null,
          boxShadow: Shadows.card(c),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.event_available, size: 18, color: c.primary),
            const SizedBox(width: 8),
            Text('Next reminder',
                style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5)),
          ]),
          const SizedBox(height: 6),
          Text(_fmt(next),
              style: TextStyle(
                  color: c.textPrimary, fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: Gaps.sm),
          Divider(height: 1, color: c.border),
          const SizedBox(height: Gaps.sm),
          Text('It will offer to settle',
              style: TextStyle(color: c.textSecondary, fontSize: 12)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final m in months)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: c.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Radii.xxl),
                ),
                child: Text('${_months[m.month - 1]} ${m.year}',
                    style: TextStyle(
                        color: c.primary, fontSize: 11.5, fontWeight: FontWeight.w800)),
              ),
          ]),
          const SizedBox(height: Gaps.sm),
          Text(
              'The current month is not included — it is already invoiced and appears '
              'under Fees Due.',
              style: TextStyle(color: c.textMuted, fontSize: 11, height: 1.4)),
        ]),
      );

  Widget _label(AppColors c, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: TextStyle(
                color: c.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8)),
      );

  Widget _dayPicker(AppColors c) => Container(
        padding: const EdgeInsets.all(Gaps.sm),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Radii.lg),
          border: Border.all(color: c.border),
        ),
        child: Column(children: [
          Text('Day ${_prefs.dayOfMonth} of each month',
              style: TextStyle(
                  color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
          Slider(
            value: _prefs.dayOfMonth.toDouble(),
            min: 1,
            max: 28,
            divisions: 27,
            label: '${_prefs.dayOfMonth}',
            activeColor: c.primary,
            onChanged: _saving
                ? null
                : (v) => setState(
                    () => _prefs = _prefs.copyWith(dayOfMonth: v.round())),
            onChangeEnd: (v) => _apply(_prefs.copyWith(dayOfMonth: v.round())),
          ),
          Text('Capped at 28 so the reminder never lands on a day February does not have.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textMuted, fontSize: 11)),
        ]),
      );

  Widget _monthsPicker(AppColors c) => Wrap(
        spacing: Gaps.sm,
        children: [
          for (final n in [1, 2, 3, 6])
            ChoiceChip(
              label: Text(n == 1 ? '1 month' : '$n months'),
              selected: _prefs.monthsAhead == n,
              onSelected: _saving
                  ? null
                  : (v) {
                      if (v) _apply(_prefs.copyWith(monthsAhead: n));
                    },
            ),
        ],
      );
}
