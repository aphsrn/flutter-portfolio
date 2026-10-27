// lib/screens/profile_settings_screen.dart
// pubspec.yaml: เพิ่ม crypto  (flutter pub add crypto)  -- ใช้ Hash PIN ไม่เก็บเป็นข้อความตรงๆ
//
// ฐานข้อมูล: รัน supabase/upgrade_v3.sql แล้วตามด้วย supabase/upgrade_v4.sql
//   profiles: fast_track_limit, budget_alert_pct, default_currency, pin_code (เก็บ Hash),
//             notify_new_pr, notify_budget_critical, avatar_url
//   app_settings: fast_track_limit (ค่ากลางที่ Trigger อนุมัติอัตโนมัติและหน้าสร้าง PR อ่าน)
import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // เพิ่มบรรทัดนี้

import '../main.dart'; // ดึง globalAvatarUrl, globalLanguage, supabase, AppColors

// ====== รายการภาษาสากล เรียงตามตัวอักษร A-Z ======
class LanguageItem {
  final String code;
  final String label;
  const LanguageItem(this.code, this.label);
}

final List<LanguageItem> _availableLanguages = [
  const LanguageItem('ar', 'Arabic (العربية)'),
  const LanguageItem('zh', 'Chinese (中文)'),
  const LanguageItem('en', 'English (EN)'),
  const LanguageItem('fr', 'French (Français)'),
  const LanguageItem('de', 'German (Deutsch)'),
  const LanguageItem('ja', 'Japanese (日本語)'),
  const LanguageItem('ko', 'Korean (한국어)'),
  const LanguageItem('es', 'Spanish (Español)'),
  const LanguageItem('th', 'Thai (ไทย)'),
]..sort((a, b) => a.label.compareTo(b.label)); // เรียง A-Z

