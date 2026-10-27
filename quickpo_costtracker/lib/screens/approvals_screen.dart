// lib/screens/approvals_screen.dart
// pubspec.yaml: เพิ่ม url_launcher  (flutter pub add url_launcher)
// Web ไม่ต้องตั้งค่าเพิ่ม | Android 11+: เพิ่ม <queries> ใน AndroidManifest ตามเอกสาร url_launcher
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../main.dart'; // supabase, AppColors

final NumberFormat _currency =
    NumberFormat.currency(locale: 'th_TH', symbol: '฿', decimalDigits: 2);
final DateFormat _dateFmt = DateFormat('dd/MM/yyyy HH:mm');

const String _kAttachBucket = 'pr-attachments'; // ต้องตรงกับหน้าสร้าง PR

double _n(dynamic v) => (v as num?)?.toDouble() ?? 0.0;

// ====== Status Badge Style ======
class _StatusStyle {
  final Color color;
  final String label;
  final IconData icon;
  const _StatusStyle(this.color, this.label, this.icon);
}

_StatusStyle _styleOf(String status) {
  switch (status) {
    case 'pending':
      return const _StatusStyle(
          Color(0xFFF2B100), 'Pending', Icons.hourglass_top); // เหลือง
    case 'approved':
      return const _StatusStyle(
          AppColors.success, 'Approved', Icons.check_circle); // เขียว
    case 'rejected':
      return const _StatusStyle(
          AppColors.danger, 'Rejected', Icons.cancel); // แดง
    default:
      return _StatusStyle(Colors.grey, status, Icons.help_outline);
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge(this.status);

  @override
  Widget build(BuildContext context) {
    final s = _styleOf(status);
    final dark = Theme.of(context).brightness == Brightness.dark;
    // สีตัวอักษรเหลืองต้องเข้มขึ้นในโหมดสว่างเพื่อให้อ่านออก
    final textColor = status == 'pending'
        ? (dark ? const Color(0xFFFFD54F) : const Color(0xFF8A6500))
        : s.color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: s.color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: s.color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(s.icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(s.label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: textColor)),
        ],
      ),
    );
  }
}

// ====== ผลการตัดสินใจจาก Dialog ======
class _Decision {
  final bool approve;
  final String? reason;
  const _Decision.approve()
      : approve = true,
        reason = null;
  const _Decision.reject(this.reason) : approve = false;
}

