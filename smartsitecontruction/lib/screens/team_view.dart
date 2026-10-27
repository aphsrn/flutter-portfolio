import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeamView extends StatefulWidget {
  const TeamView({Key? key}) : super(key: key);

  @override
  State<TeamView> createState() => _TeamViewState();
}

class _TeamViewState extends State<TeamView> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _teamMembers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTeam();
  }

  Future<void> _fetchTeam() async {
    try {
      // 🚀 ดึงข้อมูลรายชื่อพนักงานทั้งหมดจากตาราง users
      final data = await _supabase.from('users').select().order('role');
      setState(() {
        _teamMembers = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching team: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_teamMembers.isEmpty) {
      return const Center(child: Text('ยังไม่มีข้อมูลทีมงานในระบบ'));
    }

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'รายชื่อทีมงานทั้งหมด (Team Members)',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'ข้อมูลบุคลากรทั้งหมดที่อยู่ในระบบ Smart Site',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),

          Expanded(
            child: ListView.builder(
              itemCount: _teamMembers.length,
              itemBuilder: (context, index) {
                final member = _teamMembers[index];
                final role = (member['role'] ?? 'No Role')
                    .toString()
                    .toUpperCase();
                final name = member['full_name']?.toString() ?? 'ไม่มีชื่อ';
                final email = member['email']?.toString() ?? '-';
                final phone = member['phone']?.toString() ?? '-';

                // ดึงตัวอักษรตัวแรกของชื่อมาทำเป็นรูปโปรไฟล์ชั่วคราว
                final initial = name.isNotEmpty
                    ? name.substring(0, 1).toUpperCase()
                    : '?';

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: const Color(0xFFE8EEFF),
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: Color(0xFF4F6EF7),
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.email,
                                size: 14,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(email),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.phone,
                                size: 14,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(phone),
                            ],
                          ),
                        ],
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        role,
                        style: const TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
