import 'package:flutter/material.dart';

import '../services/notification_prefs.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';

/// How this device behaves when the club sends something.
///
/// Every option is per-device, so a member's phone and tablet can differ.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  NotifPrefs _p = NotifPrefs.defaults;
  bool _loading = true;
  bool _permitted = true;
  bool _testing = false;
  String? _picking; // 'start' | 'end'

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await NotifPrefsStore.load();
    final ok = await NotificationService.hasPermission();
    if (!mounted) return;
    setState(() {
      _p = p;
      _permitted = ok;
      _loading = false;
    });
  }

  Future<void> _update(NotifPrefs next) async {
    setState(() => _p = next);
    await NotifPrefsStore.save(next);
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    if (!_permitted) {
      final granted = await NotificationService.requestPermission();
      if (!mounted) return;
      setState(() => _permitted = granted);
      if (!granted) {
        setState(() => _testing = false);
        _say('Notifications are blocked for D-CLIX. Allow them in your device settings.');
        return;
      }
    }
    final shown = await NotificationService.sendTestAlert();
    if (!mounted) return;
    setState(() => _testing = false);
    if (!shown) {
      // The test bypasses categories and quiet hours, so the master switch is the only
      // preference that can block it — anything else is the platform refusing.
      _say(_p.enabled
          ? "This device wouldn't show the notification. Check that alerts are allowed for D-CLIX."
          : 'Push notifications are turned off above.');
    }
  }

  void _say(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  String _hh(int h) => '${h.toString().padLeft(2, '0')}:00';

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    // Scaffold, not a bare Container: these are STANDALONE routes, so nothing above them
    // provides Material, and AppHeader's back button is an InkWell — which asserts
    // "No Material widget found". The tab screens get away with a Container only because
    // TabsShell wraps them in its own Scaffold.
    return Scaffold(
      backgroundColor: c.background,
      body: Column(children: [
        const AppHeader(title: 'Notification settings', showBack: true),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(Gaps.xl, Gaps.md, Gaps.xl, Gaps.xxxl),
                  children: [
                    if (!_permitted) _blockedBanner(c),
                    _card(c, [
                      _toggle(c,
                          icon: Icons.notifications_active,
                          title: 'Push notifications',
                          sub: 'Alerts on your lock screen and notification tray',
                          value: _p.enabled,
                          onChanged: (v) => _update(_p.copyWith(enabled: v))),
                      _divider(c),
                      _toggle(c,
                          icon: Icons.volume_up,
                          title: 'Sound',
                          sub: 'Play the D-CLIX chime',
                          value: _p.sound,
                          enabled: _p.enabled,
                          onChanged: (v) => _update(_p.copyWith(sound: v))),
                      _divider(c),
                      _toggle(c,
                          icon: Icons.vibration,
                          title: 'Vibration',
                          sub: 'Buzz when an alert arrives',
                          value: _p.vibrate,
                          enabled: _p.enabled,
                          onChanged: (v) => _update(_p.copyWith(vibrate: v))),
                    ]),
                    const SizedBox(height: Gaps.md),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _testing ? null : _test,
                        icon: const Icon(Icons.play_circle_outline, size: 19),
                        label: Text(_testing ? 'Sending…' : 'Send a test notification'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: c.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: Gaps.xl),
                    _sectionTitle(c, 'What to alert me about'),
                    _card(c, [
                      for (var i = 0; i < NotifCategory.values.length; i++) ...[
                        if (i > 0) _divider(c),
                        _toggle(c,
                            icon: switch (NotifCategory.values[i]) {
                              NotifCategory.payments => Icons.account_balance_wallet,
                              NotifCategory.classes => Icons.fitness_center,
                              NotifCategory.general => Icons.campaign,
                            },
                            title: NotifCategory.values[i].label,
                            sub: NotifCategory.values[i].hint,
                            value: _p.categories[NotifCategory.values[i]] ?? true,
                            enabled: _p.enabled,
                            onChanged: (v) => _update(_p.copyWith(categories: {
                                  ..._p.categories,
                                  NotifCategory.values[i]: v,
                                }))),
                      ],
                    ]),
                    const SizedBox(height: Gaps.xl),
                    _sectionTitle(c, 'Quiet hours'),
                    _card(c, [
                      _toggle(c,
                          icon: Icons.nightlight_round,
                          title: 'Silence overnight',
                          sub: _p.quietEnabled
                              ? 'No alerts from ${_hh(_p.quietStartHour)} to ${_hh(_p.quietEndHour)}'
                              : 'Alerts arrive at any hour',
                          value: _p.quietEnabled,
                          enabled: _p.enabled,
                          onChanged: (v) => _update(_p.copyWith(quietEnabled: v))),
                      if (_p.quietEnabled) ...[
                        _divider(c),
                        _range(c),
                      ],
                    ]),
                    const SizedBox(height: Gaps.md),
                    Text(
                      'Nothing is lost during quiet hours — anything that arrives inside the '
                      'window alerts you once it ends.',
                      style: TextStyle(color: c.textMuted, fontSize: 11.5, height: 1.4),
                    ),
                    const SizedBox(height: Gaps.xl),
                    _sectionTitle(c, 'How delivery works'),
                    _card(c, [
                      _info(c, Icons.android,
                          'Android: alerts arrive with the app open or closed. Long-press an alert to fine-tune its channel in system settings.'),
                      _divider(c),
                      _info(c, Icons.phone_iphone,
                          'iOS: alerts arrive with the app open or closed, using the bundled chime and your ringer switch.'),
                    ]),
                    const SizedBox(height: Gaps.md),
                    Text(
                      'The club server delivers notifications to the app, which checks for new '
                      'ones about every minute while open.',
                      style: TextStyle(color: c.textMuted, fontSize: 11, height: 1.4),
                    ),
                  ],
                ),
        ),
      ]),
    );
  }

  Widget _blockedBanner(AppColors c) => Container(
        margin: const EdgeInsets.only(bottom: Gaps.md),
        padding: const EdgeInsets.all(Gaps.md),
        decoration: BoxDecoration(
          color: c.danger.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.danger.withValues(alpha: 0.45)),
        ),
        child: Row(children: [
          Icon(Icons.warning_amber_rounded, size: 20, color: c.danger),
          const SizedBox(width: Gaps.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Alerts are blocked',
                  style: TextStyle(
                      color: c.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text('Allow notifications for D-CLIX in your device settings.',
                  style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.35)),
            ]),
          ),
        ]),
      );

  Widget _sectionTitle(AppColors c, String t) => Padding(
        padding: const EdgeInsets.only(bottom: Gaps.sm),
        child: Text(t,
            style: TextStyle(
                color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
      );

  Widget _card(AppColors c, List<Widget> children) => Container(
        padding: const EdgeInsets.symmetric(horizontal: Gaps.md),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: Column(children: children),
      );

  Widget _divider(AppColors c) => Container(height: 1, color: c.border);

  Widget _toggle(
    AppColors c, {
    required IconData icon,
    required String title,
    required String sub,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool enabled = true,
  }) =>
      Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Gaps.md),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle),
              child: Icon(icon, size: 18, color: c.primary),
            ),
            const SizedBox(width: Gaps.md),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: TextStyle(
                        color: c.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(sub,
                    style: TextStyle(color: c.textSecondary, fontSize: 11.5, height: 1.35)),
              ]),
            ),
            Switch(
              value: value,
              onChanged: enabled ? onChanged : null,
              activeThumbColor: Colors.white,
              activeTrackColor: c.primary,
            ),
          ]),
        ),
      );

  Widget _info(AppColors c, IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Gaps.md),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle),
            child: Icon(icon, size: 18, color: c.textSecondary),
          ),
          const SizedBox(width: Gaps.md),
          Expanded(
            child: Text(text,
                style: TextStyle(color: c.textSecondary, fontSize: 12, height: 1.4)),
          ),
        ]),
      );

  Widget _range(AppColors c) => Padding(
        padding: const EdgeInsets.symmetric(vertical: Gaps.md),
        child: Column(children: [
          Row(children: [
            Expanded(child: _hourChip(c, 'From', _p.quietStartHour, 'start')),
            const SizedBox(width: Gaps.md),
            Icon(Icons.arrow_forward, size: 16, color: c.textMuted),
            const SizedBox(width: Gaps.md),
            Expanded(child: _hourChip(c, 'To', _p.quietEndHour, 'end')),
          ]),
          if (_picking != null) ...[
            const SizedBox(height: Gaps.md),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 24,
                separatorBuilder: (_, __) => const SizedBox(width: Gaps.sm),
                itemBuilder: (_, h) {
                  final on = _picking == 'start'
                      ? h == _p.quietStartHour
                      : h == _p.quietEndHour;
                  return GestureDetector(
                    onTap: () {
                      _update(_picking == 'start'
                          ? _p.copyWith(quietStartHour: h)
                          : _p.copyWith(quietEndHour: h));
                      setState(() => _picking = null);
                    },
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: on ? c.primary : c.surfaceAlt,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(_hh(h),
                          style: TextStyle(
                              color: on ? Colors.white : c.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),
                  );
                },
              ),
            ),
          ],
        ]),
      );

  Widget _hourChip(AppColors c, String label, int hour, String which) => GestureDetector(
        onTap: () => setState(() => _picking = _picking == which ? null : which),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: _picking == which ? c.primary : Colors.transparent),
          ),
          child: Column(children: [
            Text(label,
                style: TextStyle(
                    color: c.textSecondary, fontSize: 10.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(_hh(hour),
                style: TextStyle(
                    color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w800)),
          ]),
        ),
      );
}
