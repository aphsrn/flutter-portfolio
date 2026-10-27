// lib/screens/create_pr_screen.dart
// pubspec.yaml: ต้องมี file_picker  (flutter pub add file_picker)
//
// Schema ที่ใช้ (purchase_requests):
//   justification, attachment_url (เก็บ "path" ใน bucket pr_attachments), attachment_name,
//   requester_id (= auth.uid ของผู้ใช้ที่ Login), department_id, title, total_amount,
//   status, auto_approved, approved_at, pr_number
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // FileOptions

import '../main.dart'; // supabase, AppColors

final NumberFormat _currency =
    NumberFormat.currency(locale: 'th_TH', symbol: '฿', decimalDigits: 2);

// หมวดหมู่สินค้า (ปรับตามต้องการ)
const List<String> kCategories = [
  'วัสดุสำนักงาน',
  'อุปกรณ์ IT',
  'เครื่องมือ/อุปกรณ์',
  'วัตถุดิบ',
  'บริการ',
  'อื่นๆ',
];

// ====== Config ======
const String kAttachBucket = 'pr_attachments'; // Supabase Storage bucket (private)
const int kMaxAttachBytes = 10 * 1024 * 1024; // จำกัดไฟล์แนบ 10 MB
// ค่าสำรองของวงเงิน Fast-Track ถ้าดึงจาก app_settings ไม่ได้ (0 = ปิดระบบ)
const double kDefaultFastTrackLimit = 5000;

// ====== Model แถวสินค้า (เก็บ controller ต่อแถว) ======
class _ItemRow {
  final TextEditingController name = TextEditingController();
  final TextEditingController qty = TextEditingController(text: '1');
  final TextEditingController price = TextEditingController();
  String? category;

  double get qtyValue => double.tryParse(qty.text.trim()) ?? 0;
  double get priceValue => double.tryParse(price.text.trim()) ?? 0;
  double get subtotal => qtyValue * priceValue;

  void dispose() {
    name.dispose();
    qty.dispose();
    price.dispose();
  }
}

class CreatePRScreen extends StatefulWidget {
  const CreatePRScreen({super.key});

  @override
  State<CreatePRScreen> createState() => _CreatePRScreenState();
}

