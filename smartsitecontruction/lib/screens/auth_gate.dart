import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';

// 🚀 นำเข้าหน้าของแต่ละตำแหน่งที่เราเพิ่งสร้าง
import 'foreman_screen.dart';
import 'pm_screen.dart';
import 'finance_screen.dart';
import 'purchasing_screen.dart';
import 'staff_screen.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    await Future.delayed(const Duration(milliseconds: 500));
    final user = _supabase.auth.currentUser;

    if (!mounted) return;

    if (user == null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    } else {
      try {
        final userData = await _supabase
            .from('users')
            .select('role')
            .eq('id', user.id)
            .maybeSingle();
        final role = userData?['role']?.toString().toLowerCase() ?? '';

        if (!mounted) return;

        final String dummyProjectId = '00000000-0000-0000-0000-000000000000';

        // 🧭 แยกเส้นทางตามตำแหน่ง (กระจายคนไปตามหน้างานของตัวเอง)
        if (role == 'owner') {
          // เจ้าของ เข้า Dashboard
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => DashboardScreen(projectId: dummyProjectId),
            ),
          );
        } else if (role == 'pm') {
          // PM เข้าหน้า PM
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const PMScreen()),
          );
        } else if (role == 'foreman') {
          // โฟร์แมน เข้าหน้า โฟร์แมน
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const ForemanScreen()),
          );
        } else if (role == 'finance') {
          // การเงิน เข้าหน้า การเงิน
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const FinanceScreen()),
          );
        } else if (role == 'purchasing') {
          // จัดซื้อ เข้าหน้า จัดซื้อ
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const PurchasingScreen()),
          );
        } else {
          // พนักงานทั่วไป
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const StaffScreen()),
          );
        }
      } catch (e) {
        await _supabase.auth.signOut();
        if (mounted)
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1A1D23),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Color(0xFF4F6EF7),
              child: Icon(Icons.handyman, color: Colors.white, size: 40),
            ),
            SizedBox(height: 24),
            CircularProgressIndicator(color: Color(0xFF4F6EF7)),
            SizedBox(height: 16),
            Text(
              'กำลังตรวจสอบสิทธิ์...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
