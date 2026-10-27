// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart'; // supabase, AppColors, globalLanguage

// ====== ข้อความ 2 ภาษา (ภาษาอื่นใช้ EN สำรอง) ======
const Map<String, Map<String, String>> _t = {
  'th': {
    'subtitle': 'ระบบจัดซื้อและควบคุมงบประมาณ',
    'login': 'เข้าสู่ระบบ',
    'register': 'สมัครสมาชิก',
    'name': 'ชื่อ-นามสกุล',
    'email': 'อีเมล',
    'password': 'รหัสผ่าน',
    'confirm': 'ยืนยันรหัสผ่าน',
    'nameRequired': 'กรุณากรอกชื่อ',
    'emailInvalid': 'รูปแบบอีเมลไม่ถูกต้อง',
    'passShort': 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร',
    'passMismatch': 'รหัสผ่านไม่ตรงกัน',
    'toRegister': 'ยังไม่มีบัญชี? สมัครสมาชิก',
    'toLogin': 'มีบัญชีแล้ว? เข้าสู่ระบบ',
    'registerConfirm':
        'สมัครสำเร็จ กรุณายืนยันอีเมลของคุณ แล้วกลับมาเข้าสู่ระบบ',
    'errInvalid': 'อีเมลหรือรหัสผ่านไม่ถูกต้อง',
    'errNotConfirmed': 'อีเมลนี้ยังไม่ได้ยืนยัน กรุณาตรวจสอบกล่องจดหมาย',
    'errExists': 'อีเมลนี้ถูกใช้สมัครแล้ว',
    'errWeak': 'รหัสผ่านไม่ปลอดภัยพอ',
    'errRate': 'ส่งคำขอบ่อยเกินไป กรุณารอสักครู่แล้วลองใหม่',
    'errUnknown': 'เกิดข้อผิดพลาด',
  },
  'en': {
    'subtitle': 'Procurement & Cost Control System',
    'login': 'Sign in',
    'register': 'Create account',
    'name': 'Full name',
    'email': 'Email',
    'password': 'Password',
    'confirm': 'Confirm password',
    'nameRequired': 'Please enter your name',
    'emailInvalid': 'Invalid email format',
    'passShort': 'Password must be at least 6 characters',
    'passMismatch': 'Passwords do not match',
    'toRegister': "Don't have an account? Register",
    'toLogin': 'Already have an account? Sign in',
    'registerConfirm':
        'Account created. Please confirm your email, then sign in.',
    'errInvalid': 'Invalid email or password',
    'errNotConfirmed': 'Email not confirmed yet. Please check your inbox.',
    'errExists': 'This email is already registered',
    'errWeak': 'Password is too weak',
    'errRate': 'Too many requests. Please wait and try again',
    'errUnknown': 'Something went wrong',
  },
};

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _isRegister = false;
  bool _loading = false;
  bool _obscure = true;
  String? _error;
  String? _info;

  String tr(String k) {
    final lang = globalLanguage.value;
    return _t[lang]?[k] ?? _t['en']![k] ?? k;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // แปลข้อความ Error ของ Supabase Auth เป็นข้อความที่อ่านง่าย
  String _mapError(String msg) {
    final m = msg.toLowerCase();
    if (m.contains('invalid login')) return tr('errInvalid');
    if (m.contains('not confirmed')) return tr('errNotConfirmed');
    if (m.contains('already registered') ||
        m.contains('already been registered')) {
      return tr('errExists');
    }
    if (m.contains('password') && m.contains('characters')) {
      return tr('errWeak');
    }
    if (m.contains('rate limit')) return tr('errRate');
    return msg;
  }

  void _toggleMode() {
    setState(() {
      _isRegister = !_isRegister;
      _error = null;
      _info = null;
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;

    try {
      if (_isRegister) {
        // full_name ถูกส่งไปกับ metadata เพื่อให้ Trigger สร้างแถวใน profiles
        final res = await supabase.auth.signUp(
          email: email,
          password: pass,
          data: {'full_name': _nameCtrl.text.trim()},
        );
        // ถ้ามี session แล้ว Auth Gate ใน main.dart จะพาเข้าแอปเอง
        // ถ้าไม่มี = เปิด Confirm email อยู่ ต้องยืนยันอีเมลก่อน
        if (res.session == null && mounted) {
          setState(() {
            _isRegister = false;
            _info = tr('registerConfirm');
          });
        }
      } else {
        await supabase.auth.signInWithPassword(email: email, password: pass);
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = _mapError(e.message));
    } catch (e) {
      if (mounted) setState(() => _error = '${tr('errUnknown')}: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ครอบด้วย ValueListenableBuilder เพื่อให้สลับภาษาแล้วเปลี่ยนทันที
    return ValueListenableBuilder<String>(
      valueListenable: globalLanguage,
      builder: (context, lang, _) {
        return Scaffold(
          body: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.navyDark, AppColors.navyLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  // ปุ่มสลับภาษา TH / EN
                  Positioned(
                    top: 8,
                    right: 12,
                    child: SegmentedButton<String>(
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                        backgroundColor: Colors.white12,
                        foregroundColor: Colors.white70,
                        selectedBackgroundColor: Colors.white,
                        selectedForegroundColor: AppColors.navy,
                        visualDensity: VisualDensity.compact,
                      ),
                      segments: const [
                        ButtonSegment(value: 'th', label: Text('TH')),
                        ButtonSegment(value: 'en', label: Text('EN')),
                      ],
                      selected: {lang == 'th' ? 'th' : 'en'},
                      onSelectionChanged: (s) =>
                          globalLanguage.value = s.first,
                    ),
                  ),
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildHeader(),
                            const SizedBox(height: 24),
                            _buildFormCard(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() => Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.white12,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.receipt_long,
                size: 40, color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text(
            'QuickPO & Cost Tracker',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            tr('subtitle'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      );

  Widget _buildFormCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isRegister ? tr('register') : tr('login'),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              if (_info != null) _banner(_info!, AppColors.success),
              if (_error != null) _banner(_error!, AppColors.danger),
              if (_isRegister) ...[
                TextFormField(
                  controller: _nameCtrl,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                  decoration: InputDecoration(
                    labelText: tr('name'),
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? tr('nameRequired')
                      : null,
                ),
                const SizedBox(height: 14),
              ],
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(
                  labelText: tr('email'),
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
                validator: (v) {
                  final s = (v ?? '').trim();
                  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)
                      ? null
                      : tr('emailInvalid');
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passCtrl,
                obscureText: _obscure,
                textInputAction:
                    _isRegister ? TextInputAction.next : TextInputAction.done,
                autofillHints: [
                  _isRegister
                      ? AutofillHints.newPassword
                      : AutofillHints.password
                ],
                onFieldSubmitted: (_) {
                  if (!_isRegister && !_loading) _submit();
                },
                decoration: InputDecoration(
                  labelText: tr('password'),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.length < 6) ? tr('passShort') : null,
              ),
              if (_isRegister) ...[
                const SizedBox(height: 14),
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) {
                    if (!_loading) _submit();
                  },
                  decoration: InputDecoration(
                    labelText: tr('confirm'),
                    prefixIcon: const Icon(Icons.lock_reset),
                  ),
                  validator: (v) =>
                      v != _passCtrl.text ? tr('passMismatch') : null,
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_isRegister ? tr('register') : tr('login')),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loading ? null : _toggleMode,
                child: Text(_isRegister ? tr('toLogin') : tr('toRegister')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _banner(String text, Color color) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              color == AppColors.danger
                  ? Icons.error_outline
                  : Icons.check_circle_outline,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text, style: TextStyle(fontSize: 13, color: color)),
            ),
          ],
        ),
      );
}
