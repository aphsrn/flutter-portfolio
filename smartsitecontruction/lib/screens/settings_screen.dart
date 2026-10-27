import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 🚀 ใช้ Riverpod ควบคุมธีม
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/app_settings_provider.dart'; // 🚀 เรียกใช้ตัวควบคุมโหมดมืด
import 'login_screen.dart'; 

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isEditing = false;

  String _role = '';
  String _email = '';
  String? _avatarUrl; // ลิงก์รูปภาพจากเซิร์ฟเวอร์

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _notifyRequest = true;
  bool _notifyLowStock = true;
  bool _notifyDailyReport = false;

  String _selectedLanguage = 'ไทย';

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifyRequest = prefs.getBool('notifyRequest') ?? true;
      _notifyLowStock = prefs.getBool('notifyLowStock') ?? true;
      _notifyDailyReport = prefs.getBool('notifyDailyReport') ?? false;
    });
  }

  Future<void> _saveNotificationSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  // 🚀 ดึงข้อมูลผู้ใช้จากตาราง รวมถึงรูปโปรไฟล์ล่าสุด
  Future<void> _fetchUserData() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      _email = user.email ?? '';
      try {
        final data = await _supabase.from('users').select().eq('id', user.id).single();
        setState(() {
          _nameController.text = data['full_name'] ?? '';
          _phoneController.text = data['phone'] ?? '';
          _role = data['role'] ?? 'no role';
          _avatarUrl = data['avatar_url']; // ดึง URL รูปภาพ
          _isLoading = false;
        });
      } catch (e) {
        debugPrint('ดึงข้อมูลล้มเหลว: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  // 🚀 เลือกรูปภาพและอัปโหลดขึ้น Supabase Storage ทันทีเพื่อบันทึกถาวร
  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
      if (image == null) return;

      setState(() => _isLoading = true);
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final bytes = await image.readAsBytes();
      final fileExt = image.path.split('.').last;
      final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'profile_pics/$fileName';

      // 1. อัปโหลดไฟล์เข้า Bucket ที่ชื่อ 'site_photos'
      await _supabase.storage.from('site_photos').uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      // 2. ดึง Public URL ของรูปภาพที่อัปโหลดสำเร็จ
      final String publicUrl = _supabase.storage.from('site_photos').getPublicUrl(filePath);

      // 3. บันทึก URL ลงตารางข้อมูลผู้ใช้
      await _supabase.from('users').update({'avatar_url': publicUrl}).eq('id', user.id);

      setState(() {
        _avatarUrl = publicUrl;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('อัปเดตรูปโปรไฟล์สำเร็จ!')));
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('อัปเดตรูปภาพล้มเหลว: $e')));
    }
  }

  // 🚀 บันทึกชื่อและเบอร์โทรลงฐานข้อมูล
  Future<void> _saveUserData() async {
    setState(() => _isLoading = true);
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        await _supabase.from('users').update({
          'full_name': _nameController.text,
          'phone': _phoneController.text,
        }).eq('id', user.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกข้อมูลสำเร็จ!')));
          setState(() {
            _isEditing = false;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _signOut() async {
    await _supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false, 
      );
    }
  }

// 🚀 1. ฟังก์ชันแปลภาษา
  String tr(String th, String en, String currentLang) {
    return currentLang == 'English' ? en : th;
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(isDarkModeProvider);
    final currentLanguage = ref.watch(languageProvider); // 🚀 2. ดึงค่าภาษาปัจจุบัน

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: Text(tr('ตั้งค่า', 'Settings', currentLanguage), style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
        backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : const Color(0xFFF4F6FB),
        elevation: 0,
        iconTheme: IconThemeData(color: isDarkMode ? Colors.white : Colors.black87),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tr('บัญชีและโปรไฟล์', 'Account & Profile', currentLanguage), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 12),
                
                // 🔹 กล่องโปรไฟล์
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white, 
                    borderRadius: BorderRadius.circular(16), 
                    border: Border.all(color: isDarkMode ? Colors.transparent : Colors.grey.shade200),
                  ),
                  child: Column(
                     children: [
                      // ส่วนรูปภาพโปรไฟล์จริง
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          _avatarUrl != null
                              ? CircleAvatar(radius: 40, backgroundImage: NetworkImage(_avatarUrl!))
                              : const CircleAvatar(radius: 40, backgroundColor: Color(0xFFE8EEFF), child: Icon(Icons.person, size: 40, color: Colors.grey)),
                          CircleAvatar(
                            radius: 14, 
                            backgroundColor: const Color(0xFF4F6EF7), 
                            child: IconButton(
                              padding: EdgeInsets.zero, 
                              icon: const Icon(Icons.camera_alt, size: 14, color: Colors.white), 
                              onPressed: _pickAndUploadImage,
                            )
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      if (!_isEditing) ...[
                        Text(_nameController.text.isEmpty ? tr('ยังไม่ได้ตั้งชื่อ', 'Not set', currentLanguage) : _nameController.text, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)),
                        const SizedBox(height: 4),
                        Text('Role: ${_role.toLowerCase()}', style: const TextStyle(color: Colors.blue, fontSize: 14)),
                      ] else ...[
                        TextField(controller: _nameController, style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87), decoration: InputDecoration(labelText: tr('ชื่อ-นามสกุล', 'Full Name', currentLanguage), border: const OutlineInputBorder()), textAlign: TextAlign.center),
                      ],
                      
                      Padding(padding: const EdgeInsets.symmetric(vertical: 16.0), child: Divider(color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200)),
                      
                      Row(
                        children: [
                          const Icon(Icons.email, color: Colors.grey, size: 20),
                          const SizedBox(width: 16),
                          const Text('Email: ', style: TextStyle(color: Colors.grey)),
                          Expanded(child: Text(_email, textAlign: TextAlign.right, style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87))),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          const Icon(Icons.phone, color: Colors.grey, size: 20),
                          const SizedBox(width: 16),
                          const Text('Phone: ', style: TextStyle(color: Colors.grey)),
                          Expanded(
                            child: _isEditing 
                                ? TextField(controller: _phoneController, style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87), decoration: InputDecoration(hintText: tr('กรอกเบอร์โทรศัพท์', 'Enter Phone', currentLanguage), isDense: true), textAlign: TextAlign.right)
                                : Text(_phoneController.text.isEmpty ? '-' : _phoneController.text, textAlign: TextAlign.right, style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: _isEditing
                            ? ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                                icon: const Icon(Icons.save),
                                label: Text(tr('บันทึกข้อมูล', 'Save Data', currentLanguage)),
                                onPressed: _saveUserData,
                              )
                            : OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(foregroundColor: isDarkMode ? Colors.white : Colors.black87, side: BorderSide(color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
                                icon: const Icon(Icons.edit, size: 18),
                                label: Text(tr('แก้ไขโปรไฟล์', 'Edit Profile', currentLanguage)),
                                onPressed: () => setState(() => _isEditing = true),
                              ),
                      ),
                      
                      if (_isEditing) ...[
                        const SizedBox(height: 8),
                        TextButton(onPressed: () {
                          setState(() {
                            _isEditing = false;
                            _fetchUserData(); 
                          });
                        }, child: Text(tr('ยกเลิก', 'Cancel', currentLanguage), style: const TextStyle(color: Colors.red))),
                      ]
                    ],
                  ),
                ),

                const SizedBox(height: 32),
                
                // 🔹 ส่วนการแสดงผลและภาษา
                Text(tr('การแสดงผลและภาษา', 'Display & Language', currentLanguage), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDarkMode ? Colors.transparent : Colors.grey.shade200)),
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.language, color: Colors.grey),
                        title: Text(tr('ภาษา (Language)', 'Language (ภาษา)', currentLanguage), style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87)),
                        trailing: DropdownButton<String>(
                          value: currentLanguage, // 🚀 3. ใช้ state จาก Riverpod
                          dropdownColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
                          underline: const SizedBox(),
                          items: ['ไทย', 'English'].map((String val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              // 🚀 4. สั่งเปลี่ยนภาษาทั่วแอป
                              ref.read(languageProvider.notifier).state = val;
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('เปลี่ยนภาษาเป็น $val สำเร็จ', 'Language changed to $val', val))));
                            }
                          },
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(isDarkMode ? Icons.dark_mode : Icons.dark_mode_outlined, color: Colors.grey),
                        title: Text(tr('ธีม (Theme)', 'Theme (ธีม)', currentLanguage), style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87)),
                        trailing: DropdownButton<String>(
                          value: isDarkMode ? tr('โหมดมืด (Dark)', 'Dark Mode', currentLanguage) : tr('โหมดสว่าง (Light)', 'Light Mode', currentLanguage),
                          dropdownColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
                          style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
                          underline: const SizedBox(),
                          items: [tr('โหมดสว่าง (Light)', 'Light Mode', currentLanguage), tr('โหมดมืด (Dark)', 'Dark Mode', currentLanguage)].map((String val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              ref.read(isDarkModeProvider.notifier).state = (val == tr('โหมดมืด (Dark)', 'Dark Mode', currentLanguage));
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // 🔹 ส่วนการแจ้งเตือน 
                Text(tr('การแจ้งเตือน', 'Notifications', currentLanguage), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDarkMode ? Colors.transparent : Colors.grey.shade200)),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: Text(tr('แจ้งเตือนการขอเบิกวัสดุ', 'Material Request Alerts', currentLanguage), style: TextStyle(fontSize: 14, color: isDarkMode ? Colors.white : Colors.black87)),
                        subtitle: Text(tr('เมื่อมีคำขอเบิกจากหน้างาน', 'When requested from site', currentLanguage), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        value: _notifyRequest,
                        activeColor: const Color(0xFF4F6EF7),
                        onChanged: (val) {
                          setState(() => _notifyRequest = val);
                          _saveNotificationSetting('notifyRequest', val);
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: Text(tr('แจ้งเตือนวัสดุใกล้หมด', 'Low Stock Alerts', currentLanguage), style: TextStyle(fontSize: 14, color: isDarkMode ? Colors.white : Colors.black87)),
                        subtitle: Text(tr('เมื่อสต๊อกต่ำกว่าโควต้า', 'When stock is below quota', currentLanguage), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        value: _notifyLowStock,
                        activeColor: const Color(0xFF4F6EF7),
                        onChanged: (val) {
                          setState(() => _notifyLowStock = val);
                          _saveNotificationSetting('notifyLowStock', val);
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: Text(tr('แจ้งเตือนรายงานประจำวัน', 'Daily Report Alerts', currentLanguage), style: TextStyle(fontSize: 14, color: isDarkMode ? Colors.white : Colors.black87)),
                        value: _notifyDailyReport,
                        activeColor: const Color(0xFF4F6EF7),
                        onChanged: (val) {
                          setState(() => _notifyDailyReport = val);
                          _saveNotificationSetting('notifyDailyReport', val);
                        },
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),

                // 🚪 ปุ่มออกจากระบบ 
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.05), 
                      foregroundColor: Colors.red, 
                      elevation: 0,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.logout),
                    label: Text(tr('ออกจากระบบ', 'Sign Out', currentLanguage), style: const TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: _signOut,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
    );
  }
}