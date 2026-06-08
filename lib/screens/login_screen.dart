import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../services/api.dart';
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
  bool _remember = true;
  bool _busy = false;

  // Instructor mode: branch dropdown state.
  List<Map<String, dynamic>> _branches = const [];
  int? _branchId;
  bool _branchesLoading = false;
  String? _branchesLoadedForCode;

  @override
  void dispose() {
    _idCtrl.dispose();
    _pwdCtrl.dispose();
    _clubCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBranches() async {
    final code = _clubCtrl.text.trim();
    if (code.length < 2) return;
    if (_branchesLoading) return;
    if (_branchesLoadedForCode == code && _branches.isNotEmpty) return;
    setState(() {
      _branchesLoading = true;
    });
    try {
      final resp = await Api.accountGetBranchesByClubCode(code);
      final list = (resp is List)
          ? resp
          : (resp is Map && resp['data'] is List ? resp['data'] as List : const []);
      _branches = list
          .whereType<Map>()
          .map<Map<String, dynamic>>((m) => Map<String, dynamic>.from(m))
          .toList();
      _branchesLoadedForCode = code;
      _branchId = null;
    } catch (e) {
      debugPrint('GetBranchesByClubCode failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load branches: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _branchesLoading = false);
    }
  }

  Future<void> _openForgotPassword() async {
    final ctrl = TextEditingController(text: _idCtrl.text.trim());
    final c = context.appColors;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Forgot password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your username to receive a reset link.',
              style: TextStyle(fontSize: 12, color: c.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(labelText: 'Username'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final value = ctrl.text.trim();
              if (value.isEmpty) return;
              try {
                final resp = await Api.accountForgotPassword(<String, dynamic>{
                  'username': value,
                  'userType': _isInstructor ? 0 : 3,
                });
                final msg = (resp is Map
                        ? (resp['message'] ?? resp['data'] ?? 'Reset request sent')
                        : 'Reset request sent')
                    .toString();
                if (!mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(msg)),
                );
              } catch (e) {
                debugPrint('ForgotPassword failed: $e');
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed: $e')),
                );
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  Future<void> _signIn() async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Login failed: ${UserSession.instance.error ?? 'Unknown error'}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final theme = context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: c.background,
      body: Stack(
        children: [
          Positioned(
            top: -130,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                color: c.primary.withOpacity(c.isDark ? 0.22 : 0.18),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -60,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                color: c.primaryLight.withOpacity(c.isDark ? 0.18 : 0.16),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Gaps.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Colors.white),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(kLogoAssetPath, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('D-CLIX',
                          style: TextStyle(
                              color: c.textPrimary,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 3,
                              fontSize: 14)),
                      const Spacer(),
                      InkWell(
                        onTap: theme.toggle,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                              color: c.surfaceAlt,
                              borderRadius: BorderRadius.circular(10)),
                          child: Icon(
                              theme.isDark ? Icons.light_mode : Icons.dark_mode,
                              size: 16,
                              color: c.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                  Text('WELCOME BACK',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: c.primary,
                          letterSpacing: 2.5)),
                  const SizedBox(height: 10),
                  Text("Let's get you\nback on the mat.",
                      style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: c.textPrimary,
                          letterSpacing: -0.8,
                          height: 1.2)),
                  const SizedBox(height: 10),
                  Text('Sign in to continue your training journey',
                      style: TextStyle(
                          color: c.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(Radii.xxl),
                      border: c.isDark ? Border.all(color: c.border) : null,
                      boxShadow: Shadows.card(c),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Segmented role toggle.
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: c.surfaceAlt,
                            borderRadius: BorderRadius.circular(Radii.md),
                            border: Border.all(color: c.border),
                          ),
                          child: Row(children: [
                            Expanded(
                              child: _segment(
                                c,
                                'Student / Parent Login',
                                Icons.school,
                                !_isInstructor,
                                () => setState(() => _isInstructor = false),
                              ),
                            ),
                            Expanded(
                              child: _segment(
                                c,
                                'Instructor',
                                Icons.workspace_premium,
                                _isInstructor,
                                () => setState(() => _isInstructor = true),
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 22),
                        if (_isInstructor) ...[
                          _fieldLabel(c, 'Club Code'),
                          TextField(
                            controller: _clubCtrl,
                            textCapitalization: TextCapitalization.characters,
                            onChanged: (_) {
                              final code = _clubCtrl.text.trim();
                              // Invalidate previously loaded branches when code changes.
                              if (_branchesLoadedForCode != null &&
                                  _branchesLoadedForCode != code) {
                                setState(() {
                                  _branches = const [];
                                  _branchId = null;
                                  _branchesLoadedForCode = null;
                                });
                              }
                              // Auto-fetch branches as soon as the user has typed
                              // a 2+ char club code, so the dropdown is ready.
                              if (code.length >= 2 &&
                                  !_branchesLoading &&
                                  _branchesLoadedForCode != code) {
                                _loadBranches();
                              }
                            },
                            onSubmitted: (_) => _loadBranches(),
                            style: TextStyle(
                              color: c.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              prefixIcon:
                                  Icon(Icons.search, size: 18, color: c.textMuted),
                              hintText: 'Enter club code (e.g. RTT)',
                            ),
                          ),
                          const SizedBox(height: 18),
                          _fieldLabel(c, 'Branch'),
                          _branchDropdown(c),
                          const SizedBox(height: 22),
                        ],
                        _fieldLabel(
                            c,
                            _isInstructor
                                ? 'Email / User Id'
                                : 'Student ID, phone or email'),
                        _inputLine(c, _idCtrl,
                            icon: _isInstructor
                                ? Icons.person_outline
                                : Icons.alternate_email),
                        const SizedBox(height: 22),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _fieldLabel(c, 'Password'),
                            InkWell(
                              onTap: _openForgotPassword,
                              child: Text('Forgot?',
                                  style: TextStyle(
                                      color: c.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ),
                        _inputLine(
                          c,
                          _pwdCtrl,
                          icon: Icons.lock_outline,
                          obscure: !_showPwd,
                          trailing: IconButton(
                            icon: Icon(
                                _showPwd
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                size: 18,
                                color: c.textSecondary),
                            onPressed: () =>
                                setState(() => _showPwd = !_showPwd),
                          ),
                        ),
                        const SizedBox(height: 18),
                        InkWell(
                          onTap: () => setState(() => _remember = !_remember),
                          child: Row(children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                  color: _remember ? c.primary : c.border,
                                  borderRadius: BorderRadius.circular(5)),
                              child: _remember
                                  ? const Icon(Icons.check,
                                      size: 12, color: Colors.white)
                                  : null,
                            ),
                            const SizedBox(width: 8),
                            Text('Keep me signed in',
                                style: TextStyle(
                                    color: c.textSecondary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ]),
                        ),
                        const SizedBox(height: 20),
                        GradientButton(
                          label: _busy ? 'Signing In…' : 'Sign In',
                          trailingIcon: Icons.arrow_forward,
                          onPressed: _busy ? null : () => _signIn(),
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: TextButton(
                            onPressed: _openForgotPassword,
                            child: Text(
                              'Forgot password?',
                              style: TextStyle(
                                color: c.primary,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Center(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(color: c.textSecondary, fontSize: 13),
                        children: [
                          const TextSpan(text: 'New to D-Clix? '),
                          TextSpan(
                              text: 'Contact your academy',
                              style: TextStyle(
                                  color: c.primary,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
    final code = _clubCtrl.text.trim();
    if (code.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your club code first.')),
      );
      return;
    }
    if (_branches.isEmpty) {
      await _loadBranches();
    }
    if (!mounted) return;
    if (_branches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No branches found for that club code.')),
      );
      return;
    }
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final c2 = ctx.appColors;
        final screenH = MediaQuery.of(ctx).size.height;
        return StatefulBuilder(builder: (ctx, setSheetState) {
          String filter = '';
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
                        Icon(Icons.search, size: 18, color: c2.textMuted),
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
                      return ListTile(
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
                            ? Icon(Icons.check_circle,
                                color: c2.primary, size: 20)
                            : Icon(Icons.chevron_right,
                                color: c2.textMuted, size: 18),
                        onTap: () => Navigator.pop(ctx, id),
                      );
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
    final canTap = code.length >= 2 && !_branchesLoading;
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
        color: c.isDark ? c.surfaceAlt : const Color(0xFFF8FAFC),
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
                            orElse: () => const <String, dynamic>{})['text'] ??
                            '')
                        .toString()
                    : (code.length < 2
                        ? 'Enter club code first'
                        : (hasBranches ? 'Select a branch' : 'Tap to load branches')),
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
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: c.primary))
        else
          Icon(Icons.keyboard_arrow_down_rounded,
              color: canTap ? c.primary : c.textMuted, size: 22),
      ]),
    );
  }

  // OLD inline implementation below kept disabled so old code can be safely removed.
  // ignore: unused_element
  Widget _branchDropdownLegacy(AppColors c) {
    final code = _clubCtrl.text.trim();
    final canTap = code.length >= 2 && !_branchesLoading;
    final hasBranches = _branches.isNotEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.md),
      onTap: !canTap
          ? null
          : () async {
              if (!hasBranches) {
                await _loadBranches();
              }
              if (!mounted || _branches.isEmpty) return;
              final picked = await showModalBottomSheet<int>(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (ctx) {
                  final c2 = ctx.appColors;
                  return Container(
                    decoration: BoxDecoration(
                      color: c2.surface,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28)),
                    ),
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                            color: c2.border,
                            borderRadius: BorderRadius.circular(2)),
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
                        ]),
                      ),
                      const SizedBox(height: 10),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 360),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _branches.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: c2.border),
                          itemBuilder: (_, i) {
                            final b = _branches[i];
                            final id = (b['id'] as num?)?.toInt() ?? 0;
                            final text = (b['text'] ?? '').toString();
                            final selected = id == _branchId;
                            return ListTile(
                              title: Text(text,
                                  style: TextStyle(
                                      color: c2.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14)),
                              trailing: selected
                                  ? Icon(Icons.check_circle,
                                      color: c2.primary, size: 20)
                                  : null,
                              onTap: () => Navigator.pop(ctx, id),
                            );
                          },
                        ),
                      ),
                    ]),
                  );
                },
              );
              if (picked != null) {
                setState(() => _branchId = picked);
              }
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: c.isDark ? c.surfaceAlt : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: c.border),
        ),
        child: Row(children: [
          Icon(Icons.store_mall_directory_outlined,
              size: 18,
              color: canTap ? c.primary : c.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _branchesLoading
                  ? 'Loading branches…'
                  : _branchId != null
                      ? (_branches.firstWhere(
                          (b) => (b['id'] as num?)?.toInt() == _branchId,
                          orElse: () => const <String, dynamic>{})['text'] ??
                              '')
                          .toString()
                      : (code.length < 2
                          ? 'Enter club code first'
                          : (hasBranches
                              ? 'Select a branch'
                              : 'Tap to load branches')),
              style: TextStyle(
                color: _branchId != null ? c.textPrimary : c.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (_branchesLoading)
            SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: c.primary))
          else
            Icon(Icons.keyboard_arrow_down,
                color: canTap ? c.textPrimary : c.textMuted, size: 20),
        ]),
      ),
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
        prefixIcon: Icon(icon, size: 18, color: c.textMuted),
        suffixIcon: trailing,
      ),
    );
  }

}
