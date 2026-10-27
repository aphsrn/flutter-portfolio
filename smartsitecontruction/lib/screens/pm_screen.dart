import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'dashboard_screen.dart'; // 🚀 นำเข้าหน้า Dashboard จัดเต็มที่เราสร้างไว้

class PMScreen extends StatefulWidget {
  const PMScreen({Key? key}) : super(key: key);

  @override
  State<PMScreen> createState() => _PMScreenState();
}

class _PMScreenState extends State<PMScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _projects = [];
  bool _isLoading = true;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _fetchProjects();
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
        setState(() => _avatarUrl = data['avatar_url']);
      } catch (e) {
        debugPrint('Error fetching user data: $e');
      }
    }
  }

  Future<void> _fetchProjects() async {
    try {
      final data = await _supabase
          .from('projects')
          .select()
          .eq('status', 'active');
      setState(() {
        _projects = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text(
          'PM Workspace',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1D23),
        elevation: 1,
        actions: [
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
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'เลือกโครงการเพื่อจัดการ (Select Project)',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1A1D23),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'คลิกที่การ์ดโครงการเพื่อเข้าสู่หน้ารายละเอียด งบประมาณ และการอนุมัติ',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 24),

                  if (_projects.isEmpty)
                    const Expanded(
                      child: Center(
                        child: Text(
                          'ไม่พบโครงการที่กำลังดำเนินการ',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      // 🚀 เปลี่ยนจาก GridView เป็น ListView เพื่อให้รองรับหน้าจอมือถือได้สมบูรณ์ ไม่ล้นจอ
                      child: ListView.separated(
                        itemCount: _projects.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final project = _projects[index];
                          return InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      DashboardScreen(projectId: project['id']),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
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
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEEF1FE),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.business,
                                      color: Color(0xFF4F6EF7),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          project['name'] ?? 'ไม่ระบุชื่อ',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Color(0xFF1A1D23),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          'สถานะ: กำลังก่อสร้าง',
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.grey,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
