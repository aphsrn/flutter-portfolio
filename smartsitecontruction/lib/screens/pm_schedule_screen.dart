import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class PmScheduleScreen extends StatefulWidget {
  final String projectId;
  const PmScheduleScreen({super.key, required this.projectId});

  @override
  State<PmScheduleScreen> createState() => _PmScheduleScreenState();
}

class _PmScheduleScreenState extends State<PmScheduleScreen> {
  final _supabase = Supabase.instance.client;

  static const _primary = Color(0xFF4F6EF7);
  static const _textDark = Color(0xFF1A1D23);
  static const _textMuted = Color(0xFF8A93A4);

  Future<void> _showAddTaskDialog() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    DateTime? selectedDate = DateTime.now();
    bool isSubmitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text(
              'สร้างตารางงานใหม่',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ชื่องาน:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      hintText: 'เช่น ติดตั้งโครงสร้างไฟ ชั้น 1',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'รายละเอียด / สั่งการ:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText: 'ระบุรายละเอียดงาน...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'วันที่และเวลาปฏิบัติงาน (Due Date & Time):',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (pickedDate != null) {
                        final pickedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.fromDateTime(
                            selectedDate ?? DateTime.now(),
                          ),
                        );
                        if (pickedTime != null) {
                          setStateDialog(() {
                            selectedDate = DateTime(
                              pickedDate.year,
                              pickedDate.month,
                              pickedDate.day,
                              pickedTime.hour,
                              pickedTime.minute,
                            );
                          });
                        }
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            selectedDate == null
                                ? 'เลือกวันที่และเวลา'
                                : DateFormat(
                                    'dd MMM yyyy, HH:mm น.',
                                  ).format(selectedDate!),
                            style: const TextStyle(fontSize: 16),
                          ),
                          const Icon(
                            Icons.access_time_rounded,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isSubmitting) ...[
                    const SizedBox(height: 16),
                    const Center(child: CircularProgressIndicator()),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(context),
                child: const Text(
                  'ยกเลิก',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (titleController.text.isEmpty ||
                            selectedDate == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('กรุณากรอกชื่องานและกำหนดเวลา'),
                            ),
                          );
                          return;
                        }

                        setStateDialog(() => isSubmitting = true);

                        try {
                          final user = _supabase.auth.currentUser;

                          // 🚀 เพิ่มการแนบ created_by เพื่อแก้ Error บังคับใส่ผู้สร้าง
                          await _supabase.from('tasks').insert({
                            'project_id': widget.projectId,
                            'title': titleController.text,
                            'description': descController.text,
                            'status': 'todo',
                            'due_at': selectedDate!.toIso8601String(),
                            'created_by': user?.id,
                          });

                          if (context.mounted) {
                            Navigator.pop(context);
                            setState(() {});
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('สร้างคำสั่งงานสำเร็จ!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          setStateDialog(() => isSubmitting = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('เกิดข้อผิดพลาด: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                child: const Text('บันทึกคำสั่งงาน'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Project Schedule (ตารางงาน)',
                style: TextStyle(
                  color: _textDark,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showAddTaskDialog,
                icon: const Icon(Icons.add),
                label: const Text('สร้างงานใหม่'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _supabase
                  .from('tasks')
                  .select()
                  .eq('project_id', widget.projectId)
                  .order('due_at', ascending: true),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError)
                  return Center(child: Text('Error: ${snapshot.error}'));

                final tasks = snapshot.data ?? [];
                if (tasks.isEmpty)
                  return const Center(
                    child: Text(
                      'ยังไม่มีตารางงานในโครงการนี้',
                      style: TextStyle(color: _textMuted, fontSize: 16),
                    ),
                  );

                return ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    final date = task['due_at'] != null
                        ? DateTime.parse(task['due_at']).toLocal()
                        : null;
                    final dateStr = date != null
                        ? DateFormat('dd MMM yyyy, เวลา HH:mm น.').format(date)
                        : 'ไม่ระบุ';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF1FE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.assignment, color: _primary),
                        ),
                        title: Text(
                          task['title'] ?? 'No Title',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              task['description'] ?? '',
                              style: const TextStyle(color: _textMuted),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(
                                  Icons.access_time_rounded,
                                  size: 14,
                                  color: Colors.orange,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'กำหนดเข้างาน: $dateStr',
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: _buildStatusChip(
                          task['status']?.toString() ?? 'todo',
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color bg;
    Color textC;
    String label;
    if (status == 'completed') {
      bg = Colors.green.shade50;
      textC = Colors.green.shade700;
      label = 'เสร็จสิ้น';
    } else if (status == 'in_progress') {
      bg = Colors.blue.shade50;
      textC = Colors.blue.shade700;
      label = 'กำลังทำ';
    } else {
      bg = Colors.orange.shade50;
      textC = Colors.orange.shade800;
      label = 'รอดำเนินการ';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textC,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