// ====== Dictionary ข้อความ ======
const Map<String, Map<String, String>> _t = {
  'th': {
    'title': 'โปรไฟล์และการตั้งค่าระบบ',
    'profile': 'ข้อมูลโปรไฟล์',
    'name': 'ชื่อผู้ใช้',
    'department': 'แผนก',
    'role': 'บทบาท',
    'editName': 'แก้ไขชื่อผู้ใช้',
    'changeAvatar': 'เปลี่ยนรูปโปรไฟล์',
    'save': 'บันทึก',
    'cancel': 'ยกเลิก',
    'nameRequired': 'กรุณากรอกชื่อผู้ใช้',
    'saved': 'บันทึกข้อมูลเรียบร้อย',
    'saveFailed': 'บันทึกไม่สำเร็จ',
    'settings': 'การตั้งค่าทั่วไป',
    'theme': 'ธีมการแสดงผล',
    'system': 'ตามระบบ (System)',
    'light': 'สว่าง (Light)',
    'dark': 'มืด (Dark)',
    'language': 'ภาษา (Language)',
    'procurementSettings': 'การตั้งค่าระบบจัดซื้อ & งบประมาณ (ERP Config)',
    'currency': 'สกุลเงินหลักในการแสดงผล',
    'budgetAlert': 'แจ้งเตือนเมื่องบถูกใช้เกิน (%)',
    'notiSection': 'การแจ้งเตือนและการอนุมัติ',
    'notiPR': 'แจ้งเตือนเมื่อมีคำขอซื้อรออนุมัติใหม่',
    'notiBudget': 'แจ้งเตือนทันทีเมื่องบประมาณเข้าขั้นวิกฤต',
    'autoApproveThreshold': 'วงเงินอนุมัติอัตโนมัติ (Fast-Track PO)',
    'budgetAdmin': 'จัดการงบประมาณ (Budget Management)',
    'logout': 'ออกจากระบบ (Logout)',
    'logoutConfirm': 'ต้องการออกจากระบบใช่หรือไม่?',
    'confirm': 'ยืนยัน',
    'approver': 'ผู้อนุมัติ (Approver)',
    'employee': 'พนักงาน (Employee)',
    'noDept': 'ไม่ระบุแผนก',
    'noName': 'ผู้ใช้งาน',
    'loadFail': 'โหลดโปรไฟล์ไม่สำเร็จ',
    'retry': 'ลองอีกครั้ง',
    'chooseAvatarTitle': 'เลือกรูปภาพโปรไฟล์',
    'pickGallery': 'เลือกรูปภาพจากคลังภาพ (Gallery)',
    'authTitle': 'ยืนยันสิทธิ์ผู้อนุมัติ (Security Check)',
    'authDesc': 'กรุณากรอก PIN เพื่อปรับวงเงิน Fast-Track',
    'authError': 'PIN ไม่ถูกต้อง การยืนยันตัวตนล้มเหลว',
    'authLocked': 'กรอก PIN ผิดเกินกำหนด กรุณาลองใหม่ใน 30 วินาที',
    'noPermission': 'เฉพาะผู้อนุมัติ/ผู้ดูแลระบบเท่านั้นที่ปรับค่านี้ได้',
    'pinHint': 'PIN',
    'pinSetupTitle': 'ตั้งรหัส PIN ผู้อนุมัติ',
    'pinSetupDesc': 'ยังไม่เคยตั้ง PIN กรุณาตั้ง PIN ตัวเลข 4-6 หลักก่อนปรับวงเงิน',
    'pinNew': 'PIN ใหม่ (4-6 หลัก)',
    'pinConfirm': 'ยืนยัน PIN อีกครั้ง',
    'pinInvalid': 'PIN ต้องเป็นตัวเลข 4-6 หลัก',
    'pinMismatch': 'PIN ทั้งสองช่องไม่ตรงกัน',
    'pinSet': 'ตั้งค่า PIN เรียบร้อย',
    'customAmount': 'กำหนดวงเงินเอง...',
    'disabled': 'ปิดการใช้งาน (Disabled)',
    'enterAmount': 'ระบุวงเงิน (฿)',
  },
  'en': {
    'title': 'Profile & System Settings',
    'profile': 'Profile',
    'name': 'Username',
    'department': 'Department',
    'role': 'Role',
    'editName': 'Edit username',
    'changeAvatar': 'Change Avatar',
    'save': 'Save',
    'cancel': 'Cancel',
    'nameRequired': 'Please enter a username',
    'saved': 'Saved successfully',
    'saveFailed': 'Failed to save',
    'settings': 'General Settings',
    'theme': 'Theme Mode',
    'system': 'System',
    'light': 'Light',
    'dark': 'Dark',
    'language': 'Language',
    'procurementSettings': 'Procurement & Budget Settings (ERP)',
    'currency': 'Default Currency',
    'budgetAlert': 'Budget Warning Threshold (%)',
    'notiSection': 'Notifications & Approvals',
    'notiPR': 'Notify on new pending PRs',
    'notiBudget': 'Alert when department budget is critical',
    'autoApproveThreshold': 'Auto-Approve Threshold Limit',
    'budgetAdmin': 'Budget Management',
    'logout': 'Logout',
    'logoutConfirm': 'Do you want to log out?',
    'confirm': 'Confirm',
    'approver': 'Approver',
    'employee': 'Employee',
    'noDept': 'No department',
    'noName': 'User',
    'loadFail': 'Failed to load profile',
    'retry': 'Retry',
    'chooseAvatarTitle': 'Select Profile Avatar',
    'pickGallery': 'Choose from Device Gallery',
    'authTitle': 'Authorization Verification',
    'authDesc': 'Please enter your PIN to modify Fast-Track limits',
    'authError': 'Invalid PIN',
    'authLocked': 'Too many wrong attempts. Try again in 30 seconds',
    'noPermission': 'Only approvers/admins can change this setting',
    'pinHint': 'PIN',
    'pinSetupTitle': 'Set Approver PIN',
    'pinSetupDesc': 'No PIN set yet. Create a 4-6 digit PIN before changing limits',
    'pinNew': 'New PIN (4-6 digits)',
    'pinConfirm': 'Confirm PIN',
    'pinInvalid': 'PIN must be 4-6 digits',
    'pinMismatch': 'PINs do not match',
    'pinSet': 'PIN has been set',
    'customAmount': 'Custom limit...',
    'disabled': 'Disabled',
    'enterAmount': 'Enter limit amount',
  },
  // เติมคำแปลภาษาอื่นคร่าวๆ เพื่อให้เห็นผลการเปลี่ยนภาษาได้ชัดเจน
  'ja': {
    'title': 'プロフィールと設定',
    'language': '言語 (Language)',
    'settings': '一般設定',
    'logout': 'ログアウト (Logout)',
    // ... เติมคำอื่นๆ ที่เหลือถ้าต้องการ
  },
  'zh': {
    'title': '个人资料和设置',
    'language': '语言 (Language)',
    'settings': '常规设置',
    'logout': '登出 (Logout)',
  }
};

// ====== เปลี่ยนรูปอวตารแนะนำเป็น 3D Cartoon / เสมือนจริง ======
final List<String> _presetAvatars = [
  'https://api.dicebear.com/9.x/micah/png?seed=Felix&backgroundColor=b6e3f4',
  'https://api.dicebear.com/9.x/micah/png?seed=Aneka&backgroundColor=c0aede',
  'https://api.dicebear.com/9.x/micah/png?seed=Jude&backgroundColor=ffdfbf',
  'https://api.dicebear.com/9.x/micah/png?seed=Alex&backgroundColor=d1d4f9',
  'https://api.dicebear.com/9.x/micah/png?seed=Avery&backgroundColor=b6e3f4',
];

// ====== สกุลเงินที่เลือกได้ (code อยู่หน้าวงเล็บ ใช้เก็บลง DB) ======
const List<String> _currencies = ['THB (฿)', 'USD (\$)', 'EUR (€)'];

// ====== โหมด Demo (ไม่ได้ล็อกอิน): เก็บค่าในหน่วยความจำให้คงอยู่ระหว่างเปิดหน้านี้ซ้ำ ======
String? _demoPinHash;
final Map<String, dynamic> _demoErp = {};

