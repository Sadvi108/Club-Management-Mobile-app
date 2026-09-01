import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/theme_provider.dart';
import '../widgets/gradient_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _idCtrl = TextEditingController(text: 'SA-2026-0142');
  final _pwdCtrl = TextEditingController(text: 'demo1234');
  bool _showPwd = false;
  bool _isInstructor = false;
  bool _remember = true;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final theme = context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: c.background,
      body: Stack(
        children: [
          Positioned(
            top: -130, right: -80,
            child: Container(
              width: 280, height: 280,
              decoration: BoxDecoration(
                color: c.primary.withOpacity(c.isDark ? 0.22 : 0.18),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -80, left: -60,
            child: Container(
              width: 220, height: 220,
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
                        width: 38, height: 38,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Colors.white),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset(kLogoAssetPath, fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('D-CLIX', style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w900, letterSpacing: 3, fontSize: 14)),
                      const Spacer(),
                      InkWell(
                        onTap: theme.toggle,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(10)),
                          child: Icon(theme.isDark ? Icons.light_mode : Icons.dark_mode, size: 16, color: c.primary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),
                  Text('WELCOME BACK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: c.primary, letterSpacing: 2.5)),
                  const SizedBox(height: 10),
                  Text("Let's get you\nback on the mat.",
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: c.textPrimary, letterSpacing: -0.8, height: 1.2)),
                  const SizedBox(height: 10),
                  Text('Sign in to continue your training journey',
                      style: TextStyle(color: c.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 32),
                  Row(children: [
                    Expanded(child: _chip(c, 'Student', Icons.school, !_isInstructor, () => setState(() => _isInstructor = false))),
                    const SizedBox(width: 10),
                    Expanded(child: _chip(c, 'Instructor', Icons.workspace_premium, _isInstructor, () => setState(() => _isInstructor = true))),
                  ]),
                  const SizedBox(height: 24),
                  _fieldLabel(c, _isInstructor ? 'Instructor ID, phone or email' : 'Student ID, phone or email'),
                  _inputLine(c, _idCtrl, icon: Icons.alternate_email),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _fieldLabel(c, 'Password'),
                      InkWell(onTap: () {}, child: Text('Forgot?', style: TextStyle(color: c.primary, fontSize: 12, fontWeight: FontWeight.w700))),
                    ],
                  ),
                  _inputLine(
                    c,
                    _pwdCtrl,
                    icon: Icons.lock_outline,
                    obscure: !_showPwd,
                    trailing: IconButton(
                      icon: Icon(_showPwd ? Icons.visibility_off : Icons.visibility, size: 18, color: c.textSecondary),
                      onPressed: () => setState(() => _showPwd = !_showPwd),
                    ),
                  ),
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: () => setState(() => _remember = !_remember),
                    child: Row(children: [
                      Container(
                        width: 18, height: 18,
                        decoration: BoxDecoration(color: _remember ? c.primary : c.border, borderRadius: BorderRadius.circular(5)),
                        child: _remember ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
                      ),
                      const SizedBox(width: 8),
                      Text('Keep me signed in', style: TextStyle(color: c.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                  const SizedBox(height: 28),
                  GradientButton(
                    label: 'Sign In',
                    trailingIcon: Icons.arrow_forward,
                    onPressed: () => context.go('/home'),
                  ),
                  const SizedBox(height: 22),
                  Row(children: [
                    Expanded(child: Container(height: 1, color: c.border)),
                    const SizedBox(width: 10),
                    Text('or continue with', style: TextStyle(color: c.textMuted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
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
                          TextSpan(text: 'Contact your academy', style: TextStyle(color: c.primary, fontWeight: FontWeight.w800)),
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

  Widget _chip(AppColors c, String label, IconData icon, bool active, VoidCallback onTap) {
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
        child: Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: active ? Colors.white : c.textSecondary),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: active ? Colors.white : c.textSecondary, fontWeight: FontWeight.w700, fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _fieldLabel(AppColors c, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: TextStyle(fontSize: 12, color: c.textSecondary, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
      );

  Widget _inputLine(AppColors c, TextEditingController ctrl, {required IconData icon, bool obscure = false, Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border, width: 1.5))),
      child: Row(children: [
        Icon(icon, size: 18, color: c.textMuted),
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: ctrl,
            obscureText: obscure,
            style: TextStyle(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(border: InputBorder.none, isDense: true),
          ),
        ),
        if (trailing != null) trailing,
      ]),
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
          Text(label, style: TextStyle(color: c.textPrimary, fontWeight: FontWeight.w700, fontSize: 13)),
        ]),
      ),
    );
  }
}
