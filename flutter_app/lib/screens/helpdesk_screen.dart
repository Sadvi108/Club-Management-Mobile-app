import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api.dart';
import '../services/response_utils.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/gradient_button.dart';

/// Help Desk — send a message to the club.
///
/// Posts `/Profile/Send2ClubHelpDesk`. The API keeps no copy on the sender's side, so the
/// club's reply comes back as a NEW notification with its own groupId rather than landing
/// in a thread — which is why Chat Academy pins sent help desk messages locally.
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
    final body = _message.text.trim();
    if (body.isEmpty) {
      _toast('Please type your message.');
      return;
    }
    setState(() => _sending = true);
    try {
      // Same three fields the working Chat Academy send uses. No `id` — it is not in the
      // shape either the Expo app or chat_thread_screen posts.
      await Api.profileSend2ClubHelpDesk({
        'text': _subject.text.trim().isEmpty ? 'Help Desk' : _subject.text.trim(),
        'value': body,
        'notificationType': 'HelpDesk',
      });
      if (!mounted) return;
      setState(() => _sending = false);
      _toast('Your message has been sent to the club help desk.');
      Navigator.of(context).maybePop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      _toast('Could not send your message: ${friendlyError(e)}', seconds: 6);
    }
  }

  void _toast(String msg, {int seconds = 4}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), duration: Duration(seconds: seconds)));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final club = context.watch<UserSession>().clubDisplayName;

    return Scaffold(
      backgroundColor: c.background,
      body: Column(children: [
        const AppHeader(title: 'Help Desk', showBack: true),
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(Gaps.lg, Gaps.md, Gaps.lg, Gaps.xxxl),
            children: [
              Container(
                padding: const EdgeInsets.all(Gaps.md),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(Radii.lg),
                  border: c.isDark ? Border.all(color: c.border) : null,
                  boxShadow: Shadows.card(c),
                ),
                child: Row(children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration:
                        BoxDecoration(color: c.surfaceAlt, shape: BoxShape.circle),
                    child: Icon(Icons.headset_mic, size: 24, color: c.primary),
                  ),
                  const SizedBox(width: Gaps.md),
                  Expanded(
                    child:
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${club.isEmpty ? "Club" : club} Help Desk',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text('Send a message and the club will get back to you.',
                          maxLines: 2,
                          style: TextStyle(color: c.textSecondary, fontSize: 12)),
                    ]),
                  ),
                ]),
              ),
              _label(c, 'SUBJECT'),
              _input(c, _subject, hint: 'e.g. Payment query'),
              _label(c, 'MESSAGE'),
              _input(c, _message, hint: 'Type your message...', maxLines: 6),
              const SizedBox(height: Gaps.xl),
              GradientButton(
                label: 'Send message',
                trailingIcon: Icons.send,
                loading: _sending,
                onPressed: _sending ? null : _submit,
              ),
              const SizedBox(height: Gaps.md),
              Text(
                'The club replies as a new notification, so look for it in Chat Academy.',
                style: TextStyle(color: c.textMuted, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _label(AppColors c, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6, top: Gaps.md),
        child: Text(text,
            style: TextStyle(
                color: c.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5)),
      );

  Widget _input(AppColors c, TextEditingController controller,
          {String? hint, int maxLines = 1}) =>
      TextField(
        controller: controller,
        maxLines: maxLines,
        enabled: !_sending,
        textCapitalization: TextCapitalization.sentences,
        style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: c.textMuted, fontWeight: FontWeight.w400),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          filled: true,
          fillColor: c.surface,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.lg),
            borderSide: BorderSide(color: c.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.lg),
            borderSide: BorderSide(color: c.primary),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.lg),
            borderSide: BorderSide(color: c.border),
          ),
        ),
      );
}