class ProfileSettingsScreen extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;
  final VoidCallback? onLoggedOut;

  const ProfileSettingsScreen({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
    this.onLoggedOut,
  });

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  late ThemeMode _themeMode = widget.themeMode;

  Map<String, dynamic>? _profile;
  String? _avatarUrl;
  Uint8List? _avatarBytes;
  bool _loading = true;
  bool _error = false;
  bool _loggingOut = false;
  bool _isLogoutHovered = false;

  final ImagePicker _picker = ImagePicker();

  // ERP Settings
  String _selectedCurrency = 'THB (฿)';
  double _budgetThreshold = 80.0;
  double _savedThreshold = 80.0; // ค่าที่บันทึกสำเร็จล่าสุด (ใช้ย้อนกลับถ้าบันทึกพลาด)
  bool _notiNewPR = true;
  bool _notiBudgetWarning = true;
  String _autoApproveLimit = '5,000 ฿';

  // PIN ผู้อนุมัติ (เก็บเป็น Hash)
  String? _pinHash;
  DateTime? _pinLockedUntil;

  String tr(String k) {
    // ดึงภาษาจากตัวแปร global
    final lang = globalLanguage.value;
    return _t[lang]?[k] ?? _t['en']?[k] ?? k;
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void didUpdateWidget(covariant ProfileSettingsScreen old) {
    super.didUpdateWidget(old);
    _themeMode = widget.themeMode;
  }

  // ====== Helpers: ERP Config ======
  // 0 = ปิดการใช้งาน
  String _fmtLimit(double v) =>
      v <= 0 ? 'Disabled' : '${NumberFormat('#,##0.##').format(v)} ฿';

  double _parseLimit(String s) => s == 'Disabled'
      ? 0
      : (double.tryParse(s.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0);

  // ตั้งค่าตัวแปร ERP จากข้อมูลโปรไฟล์ (หรือจากค่า Demo)
  void _applyErpConfig(Map<String, dynamic> src) {
    final cur = src['default_currency']?.toString();
    if (cur != null && cur.isNotEmpty) {
      final m = _currencies.where((e) => e.startsWith(cur));
      if (m.isNotEmpty) _selectedCurrency = m.first;
    }

    final pct = src['budget_alert_pct'];
    if (pct is num) {
      // Slider มี step ละ 5 ในช่วง 50-100
      _budgetThreshold = ((pct.toDouble() / 5).round() * 5).clamp(50, 100).toDouble();
      _savedThreshold = _budgetThreshold;
    }

    final lim = src['fast_track_limit'];
    if (lim is num) _autoApproveLimit = _fmtLimit(lim.toDouble());

    final nPR = src['notify_new_pr'];
    if (nPR is bool) _notiNewPR = nPR;

    final nBudget = src['notify_budget_critical'];
    if (nBudget is bool) _notiBudgetWarning = nBudget;
  }

  // อัปเดตตาราง profiles ของผู้ใช้ปัจจุบัน (Demo Mode = ไม่แตะ DB)
  Future<bool> _updateProfile(Map<String, dynamic> patch) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return true;
    try {
      final res = await supabase
          .from('profiles')
          .update(patch)
          .eq('id', uid)
          .select('id');
      if ((res as List).isEmpty) throw Exception('profile row not found');
      return true;
    } catch (e) {
      _snack('${tr('saveFailed')}: $e', error: true);
      return false;
    }
  }

  // บันทึกค่า ERP (Demo Mode เก็บไว้ในหน่วยความจำ)
  Future<bool> _persistErp(Map<String, dynamic> patch) async {
    if (supabase.auth.currentUser == null) {
      _demoErp.addAll(patch);
      return true;
    }
    return _updateProfile(patch);
  }

  // สะท้อนวงเงิน Fast-Track ไปที่ app_settings ด้วย เพราะ Trigger อนุมัติอัตโนมัติ
  // และหน้าสร้าง PR อ่านค่าจากตารางนั้น (ลบฟังก์ชันนี้ได้ ถ้าไม่ต้องการให้มีผลกับ PR จริง)
  Future<void> _syncOrgFastTrack(double amount) async {
    try {
      await supabase.from('app_settings').upsert({
        'key': 'fast_track_limit',
        'value_numeric': amount,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      print('Sync fast_track_limit error: $e');
    }
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = false;
    });

    try {
      final uid = supabase.auth.currentUser?.id;
      
      // 1. ถ้าล็อกอินอยู่ ให้พยายามดึงข้อมูลจากตาราง profiles
      if (uid != null) {
        final res = await supabase
            .from('profiles')
            .select('*, departments(name)')
            .eq('id', uid)
            .maybeSingle();

        if (res != null) {
          if (!mounted) return;
          
          final String? dbAvatarUrl = res['avatar_url'];
          
          setState(() {
            _profile = res;
            _avatarUrl = dbAvatarUrl; 
            // ดึงค่า ERP Config และ PIN จากฐานข้อมูลมาเป็นค่าเริ่มต้น
            _applyErpConfig(Map<String, dynamic>.from(res));
            _pinHash = res['pin_code']?.toString();
            _loading = false;
          });
          
          if (dbAvatarUrl != null && dbAvatarUrl.isNotEmpty) {
             globalAvatarUrl.value = dbAvatarUrl;
             globalAvatarBytes.value = null; 
          }
          return;
        }
      }

      // 2. กรณีโหมด Demo (ไม่ได้ล็อกอิน) ให้ดึงค่าจากตัวแปร global ที่เก็บไว้ล่าสุด
      if (!mounted) return;
      
      // ดึง URL หรือ Bytes ล่าสุดที่เพิ่งเลือกมาใช้ ห้ามเอา Default ไปทับ
      final currentAvatarUrl = globalAvatarUrl.value ?? _presetAvatars[0];
      final currentAvatarBytes = globalAvatarBytes.value;

      setState(() {
        _profile = {
          'full_name': 'Admin User',
          'role': 'approver',
          'departments': {'name': 'IT Solutions'}
        };
        // ถ้ารูปเดิมเป็น Bytes ก็ต้องให้เป็น Bytes
        if (currentAvatarBytes != null) {
           _avatarBytes = currentAvatarBytes;
           _avatarUrl = null;
        } else {
           _avatarUrl = currentAvatarUrl;
           _avatarBytes = null;
        }
        _applyErpConfig(_demoErp);
        _pinHash = _demoPinHash;
        _loading = false;
      });
      
    } catch (e) {
      if (!mounted) return;
      
      final currentAvatarUrl = globalAvatarUrl.value ?? _presetAvatars[0];
      final currentAvatarBytes = globalAvatarBytes.value;

      setState(() {
        _profile = {
          'full_name': 'Admin User',
          'role': 'approver',
          'departments': {'name': 'IT Solutions'}
        };
        if (currentAvatarBytes != null) {
           _avatarBytes = currentAvatarBytes;
           _avatarUrl = null;
        } else {
           _avatarUrl = currentAvatarUrl;
           _avatarBytes = null;
        }
        _applyErpConfig(_demoErp);
        _pinHash = _demoPinHash;
        _loading = false;
      });
    }
  }

  String get _name {
    final n = (_profile?['full_name'] ?? '').toString().trim();
    if (n.isNotEmpty) return n;
    final email = supabase.auth.currentUser?.email;
    return email ?? tr('noName');
  }

  String get _dept =>
      (_profile?['departments'] as Map?)?['name']?.toString() ?? tr('noDept');

  bool get _isApprover =>
      (_profile?['role'] ?? '').toString().toLowerCase() == 'approver';

  bool get _isAdmin =>
      (_profile?['role'] ?? '').toString().toLowerCase() == 'admin';

  // สิทธิ์จัดการงบประมาณ / ปรับวงเงิน: Approver หรือ Admin เท่านั้น
  bool get _canManageBudget => _isApprover || _isAdmin;

  String get _initials {
    final parts = _name.trim().split(RegExp(r'\s+'));
    final s = parts.take(2).map((e) => e.isEmpty ? '' : e[0]).join();
    return s.toUpperCase();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.danger : AppColors.success,
    ));
  }

  // ====== PIN: Hash (ผูกกับ user id) ======
  String _hashPin(String pin) {
    final uid = supabase.auth.currentUser?.id ?? 'demo';
    return sha256.convert(utf8.encode('quickpo:$uid:$pin')).toString();
  }

  Future<bool> _savePinHash(String hash) async {
    if (supabase.auth.currentUser == null) {
      _demoPinHash = hash;
      return true;
    }
    return _updateProfile({'pin_code': hash});
  }

  // ====== ยืนยันตัวตนก่อนแก้ Limit ======
  Future<bool> _authenticateApprover() async {
    // ยังไม่เคยตั้ง PIN -> บังคับตั้ง PIN ใหม่ก่อน
    if (_pinHash == null || _pinHash!.isEmpty) {
      final newPin = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _PinDialog(tr: tr, setup: true),
      );
      if (newPin == null) return false;

      final hash = _hashPin(newPin);
      if (!await _savePinHash(hash)) return false;
      if (!mounted) return false;
      setState(() => _pinHash = hash);
      _snack(tr('pinSet'));
      return true;
    }

    // ถูกล็อกชั่วคราวจากการกรอกผิดหลายครั้ง
    if (_pinLockedUntil != null && DateTime.now().isBefore(_pinLockedUntil!)) {
      _snack(tr('authLocked'), error: true);
      return false;
    }

    // มี PIN แล้ว -> ตรวจสอบกับค่าจากตาราง profiles
    final entered = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PinDialog(
        tr: tr,
        setup: false,
        verify: (p) => _hashPin(p) == _pinHash,
        onLocked: () =>
            _pinLockedUntil = DateTime.now().add(const Duration(seconds: 30)),
      ),
    );

    if (entered == null) {
      if (_pinLockedUntil != null && DateTime.now().isBefore(_pinLockedUntil!)) {
        _snack(tr('authLocked'), error: true);
      }
      return false;
    }
    return true;
  }

  // ====== จัดการปรับวงเงิน Fast-Track ======
  Future<void> _handleLimitChange(String? value) async {
    if (value == null) return;

    // เฉพาะ Approver/Admin เท่านั้นที่ปรับวงเงินได้
    if (!_canManageBudget) {
      _snack(tr('noPermission'), error: true);
      return;
    }

    final authOk = await _authenticateApprover();
    if (!authOk) return;

    String? newLimit;

    if (value == 'CUSTOM') {
      final customCtrl = TextEditingController();
      newLimit = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(tr('enterAmount')),
          content: TextField(
            controller: customCtrl,
            keyboardType: TextInputType.number,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'เช่น 25000, 50000',
              suffixText: '฿',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('cancel'))),
            ElevatedButton(
              onPressed: () {
                final n = double.tryParse(
                    customCtrl.text.replaceAll(RegExp(r'[^0-9.]'), ''));
                if (n != null && n > 0) {
                  Navigator.pop(ctx, _fmtLimit(n));
                }
              },
              child: Text(tr('save')),
            ),
          ],
        ),
      );
    } else {
      newLimit = value;
    }

    if (newLimit == null) return;

    // บันทึกลง profiles (ถ้าพลาดให้ย้อนค่าเดิม)
    final old = _autoApproveLimit;
    final amount = _parseLimit(newLimit);
    setState(() => _autoApproveLimit = newLimit!);

    final ok = await _persistErp({'fast_track_limit': amount});
    if (!ok) {
      if (mounted) setState(() => _autoApproveLimit = old);
      return;
    }
    await _syncOrgFastTrack(amount);
    _snack(tr('saved'));
  }

  // ====== ดึงรูปจากคลังภาพในเครื่อง และอัปโหลดขึ้น Supabase ======
  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        
        // 1. โชว์รูปให้ผู้ใช้เห็นทันทีบนหน้าจอก่อนอัปโหลด
        setState(() {
          _avatarBytes = bytes;
          _avatarUrl = null;
        });
        globalAvatarBytes.value = bytes;
        globalAvatarUrl.value = null;

        // 2. อัปโหลดขึ้น Supabase Storage เพื่อให้กลายเป็น URL ถาวร
        try {
          final uid = supabase.auth.currentUser?.id;
          if (uid != null) {
            // สร้างชื่อไฟล์ไม่ให้ซ้ำกัน
            final fileExt = image.name.split('.').last.toLowerCase();
            final fileName = '$uid-${DateTime.now().millisecondsSinceEpoch}.$fileExt';
            
            // อัปโหลดไฟล์แบบ Binary ขึ้นถัง 'avatars'
            await supabase.storage.from('avatars').uploadBinary(
              fileName, 
              bytes,
              fileOptions: FileOptions(contentType: 'image/$fileExt'),
            );

            // ดึง URL ที่เป็นสาธารณะของรูปที่เพิ่งอัปโหลด
            final String publicUrl = supabase.storage.from('avatars').getPublicUrl(fileName);

            // บันทึก URL นี้ลงตาราง profiles
            await supabase.from('profiles').update({'avatar_url': publicUrl}).eq('id', uid);

            // เมื่ออัปโหลดเสร็จ ให้ระบบหันมาใช้ URL แทนก้อน Bytes (ทำให้เหมือนรูปอวตารแนะนำทุกประการ)
            setState(() {
              _avatarUrl = publicUrl;
              _avatarBytes = null;
            });
            globalAvatarUrl.value = publicUrl;
            globalAvatarBytes.value = null;
            
            _snack('อัปโหลดและบันทึกรูปโปรไฟล์สำเร็จ');
          } else {
            _snack(tr('saved') + ' (Demo Mode)');
          }
        } catch (e) {
          print('Storage upload error: $e');
          _snack('เกิดข้อผิดพลาดในการอัปโหลดขึ้นระบบ (ต้องสร้าง Bucket ชื่อ avatars)', error: true);
        }
      }
    } catch (e) {
      _snack('ข้อผิดพลาดในการดึงรูป: $e', error: true);
    }
  }

  // ====== Dialog เลือกรูปภาพ ======
  Future<void> _changeAvatar() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('chooseAvatarTitle')),
        content: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                leading: const CircleAvatar(
                  backgroundColor: AppColors.navyLight,
                  child: Icon(Icons.photo_library, color: Colors.white, size: 20),
                ),
                title: Text(
                  tr('pickGallery'),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImageFromGallery();
                },
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('หรือเลือกอวตารแนะนำ', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: _presetAvatars.map((url) {
                  return InkWell(
                    onTap: () async {
                      // 1. อัปเดต State ภายในหน้า Profile ทันที
                      setState(() {
                        _avatarUrl = url;
                        _avatarBytes = null;
                      });
                      
                      // 2. อัปเดต Global State ให้มุมขวาบนเปลี่ยนตาม
                      globalAvatarUrl.value = url;
                      
                      // ปิด Dialog
                      Navigator.pop(ctx);

                      // 3. บันทึกลงฐานข้อมูล Supabase 
                      try {
                        final uid = supabase.auth.currentUser?.id;
                        if (uid != null) {
                          // อัปเดต URL ไปที่ตาราง profiles
                          await supabase.from('profiles').update({'avatar_url': url}).eq('id', uid);
                        } else {
                          // (สำหรับการทดสอบแบบ Offline: สมมติว่าสำเร็จถ้าไม่มี UID)
                          print('Demo mode: Avatar changed to $url');
                        }
                      } catch (e) {
                        print('Error updating avatar: $e');
                      }
                      
                      _snack(tr('saved'));
                    },
                    borderRadius: BorderRadius.circular(40),
                    child: CircleAvatar(
                      radius: 26,
                      backgroundImage: NetworkImage(url),
                      child: _avatarUrl == url && _avatarBytes == null
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ====== แก้ไขชื่อและบันทึกลง Supabase ======
  Future<void> _editName() async {
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _EditNameDialog(
        initial: (_profile?['full_name'] ?? '').toString(),
        tr: tr,
      ),
    );
    if (newName == null || newName == _profile?['full_name']) return;

    // --- บันทึกลงฐานข้อมูล Supabase ทันที ---
    try {
      final uid = supabase.auth.currentUser?.id;
      if (uid != null) {
        await supabase.from('profiles').update({'full_name': newName}).eq('id', uid);
      }
    } catch (e) {
      print('Error updating name: $e');
    }

    setState(() => _profile = {...?_profile, 'full_name': newName});
    _snack(tr('saved'));
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('logout')),
        content: Text(tr('logoutConfirm')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('cancel'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr('confirm')),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _loggingOut = true);
    try {
      await supabase.auth.signOut();
      if (!mounted) return;
      if (widget.onLoggedOut != null) {
        widget.onLoggedOut!();
      } else {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    } catch (e) {
      _snack('$e', error: true);
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // นำ ValueListenableBuilder มาครอบทั้งหน้าเพื่อให้เปลี่ยนภาษาทันที
    return ValueListenableBuilder<String>(
      valueListenable: globalLanguage,
      builder: (context, lang, child) {
        return Scaffold(
          appBar: AppBar(title: Text(tr('title'))),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error
                  ? _buildError()
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildProfileCard(),
                        const SizedBox(height: 16),
                        _buildProcurementSettingsCard(),
                        const SizedBox(height: 16),
                        _buildGeneralSettingsCard(),
                        const SizedBox(height: 24),
                        _buildHoverLogoutButton(),
                        const SizedBox(height: 24),
                      ],
                    ),
        );
      }
    );
  }

  Widget _buildError() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(tr('loadFail')),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loadProfile,
              icon: const Icon(Icons.refresh),
              label: Text(tr('retry')),
            ),
          ],
        ),
      );

  Widget _buildProfileCard() {
    final cs = Theme.of(context).colorScheme;
    ImageProvider? imageProvider;
    if (_avatarBytes != null) {
      imageProvider = MemoryImage(_avatarBytes!);
    } else if (_avatarUrl != null) {
      imageProvider = NetworkImage(_avatarUrl!);
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.navyDark, AppColors.navyLight],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 46,
                      backgroundColor: Colors.white24,
                      child: CircleAvatar(
                        radius: 42,
                        backgroundColor: Colors.white,
                        backgroundImage: imageProvider,
                        child: imageProvider == null
                            ? (_initials.isEmpty
                                ? const Icon(Icons.person, size: 40, color: AppColors.navy)
                                : Text(_initials,
                                    style: const TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.navy)))
                            : null,
                      ),
                    ),
                    InkWell(
                      onTap: _changeAvatar,
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: const BoxDecoration(
                          color: AppColors.navyLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, size: 17, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(_name,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _roleChip(),
              ],
            ),
          ),
          _infoTile(Icons.badge_outlined, tr('name'), _name,
              trailing: IconButton(
                tooltip: tr('editName'),
                icon: Icon(Icons.edit_outlined, color: cs.primary),
                onPressed: _editName,
              )),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _infoTile(Icons.apartment_outlined, tr('department'), _dept),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _infoTile(Icons.verified_user_outlined, tr('role'),
              _isApprover ? tr('approver') : tr('employee')),
        ],
      ),
    );
  }

  Widget _buildProcurementSettingsCard() {
    final cs = Theme.of(context).colorScheme;
    final isCustomLimit = !['Disabled', '1,000 ฿', '5,000 ฿', '10,000 ฿'].contains(_autoApproveLimit);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.business_center_outlined, size: 20, color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(tr('procurementSettings'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ]),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.monetization_on_outlined),
              title: Text(tr('currency')),
              trailing: DropdownButton<String>(
                value: _selectedCurrency,
                underline: const SizedBox(),
                items: _currencies
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) async {
                  if (v == null || v == _selectedCurrency) return;
                  final old = _selectedCurrency;
                  setState(() => _selectedCurrency = v);

                  // บันทึกเฉพาะรหัสสกุลเงิน เช่น THB / USD / EUR
                  final ok = await _persistErp({'default_currency': v.split(' ').first});
                  if (!ok) {
                    if (mounted) setState(() => _selectedCurrency = old);
                    return;
                  }
                  _snack(tr('saved'));
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(tr('budgetAlert')),
                      Text('${_budgetThreshold.toInt()}%',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _budgetThreshold >= 85 ? Colors.red : cs.primary)),
                    ],
                  ),
                  Slider(
                    value: _budgetThreshold,
                    min: 50,
                    max: 100,
                    divisions: 10,
                    label: '${_budgetThreshold.toInt()}%',
                    onChanged: (v) => setState(() => _budgetThreshold = v),
                    // บันทึกลง DB ตอนปล่อยนิ้ว (ไม่ยิงทุกครั้งที่ลาก)
                    onChangeEnd: (v) async {
                      final ok = await _persistErp({'budget_alert_pct': v.toInt()});
                      if (!ok) {
                        if (mounted) setState(() => _budgetThreshold = _savedThreshold);
                        return;
                      }
                      _savedThreshold = v;
                      _snack(tr('saved'));
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr('notiPR')),
              value: _notiNewPR,
              onChanged: (v) async {
                final old = _notiNewPR;
                setState(() => _notiNewPR = v);
                final ok = await _persistErp({'notify_new_pr': v});
                if (!ok) {
                  if (mounted) setState(() => _notiNewPR = old);
                  return;
                }
                _snack(tr('saved'));
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr('notiBudget')),
              value: _notiBudgetWarning,
              onChanged: (v) async {
                final old = _notiBudgetWarning;
                setState(() => _notiBudgetWarning = v);
                final ok = await _persistErp({'notify_budget_critical': v});
                if (!ok) {
                  if (mounted) setState(() => _notiBudgetWarning = old);
                  return;
                }
                _snack(tr('saved'));
              },
            ),
            const Divider(height: 1),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.speed),
              title: Text(tr('autoApproveThreshold')),
              subtitle: const Text('ต้องยืนยันตัวตนก่อนปรับปรุงวงเงิน', style: TextStyle(fontSize: 11, color: Colors.grey)),
              trailing: DropdownButton<String>(
                value: isCustomLimit ? 'CUSTOM' : _autoApproveLimit,
                underline: const SizedBox(),
                items: [
                  DropdownMenuItem(value: 'Disabled', child: Text(tr('disabled'))),
                  const DropdownMenuItem(value: '1,000 ฿', child: Text('1,000 ฿')),
                  const DropdownMenuItem(value: '5,000 ฿', child: Text('5,000 ฿')),
                  const DropdownMenuItem(value: '10,000 ฿', child: Text('10,000 ฿')),
                  DropdownMenuItem(
                    value: 'CUSTOM',
                    child: Text(isCustomLimit ? _autoApproveLimit : tr('customAmount')),
                  ),
                ],
                onChanged: _handleLimitChange,
              ),
            ),
            // ปุ่มจัดการงบประมาณ: แสดงเฉพาะ Approver / Admin
            if (_canManageBudget) ...[
              const Divider(height: 1),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.account_balance_outlined),
                title: Text(tr('budgetAdmin')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BudgetAdminScreen()),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGeneralSettingsCard() {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('settings'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),

            // 1. Theme
            Row(children: [
              Icon(Icons.palette_outlined, size: 20, color: cs.primary),
              const SizedBox(width: 8),
              Text(tr('theme'), style: const TextStyle(fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _themeRadioTile(ThemeMode.system, Icons.brightness_auto, tr('system'), cs),
                const SizedBox(height: 8),
                _themeRadioTile(ThemeMode.light, Icons.light_mode, tr('light'), cs),
                const SizedBox(height: 8),
                _themeRadioTile(ThemeMode.dark, Icons.dark_mode, tr('dark'), cs),
              ],
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1),
            ),

            // 2. Language 
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Icon(Icons.language, size: 20, color: cs.primary),
                  const SizedBox(width: 8),
                  Text(tr('language'), style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
                DropdownButton<String>(
                  // อ่านค่าจาก globalLanguage เสมอ
                  value: _availableLanguages.any((l) => l.code == globalLanguage.value) 
                      ? globalLanguage.value 
                      : 'en',
                  underline: const SizedBox(),
                  alignment: AlignmentDirectional.centerEnd,
                  items: _availableLanguages.map((item) {
                    return DropdownMenuItem(
                      value: item.code,
                      child: Text(item.label),
                    );
                  }).toList(),
                  onChanged: (newCode) {
                    if (newCode != null) {
                      // อัปเดต State หลัก
                      globalLanguage.value = newCode;
                      _snack(tr('saved'));
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _themeRadioTile(ThemeMode mode, IconData icon, String label, ColorScheme cs) {
    final isSelected = _themeMode == mode;
    return InkWell(
      onTap: () {
        setState(() => _themeMode = mode);
        widget.onThemeChanged(mode);
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? cs.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? cs.primary : Colors.grey.withOpacity(0.3),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isSelected ? cs.primary : Colors.grey),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? cs.primary : null,
              ),
            ),
            const Spacer(),
            if (isSelected) Icon(Icons.check_circle, size: 18, color: cs.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildHoverLogoutButton() {
    return MouseRegion(
      onEnter: (_) => setState(() => _isLogoutHovered = true),
      onExit: (_) => setState(() => _isLogoutHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: _loggingOut ? null : _logout,
          icon: _loggingOut
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Icon(
                  Icons.logout,
                  color: _isLogoutHovered ? Colors.white : AppColors.danger,
                ),
          label: Text(
            tr('logout'),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: _isLogoutHovered ? Colors.white : AppColors.danger,
            ),
          ),
          style: ElevatedButton.styleFrom(
            elevation: _isLogoutHovered ? 4 : 0,
            backgroundColor: _isLogoutHovered ? const Color(0xFF8B0000) : Colors.transparent, 
            foregroundColor: _isLogoutHovered ? Colors.white : AppColors.danger,
            side: BorderSide(
              color: _isLogoutHovered ? const Color(0xFF8B0000) : AppColors.danger,
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }

  Widget _roleChip() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: _isApprover ? AppColors.warning : Colors.white24,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _isApprover ? tr('approver') : tr('employee'),
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );

  Widget _infoTile(IconData icon, String label, String value, {Widget? trailing}) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: cs.primary),
      title: Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      subtitle: Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: cs.onSurface)),
      trailing: trailing,
    );
  }
}

class _EditNameDialog extends StatefulWidget {
  final String initial;
  final String Function(String) tr;
  const _EditNameDialog({required this.initial, required this.tr});

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _ctrl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tr = widget.tr;
    return AlertDialog(
      title: Text(tr('editName')),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _ctrl,
          autofocus: true,
          decoration: InputDecoration(labelText: tr('name')),
          validator: (v) => (v == null || v.trim().isEmpty) ? tr('nameRequired') : null,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('cancel'))),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, _ctrl.text.trim());
            }
          },
          child: Text(tr('save')),
        ),
      ],
    );
  }
}

