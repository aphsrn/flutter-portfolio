import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/boq_item.dart';
import '../models/material_request.dart';

// ── Raw client ──────────────────────────────────────────────────────────────
final supabaseClientProvider = Provider<SupabaseClient>(
  (_) => Supabase.instance.client,
);

// ── BOQ ─────────────────────────────────────────────────────────────────────
final boqItemsProvider = FutureProvider.family<List<BOQItem>, String>((
  ref,
  projectId,
) async {
  final client = ref.read(supabaseClientProvider);
  final data = await client
      .from('boq_items')
      .select()
      .eq('project_id', projectId)
      .order('name');
  return (data as List).map((e) => BOQItem.fromJson(e)).toList();
});

// ── Material Requests ────────────────────────────────────────────────────────
final materialRequestsProvider =
    FutureProvider.family<List<MaterialRequest>, String>((
      ref,
      projectId,
    ) async {
      final client = ref.read(supabaseClientProvider);
      final data = await client
          .from('material_requests')
          .select()
          .eq('project_id', projectId)
          .order('created_at', ascending: false)
          .limit(50);
      return (data as List).map((e) => MaterialRequest.fromJson(e)).toList();
    });

// ── Service class for mutations ──────────────────────────────────────────────
class MaterialRequestService {
  final SupabaseClient _client;
  const MaterialRequestService(this._client);

  /// Returns null on success, or an error message string.
  Future<String?> submitRequest({
    required String projectId,
    required String itemName,
    required double requestedQty,
    BOQItem? boqItem,
    String? imageUrl,
    String? description,
    bool allowExceedQuota = false,
  }) async {
    try {
      await _client.from('material_requests').insert({
        'project_id': projectId,
        'boq_id': boqItem?.id,
        'item_name': itemName,
        'requested_qty': requestedQty,
        'image_url': imageUrl,
        'description': description,
        'status': RequestStatus.pending.name,
      });
      return null; // success
    } on PostgrestException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }
}

final materialRequestServiceProvider = Provider<MaterialRequestService>(
  (ref) => MaterialRequestService(ref.read(supabaseClientProvider)),
);
