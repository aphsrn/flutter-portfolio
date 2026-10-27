import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

class StaffScreen extends StatelessWidget {
  const StaffScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text(
          'Staff Workspace',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        actions: _buildAppBarActions(context),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ประกาศจากบริษัท (Announcements)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: const ListTile(
                leading: Icon(Icons.campaign, color: Colors.blue),
                title: Text(
                  'นโยบายการเบิกจ่ายใหม่',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'อัปเดตเมื่อ: 1 ก.ค. 2026\nกรุณาอ่านและทำความเข้าใจระเบียบใหม่...',
                ),
                isThreeLine: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<Widget> _buildAppBarActions(BuildContext context) {
  return [
    IconButton(
      icon: const Icon(Icons.person),
      onPressed: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
    ),
    IconButton(
      icon: const Icon(Icons.logout, color: Colors.redAccent),
      onPressed: () async {
        await Supabase.instance.client.auth.signOut();
        if (context.mounted)
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
      },
    ),
    const SizedBox(width: 8),
  ];
}
