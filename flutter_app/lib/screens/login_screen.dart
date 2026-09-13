import '../theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/api.dart';
import '../services/response_utils.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/gradient_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _idCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _clubCtrl = TextEditingController();
  bool _showPwd = false;
  bool _isInstructor = false;
  bool _busy = false;

  // Instructor mode: branch dropdown state.
  List<Map<String, dynamic>> _branches = const [];
  int? _branchId;
  bool _branchesLoading = false;
  String? _branchesLoadedForCode;
  int _branchRequest = 0;

  @override
  void dispose() {
    _idCtrl.dispose();
    _pwdCtrl.dispose();
    _clubCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    final code = _clubCtrl.text.trim();
    if (code.isEmpty) return;
    final request = ++_branchRequest;
    setState(() => _branchesLoading = true);
    try {
      final response = await Api.accountGetBranchesByClubCode(code);
      final error = apiEnvelopeError(response);
      if (error != null) throw Exception(error);
      if (!mounted ||
          request != _branchRequest ||
          code != _clubCtrl.text.trim()) return;
      setState(() {
        _branches = findRecordList(response)
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
        _branchesLoadedForCode = code;
        _branchId = null;
      });
    } catch (e) {
      if (mounted && request == _branchRequest)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
    } finally {
      if (mounted && request == _branchRequest)
        setState(() => _branchesLoading = false);
    }
  }

  Future<void> _openForgotPassword() => showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
            title: const Text('Forgot password'),
            content: const Text(
                "Password resets are handled by your academy — please contact them and they'll reset it for you."),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'))
            ],
          ));

  Future<void> _signIn() async {
    if (_busy) return;
    final id = _idCtrl.text.trim();
    final pwd = _pwdCtrl.text;

    if (id.isEmpty || pwd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your ID and password.')),
      );
      return;
    }

    String? clubCode;
    int? branchId;
    if (_isInstructor) {
      clubCode = _clubCtrl.text.trim();
      if (clubCode.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter your club code.')),
        );
        return;
      }
      branchId = _branchId;
      if (branchId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select a branch.')),
        );
        return;
      }
    }

    setState(() => _busy = true);
    final ok = await UserSession.instance.login(
      username: id,
      password: pwd,
      userType: _isInstructor ? 0 : 3,
      clubCode: clubCode,
      branchId: branchId,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (ok) {
      final session = UserSession.instance;
      context.go(session.isInstructor ? '/instructor/home' : '/home');
    } else {
      final raw = UserSession.instance.error ?? 'Unknown error';
      // Strip the Dart "Exception: " prefix and our error glyphs so the
      // dialog shows the clean, user-facing message.
      final msg =
          raw.replaceFirst('Exception: ', '').replaceAll('❌', '').trim();
      await _showLoginError(msg.isEmpty ? 'Unknown error' : msg);
    }
  }

  Future<void> _showLoginError(String message) async {
    final c = context.appColors;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        icon: Icon(AppIcons.lock_outline, color: c.danger, size: 32),
        title: const Text('Sign in failed'),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final theme = context.watch<ThemeProvider>();
    return Scaffold(
        body: Stack(children: [
      Positioned(
          top: -130,
          right: -80,
          child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                  color: c.primary.withValues(alpha: c.isDark ? .22 : .18),
                  shape: BoxShape.circle))),
      Positioned(
          bottom: -80,
          left: -60,
          child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                  color: c.primaryLight.withValues(alpha: c.isDark ? .18 : .16),
                  shape: BoxShape.circle))),
      SafeArea(
          child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(kLogoAssetPath,
                              width: 42, height: 42)),
                      const SizedBox(width: 10),
                      Text('D-CLIX',
                          style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 18,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w900)),
                      const Spacer(),
                      IconButton(
                          onPressed: theme.toggle,
                          icon: Icon(theme.isDark
                              ? AppIcons.light_mode_outlined
                              : AppIcons.dark_mode_outlined)),
                      TextButton(
                          onPressed: () => context.push('/user-guide'),
                          child: const Text('Help')),
                    ]),
                    const SizedBox(height: 28),
                    Text('WELCOME BACK',
                        style: TextStyle(
                            color: c.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.5)),
                    const SizedBox(height: 10),
                    Text("Let's get you\nback on the mat.",
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: c.textPrimary,
                            letterSpacing: -.8,
                            height: 1.2)),
                    const SizedBox(height: 10),
                    Text('Sign in to continue your training journey',
                        style: TextStyle(color: c.textSecondary, fontSize: 14)),
                    const SizedBox(height: 28),
                    Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                            color: c.surfaceAlt,
                            borderRadius: BorderRadius.circular(14)),
                        child: Row(children: [
                          Expanded(
                              child: _segment(
                                  c,
                                  'Student',
                                  AppIcons.school,
                                  !_isInstructor,
                                  () => setState(() => _isInstructor = false))),
                          Expanded(
                              child: _segment(
                                  c,
                                  'Instructor',
                                  AppIcons.military_tech,
                                  _isInstructor,
                                  () => setState(() => _isInstructor = true)))
                        ])),
                    const SizedBox(height: 24),
                    if (_isInstructor) ...[
                      _fieldLabel(c, 'Club code'),
                      TextField(
                          controller: _clubCtrl,
                          textCapitalization: TextCapitalization.characters,
                          onChanged: (_) => setState(() {
                                _branchRequest++;
                                _branchId = null;
                                _branches = [];
                                _branchesLoadedForCode = null;
                                _branchesLoading = false;
                              }),
                          decoration: InputDecoration(
                              hintText: 'e.g. RTT',
                              prefixIcon:
                                  Icon(AppIcons.business, color: c.textMuted))),
                      const SizedBox(height: 18),
                      _fieldLabel(c, 'Branch'),
                      _branchDropdown(c),
                      const SizedBox(height: 18),
                    ],
                    _fieldLabel(
                        c,
                        _isInstructor
                            ? 'Instructor ID'
                            : 'Student ID, phone or email'),
                    _inputLine(c, _idCtrl, icon: AppIcons.alternate_email),
                    const SizedBox(height: 18),
                    Row(children: [
                      Expanded(child: _fieldLabel(c, 'Password')),
                      TextButton(
                          onPressed: _openForgotPassword,
                          child: const Text('Forgot password?'))
                    ]),
                    _inputLine(c, _pwdCtrl,
                        icon: AppIcons.lock_outline,
                        obscure: !_showPwd,
                        trailing: IconButton(
                            tooltip:
                                _showPwd ? 'Hide password' : 'Show password',
                            onPressed: () =>
                                setState(() => _showPwd = !_showPwd),
                            icon: Icon(_showPwd
                                ? AppIcons.visibility_off_outlined
                                : AppIcons.visibility_outlined))),
                    const SizedBox(height: 18),
                    Text("ⓘ  You'll stay signed in on this device",
                        style: TextStyle(color: c.textSecondary, fontSize: 12)),
                    const SizedBox(height: 24),
                    GradientButton(
                        label: _busy ? 'Signing In…' : 'Sign In',
                        trailingIcon: AppIcons.arrow_forward,
                        onPressed: _busy ? null : _signIn),
                    const SizedBox(height: 18),
                    Center(
                        child: TextButton.icon(
                            onPressed: () => context.push('/user-guide'),
                            icon: const Icon(AppIcons.menu_book_outlined,
                                size: 18),
                            label: const Text('How to use this app'))),
                    const SizedBox(height: 18),
                    Center(
                        child: Text('New to D-Clix? Contact your academy',
                            style: TextStyle(
                                color: c.textSecondary, fontSize: 13))),
                  ]))),
    ]));
  }

  Widget _segment(AppColors c, String label, IconData icon, bool active,
      VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
        decoration: BoxDecoration(
          gradient: active ? LinearGradient(colors: c.gradient) : null,
          color: active ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(Radii.sm),
          boxShadow: active ? Shadows.strong(c) : null,
        ),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 14, color: active ? Colors.white : c.textSecondary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: active ? Colors.white : c.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ),
            ]),
      ),
    );
  }

  Future<void> _openBranchSheet() async {
    FocusScope.of(context).unfocus();
    final code = _clubCtrl.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your club code first.')),
      );
      return;
    }
    if (_branches.isEmpty || _branchesLoadedForCode != code) {
      await _loadBranches();
    }
    if (!mounted) return;
    if (_branches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No branches found for that club code.')),
      );
      return;
    }
    String filter = '';
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final c2 = ctx.appColors;
        final screenH = MediaQuery.of(ctx).size.height;
        return StatefulBuilder(builder: (ctx, setSheetState) {
          final filtered = _branches.where((b) {
            if (filter.isEmpty) return true;
            final text = (b['text'] ?? '').toString().toLowerCase();
            return text.contains(filter.toLowerCase());
          }).toList();
          return Container(
            constraints: BoxConstraints(maxHeight: screenH * 0.75),
            decoration: BoxDecoration(
              color: c2.surface,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.fromLTRB(
                12, 12, 12, MediaQuery.of(ctx).viewInsets.bottom + 18),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                    color: c2.border, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(children: [
                  Icon(Icons.store_mall_directory_outlined,
                      color: c2.primary, size: 18),
                  const SizedBox(width: 8),
                  Text('Select Branch',
                      style: TextStyle(
                          color: c2.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16)),
                  const Spacer(),
                  Text('${filtered.length}/${_branches.length}',
                      style: TextStyle(
                          color: c2.textMuted,
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                ]),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: TextField(
                  autofocus: false,
                  onChanged: (v) => setSheetState(() => filter = v),
                  decoration: InputDecoration(
                    prefixIcon:
                        Icon(AppIcons.search, size: 18, color: c2.textMuted),
                    hintText: 'Search branch (e.g. KCP)',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Scrollbar(
                  thumbVisibility: true,
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: c2.border),
                    itemBuilder: (_, i) {
                      final b = filtered[i];
                      final id = (b['id'] as num?)?.toInt() ?? 0;
                      final text = (b['text'] ?? '').toString();
                      final selected = id == _branchId;
                      return Material(
                          color: Colors.transparent,
                          child: ListTile(
                            title: Text(text,
                                style: TextStyle(
                                    color: c2.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14)),
                            subtitle: Text('Branch #$id',
                                style: TextStyle(
                                    color: c2.textMuted,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 11)),
                            trailing: selected
                                ? Icon(AppIcons.check_circle,
                                    color: c2.primary, size: 20)
                                : Icon(AppIcons.chevron_right,
                                    color: c2.textMuted, size: 18),
                            onTap: () => Navigator.pop(ctx, id),
                          ));
                    },
                  ),
                ),
              ),
            ]),
          );
        });
      },
    );
    if (picked != null && mounted) {
      setState(() => _branchId = picked);
    }
  }

  Widget _branchDropdown(AppColors c) {
    final code = _clubCtrl.text.trim();
    final canTap = code.isNotEmpty && !_branchesLoading;
    final hasBranches = _branches.isNotEmpty;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(Radii.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: !canTap
            ? () {
                // Always give feedback even when disabled.
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_branchesLoading
                        ? 'Loading branches…'
                        : 'Enter your club code first.'),
                  ),
                );
              }
            : _openBranchSheet,
        child: AbsorbPointer(
          // Container below is decorative only — let InkWell handle taps.
          child: _branchDropdownBody(c, canTap, hasBranches, code),
        ),
      ),
    );
  }

  Widget _branchDropdownBody(
      AppColors c, bool canTap, bool hasBranches, String code) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: c.border),
      ),
      child: Row(children: [
        Icon(Icons.store_mall_directory_outlined,
            size: 18, color: canTap ? c.primary : c.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _branchesLoading
                ? 'Loading branches…'
                : _branchId != null
                    ? (_branches.firstWhere(
                                (b) => (b['id'] as num?)?.toInt() == _branchId,
                                orElse: () =>
                                    const <String, dynamic>{})['text'] ??
                            '')
                        .toString()
                    : (code.isEmpty
                        ? 'Enter club code first'
                        : (hasBranches
                            ? 'Select a branch'
                            : 'Tap to load branches')),
            style: TextStyle(
                color: c.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600),
          ),
        ),
        if (_branchesLoading)
          SizedBox(
              width: 16,
              height: 16,
              child:
                  CircularProgressIndicator(strokeWidth: 2, color: c.primary))
        else
          Icon(Icons.keyboard_arrow_down_rounded,
              color: canTap ? c.primary : c.textMuted, size: 22),
      ]),
    );
  }

  Widget _fieldLabel(AppColors c, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text,
            style: TextStyle(
                fontSize: 12,
                color: c.textSecondary,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3)),
      );

  Widget _inputLine(AppColors c, TextEditingController ctrl,
      {required IconData icon, bool obscure = false, Widget? trailing}) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      style: TextStyle(
        color: c.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        filled: false,
        border: UnderlineInputBorder(
            borderSide: BorderSide(color: c.border, width: 1.5)),
        enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: c.border, width: 1.5)),
        focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: c.primary, width: 1.5)),
        prefixIcon: Icon(icon, size: 18, color: c.textMuted),
        suffixIcon: trailing,
      ),
    );
  }
}
