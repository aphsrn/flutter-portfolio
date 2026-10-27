import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ReportsScreen extends StatefulWidget {
  final String? projectId;
  const ReportsScreen({super.key, this.projectId});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  double _totalBudget = 0.0;
  double _totalCost = 0.0;
  int _totalProjects = 0;
  int _totalTasks = 0;
  String _projectName = 'ไม่ระบุโครงการ';
  List<dynamic> _tasks = [];

  @override
  void initState() {
    super.initState();
    _fetchReportData();
  }

  Future<void> _fetchReportData() async {
    try {
      var boqQuery = _supabase
          .from('boq_items')
          .select('budget_amount, actual_cost');
      var taskQuery = _supabase.from('tasks').select('*');
      var projQuery = _supabase.from('projects').select('id, name');

      if (widget.projectId != null) {
        boqQuery = _supabase
            .from('boq_items')
            .select('budget_amount, actual_cost')
            .eq('project_id', widget.projectId!);
        taskQuery = _supabase
            .from('tasks')
            .select('*')
            .eq('project_id', widget.projectId!);

        final pInfo = await _supabase
            .from('projects')
            .select('name')
            .eq('id', widget.projectId!)
            .single();
        _projectName = pInfo['name'] ?? 'โครงการ';
      }

      final boqData = await boqQuery;
      final taskData = await taskQuery;
      final projData = await projQuery;

      double bSum = 0;
      double cSum = 0;
      for (var item in boqData) {
        bSum += (item['budget_amount'] as num?)?.toDouble() ?? 0.0;
        cSum += (item['actual_cost'] as num?)?.toDouble() ?? 0.0;
      }

      if (mounted) {
        setState(() {
          _totalBudget = bSum;
          _totalCost = cSum;
          _totalProjects = projData.length;
          _totalTasks = taskData.length;
          _tasks = taskData;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading reports: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatCurrency(double amount) {
    String s = amount.toStringAsFixed(2);
    final parts = s.split('.');
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    final formattedInt = parts[0].replaceAllMapped(
      reg,
      (Match m) => '${m[1]},',
    );
    return '฿$formattedInt.${parts[1]}';
  }

  Future<void> _exportPdfReport(String reportType) async {
    try {
      final pdf = pw.Document();
      final font = await PdfGoogleFonts.sarabunRegular();
      final fontBold = await PdfGoogleFonts.sarabunBold();
      final now = DateTime.now();
      final dateStr = '${now.day}/${now.month}/${now.year}';

      if (reportType == 'Daily') {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'DAILY CONSTRUCTION REPORT (รายงานผลประจำวัน)',
                    style: pw.TextStyle(font: fontBold, fontSize: 16),
                  ),
                  pw.Text(
                    'โครงการ: $_projectName | วันที่: $dateStr',
                    style: pw.TextStyle(font: font, fontSize: 11),
                  ),
                  pw.Divider(thickness: 1.5),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    '1. สภาพอากาศ (Weather Condition)',
                    style: pw.TextStyle(font: fontBold, fontSize: 12),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        pw.Text(
                          'เช้า: [ / ] ปกติ  [   ] ฝนตก',
                          style: pw.TextStyle(font: font, fontSize: 10),
                        ),
                        pw.Text(
                          'บ่าย: [ / ] ปกติ  [   ] ฝนตก',
                          style: pw.TextStyle(font: font, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    '2. งานที่ดำเนินการวันนี้ (Work Summary)',
                    style: pw.TextStyle(font: fontBold, fontSize: 12),
                  ),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                    ),
                    child: _tasks.isEmpty
                        ? pw.Text(
                            'ไม่มีตารางงานวันนี้',
                            style: pw.TextStyle(font: font, fontSize: 10),
                          )
                        : pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: _tasks
                                .map(
                                  (t) => pw.Text(
                                    '• ${t['title']} (${t['description'] ?? '-'})',
                                    style: pw.TextStyle(
                                      font: font,
                                      fontSize: 10,
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    '3. กำลังคนและเครื่องจักร (Manpower & Machine)',
                    style: pw.TextStyle(font: fontBold, fontSize: 12),
                  ),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        pw.Text(
                          '• หัวหน้างาน: 1 คน',
                          style: pw.TextStyle(font: font, fontSize: 10),
                        ),
                        pw.Text(
                          '• ช่างทั่วไป: 5 คน',
                          style: pw.TextStyle(font: font, fontSize: 10),
                        ),
                        pw.Text(
                          '• เครื่องจักร (แม็คโคร): 1 คัน',
                          style: pw.TextStyle(font: font, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    '4. ปัญหา อุปสรรค และแนวทางแก้ไข (Problems & Action)',
                    style: pw.TextStyle(font: fontBold, fontSize: 12),
                  ),
                  pw.Container(
                    height: 40,
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                    ),
                    child: pw.Text(
                      '- ไม่มีปัญหาหน้างาน -',
                      style: pw.TextStyle(
                        font: font,
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 30),
                  _buildSignatures(font),
                ],
              );
            },
          ),
        );
      } else if (reportType == 'Weekly') {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'WEEKLY PROGRESS REPORT (รายงานผลประจำสัปดาห์)',
                    style: pw.TextStyle(font: fontBold, fontSize: 16),
                  ),
                  pw.Text(
                    'โครงการ: $_projectName | สัปดาห์ที่ออกรายงาน: $dateStr',
                    style: pw.TextStyle(font: font, fontSize: 11),
                  ),
                  pw.Divider(thickness: 1.5),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    '1. สรุปความคืบหน้าภาพรวมสัปดาห์นี้',
                    style: pw.TextStyle(font: fontBold, fontSize: 12),
                  ),
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          '• งานโครงสร้างหลัก: ดำเนินการตามแผนงาน',
                          style: pw.TextStyle(font: font, fontSize: 10),
                        ),
                        pw.Text(
                          '• จำนวนงานในระบบทั้งหมด: $_totalTasks งาน',
                          style: pw.TextStyle(font: font, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    '2. แผนงานสัปดาห์หน้า (Next Week Plan)',
                    style: pw.TextStyle(font: fontBold, fontSize: 12),
                  ),
                  pw.Container(
                    height: 60,
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                    ),
                    child: pw.Text(
                      '- เตรียมงานติดตั้งระบบไฟฟ้าและประปาชั้น 1 -\n- ตรวจสอบความเรียบร้อยของแบบหล่อคอนกรีต -',
                      style: pw.TextStyle(font: font, fontSize: 10),
                    ),
                  ),
                  pw.SizedBox(height: 30),
                  _buildSignatures(font),
                ],
              );
            },
          ),
        );
      } else {
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'PROJECT CLOSEOUT REPORT (รายงานสรุปปิดโครงการ)',
                    style: pw.TextStyle(font: fontBold, fontSize: 16),
                  ),
                  pw.Text(
                    'โครงการ: $_projectName | วันที่สรุปผล: $dateStr',
                    style: pw.TextStyle(font: font, fontSize: 11),
                  ),
                  pw.Divider(thickness: 1.5),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    '1. สรุปผลการดำเนินงานและงบประมาณ (Financial Closeout)',
                    style: pw.TextStyle(font: fontBold, fontSize: 12),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                    ),
                    child: pw.Column(
                      children: [
                        _buildPdfRow(
                          font,
                          'งบประมาณรวมทั้งสิ้น (Total Budget):',
                          _formatCurrency(_totalBudget),
                        ),
                        pw.SizedBox(height: 6),
                        _buildPdfRow(
                          font,
                          'ต้นทุนเบิกจ่ายจริง (Total Actual Cost):',
                          _formatCurrency(_totalCost),
                        ),
                        pw.SizedBox(height: 6),
                        _buildPdfRow(
                          font,
                          'สถานะงบประมาณคงเหลือ (Balance):',
                          _formatCurrency(_totalBudget - _totalCost),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Text(
                    '2. การส่งมอบงานและการตรวจสอบคุณภาพ (Quality & Handover)',
                    style: pw.TextStyle(font: fontBold, fontSize: 12),
                  ),
                  pw.Container(
                    height: 50,
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey400),
                    ),
                    child: pw.Text(
                      'งานโครงสร้างและสถาปัตยกรรมแล้วเสร็จสมบูรณ์ ผ่านการตรวจสอบจากวิศวกรผู้ควบคุมงาน',
                      style: pw.TextStyle(font: font, fontSize: 10),
                    ),
                  ),
                  pw.SizedBox(height: 30),
                  _buildSignatures(font),
                ],
              );
            },
          ),
        );
      }

      final bytes = await pdf.save();
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'SmartSite_${reportType}_Report.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  pw.Widget _buildPdfRow(pw.Font font, String label, String value) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(font: font, fontSize: 11)),
        pw.Text(value, style: pw.TextStyle(font: font, fontSize: 11)),
      ],
    );
  }

  pw.Widget _buildSignatures(pw.Font font) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
      children: [
        pw.Column(
          children: [
            pw.Text(
              'ลงชื่อ..................................................',
              style: pw.TextStyle(font: font),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              '( ผู้ควบคุมงาน / PM )',
              style: pw.TextStyle(font: font, fontSize: 10),
            ),
          ],
        ),
        pw.Column(
          children: [
            pw.Text(
              'ลงชื่อ..................................................',
              style: pw.TextStyle(font: font),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              '( ผู้ออนุมัติ / Owner )',
              style: pw.TextStyle(font: font, fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }

  void _showReportTypeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('เลือกประเภทรายงานที่ต้องการออก (Export PDF)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.today, color: Colors.blue),
              title: const Text('รายงานประจำวัน (Daily Report)'),
              onTap: () {
                Navigator.pop(context);
                _exportPdfReport('Daily');
              },
            ),
            ListTile(
              leading: const Icon(Icons.date_range, color: Colors.orange),
              title: const Text('รายงานประจำสัปดาห์ (Weekly Report)'),
              onTap: () {
                Navigator.pop(context);
                _exportPdfReport('Weekly');
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.assignment_turned_in,
                color: Colors.green,
              ),
              title: const Text('รายงานปิดโครงการ (Closeout Report)'),
              onTap: () {
                Navigator.pop(context);
                _exportPdfReport('Closeout');
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompanyView = widget.projectId == null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          isCompanyView
              ? 'Company Reports (รายงานสรุปองค์กร)'
              : 'Project Reports (รายงานสรุปโครงการ)',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _showReportTypeDialog,
              icon: const Icon(Icons.picture_as_pdf, size: 18),
              label: const Text('Export PDF Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4F6EF7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
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
                    'Executive Summary & Report Center',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _ReportCard(
                          title: 'งบประมาณรวม',
                          value: _formatCurrency(_totalBudget),
                          icon: Icons.account_balance_wallet,
                          color: Colors.indigo,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _ReportCard(
                          title: 'ต้นทุนที่ใช้ไป',
                          value: _formatCurrency(_totalCost),
                          icon: Icons.payments,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'คำแนะนำในการใช้งานรายงาน',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '• กดปุ่ม "Export PDF Report" มุมขวาบนเพื่อเลือกประเภทรายงาน (Daily, Weekly, Closeout)',
                        ),
                        const Text(
                          '• แต่ละรายงานจะถูกแยกเนื้อหาตามประเภท เช่น สภาพอากาศ, กำลังคน, และสรุปการเงินทางการ',
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

class _ReportCard extends StatelessWidget {
  final String title, value;
  final IconData icon;
  final MaterialColor color;
  const _ReportCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            child: Icon(icon, color: color.shade600, size: 24),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
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