// ====================================================================
// หน้ารายการอนุมัติ (Pending / History)
// ====================================================================
class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key});

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  List<Map<String, dynamic>> _all = [];
  bool _loading = true;
  bool _busy = false; // กำลังอนุมัติ/ปฏิเสธ
  String? _error;
  String _historyFilter = 'all'; // all | approved | rejected

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ดึง PR ทั้งหมดพร้อมแผนกและรายการสินค้า แล้วแยกแท็บฝั่ง Client
  Future<void> _load() async {
    try {
      final res = await supabase
          .from('purchase_requests')
          .select('*, departments(name), pr_items(*)')
          .order('created_at', ascending: false)
          .limit(300);
      if (!mounted) return;
      setState(() {
        _all = List<Map<String, dynamic>>.from(res as List);
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
      if (_all.isNotEmpty) _snack('รีเฟรชไม่สำเร็จ: $e', error: true);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.danger : AppColors.success,
      ),
    );
  }

  // ====== เปิด Dialog รายละเอียด ======
  Future<void> _openDetail(Map<String, dynamic> pr) async {
    final d = await showDialog<_Decision>(
      context: context,
      builder: (_) => _PRDetailDialog(pr: pr),
    );
    if (d == null || !mounted) return;
    await _decide(pr, d);
  }

  // ====== Approve / Reject แล้วรีเฟรชอัตโนมัติ ======
  Future<void> _decide(Map<String, dynamic> pr, _Decision d) async {
    final id = '${pr['id']}';
    setState(() => _busy = true);
    try {
      final res = await supabase
          .from('purchase_requests')
          .update({
            'status': d.approve ? 'approved' : 'rejected',
            if (!d.approve) 'rejection_reason': d.reason,
            'decided_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', id)
          .eq('status', 'pending')
          .select('id');

      if ((res as List).isEmpty) {
        _snack('รายการนี้ถูกดำเนินการไปแล้ว', error: true);
      } else {
        _snack(d.approve ? 'อนุมัติเรียบร้อย' : 'ปฏิเสธคำขอเรียบร้อย');
      }
      await _load();
    } catch (e) {
      _snack('ดำเนินการไม่สำเร็จ: $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pending เรียงเก่าสุดก่อน (FIFO) / History เรียงใหม่สุดก่อน
    final pending = _all.where((e) => e['status'] == 'pending').toList()
      ..sort((a, b) => '${a['created_at']}'.compareTo('${b['created_at']}'));
    final history = _all.where((e) => e['status'] != 'pending').toList();
    final historyShown = _historyFilter == 'all'
        ? history
        : history.where((e) => e['status'] == _historyFilter).toList();

    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Material(
          color: cs.surface,
          child: TabBar(
            controller: _tab,
            labelColor: cs.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: cs.primary,
            tabs: [
              Tab(text: 'Pending (${pending.length})'),
              Tab(text: 'History (${history.length})'),
            ],
          ),
        ),
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : (_error != null && _all.isEmpty)
                  ? _buildError()
                  : TabBarView(
                      controller: _tab,
                      children: [
                        _buildList(pending, history: false),
                        _buildList(historyShown, history: true),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppColors.danger),
              const SizedBox(height: 12),
              const Text('โหลดข้อมูลไม่สำเร็จ',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text('$_error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() => _loading = true);
                  _load();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('ลองอีกครั้ง'),
              ),
            ],
          ),
        ),
      );

  // ====== รายการในแต่ละแท็บ ======
  Widget _buildList(List<Map<String, dynamic>> list, {required bool history}) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          if (history) ...[
            _buildHistoryFilter(),
            const SizedBox(height: 12),
          ],
          if (list.isEmpty) _buildEmpty(history),
          for (final pr in list) ...[
            _buildPRCard(pr),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryFilter() {
    Widget chip(String key, String label) => ChoiceChip(
          label: Text(label),
          selected: _historyFilter == key,
          onSelected: (_) => setState(() => _historyFilter = key),
        );
    return Wrap(
      spacing: 8,
      children: [
        chip('all', 'ทั้งหมด'),
        chip('approved', 'Approved'),
        chip('rejected', 'Rejected'),
      ],
    );
  }

  Widget _buildEmpty(bool history) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Column(
          children: [
            Icon(history ? Icons.history : Icons.task_alt,
                size: 56, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(history ? 'ยังไม่มีประวัติการอนุมัติ' : 'ไม่มีรายการรออนุมัติ',
                style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );

  // ====== การ์ด PR (กดเพื่อดูรายละเอียด) ======
  Widget _buildPRCard(Map<String, dynamic> pr) {
    final status = '${pr['status']}';
    final dept = (pr['departments'] as Map?)?['name'] ?? '-';
    final total = _n(pr['total_amount']);
    final created = DateTime.tryParse('${pr['created_at']}')?.toLocal();
    final prNo = pr['pr_number'];
    final auto = pr['auto_approved'] == true;
    final rejectReason = '${pr['rejection_reason'] ?? ''}'.trim();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openDetail(pr),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text('${pr['title'] ?? '-'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(status),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 14,
                runSpacing: 4,
                children: [
                  if (prNo != null) _meta(Icons.tag, '$prNo'),
                  _meta(Icons.apartment, '$dept'),
                  if (created != null)
                    _meta(Icons.schedule, _dateFmt.format(created)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(_currency.format(total),
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navyLight)),
                  ),
                  if (auto) ...[
                    _fastTrackChip(),
                    const SizedBox(width: 6),
                  ],
                  const Icon(Icons.chevron_right,
                      color: AppColors.textSecondary),
                ],
              ),
              if (status == 'rejected' && rejectReason.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('เหตุผล: $rejectReason',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.danger)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(text,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ],
      );

  Widget _fastTrackChip() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.navyLight.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text('Fast-Track',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.navyLight)),
      );
}

// ====================================================================
// Dialog รายละเอียด PR (เหตุผล / ไฟล์แนบ / งบคงเหลือ / รายการสินค้า)
// ====================================================================
class _PRDetailDialog extends StatefulWidget {
  final Map<String, dynamic> pr;
  const _PRDetailDialog({required this.pr});

  @override
  State<_PRDetailDialog> createState() => _PRDetailDialogState();
}

class _PRDetailDialogState extends State<_PRDetailDialog> {
  late final Future<Map<String, dynamic>?> _budgetFuture = _fetchBudget();
  late final Future<String?> _urlFuture = _fetchSignedUrl();

  Map<String, dynamic> get pr => widget.pr;
  String get _status => '${pr['status']}';
  bool get _isPending => _status == 'pending';

  // งบประมาณแผนกจาก View
  Future<Map<String, dynamic>?> _fetchBudget() async {
    final deptId = pr['department_id'];
    if (deptId == null) return null;
    try {
      return await supabase
          .from('vw_department_budget_bi')
          .select()
          .eq('department_id', deptId)
          .maybeSingle();
    } catch (_) {
      return null;
    }
  }

  // Signed URL ของไฟล์แนบ (bucket เป็น private) อายุ 1 ชั่วโมง
  Future<String?> _fetchSignedUrl() async {
    final path = '${pr['attachment_path'] ?? ''}';
    if (path.isEmpty) return null;
    try {
      return await supabase.storage
          .from(_kAttachBucket)
          .createSignedUrl(path, 3600);
    } catch (_) {
      return null;
    }
  }

  Future<void> _openUrl(String url) async {
    final ok = await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('เปิดไฟล์ไม่สำเร็จ'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  // Reject ต้องกรอกเหตุผลเสมอ
  Future<void> _reject() async {
    final reason = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _RejectDialog(),
    );
    if (reason == null || !mounted) return;
    Navigator.pop(context, _Decision.reject(reason));
  }

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.85;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560, maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummary(),
                    const SizedBox(height: 16),
                    _section('เหตุผล/ความจำเป็น', _buildReason()),
                    if (_status == 'rejected' || pr['auto_approved'] == true)
                      ...[
                      const SizedBox(height: 16),
                      _section('ผลการพิจารณา', _buildDecisionInfo()),
                    ],
                    const SizedBox(height: 16),
                    _section('งบประมาณแผนก', _buildBudget()),
                    const SizedBox(height: 16),
                    _section('ไฟล์แนบ', _buildAttachment()),
                    const SizedBox(height: 16),
                    _section('รายการสินค้า', _buildItems()),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${pr['title'] ?? '-'}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
                  if (pr['pr_number'] != null)
                    Text('${pr['pr_number']}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _StatusBadge(_status),
            IconButton(
              tooltip: 'ปิด',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );

  Widget _section(String title, Widget child) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navyLight)),
          const SizedBox(height: 8),
          child,
        ],
      );

  Widget _kv(String k, String v,
      {Color? color, bool bold = false, double size = 13}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(k,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(v,
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: size,
                    color: color,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  // ข้อมูลสรุป: แผนก / วันที่ / ยอดรวม
  Widget _buildSummary() {
    final dept = (pr['departments'] as Map?)?['name'] ?? '-';
    final created = DateTime.tryParse('${pr['created_at']}')?.toLocal();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _kv('แผนก', '$dept'),
          if (created != null) _kv('วันที่ขอ', _dateFmt.format(created)),
          _kv('ยอดรวม', _currency.format(_n(pr['total_amount'])),
              bold: true, size: 16, color: AppColors.navyLight),
        ],
      ),
    );
  }

  Widget _buildReason() {
    final reason = '${pr['reason'] ?? ''}'.trim();
    return Text(reason.isEmpty ? '-' : reason,
        style: const TextStyle(fontSize: 14, height: 1.4));
  }

  // เหตุผลที่ปฏิเสธ / อนุมัติอัตโนมัติ
  Widget _buildDecisionInfo() {
    final rejected = _status == 'rejected';
    final reason = '${pr['rejection_reason'] ?? ''}'.trim();
    final decided = DateTime.tryParse('${pr['decided_at']}')?.toLocal();
    final color = rejected ? AppColors.danger : AppColors.success;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rejected
                ? (reason.isEmpty ? 'ไม่ได้ระบุเหตุผล' : reason)
                : 'อนุมัติอัตโนมัติตามวงเงิน Fast-Track',
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
          if (decided != null) ...[
            const SizedBox(height: 4),
            Text('เมื่อ ${_dateFmt.format(decided)}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
        ],
      ),
    );
  }

  // งบคงเหลือของแผนก (+ ยอดคงเหลือหลังอนุมัติ ถ้ายัง Pending)
  Widget _buildBudget() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _budgetFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const LinearProgressIndicator(minHeight: 2);
        }
        final b = snap.data;
        if (b == null) {
          return const Text('ไม่พบข้อมูลงบประมาณของแผนก',
              style: TextStyle(color: AppColors.textSecondary));
        }
        final allocated = _n(b['allocated_budget']);
        final spent = _n(b['actual_spent']);
        final remaining = b['remaining_budget'] == null
            ? allocated - spent
            : _n(b['remaining_budget']);
        final after = remaining - _n(pr['total_amount']);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _kv('งบที่จัดสรร', _currency.format(allocated)),
              _kv('ใช้ไปแล้ว', _currency.format(spent)),
              _kv('งบคงเหลือ', _currency.format(remaining),
                  bold: true,
                  color: remaining < 0 ? AppColors.danger : AppColors.success),
              if (_isPending) ...[
                const Divider(height: 16),
                _kv('คงเหลือหลังอนุมัติ', _currency.format(after),
                    bold: true,
                    color: after < 0 ? AppColors.danger : AppColors.navyLight),
                if (after < 0)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 16, color: AppColors.danger),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text('ยอดขอซื้อเกินงบคงเหลือของแผนก',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.danger)),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ไฟล์แนบ: พรีวิวรูป + ปุ่มเปิดไฟล์
  Widget _buildAttachment() {
    final path = '${pr['attachment_path'] ?? ''}';
    if (path.isEmpty) {
      return const Text('ไม่มีไฟล์แนบ',
          style: TextStyle(color: AppColors.textSecondary));
    }
    final name = '${pr['attachment_name'] ?? path.split('/').last}';
    final ext = name.split('.').last.toLowerCase();
    final isImage = ['jpg', 'jpeg', 'png'].contains(ext);

    return FutureBuilder<String?>(
      future: _urlFuture,
      builder: (context, snap) {
        final loading = snap.connectionState != ConnectionState.done;
        final url = snap.data;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isImage && url != null) ...[
              GestureDetector(
                onTap: () => _openUrl(url),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    url,
                    height: 170,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Icon(
                      ext == 'pdf'
                          ? Icons.picture_as_pdf
                          : Icons.image_outlined,
                      color: AppColors.navyLight),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed:
                        (loading || url == null) ? null : () => _openUrl(url),
                    icon: loading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.open_in_new, size: 16),
                    label: const Text('เปิดไฟล์'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
            ),
            if (!loading && url == null)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('ไม่สามารถสร้างลิงก์ไฟล์แนบได้',
                    style:
                        TextStyle(fontSize: 12, color: AppColors.danger)),
              ),
          ],
        );
      },
    );
  }

  Widget _buildItems() {
    final items = List<Map<String, dynamic>>.from(pr['pr_items'] ?? []);
    if (items.isEmpty) {
      return const Text('ไม่มีรายการสินค้า',
          style: TextStyle(color: AppColors.textSecondary));
    }
    return Column(
      children: [
        for (int i = 0; i < items.length; i++) _itemRow(i + 1, items[i]),
      ],
    );
  }

  Widget _itemRow(int no, Map<String, dynamic> it) {
    final qty = _n(it['quantity']);
    final price = _n(it['unit_price']);
    final qtyText =
        qty == qty.roundToDouble() ? qty.toInt().toString() : qty.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Text('$no.',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${it['item_name'] ?? '-'}',
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  '${it['category'] ?? '-'}  •  $qtyText x ${_currency.format(price)}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(_currency.format(qty * price),
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ปุ่ม Approve / Reject (เฉพาะรายการที่ยัง Pending)
  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: _isPending
          ? Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _reject,
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () =>
                        Navigator.pop(context, const _Decision.approve()),
                    icon: const Icon(Icons.check),
                    label: const Text('Approve'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success),
                  ),
                ),
              ],
            )
          : Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('ปิด'),
              ),
            ),
    );
  }
}

// ====== Dialog กรอกเหตุผลการปฏิเสธ (บังคับกรอก) ======
class _RejectDialog extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _formKey = GlobalKey<FormState>();
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('ปฏิเสธคำขอซื้อ'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _ctrl,
          autofocus: true,
          minLines: 3,
          maxLines: 5,
          maxLength: 300,
          decoration: const InputDecoration(
            labelText: 'เหตุผลในการปฏิเสธ (บังคับ)',
            alignLabelWithHint: true,
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'กรุณากรอกเหตุผล' : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _ctrl.text.trim());
            }
          },
          child: const Text('ยืนยันปฏิเสธ'),
        ),
      ],
    );
  }
}