import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
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
  bool _showPwd = false;
  bool _isInstructor = false;
  bool _remember = true;
  bool _busy = false;

  Future<void> _signIn() async {
    final id = _idCtrl.text.trim();
    final pwd = _pwdCtrl.text;

    if (id.isEmpty || pwd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your ID and password.')),
      );
      return;
    }

    setState(() => _busy = true);
    final ok = await UserSession.instance.login(
      username: id,
      password: pwd,
      userType: _isInstructor ? 2 : 3,
    );
    if (!mounted) return;
    setState(() => _busy = false);

    if (ok) {
      context.go('/home');
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
                        Row(children: [
                          Expanded(
                              child: _chip(
                                  c,
                                  'Student',
                                  Icons.school,
                                  !_isInstructor,
                                  () => setState(() => _isInstructor = false))),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _chip(
                                  c,
                                  'Instructor',
                                  Icons.workspace_premium,
                                  _isInstructor,
                                  () => setState(() => _isInstructor = true))),
                        ]),
                        const SizedBox(height: 22),
                        _fieldLabel(
                            c,
                            _isInstructor
                                ? 'Instructor ID, phone or email'
                                : 'Student ID, phone or email'),
                        _inputLine(c, _idCtrl, icon: Icons.alternate_email),
                        const SizedBox(height: 22),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _fieldLabel(c, 'Password'),
                            InkWell(
                              onTap: () {},
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(children: [
                    Expanded(child: Container(height: 1, color: c.border)),
                    const SizedBox(width: 10),
                    Text('or continue with',
                        style: TextStyle(
                            color: c.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5)),
                    const SizedBox(width: 10),
                    Expanded(child: Container(height: 1, color: c.border)),
                  ]),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(child: _altBtn(c, Icons.qr_code_2, 'Academy QR')),
                    const SizedBox(width: 12),
                    Expanded(child: _altBtn(c, Icons.fingerprint, 'Biometric')),
                  ]),
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

  Widget _chip(AppColors c, String label, IconData icon, bool active,
      VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: active ? LinearGradient(colors: c.gradient) : null,
          color: active ? null : c.surfaceAlt,
          borderRadius: BorderRadius.circular(Radii.md),
          border: active ? null : Border.all(color: c.border),
          boxShadow: active ? Shadows.strong(c) : null,
        ),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 15, color: active ? Colors.white : c.textSecondary),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: active ? Colors.white : c.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
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

  Widget _altBtn(AppColors c, IconData icon, String label) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(Radii.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: c.border),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 20, color: c.primary),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: c.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
        ]),
      ),
    );
  }
}
