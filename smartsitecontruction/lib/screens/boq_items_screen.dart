import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BoqItemsScreen extends StatefulWidget {
  final String projectId;
  const BoqItemsScreen({super.key, required this.projectId});

  @override
  State<BoqItemsScreen> createState() => _BoqItemsScreenState();
}

class _BoqItemsScreenState extends State<BoqItemsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBOQ();
  }

  Future<void> _fetchBOQ() async {
    try {
      final data = await _supabase
          .from('boq_items')
          .select()
          .eq('project_id', widget.projectId)
          .order('name');
      setState(() {
        _items = List<Map<String, dynamic>>.from(data);
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
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'BOQ Items (รายการวัสดุและงบประมาณ)',
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
                      child: _items.isEmpty
                          ? const Center(
                              child: Text(
                                'ไม่มีข้อมูล BOQ สำหรับโครงการนี้',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              // 🚀 เปิดระบบเลื่อนดูได้ทั้ง แนวตั้ง และ แนวนอน รองรับจอมือถือและจอเล็ก
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
                                          'Item Name',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Category',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Budget (฿)',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Actual Cost (฿)',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Text(
                                          'Remaining (฿)',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                    rows: _items.map((item) {
                                      final budget =
                                          (item['budget_amount'] as num?)
                                              ?.toDouble() ??
                                          0.0;
                                      final cost =
                                          (item['actual_cost'] as num?)
                                              ?.toDouble() ??
                                          0.0;
                                      final remaining = budget - cost;

                                      return DataRow(
                                        cells: [
                                          DataCell(Text(item['name'] ?? '-')),
                                          DataCell(
                                            Text(item['category'] ?? '-'),
                                          ),
                                          DataCell(
                                            Text(budget.toStringAsFixed(2)),
                                          ),
                                          DataCell(
                                            Text(
                                              cost.toStringAsFixed(2),
                                              style: TextStyle(
                                                color: cost > budget
                                                    ? Colors.red
                                                    : Colors.black,
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Text(
                                              remaining.toStringAsFixed(2),
                                              style: TextStyle(
                                                color: remaining < 0
                                                    ? Colors.red
                                                    : Colors.green,
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
