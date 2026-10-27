import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_gate.dart'; // 🚀 ให้วิ่งไปเช็คสิทธิ์ที่ AuthGate เสมอ

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _supabase = Supabase.instance.client;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isLoginMode = true;

  // 📋 รายชื่อตำแหน่งให้เลือกตอนสมัคร (ต้องตรงกับ Enum ใน Supabase)
  final List<String> _roles = [
    'pm',
    'owner',
    'foreman',
    'purchasing',
    'finance',
    'staff',
  ];
  String _selectedRole = 'foreman'; // ค่าเริ่มต้น

  Future<void> _submitAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('กรุณากรอกอีเมลและรหัสผ่านให้ครบถ้วน');
      return;
    }

    if (!_isLoginMode && name.isEmpty) {
      _showError('กรุณากรอกชื่อ-นามสกุลสำหรับสมัครสมาชิก');
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLoginMode) {
        // 🟢 เข้าสู่ระบบ
        await _supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
        if (mounted) _goToAuthGate();
      } else {
        // 🔵 สมัครสมาชิกใหม่
        final AuthResponse response = await _supabase.auth.signUp(
          email: email,
          password: password,
        );
        if (response.user != null) {
          // บันทึกตำแหน่งที่เลือกลงฐานข้อมูล
          await _supabase.from('users').upsert({
            'id': response.user!.id,
            'email': email,
            'full_name': name,
            'role': _selectedRole, // 🚀 ใช้ค่าตำแหน่งที่เลือกจาก Dropdown
            'created_at': DateTime.now().toIso8601String(),
          });

          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('สมัครสมาชิกสำเร็จ!')));
            _goToAuthGate();
          }
        }
      }
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('เกิดข้อผิดพลาด: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  // 🚀 ย้ายไปหน้า AuthGate เพื่อคัดกรองตำแหน่ง (แทนการไป Dashboard ตรงๆ)
  void _goToAuthGate() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const AuthGate()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Color(0xFF4F6EF7),
                  child: Icon(Icons.handyman, color: Colors.white, size: 30),
                ),
                const SizedBox(height: 24),
                Text(
                  _isLoginMode ? 'Welcome Back' : 'Create an Account',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),

                if (!_isLoginMode) ...[
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อ-นามสกุล',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ✨ เพิ่ม Dropdown เลือกตำแหน่งงาน สำหรับตอนสมัครสมาชิก
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'ตำแหน่งงาน (Role)',
                      border: OutlineInputBorder(),
                    ),
                    items: _roles
                        .map(
                          (r) => DropdownMenuItem(
                            value: r,
                            child: Text(r.toUpperCase()),
                          ),
                        )
                        .toList(),
                    onChanged: (val) => setState(() => _selectedRole = val!),
                  ),
                  const SizedBox(height: 16),
                ],

                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),

                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitAuth,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F6EF7),
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            _isLoginMode ? 'Sign In' : 'Sign Up',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _isLoginMode = !_isLoginMode),
                  child: Text(
                    _isLoginMode
                        ? "Don't have an account? Sign Up"
                        : "Already have an account? Sign In",
                    style: const TextStyle(color: Color(0xFF4F6EF7)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
