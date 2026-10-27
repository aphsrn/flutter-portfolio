import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart'; // Import kIsWeb
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../models/boq_item.dart';
import '../services/supabase_providers.dart';

const Color _textMuted = Colors.grey;

// ── Request Type Enum ────────────────────────────────────────────────────────
enum RequestType { withinQuota, exceedsQuota, newMaterial }

extension RequestTypeExtension on RequestType {
  String toThaiString() {
    switch (this) {
      case RequestType.withinQuota:
        return 'อยู่ในโควต้า';
      case RequestType.exceedsQuota:
        return 'เบิกเกินโควต้า';
      case RequestType.newMaterial:
        return 'เพิ่มวัสดุใหม่';
    }
  }
}

// ── Local state ──────────────────────────────────────────────────────────────
class _FormState {
  final BOQItem? selectedItem;
  final bool isSubmitting;
  final RequestType selectedRequestType;

  const _FormState({
    this.selectedItem,
    this.isSubmitting = false,
    this.selectedRequestType = RequestType.withinQuota,
  });

  _FormState copyWith({
    BOQItem? selectedItem,
    bool? isSubmitting,
    RequestType? selectedRequestType,
  }) {
    return _FormState(
      selectedItem: selectedItem, // Allow nulling out the item
      isSubmitting: isSubmitting ?? this.isSubmitting,
      selectedRequestType: selectedRequestType ?? this.selectedRequestType,
    );
  }
}

final _formStateProvider = StateProvider.autoDispose<_FormState>(
  (_) => const _FormState(),
);

// ── Screen ───────────────────────────────────────────────────────────────────
class MaterialRequestScreen extends ConsumerStatefulWidget {
  final String projectId;
  const MaterialRequestScreen({super.key, required this.projectId});

  @override
  ConsumerState<MaterialRequestScreen> createState() =>
      _MaterialRequestScreenState();
}

class _MaterialRequestScreenState extends ConsumerState<MaterialRequestScreen> {
  final _qtyController = TextEditingController();
  final _customItemController = TextEditingController();
  String _newItemName = '';
  final _formKey = GlobalKey<FormState>();
  XFile? _pickedImageFile; // Use XFile for web compatibility

  // ── Palette ─────────────────────────────────────────────────────────────
  static const _bg = Color(0xFFF5F7FA);
  static const _surface = Color(0xFFFFFFFF);
  static const _primary = Color(0xFF4F6EF7);
  static const _primaryLight = Color(0xFFEEF1FE);
  static const _warning = Color(0xFFFFF3E0);
  static const _warningAccent = Color(0xFFE65100);
  static const _success = Color(0xFFE8F5E9);
  static const _successAccent = Color(0xFF2E7D32);
  static const _textDark = Color(0xFF1A1D23);
  static const _danger = Color(0xFFFFEBEE);
  static const _dangerAccent = Color(0xFFC62828);