class _CreatePRScreenState extends State<CreatePRScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController(); // เหตุผล/ความจำเป็น -> justification
  final List<_ItemRow> _items = [_ItemRow()];

  List<Map<String, dynamic>> _departments = [];
  String? _departmentId;
  bool _loadingDepts = true;
  bool _submitting = false;
  String? _deptError;

  PlatformFile? _picked; // ไฟล์แนบที่เลือก (ใบเสนอราคา)
  double _fastTrackLimit = kDefaultFastTrackLimit;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
    _loadFastTrackLimit().then((v) {
      if (mounted) setState(() => _fastTrackLimit = v);
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _reasonCtrl.dispose();
    for (final i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  // ดึงแผนกจากตาราง departments
  Future<void> _loadDepartments() async {
    setState(() {
      _loadingDepts = true;
      _deptError = null;
    });
    try {
      final res = await supabase
          .from('departments')
          .select('id, name')
          .order('name', ascending: true);
      if (!mounted) return;
      setState(() {
        _departments = List<Map<String, dynamic>>.from(res as List);
        _loadingDepts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _deptError = '$e';
        _loadingDepts = false;
      });
    }
  }

  // ดึงวงเงิน Fast-Track จาก app_settings (ถ้าดึงไม่ได้ใช้ค่าสำรอง)
  Future<double> _loadFastTrackLimit() async {
    try {
      final res = await supabase
          .from('app_settings')
          .select('value_numeric')
          .eq('key', 'fast_track_limit')
          .maybeSingle();
      final v = (res?['value_numeric'] as num?)?.toDouble();
      return v ?? kDefaultFastTrackLimit;
    } catch (_) {
      return kDefaultFastTrackLimit;
    }
  }

  // ยอดรวม Realtime (คำนวณใหม่ทุกครั้งที่ build)
  double get _total => _items.fold(0.0, (s, e) => s + e.subtotal);

  void _addItem() => setState(() => _items.add(_ItemRow()));

  void _removeItem(int index) {
    if (_items.length <= 1) return; // เหลืออย่างน้อย 1 แถว
    setState(() => _items.removeAt(index).dispose());
  }

  void _resetForm() {
    _titleCtrl.clear();
    _reasonCtrl.clear();
    for (final i in _items) {
      i.dispose();
    }
    setState(() {
      _items
        ..clear()
        ..add(_ItemRow());
      _departmentId = null;
      _picked = null;
    });
    _formKey.currentState?.reset();
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.danger : AppColors.success,
      ),
    );
  }

  // ====== เลือกไฟล์แนบ ======
  Future<void> _pickFile() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true, // ต้องใช้ bytes เพื่ออัปโหลด (รองรับ Web)
      );
      if (res == null || res.files.isEmpty) return;
      final f = res.files.first;
      if (f.size > kMaxAttachBytes) {
        _snack('ไฟล์ใหญ่เกิน 10 MB', error: true);
        return;
      }
      if (f.bytes == null) {
        _snack('อ่านไฟล์ไม่สำเร็จ', error: true);
        return;
      }
      setState(() => _picked = f);
    } catch (e) {
      _snack('เลือกไฟล์ไม่สำเร็จ: $e', error: true);
    }
  }

  String _mime(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      default:
        return 'application/octet-stream';
    }
  }

  String _fmtSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  // อัปโหลดขึ้น Storage แล้วคืนค่า path
  // path = <user_id>/<timestamp>.<ext> เพื่อให้ผ่าน Storage policy ของ bucket
  // (ชื่อไฟล์จริงภาษาไทยเก็บแยกในคอลัมน์ attachment_name เพราะ Storage ไม่รับอักขระไทยใน key)
  Future<String> _uploadAttachment(PlatformFile f, String uid) async {
    final ext = (f.extension ?? 'bin').toLowerCase();
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await supabase.storage.from(kAttachBucket).uploadBinary(
          path,
          f.bytes!,
          fileOptions: FileOptions(contentType: _mime(ext), upsert: false),
        );
    return path;
  }

  // ====== Submit: อัปโหลดไฟล์ -> บันทึก PR -> วนลูปบันทึก pr_items ======
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_total <= 0) {
      _snack('ยอดรวมต้องมากกว่า 0', error: true);
      return;
    }

    // ต้อง Login จริงเท่านั้น เพื่อให้ requester_id ไม่เป็น null
    final user = supabase.auth.currentUser;
    if (user == null) {
      _snack('กรุณาเข้าสู่ระบบก่อนสร้างคำขอซื้อ', error: true);
      return;
    }

    setState(() => _submitting = true);
    String? prId;
    String? uploadedPath;
    try {
      // 0) เช็ควงเงิน Fast-Track ล่าสุดจากฐานข้อมูล (limit = 0 คือปิดระบบ)
      final limit = await _loadFastTrackLimit();
      final autoApprove = limit > 0 && _total <= limit;

      // 1) อัปโหลดไฟล์แนบ (ถ้ามี)
      if (_picked != null) {
        uploadedPath = await _uploadAttachment(_picked!, user.id);
      }

      // 2) บันทึกหัวเอกสาร
      final pr = await supabase
          .from('purchase_requests')
          .insert({
            'requester_id': user.id, // ผู้ใช้ที่ Login ผ่าน Supabase Auth
            'department_id': _departmentId,
            'title': _titleCtrl.text.trim(),
            'justification': _reasonCtrl.text.trim(),
            'total_amount': _total,
            'status': autoApprove ? 'approved' : 'pending',
            'auto_approved': autoApprove,
            if (autoApprove)
              'approved_at': DateTime.now().toUtc().toIso8601String(),
            'attachment_url': uploadedPath, // path ใน bucket pr_attachments
            'attachment_name': _picked?.name,
            'pr_number':
                'PR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
          })
          .select('id')
          .single();
      prId = '${pr['id']}';

      // 3) วนลูปสร้างรายการสินค้า (pr_id, item_name, category, quantity, unit_price)
      final rows = <Map<String, dynamic>>[];
      for (final it in _items) {
        rows.add({
          'pr_id': prId,
          'item_name': it.name.text.trim(),
          'category': it.category ?? 'อื่นๆ',
          'quantity': it.qtyValue.toInt(),
          'unit_price': it.priceValue,
        });
      }
      await supabase.from('pr_items').insert(rows);

      if (!mounted) return;
      _snack(autoApprove
          ? 'อนุมัติอัตโนมัติ (Fast-Track) เรียบร้อย'
          : 'ส่งคำขอซื้อเรียบร้อย รอการอนุมัติ');
      _resetForm();
    } catch (e) {
      // Rollback: ลบหัวเอกสารและไฟล์ที่อัปโหลดไปแล้ว
      if (prId != null) {
        try {
          await supabase.from('purchase_requests').delete().eq('id', prId);
        } catch (_) {}
      }
      if (uploadedPath != null) {
        try {
          await supabase.storage.from(kAttachBucket).remove([uploadedPath]);
        } catch (_) {}
      }
      if (mounted) _snack('บันทึกไม่สำเร็จ: $e', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeaderCard(),
                const SizedBox(height: 16),
                _buildItemsCard(),
                const SizedBox(height: 16),
                _buildAttachmentCard(),
              ],
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  // ====== ส่วนหัว: Department + Title + Reason ======
  Widget _buildHeaderCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ข้อมูลคำขอซื้อ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 14),
            if (_loadingDepts)
              const LinearProgressIndicator()
            else if (_deptError != null)
              Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: AppColors.danger, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('โหลดแผนกไม่สำเร็จ')),
                  TextButton(
                      onPressed: _loadDepartments,
                      child: const Text('ลองอีกครั้ง')),
                ],
              )
            else
              DropdownButtonFormField<String>(
                value: _departmentId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'แผนก'),
                items: _departments
                    .map((d) => DropdownMenuItem<String>(
                          value: '${d['id']}',
                          child: Text('${d['name']}'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _departmentId = v),
                validator: (v) => v == null ? 'กรุณาเลือกแผนก' : null,
              ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'หัวข้อ PR'),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'กรุณากรอกหัวข้อ PR'
                  : null,
            ),
            const SizedBox(height: 14),
            // เหตุผล/ความจำเป็น (Multiline)
            TextFormField(
              controller: _reasonCtrl,
              minLines: 3,
              maxLines: 5,
              maxLength: 500,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: 'เหตุผล/ความจำเป็น',
                alignLabelWithHint: true,
                hintText: 'ระบุเหตุผลที่ต้องขอซื้อ',
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'กรุณากรอกเหตุผล/ความจำเป็น'
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  // ====== รายการสินค้า (Dynamic List) ======
  Widget _buildItemsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('รายการสินค้า',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                OutlinedButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('เพิ่มรายการ'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (int i = 0; i < _items.length; i++) ...[
              _buildItemRow(i),
              if (i < _items.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildItemRow(int index) {
    final it = _items[index];
    return Container(
      key: ObjectKey(it),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text('รายการที่ ${index + 1}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, color: AppColors.navyLight)),
              const Spacer(),
              IconButton(
                tooltip: 'ลบรายการ',
                onPressed: _items.length > 1 ? () => _removeItem(index) : null,
                icon: const Icon(Icons.delete_outline),
                color: AppColors.danger,
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: it.name,
            decoration: const InputDecoration(labelText: 'ชื่อสินค้า'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'กรุณากรอกชื่อสินค้า' : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: it.category,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'หมวดหมู่'),
            items: kCategories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => it.category = v),
            validator: (v) => v == null ? 'เลือกหมวดหมู่' : null,
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: it.qty,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: false),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  // กำหนดให้ label ลอยขึ้นเสมอ ไม่ตกลงมาทับตัวเลข 1
                  decoration: const InputDecoration(
                    labelText: 'จำนวน',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    hintText: '1',
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    return (n == null || n <= 0) ? 'ต้อง > 0' : null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: it.price,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  // กำหนดให้ label ลอยขึ้นเสมอ
                  decoration: const InputDecoration(
                    labelText: 'ราคา/หน่วย (฿)',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    hintText: '0.00',
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').trim());
                    return (n == null || n < 0) ? 'ราคาไม่ถูกต้อง' : null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'รวมรายการ: ${_currency.format(it.subtotal)}',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navyLight),
            ),
          ),
        ],
      ),
    );
  }

  // ====== ไฟล์แนบ (ใบเสนอราคา) ======
  Widget _buildAttachmentCard() {
    final f = _picked;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ไฟล์แนบ (ใบเสนอราคา)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('รองรับ PDF, JPG, PNG ขนาดไม่เกิน 10 MB',
                style:
                    TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 12),
            if (f == null)
              OutlinedButton.icon(
                onPressed: _submitting ? null : _pickFile,
                icon: const Icon(Icons.attach_file),
                label: const Text('แนบไฟล์'),
              )
            else
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      (f.extension ?? '').toLowerCase() == 'pdf'
                          ? Icons.picture_as_pdf
                          : Icons.image_outlined,
                      color: AppColors.navyLight,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          Text(_fmtSize(f.size),
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'เปลี่ยนไฟล์',
                      onPressed: _submitting ? null : _pickFile,
                      icon: const Icon(Icons.swap_horiz),
                    ),
                    IconButton(
                      tooltip: 'ลบไฟล์',
                      onPressed:
                          _submitting ? null : () => setState(() => _picked = null),
                      icon: const Icon(Icons.close),
                      color: AppColors.danger,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ====== แถบล่าง: Total + Fast-Track hint + Submit ======
  Widget _buildBottomBar() {
    final showHint = _total > 0 && _fastTrackLimit > 0;
    final isFast = _total <= _fastTrackLimit;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Total Amount',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _currency.format(_total),
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.navy),
                    ),
                  ),
                  if (showHint)
                    Text(
                      isFast
                          ? 'Fast-Track: อนุมัติอัตโนมัติ (≤ ${_currency.format(_fastTrackLimit)})'
                          : 'เกินวงเงิน Fast-Track ต้องรออนุมัติ',
                      style: TextStyle(
                        fontSize: 11,
                        color: isFast ? AppColors.success : AppColors.warning,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send),
              label: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }
}
