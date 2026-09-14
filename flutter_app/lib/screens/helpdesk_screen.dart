import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api.dart';
import '../services/response_utils.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../theme/ion.dart';
import '../widgets/rn_kit.dart';

/// Port of `frontend/app/helpdesk.tsx` (Expo v2.11.1).
///
/// Posts `/Profile/Send2ClubHelpDesk`. The API keeps no copy on the sender's side, so the
/// club's reply comes back as a NEW notification rather than landing in a thread.
class HelpDeskScreen extends StatefulWidget {
  const HelpDeskScreen({super.key});

  @override
  State<HelpDeskScreen> createState() => _HelpDeskScreenState();
}

class _HelpDeskScreenState extends State<HelpDeskScreen> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_message.text.trim().isEmpty) {
      await notify(context, 'Help Desk', 'Please type your message.');
      return;
    }
    setState(() => _sending = true);
    try {
      await Api.profileSend2ClubHelpDesk({
        'text': _subject.text.trim().isEmpty ? 'Help Desk' : _subject.text.trim(),
        'value': _message.text.trim(),
        'notificationType': 'HelpDesk',
      });
      if (!mounted) return;
      setState(() => _sending = false);
      await notify(context, 'Sent', 'Your message has been sent to the club help desk.');
      if (mounted) safeBack(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      notify(context, 'Failed', friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final user = context.watch<UserSession>().authData ?? const <String, dynamic>{};
    final club = '${user['clubName'] ?? ''}'.isEmpty ? 'Club' : '${user['clubName']}';

    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 8),
          child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textSecondary)),
        );

    InputDecoration deco(String hint) => InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: c.textMuted, fontSize: 15),
          filled: true,
          fillColor: c.surface,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md), borderSide: BorderSide(color: c.border)),
          enabledBorder:
              OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md), borderSide: BorderSide(color: c.border)),
          focusedBorder:
              OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.md), borderSide: BorderSide(color: c.border)),
        );

    return Scaffold(
      backgroundColor: c.background,
      body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const RnHeader(title: 'Help Desk'),
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(Gaps.xl, Gaps.xl, Gaps.xl, 60),
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: rnCard(c, radius: Radii.xl),
                child: Row(children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle),
                    child: Icon(Ion.headset, size: 24, color: c.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('$club Help Desk',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c.textPrimary)),
                      const SizedBox(height: 3),
                      Text('Send a message and the club will get back to you.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: c.textSecondary)),
                    ]),
                  ),
                ]),
              ),
              label('Subject'),
              TextField(
                controller: _subject,
                style: TextStyle(fontSize: 15, color: c.textPrimary),
                cursorColor: c.primary,
                decoration: deco('e.g. Payment query'),
              ),
              const SizedBox(height: 16),
              label('Message'),
              SizedBox(
                height: 130,
                child: TextField(
                  controller: _message,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: TextStyle(fontSize: 15, color: c.textPrimary),
                  cursorColor: c.primary,
                  decoration: deco('Type your message…'),
                ),
              ),
              const SizedBox(height: 22),
              Touchable(
                onPress: _sending ? null : _submit,
                activeOpacity: 0.9,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 52),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: c.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(Radii.md),
                    boxShadow: Shadows.strong(c),
                  ),
                  child: _sending
                      ? const Center(
                          child: SizedBox(
                              width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white)))
                      : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Ion.send, size: 16, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Send Message',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                        ]),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}