  @override
  void dispose() {
    _qtyController.dispose();
    _customItemController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _pickedImageFile = pickedFile;
      });
    }
  }

  Future<String?> _uploadImage(XFile image) async {
    final client = ref.read(supabaseClientProvider);
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final filePath = 'site_photos/$fileName';

    try {
      final bytes = await image.readAsBytes(); // Read as bytes for upload
      await client.storage
          .from('site_photos')
          .uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
      final response = client.storage
          .from('site_photos')
          .getPublicUrl(filePath);
      return response;
    } on StorageException catch (e) {
      _showSnackBar('Image upload failed: ${e.message}', isError: true);
      return null;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final formState = ref.read(_formStateProvider);
    final selectedBoqItem = formState.selectedItem;
    final customItemName = _customItemController.text.trim();
    final selectedRequestType = formState.selectedRequestType;
    final newMaterialName = _newItemName.trim();
    final itemName = selectedRequestType == RequestType.newMaterial
        ? newMaterialName
        : (selectedBoqItem?.name ?? customItemName);

    if (itemName.isEmpty) {
      _showSnackBar('Please select or enter a material name.', isError: true);
      return;
    }

    ref
        .read(_formStateProvider.notifier)
        .update((s) => s.copyWith(isSubmitting: true));

    final qty = double.tryParse(_qtyController.text.trim()) ?? 0;
    String? imageUrl;

    if (_pickedImageFile != null) {
      imageUrl = await _uploadImage(_pickedImageFile!);
      if (imageUrl == null) {
        ref
            .read(_formStateProvider.notifier)
            .update((s) => s.copyWith(isSubmitting: false));
        return; // Stop submission if upload fails
      }
    }

    // Construct description based on item name and request type
    var description =
        '$itemName (ประเภท: ${selectedRequestType.toThaiString()})';

    // If this is an "exceeds quota" request, append a warning note
    if (selectedRequestType == RequestType.exceedsQuota) {
      description = '$description [แจ้งเตือน: ขอเบิกเกินโควต้าที่กำหนด]';
    }

    final service = ref.read(materialRequestServiceProvider);
    final error = await service.submitRequest(
      projectId: widget.projectId,
      boqItem: selectedBoqItem,
      itemName: itemName,
      requestedQty: qty,
      imageUrl: imageUrl,
      description: description, // Pass the constructed description
      allowExceedQuota: selectedRequestType == RequestType.exceedsQuota,
    );

    ref
        .read(_formStateProvider.notifier)
        .update((s) => s.copyWith(isSubmitting: false));

    if (!mounted) return;

    if (error != null) {
      _showSnackBar('Error: $error', isError: true);
    } else {
      _qtyController.clear();
      _customItemController.clear();
      setState(() {
        _pickedImageFile = null;
        _newItemName = '';
      });
      ref
          .read(_formStateProvider.notifier)
          .update((s) => const _FormState()); // Reset state including request type
      ref.invalidate(materialRequestsProvider(widget.projectId));
      _showSnackBar('✅  Request submitted successfully!', isError: false);
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: isError ? _dangerAccent : _successAccent,
        duration: const Duration(seconds: 4),
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final boqAsync = ref.watch(boqItemsProvider(widget.projectId));
    final formState = ref.watch(_formStateProvider);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        title: const Text(
          'Request Materials',
          style: TextStyle(
            color: _textDark,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFECEFF4)),
        ),
      ),
      body: boqAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _primary)),
        error: (e, _) => _ErrorState(message: e.toString()),
        data: (items) => _buildForm(context, items, formState),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    List<BOQItem> items,
    _FormState formState,
  ) {
    final selected = formState.selectedItem;
    final selectedRequestType = formState.selectedRequestType;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Section label ──────────────────────────────────────────
            const _SectionLabel('Select Material'),
            const SizedBox(height: 10),

            // ── BOQ Dropdown or New Material input ───────────────────────
            selectedRequestType == RequestType.newMaterial
                ? _Card(
                    child: TextFormField(
                      controller: _customItemController,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Type new material name…',
                        hintStyle: TextStyle(color: _textMuted, fontSize: 15),
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: const TextStyle(
                        color: _textDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                      onChanged: (v) => setState(() => _newItemName = v),
                      validator: (v) {
                        if (selectedRequestType == RequestType.newMaterial &&
                            (v == null || v.trim().isEmpty)) {
                          return 'Enter a material name';
                        }
                        return null;
                      },
                    ),
                  )
                : _Card(
                    child: DropdownSearch<BOQItem>(
                      popupProps: PopupProps.menu(
                        showSearchBox: true,
                        searchFieldProps: const TextFieldProps(
                          decoration: InputDecoration(
                            hintText: 'Search or add material...',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                        ),
                        emptyBuilder: (context, searchEntry) {
                          if (searchEntry.trim().isEmpty) return const SizedBox.shrink();
                          return Center(
                            child: TextButton.icon(
                              onPressed: () {
                                ref.read(_formStateProvider.notifier).update((s) => 
                                    s.copyWith(selectedRequestType: RequestType.newMaterial, selectedItem: null));
                                _customItemController.text = searchEntry;
                                setState(() => _newItemName = searchEntry);
                                Navigator.of(context).pop();
                              },
                              icon: const Icon(Icons.add),
                              label: Text('เพิ่มวัสดุใหม่: "$searchEntry"'),
                            ),
                          );
                        },
                      ),
                      items: items,
                      itemAsString: (BOQItem item) => item.name,
                      selectedItem: selected,
                      onChanged: (BOQItem? item) {
                        if (item != null) {
                          ref
                              .read(_formStateProvider.notifier)
                              .update((s) => s.copyWith(selectedItem: item));
                        }
                      },
                      dropdownDecoratorProps: const DropDownDecoratorProps(
                        dropdownSearchDecoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Select material...',
                          hintStyle: TextStyle(color: _textMuted, fontSize: 15),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),

            // ── BOQ Quota card (appears after selection) ───────────────
            if (selected != null) ...[
              const SizedBox(height: 16),
              _QuotaBanner(item: selected),
            ],

            const SizedBox(height: 24),
            const _SectionLabel('Request Type'),
            const SizedBox(height: 10),

            // ── Request Type Dropdown ──────────────────────────────────
            _Card(
              child: DropdownButtonFormField<RequestType>(
                value: selectedRequestType,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Select request type…',
                  hintStyle: TextStyle(color: _textMuted, fontSize: 15),
                  contentPadding: EdgeInsets.zero,
                ),
                icon: const Icon(Icons.expand_more_rounded, color: _primary),
                items: RequestType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(
                          type.toThaiString(),
                          style: const TextStyle(
                            color: _textDark,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (type) {
                  // Update request type and clear BOQ selection when switching to "new material"
                  if (type == RequestType.newMaterial) {
                    _customItemController.clear();
                    setState(() => _newItemName = '');
                    ref
                        .read(_formStateProvider.notifier)
                        .update(
                          (s) => s.copyWith(
                            selectedRequestType: type,
                            selectedItem: null,
                          ),
                        );
                  } else {
                    ref
                        .read(_formStateProvider.notifier)
                        .update((s) => s.copyWith(selectedRequestType: type));
                  }
                },
                validator: (v) =>
                    v == null ? 'Please select a request type' : null,
              ),
            ),

            const SizedBox(height: 24),
            const _SectionLabel('Quantity Requested'),
            const SizedBox(height: 10),

            // ── Quantity input ─────────────────────────────────────────
            _Card(
              child: TextFormField(
                controller: _qtyController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                onChanged: (value) {
                  final selected = formState.selectedItem;
                  if (selected != null) {
                    // 🚀 โควต้าเปลี่ยนเป็นเช็คจากยอดงบประมาณแล้ว (เงิน) 
                    // ดังนั้นถ้าวัสดุหมวดนี้มันทะลุงบไปแล้ว เราจะขึ้นแจ้งเตือนให้โฟร์แมนรู้
                    if (selected.isOverBudget && formState.selectedRequestType != RequestType.exceedsQuota) {
                      ref
                          .read(_formStateProvider.notifier)
                          .update((s) => s.copyWith(selectedRequestType: RequestType.exceedsQuota));
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('แจ้งเตือน: วัสดุนี้เกินงบประมาณ (รออนุมัติพิเศษ)')),
                      );
                    }
                  }
                },
                style: const TextStyle(
                  color: _textDark,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: '0.00',
                  hintStyle: TextStyle(
                    color: _textMuted.withOpacity(0.5),
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                  suffixText:
                      selected?.name.split(" ").firstOrNull ??
                      _customItemController.text
                          .trim()
                          .split(" ")
                          .firstOrNull ??
                      'units',
                  suffixStyle: const TextStyle(
                    color: _textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter a quantity';
                  final n = double.tryParse(v);
                  if (n == null || n <= 0) return 'Enter a valid quantity';
                  return null;
                },
              ),
            ),

            const SizedBox(height: 24),

            // -- Image Picker ──────────────────────────────────────────
            const _SectionLabel('Proof Image (Optional)'),
            const SizedBox(height: 10),

            if (_pickedImageFile != null) ...[
              Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: kIsWeb
                        ? Image.network(
                            _pickedImageFile!.path,
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                          )
                        : Image.file(
                            File(_pickedImageFile!.path),
                            width: double.infinity,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                  ),
                  IconButton(
                    icon: const CircleAvatar(
                      backgroundColor: Colors.black54,
                      child: Icon(Icons.close, color: Colors.white, size: 18),
                    ),
                    onPressed: () => setState(() => _pickedImageFile = null),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ] else
              _Card(
                child: InkWell(
                  onTap: _pickImage,
                  borderRadius: BorderRadius.circular(16),
                  child: const Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          color: _primary,
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Attach a photo',
                          style: TextStyle(
                            color: _primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 32),

            // ── Submit button ──────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                onPressed: formState.isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  disabledBackgroundColor: _primary.withOpacity(0.4),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: formState.isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Submit Request',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Subtle hint ────────────────────────────────────────────
            const Center(
              child: Text(
                'Request will be sent to PM for approval.',
                style: TextStyle(color: _textMuted, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      color: Color(0xFF8A93A4),
      fontSize: 12,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
    ),
  );
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 12,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );
}

class _QuotaBanner extends StatelessWidget {
  final BOQItem item;
  const _QuotaBanner({required this.item});

  static const _primary = Color(0xFF4F6EF7);
  static const _primaryLight = Color(0xFFEEF1FE);
  static const _dangerBg = Color(0xFFFFEBEE);
  static const _dangerAccent = Color(0xFFC62828);

  @override
  Widget build(BuildContext context) {
    // 🚀 อัปเดตสูตรเป็น budgetAmount / actualCost
    final pct = item.budgetAmount == 0
        ? 0.0
        : (item.actualCost / item.budgetAmount).clamp(0.0, 1.0);
    final isOver = item.isOverBudget;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOver ? _dangerBg : _primaryLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'BUDGET OVERVIEW',
                style: TextStyle(
                  color: isOver ? _dangerAccent : _primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
              Text(
                '${(pct * 100).toStringAsFixed(0)}% USED',
                style: TextStyle(
                  color: isOver ? _dangerAccent : _primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 7,
              backgroundColor: Colors.white.withOpacity(0.6),
              valueColor: AlwaysStoppedAnimation(
                isOver ? _dangerAccent : _primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _QuotaStat(
                label: 'Budget (฿)',
                value: item.budgetAmount.toStringAsFixed(0),
              ),
              const SizedBox(width: 24),
              _QuotaStat(
                label: 'Cost (฿)',
                value: item.actualCost.toStringAsFixed(0),
              ),
              const SizedBox(width: 24),
              _QuotaStat(
                label: 'Remaining',
                value: '฿${item.remainingBudget.toStringAsFixed(0)}',
                highlight: !isOver,
                danger: isOver,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuotaStat extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  final bool danger;
  const _QuotaStat({
    required this.label,
    required this.value,
    this.highlight = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF8A93A4),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: TextStyle(
          color: danger
              ? const Color(0xFFC62828)
              : highlight
              ? const Color(0xFF4F6EF7)
              : const Color(0xFF1A1D23),
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFFEEF1FE),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.inventory_2_outlined,
            color: Color(0xFF4F6EF7),
            size: 34,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'No BOQ items yet',
          style: TextStyle(
            color: Color(0xFF1A1D23),
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Ask your PM to add items to the budget.',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            color: Color(0xFFC62828),
            size: 40,
          ),
          const SizedBox(height: 12),
          const Text(
            'Could not load BOQ items',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: Color(0xFF1A1D23),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    ),
  );
}