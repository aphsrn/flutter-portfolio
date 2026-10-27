import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'settings_screen.dart';

class PurchasingScreen extends StatelessWidget {
  const PurchasingScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text(
          'Purchasing Workspace',
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
              'รายการรอสั่งซื้อ (Approved for PO)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  _buildPurchaseCard(
                    context,
                    'ปูนซีเมนต์ 50 ถุง',
                    'โครงการ A - อนุมัติแล้วโดย PM',
                  ),
                  _buildPurchaseCard(
                    context,
                    'กระเบื้องปูพื้น 20 กล่อง',
                    'โครงการ B - อนุมัติแล้วโดย PM',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchaseCard(
    BuildContext context,
    String title,
    String subtitle,
  ) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFF3E5F5),
          child: Icon(Icons.shopping_cart, color: Colors.purple),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
          ),
          child: const Text('ออกใบ PO'),
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