// ====== Dialog PIN: โหมดตั้ง PIN ใหม่ (setup) / ตรวจสอบ PIN (verify) ======
// คืนค่า PIN (String) เมื่อสำเร็จ, คืน null เมื่อยกเลิกหรือถูกล็อก
class _PinDialog extends StatefulWidget {
  final String Function(String) tr;
  final bool setup;
  final bool Function(String)? verify;
  final VoidCallback? onLocked;

  const _PinDialog({
    required this.tr,
    required this.setup,
    this.verify,
    this.onLocked,
  });

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  static const int _maxAttempts = 5;

  final _pinCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String? _error;
  int _attempts = 0;

  @override
  void dispose() {
    _pinCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final tr = widget.tr;
    final pin = _pinCtrl.text.trim();

    if (widget.setup) {
      if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
        setState(() => _error = tr('pinInvalid'));
        return;
      }
      if (pin != _confirmCtrl.text.trim()) {
        setState(() => _error = tr('pinMismatch'));
        return;
      }
      Navigator.pop(context, pin);
      return;
    }

    // โหมดตรวจสอบ PIN
    if (widget.verify?.call(pin) == true) {
      Navigator.pop(context, pin);
      return;
    }
    _attempts++;
    if (_attempts >= _maxAttempts) {
      widget.onLocked?.call();
      Navigator.pop(context);
      return;
    }
    setState(() {
      _error = '${tr('authError')} (${_maxAttempts - _attempts})';
      _pinCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tr = widget.tr;
    final formatters = [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(6),
    ];

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.security, color: AppColors.navyLight),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.setup ? tr('pinSetupTitle') : tr('authTitle'),
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.setup ? tr('pinSetupDesc') : tr('authDesc'),
              style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(height: 12),
          TextField(
            controller: _pinCtrl,
            obscureText: true,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: formatters,
            onSubmitted: (_) => widget.setup ? null : _submit(),
            decoration: InputDecoration(
              hintText: widget.setup ? tr('pinNew') : tr('pinHint'),
              prefixIcon: const Icon(Icons.lock_outline),
              errorText: widget.setup ? null : _error,
            ),
          ),
          if (widget.setup) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _confirmCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: formatters,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: tr('pinConfirm'),
                prefixIcon: const Icon(Icons.lock_reset),
                errorText: _error,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(tr('cancel'))),
        ElevatedButton(onPressed: _submit, child: Text(tr('confirm'))),
      ],
    );
  }
}

// ====== Dummy Widget: หน้าจัดการงบประมาณองค์กร (แทนที่ด้วยหน้าจริงภายหลัง) ======
class BudgetAdminScreen extends StatelessWidget {
  const BudgetAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('จัดการงบประมาณ (Budget Management)')),
      body: const Center(child: Text('Budget Admin - Coming soon')),
    );
  }
}