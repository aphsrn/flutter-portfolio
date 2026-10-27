import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RequestsScreen extends StatefulWidget {
  final String? projectId; // รองรับทั้งดูแบบแยกโครงการ หรือดูภาพรวมบริษัท
  const RequestsScreen({super.key, this.projectId});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    try {
      var query = _supabase
          .from('material_requests')
          .select('*, projects(name)')
          .order('created_at', ascending: false);

      // ถ้าส่ง projectId มา ให้กรองเฉพาะโครงการนั้น (สำหรับ PM)
      if (widget.projectId != null) {
        query = _supabase
            .from('material_requests')
            .select('*, projects(name)')
            .eq('project_id', widget.projectId!)
            .order('created_at', ascending: false);
      }

      final data = await query;
      if (mounted) {
        setState(() {
          _requests = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching requests: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Material Requests (รายการขอเบิกวัสดุ)',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Container(
                      width: double.infinity,
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
                      child: _requests.isEmpty
                          ? const Center(
                              child: Text(
                                'ยังไม่มีประวัติการขอเบิกวัสดุ',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: SingleChildScrollView(
                                scrollDirection: Axis.vertical,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(
                                      const Color(0xFFF8F9FC),
                                    ),
                                    columns: const [
                                      DataColumn(
                                        label: Text(
                                          'โครงการ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'รายการวัสดุ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'จำนวนที่ขอ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'สถานะ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                    rows: _requests.map((req) {
                                      final projectName =
                                          req['projects']?['name'] ??
                                          'ไม่ระบุโครงการ';
                                      final itemName = req['item_name'] ?? '-';
                                      final qty =
                                          req['requested_qty']?.toString() ??
                                          '0';
                                      final status = req['status'] ?? 'pending';

                                      Color statusColor = Colors.orange;
                                      if (status == 'approved')
                                        statusColor = Colors.green;
                                      if (status == 'rejected')
                                        statusColor = Colors.red;

                                      return DataRow(
                                        cells: [
                                          DataCell(Text(projectName)),
                                          DataCell(Text(itemName)),
                                          DataCell(Text(qty)),
                                          DataCell(
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: statusColor.withOpacity(
                                                  0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                status.toUpperCase(),
                                                style: TextStyle(
                                                  color: statusColor,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
