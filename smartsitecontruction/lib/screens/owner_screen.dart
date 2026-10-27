import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'team_screen.dart';
import 'reports_screen.dart';
import 'dashboard_screen.dart';

class OwnerScreen extends StatefulWidget {
  const OwnerScreen({Key? key}) : super(key: key);
  @override
  State<OwnerScreen> createState() => _OwnerScreenState();
}

class _OwnerScreenState extends State<OwnerScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _projects = [];
  Map<String, Map<String, double>> _projectStats =
      {}; // ตัวแปรเก็บสถิติแยกรายโครงการ

  double _totalCompanyBudget = 0.0;
  double _totalCompanyCost = 0.0;
  bool _isLoading = true;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _fetchCompanyData();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        final data = await _supabase
            .from('users')
            .select('avatar_url')
            .eq('id', user.id)
            .single();
        if (mounted) setState(() => _avatarUrl = data['avatar_url']);
      } catch (e) {
        debugPrint('Error: $e');
      }
    }
  }

  Future<void> _fetchCompanyData() async {
    try {
      // 1. ดึงข้อมูลโครงการทั้งหมด
      final projectsData = await _supabase
          .from('projects')
          .select()
          .eq('status', 'active');

      // 2. ดึงข้อมูลวัสดุทั้งหมด พร้อมดึงว่าอยู่โครงการไหน (project_id)
      final boqData = await _supabase
          .from('boq_items')
          .select('project_id, budget_amount, actual_cost');

      double totalBudget = 0;
      double totalCost = 0;
      Map<String, Map<String, double>> stats = {};

      // เตรียมกล่องเก็บข้อมูลให้แต่ละโครงการ
      for (var p in projectsData) {
        stats[p['id']] = {'budget': 0.0, 'cost': 0.0};
      }

      // 3. คำนวณแยกรายโครงการ (Micro View) และ รวมทั้งบริษัท (Macro View)
      for (var item in boqData) {
        final pid = item['project_id'];
        final b = (item['budget_amount'] as num?)?.toDouble() ?? 0.0;
        final c = (item['actual_cost'] as num?)?.toDouble() ?? 0.0;

        totalBudget += b;
        totalCost += c;

        if (stats.containsKey(pid)) {
          stats[pid]!['budget'] = stats[pid]!['budget']! + b;
          stats[pid]!['cost'] = stats[pid]!['cost']! + c;
        }
      }

      if (mounted) {
        setState(() {
          _projects = List<Map<String, dynamic>>.from(projectsData);
          _totalCompanyBudget = totalBudget;
          _totalCompanyCost = totalCost;
          _projectStats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatCurrency(double amount) {
    if (amount >= 1000000) return '฿${(amount / 1000000).toStringAsFixed(2)}M';
    if (amount >= 1000) return '฿${(amount / 1000).toStringAsFixed(1)}K';
    return NumberFormat.currency(
      locale: 'th_TH',
      symbol: '฿',
      decimalDigits: 0,
    ).format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text(
          'Owner Workspace (ภาพรวมบริษัท)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1D23),
        elevation: 1,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF8A93A4)),
            onPressed: _fetchCompanyData,
          ),
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
              _fetchUserData();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: _avatarUrl != null
                    ? NetworkImage(_avatarUrl!)
                    : null,
                child: _avatarUrl == null
                    ? const Icon(Icons.person, color: Colors.grey)
                    : null,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () async {
              await _supabase.auth.signOut();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Company Financial Overview (ภาพรวมองค์กร)',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // [ข้อ 1] Macro View: รวมทั้งบริษัท
                  isDesktop
                      ? Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                title: 'งบประมาณรวมทั้งบริษัท',
                                amount: _formatCurrency(_totalCompanyBudget),
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _StatCard(
                                title: 'ต้นทุนที่ใช้ไปแล้ว',
                                amount: _formatCurrency(_totalCompanyCost),
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _StatCard(
                                title: 'งบประมานคงเหลือ',
                                amount: _formatCurrency(
                                  _totalCompanyBudget - _totalCompanyCost,
                                ),
                                color: Colors.green,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _StatCard(
                              title: 'งบประมาณรวมทั้งบริษัท',
                              amount: _formatCurrency(_totalCompanyBudget),
                              color: Colors.blue,
                            ),
                            const SizedBox(height: 12),
                            _StatCard(
                              title: 'ต้นทุนที่ใช้ไปแล้ว',
                              amount: _formatCurrency(_totalCompanyCost),
                              color: Colors.orange,
                            ),
                            const SizedBox(height: 12),
                            _StatCard(
                              title: 'งบประมานคงเหลือ',
                              amount: _formatCurrency(
                                _totalCompanyBudget - _totalCompanyCost,
                              ),
                              color: Colors.green,
                            ),
                          ],
                        ),

                  const SizedBox(height: 32),
                  const Text(
                    'Management Tools',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // [ข้อ 3] Smart Reports: เมนูออกรายงานภาพรวม
                  isDesktop
                      ? Row(
                          children: [
                            Expanded(
                              child: _MenuButton(
                                icon: Icons.people_alt_rounded,
                                title: 'จัดการทีม (Team)',
                                subtitle: 'จัดการบุคลากรทั้งหมดในบริษัท',
                                color: Colors.indigo,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TeamScreen(),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _MenuButton(
                                icon: Icons.analytics_rounded,
                                title: 'รายงานองค์กร (Company Reports)',
                                subtitle: 'ดูสรุปรายเดือน / ภาพรวมทุกโครงการ',
                                color: Colors.purple,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ReportsScreen(),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _MenuButton(
                              icon: Icons.people_alt_rounded,
                              title: 'จัดการทีม (Team)',
                              subtitle: 'จัดการบุคลากรทั้งหมดในบริษัท',
                              color: Colors.indigo,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => TeamScreen()),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _MenuButton(
                              icon: Icons.analytics_rounded,
                              title: 'รายงานองค์กร (Company Reports)',
                              subtitle: 'ดูสรุปรายเดือน / ภาพรวมทุกโครงการ',
                              color: Colors.purple,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ReportsScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),

                  const SizedBox(height: 32),
                  const Text(
                    'Active Projects (แยกรายละเอียดแต่ละโครงการ)',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  // [ข้อ 2] Micro View: แสดงสถานะและงบประมาณแยกรายโครงการ
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _projects.length,
                    itemBuilder: (context, index) {
                      final project = _projects[index];
                      final pid = project['id'];
                      final pBudget = _projectStats[pid]?['budget'] ?? 0.0;
                      final pCost = _projectStats[pid]?['cost'] ?? 0.0;
                      final pRem = pBudget - pCost;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  DashboardScreen(projectId: project['id']),
                            ),
                          ),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const CircleAvatar(
                                      backgroundColor: Color(0xFFEEF1FE),
                                      child: Icon(
                                        Icons.business,
                                        color: Color(0xFF4F6EF7),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            project['name'] ?? 'ไม่ระบุชื่อ',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const Text(
                                            'คลิกเพื่อเข้าสู่ Dashboard และดู Reports โครงการนี้',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: Colors.grey,
                                    ),
                                  ],
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Divider(height: 1),
                                ),
                                // โชว์ตัวเลขสรุปของแต่ละโครงการที่หน้าแรก
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _MiniStat(
                                      label: 'งบประมาณ',
                                      value: _formatCurrency(pBudget),
                                      color: Colors.blue,
                                    ),
                                    _MiniStat(
                                      label: 'ใช้ไปแล้ว',
                                      value: _formatCurrency(pCost),
                                      color: Colors.orange,
                                    ),
                                    _MiniStat(
                                      label: 'คงเหลือ',
                                      value: _formatCurrency(pRem),
                                      color: pRem < 0
                                          ? Colors.red
                                          : Colors.green,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

// ── Widget ย่อย ──
class _StatCard extends StatelessWidget {
  final String title, amount;
  final MaterialColor color;
  const _StatCard({
    required this.title,
    required this.amount,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.account_balance_wallet,
              color: color.shade600,
              size: 24,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            amount,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;
  const _MenuButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
