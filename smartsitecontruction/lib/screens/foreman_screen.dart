import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'login_screen.dart';
import 'settings_screen.dart';

class ForemanScreen extends StatefulWidget {
  const ForemanScreen({Key? key}) : super(key: key);

  @override
  State<ForemanScreen> createState() => _ForemanScreenState();
}

class _ForemanScreenState extends State<ForemanScreen> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _projects = [];
  String? _selectedProjectId;
  String? _selectedProjectName;
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
        setState(() {
          _avatarUrl = data['avatar_url'];
        });
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
        if (_projects.isNotEmpty) {
          _selectedProjectId = _projects[0]['id'];
          _selectedProjectName = _projects[0]['name'];
        }
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void _showSafetyChecklist() {
    if (_selectedProjectId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาเลือกโครงการก่อน!')));
      return;
    }

    bool check1 = false;
    bool check2 = false;
    bool check3 = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.health_and_safety, color: Colors.green),
                SizedBox(width: 8),
                Text(
                  'Checklist ก่อนเริ่มงาน',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'โครงการ: $_selectedProjectName',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      title: const Text('ตรวจสอบอุปกรณ์เซฟตี้คนงานครบถ้วน'),
                      value: check1,
                      onChanged: (val) => setStateDialog(() => check1 = val!),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    CheckboxListTile(
                      title: const Text(
                        'ตรวจสอบเครื่องจักรและนั่งร้านอยู่ในสภาพพร้อมใช้งาน',
                      ),
                      value: check2,
                      onChanged: (val) => setStateDialog(() => check2 = val!),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    CheckboxListTile(
                      title: const Text(
                        'เช็คจำนวนคนงานและวัสดุหน้างานตรงตามแผนวันนี้',
                      ),
                      value: check3,
                      onChanged: (val) => setStateDialog(() => check3 = val!),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                    const Divider(height: 32),
                    const Text(
                      'พบปัญหาหน้างาน?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                      onPressed: () => _showIssueReportDialog(context),
                      icon: const Icon(Icons.warning_amber_rounded),
                      label: const Text('แจ้งเหตุ / ของหาย / ถ่ายรูปปัญหา'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'ยกเลิก',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  if (check1 && check2 && check3) {
                    try {
                      // 🚀 ใช้ชื่อตารางที่ถูกต้อง safety_checklists
                      await _supabase.from('safety_checklists').insert({
                        'project_id': _selectedProjectId,
                        // 'submitted_by': _supabase.auth.currentUser!.id, // ลองคอมเมนต์บรรทัดนี้ออกชั่วคราว
                        'items': {
                          'safety_gear': check1,
                          'scaffold_ready': check2,
                          'plan_matched': check3,
                        },
                        'notes': 'Daily safety check completed.',
                      });

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'ส่งรายงานความปลอดภัยเรียบร้อยแล้ว เริ่มงานได้!',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      print("DEBUG: เกิดข้อผิดพลาดตอนส่งข้อมูล: $e");

                      // 🚀 บรรทัดนี้จะบังคับให้แอปโชว์ Error สีแดงบอกเราทันทีที่หน้าจอ
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                            duration: const Duration(
                              seconds: 10,
                            ), // ให้โชว์นานหน่อยจะได้อ่านทัน
                          ),
                        );
                      }
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('กรุณาตรวจสอบให้ครบทุกข้อก่อนเริ่มงาน'),
                      ),
                    );
                  }
                },
                child: const Text('ยืนยันความพร้อม'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showIssueReportDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'เลือกประเภทปัญหา',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.report_problem, color: Colors.orange),
                title: const Text('แจ้งเหตุ'),
                onTap: () {
                  Navigator.pop(context);
                  _showIssueDetailInputDialog('แจ้งเหตุ');
                },
              ),
              ListTile(
                leading: const Icon(Icons.search_off, color: Colors.red),
                title: const Text('ของหาย'),
                onTap: () {
                  Navigator.pop(context);
                  _showIssueDetailInputDialog('ของหาย');
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.blue),
                title: const Text('ถ่ายรูปปัญหา'),
                onTap: () {
                  Navigator.pop(context);
                  _showIssueDetailInputDialog('ถ่ายรูปปัญหา');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showIssueDetailInputDialog(String issueType) {
    final TextEditingController detailController = TextEditingController();
    String hintText = issueType == 'แจ้งเหตุ'
        ? 'แจ้งอะไรบ้าง...'
        : issueType == 'ของหาย'
        ? 'ของอะไรหาย...'
        : 'มีอะไรเกิดขึ้นหน้างาน...';

    XFile? selectedImage;
    Uint8List? selectedImageBytes; // 🚀 ตัวแปรเก็บไบต์รูปภาพแก้ปัญหาเว็บค้าง
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text('รายละเอียด ($issueType)'),
              content: SizedBox(
                width: double.maxFinite, // 🚀 ป้องกัน Error Render Box Layout
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: detailController,
                        decoration: InputDecoration(
                          hintText: hintText,
                          border: const OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final ImagePicker picker = ImagePicker();
                                showModalBottomSheet(
                                  context: context,
                                  builder: (BuildContext context) {
                                    return SafeArea(
                                      child: Wrap(
                                        children: <Widget>[
                                          ListTile(
                                            leading: const Icon(
                                              Icons.photo_library,
                                            ),
                                            title: const Text(
                                              'เลือกจากคลังรูปภาพ',
                                            ),
                                            onTap: () async {
                                              Navigator.of(context).pop();
                                              FocusScope.of(
                                                context,
                                              ).unfocus(); // 🚀 เคลียร์ Focus ก่อนเปิดไฟล์
                                              try {
                                                final XFile? image =
                                                    await picker.pickImage(
                                                      source:
                                                          ImageSource.gallery,
                                                    );
                                                if (image != null) {
                                                  final bytes = await image
                                                      .readAsBytes();
                                                  setStateDialog(() {
                                                    selectedImage = image;
                                                    selectedImageBytes = bytes;
                                                  });
                                                }
                                              } catch (e) {
                                                debugPrint('Error: $e');
                                              }
                                            },
                                          ),
                                          ListTile(
                                            leading: const Icon(
                                              Icons.photo_camera,
                                            ),
                                            title: const Text('ถ่ายรูป'),
                                            onTap: () async {
                                              Navigator.of(context).pop();
                                              FocusScope.of(
                                                context,
                                              ).unfocus(); // 🚀 เคลียร์ Focus ก่อนเปิดกล้อง
                                              try {
                                                final XFile? image =
                                                    await picker.pickImage(
                                                      source:
                                                          ImageSource.camera,
                                                    );
                                                if (image != null) {
                                                  final bytes = await image
                                                      .readAsBytes();
                                                  setStateDialog(() {
                                                    selectedImage = image;
                                                    selectedImageBytes = bytes;
                                                  });
                                                }
                                              } catch (e) {
                                                debugPrint('Error: $e');
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                              icon: const Icon(Icons.add_a_photo),
                              label: Text(
                                selectedImage == null
                                    ? 'เพิ่มรูปภาพ'
                                    : 'เปลี่ยนรูปภาพ',
                              ),
                            ),
                          ),
                        ],
                      ),

                      // 🚀 โชว์รูปผ่าน Memory ไหลลื่น 100% บนเว็บ
                      if (selectedImageBytes != null) ...[
                        const SizedBox(height: 16),
                        Stack(
                          alignment: Alignment.topRight,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                selectedImageBytes!,
                                height: 150,
                                width: double.maxFinite,
                                fit: BoxFit.cover,
                              ),
                            ),
                            IconButton(
                              icon: const CircleAvatar(
                                backgroundColor: Colors.white70,
                                child: Icon(
                                  Icons.cancel,
                                  color: Colors.red,
                                  size: 24,
                                ),
                              ),
                              onPressed: () => setStateDialog(() {
                                selectedImage = null;
                                selectedImageBytes = null;
                              }),
                            ),
                          ],
                        ),
                      ],

                      if (isUploading) ...[
                        const SizedBox(height: 16),
                        const Center(child: CircularProgressIndicator()),
                        const SizedBox(height: 8),
                        const Center(
                          child: Text(
                            'กำลังบันทึกข้อมูล...',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isUploading ? null : () => Navigator.pop(context),
                  child: const Text(
                    'ยกเลิก',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed:
                      (isUploading ||
                          detailController.text.isEmpty ||
                          selectedImage == null)
                      ? null
                      : () async {
                          setStateDialog(() => isUploading = true);
                          bool success = await _submitReport(
                            issueType,
                            selectedImage,
                            selectedImageBytes, // 🚀 ส่ง bytes ไปอัปโหลด
                            detailController.text,
                          );
                          if (success) {
                            if (context.mounted) {
                              Navigator.pop(context);
                              Navigator.pop(context);
                            }
                          } else {
                            setStateDialog(() => isUploading = false);
                          }
                        },
                  child: const Text('บันทึก'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _submitReport(
    String issueType,
    XFile? image,
    Uint8List? imageBytes,
    String details,
  ) async {
    if (_selectedProjectId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาเลือกโครงการก่อน!')));
      return false;
    }

    try {
      String? imageUrl;
      if (image != null && imageBytes != null) {
        final fileExt = image.name.split('.').last;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final filePath = 'issues/$fileName';

        // 🚀 อัปโหลดจาก bytes โดยตรง เสถียรกว่าบนเว็บ
        await _supabase.storage
            .from('site_photos')
            .uploadBinary(
              filePath,
              imageBytes,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: true,
              ),
            );

        imageUrl = _supabase.storage.from('site_photos').getPublicUrl(filePath);
      }

      await _supabase.from('issues').insert({
        'project_id': _selectedProjectId,
        'issue_type': issueType,
        'description': details,
        'image_url': imageUrl,
        'reported_by': _supabase.auth.currentUser?.id,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('บันทึกข้อมูล $issueType เข้าระบบเรียบร้อย'),
          backgroundColor: Colors.green,
        ),
      );
      return true;
    } catch (e) {
      debugPrint('Error: $e');
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }

  void _showAdvancedRequestForm() async {
    if (_selectedProjectId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาเลือกโครงการก่อน!')));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('กำลังดึงรายการวัสดุจาก BOQ...')),
    );
    List<Map<String, dynamic>> boqItems = [];
    try {
      final data = await _supabase
          .from('boq_items')
          .select()
          .eq('project_id', _selectedProjectId!);
      boqItems = List<Map<String, dynamic>>.from(data);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      debugPrint('ดึง BOQ ไม่สำเร็จ: $e');
    }

    final List<String> boqItemNames = boqItems
        .map((e) => e['name'].toString())
        .toList();
    if (!mounted) return;

    final itemController = TextEditingController();
    final qtyController = TextEditingController();
    final reasonController = TextEditingController();

    String selectedCategory = 'วัสดุหลัก';
    String selectedType = 'ตามแผน (โควต้า BOQ)';

    XFile? requestImage;
    Uint8List? requestImageBytes; // 🚀 แก้เว็บค้างตอนเบิกวัสดุ
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text(
              'เบิกวัสดุ: $_selectedProjectName',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            content: SizedBox(
              width: double.maxFinite, // 🚀 ป้องกัน Error Render Box
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'หมวดหมู่วัสดุ:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: selectedCategory,
                      items: ['วัสดุหลัก', 'วัสดุสิ้นเปลือง']
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setStateDialog(() => selectedCategory = val!),
                    ),
                    const SizedBox(height: 12),

                    const Text(
                      'ชื่อวัสดุ (อ้างอิงจาก BOQ):',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Autocomplete<String>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) return boqItemNames;
                        return boqItemNames.where(
                          (String option) => option.toLowerCase().contains(
                            textEditingValue.text.toLowerCase(),
                          ),
                        );
                      },
                      onSelected: (String selection) =>
                          itemController.text = selection,
                      fieldViewBuilder:
                          (
                            context,
                            textEditingController,
                            focusNode,
                            onFieldSubmitted,
                          ) {
                            return TextField(
                              controller: textEditingController,
                              focusNode: focusNode,
                              decoration: const InputDecoration(
                                hintText: 'คลิกเพื่อเลือก หรือพิมพ์ค้นหา...',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.search),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                              onChanged: (val) => itemController.text = val,
                            );
                          },
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: qtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'จำนวนที่ต้องการเบิก (เช่น 50)',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'ประเภทการเบิก:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    DropdownButton<String>(
                      isExpanded: true,
                      value: selectedType,
                      items:
                          [
                                'ตามแผน (โควต้า BOQ)',
                                'ฉุกเฉิน/นอกแผน (สั่งเพิ่ม)',
                                'แจ้งของเสียหาย/แตกหัก',
                              ]
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                      onChanged: (val) =>
                          setStateDialog(() => selectedType = val!),
                    ),
                    const SizedBox(height: 16),

                    if (selectedType != 'ตามแผน (โควต้า BOQ)') ...[
                      TextField(
                        controller: reasonController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText:
                              'ระบุเหตุผลที่ต้องเบิกเพิ่ม / สาเหตุความเสียหาย',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    const Text(
                      'รูปภาพประกอบ (ถ้ามี):',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),

                    // 🚀 โชว์พรีวิวรูปบนเว็บแบบ Memory
                    if (requestImageBytes != null) ...[
                      Stack(
                        alignment: Alignment.topRight,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.memory(
                              requestImageBytes!,
                              height: 120,
                              width: double.maxFinite,
                              fit: BoxFit.cover,
                            ),
                          ),
                          IconButton(
                            icon: const CircleAvatar(
                              backgroundColor: Colors.white70,
                              child: Icon(
                                Icons.cancel,
                                color: Colors.red,
                                size: 24,
                              ),
                            ),
                            onPressed: () => setStateDialog(() {
                              requestImage = null;
                              requestImageBytes = null;
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],

                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade50,
                              foregroundColor: Colors.blue,
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.camera_alt, size: 18),
                            label: const Text('ถ่ายรูป'),
                            onPressed: () async {
                              FocusScope.of(
                                context,
                              ).unfocus(); // 🚀 เคลียร์โฟกัสป้องกันจอลอยขาว
                              try {
                                final ImagePicker picker = ImagePicker();
                                final XFile? image = await picker.pickImage(
                                  source: ImageSource.camera,
                                );
                                if (image != null) {
                                  final bytes = await image.readAsBytes();
                                  setStateDialog(() {
                                    requestImage = image;
                                    requestImageBytes = bytes;
                                  });
                                }
                              } catch (e) {
                                debugPrint('Error: $e');
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey.shade100,
                              foregroundColor: Colors.black87,
                              elevation: 0,
                            ),
                            icon: const Icon(Icons.photo_library, size: 18),
                            label: const Text('คลังภาพ'),
                            onPressed: () async {
                              FocusScope.of(
                                context,
                              ).unfocus(); // 🚀 เคลียร์โฟกัสป้องกันจอลอยขาว
                              try {
                                final ImagePicker picker = ImagePicker();
                                final XFile? image = await picker.pickImage(
                                  source: ImageSource.gallery,
                                );
                                if (image != null) {
                                  final bytes = await image.readAsBytes();
                                  setStateDialog(() {
                                    requestImage = image;
                                    requestImageBytes = bytes;
                                  });
                                }
                              } catch (e) {
                                debugPrint('Error: $e');
                              }
                            },
                          ),
                        ),
                      ],
                    ),

                    if (isUploading) ...[
                      const SizedBox(height: 16),
                      const Center(child: CircularProgressIndicator()),
                      const SizedBox(height: 8),
                      const Center(
                        child: Text(
                          'กำลังส่งคำขอเบิก...',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isUploading ? null : () => Navigator.pop(context),
                child: const Text(
                  'ยกเลิก',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F6EF7),
                  foregroundColor: Colors.white,
                ),
                onPressed:
                    (isUploading ||
                        itemController.text.isEmpty ||
                        qtyController.text.isEmpty ||
                        (selectedType == 'แจ้งของเสียหาย/แตกหัก' &&
                            requestImage == null))
                    ? null
                    : () async {
                        setStateDialog(() => isUploading = true);

                        try {
                          final user = _supabase.auth.currentUser;
                          String? imageUrl;
                          String? boqId;

                          try {
                            final matchedBoq = boqItems.firstWhere(
                              (element) =>
                                  element['name'] == itemController.text,
                            );
                            boqId = matchedBoq['id'];
                          } catch (_) {}

                          if (requestImage != null &&
                              requestImageBytes != null) {
                            final fileExt = requestImage!.name.split('.').last;
                            final fileName =
                                '${user!.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
                            final filePath = 'material_requests/$fileName';

                            await _supabase.storage
                                .from('site_photos')
                                .uploadBinary(
                                  filePath,
                                  requestImageBytes!, // 🚀 อัปโหลดจาก bytes ชัวร์สุด
                                  fileOptions: const FileOptions(
                                    cacheControl: '3600',
                                    upsert: true,
                                  ),
                                );
                            imageUrl = _supabase.storage
                                .from('site_photos')
                                .getPublicUrl(filePath);
                          }

                          final qtyNumber =
                              double.tryParse(
                                qtyController.text.replaceAll(
                                  RegExp(r'[^0-9.]'),
                                  '',
                                ),
                              ) ??
                              0;

                          await _supabase.from('material_requests').insert({
                            'project_id': _selectedProjectId,
                            'boq_id': boqId,
                            'item_name': itemController.text,
                            'requested_qty':
                                qtyNumber, // 👈 ใช้ตัวนี้ตัวเดียว (เก็บค่าเป็นตัวเลขจริง)
                            'status': 'pending',
                            'requested_by': user!.id,
                            'image_url': imageUrl,
                            'created_at': DateTime.now()
                                .toIso8601String(), // ถ้าใน DB มี default now() แล้ว จะใส่หรือไม่ใส่ก็ได้ครับ
                          });

                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('ส่งคำขอเบิกเรียบร้อย!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          debugPrint('Error: $e');
                          setStateDialog(() => isUploading = false);
                          if (mounted)
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('ส่งคำขอล้มเหลว: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                        }
                      },
                child: const Text('ส่งคำขอเบิก'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text(
          'หน้างาน (Foreman)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
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
              if (context.mounted)
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'เลือกโครงการ:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedProjectId,
                        items: _projects
                            .map(
                              (proj) => DropdownMenuItem<String>(
                                value: proj['id'],
                                child: Text(
                                  proj['name'],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedProjectId = val;
                            _selectedProjectName = _projects.firstWhere(
                              (p) => p['id'] == val,
                            )['name'];
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  const Text(
                    'เมนูการทำงาน',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 1.1,
                      children: [
                        _buildMenuCard(
                          title: 'Safety & Site Audit',
                          icon: Icons.health_and_safety,
                          color: Colors.green,
                          onTap: _showSafetyChecklist,
                        ),
                        _buildMenuCard(
                          title: 'เบิกวัสดุ',
                          icon: Icons.inventory,
                          color: const Color(0xFF4F6EF7),
                          onTap: _showAdvancedRequestForm,
                        ),
                        _buildMenuCard(
                          title: 'เช็คตารางงาน',
                          icon: Icons.calendar_month,
                          color: Colors.orange,
                          onTap: _showScheduleDialog,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _showScheduleDialog() {
    if (_selectedProjectId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณาเลือกโครงการก่อน!')));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'ตารางงาน',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<dynamic>>(
                  future: _supabase
                      .from('tasks')
                      .select()
                      .eq('project_id', _selectedProjectId!)
                      .order('due_at', ascending: true),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return const Center(child: CircularProgressIndicator());
                    if (snapshot.hasError)
                      return Center(
                        child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'),
                      );

                    final tasks = snapshot.data ?? [];
                    if (tasks.isEmpty)
                      return const Center(
                        child: Text(
                          'ไม่มีตารางงานสำหรับโครงการนี้',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );

                    final now = DateTime.now();
                    final today = DateTime(now.year, now.month, now.day);
                    final tomorrow = today.add(const Duration(days: 1));
                    final dayAfterTomorrow = today.add(const Duration(days: 2));

                    List<dynamic> todayTasks = [],
                        tomorrowTasks = [],
                        dayAfterTasks = [],
                        laterTasks = [],
                        overdueTasks = [];

                    for (var task in tasks) {
                      if (task['due_at'] == null) {
                        laterTasks.add(task);
                        continue;
                      }
                      final dueAt = DateTime.parse(task['due_at']).toLocal();
                      final dueDate = DateTime(
                        dueAt.year,
                        dueAt.month,
                        dueAt.day,
                      );

                      if (dueDate.isBefore(today))
                        overdueTasks.add(task);
                      else if (dueDate.isAtSameMomentAs(today))
                        todayTasks.add(task);
                      else if (dueDate.isAtSameMomentAs(tomorrow))
                        tomorrowTasks.add(task);
                      else if (dueDate.isAtSameMomentAs(dayAfterTomorrow))
                        dayAfterTasks.add(task);
                      else
                        laterTasks.add(task);
                    }

                    return ListView(
                      children: [
                        if (overdueTasks.isNotEmpty)
                          _buildTaskSection(
                            'เลยกำหนด',
                            overdueTasks,
                            Colors.red,
                          ),
                        _buildTaskSection('วันนี้', todayTasks, Colors.green),
                        _buildTaskSection(
                          'พรุ่งนี้',
                          tomorrowTasks,
                          Colors.blue,
                        ),
                        _buildTaskSection(
                          'มะรืนนี้',
                          dayAfterTasks,
                          Colors.orange,
                        ),
                        if (laterTasks.isNotEmpty)
                          _buildTaskSection(
                            'วันอื่นๆ',
                            laterTasks,
                            Colors.grey,
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTaskSection(String title, List<dynamic> tasks, Color color) {
    if (tasks.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        ...tasks.map(
          (task) => Card(
            elevation: 1,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(
                task['title']?.toString() ?? 'ไม่มีชื่องาน',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                task['description']?.toString() ?? 'ไม่มีรายละเอียด',
              ),
              trailing: _buildStatusChip(
                task['status']?.toString() ?? 'pending',
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = status.toLowerCase() == 'completed'
        ? Colors.green
        : status.toLowerCase() == 'in_progress'
        ? Colors.blue
        : Colors.orange;
    String label = status.toLowerCase() == 'completed'
        ? 'เสร็จแล้ว'
        : status.toLowerCase() == 'in_progress'
        ? 'กำลังทำ'
        : 'รอดำเนินการ';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, color: Colors.white),
      ),
    );
  }

  Widget _buildMenuCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, size: 32, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
