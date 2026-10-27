enum RequestStatus { pending, approved, rejected }

class MaterialRequest {
  final String id;
  final String projectId;
  final String? boqId;
  final String itemName;
  final double requestedQty;
  final String? unit;
  final String? imageUrl;
  final String? description;
  final RequestStatus status;
  final String? createdAt;

  const MaterialRequest({
    required this.id,
    required this.projectId,
    this.boqId,
    required this.itemName,
    required this.requestedQty,
    this.unit,
    this.imageUrl,
    this.description,
    required this.status,
    this.createdAt,
  });

  factory MaterialRequest.fromJson(Map<String, dynamic> json) {
    // แปลงสถานะจาก String ในฐานข้อมูลให้เป็น Enum อย่างปลอดภัย
    RequestStatus parseStatus(String? st) {
      switch (st?.toLowerCase()) {
        case 'approved':
          return RequestStatus.approved;
        case 'rejected':
          return RequestStatus.rejected;
        default:
          return RequestStatus.pending;
      }
    }

    return MaterialRequest(
      id: json['id']?.toString() ?? '',
      projectId: json['project_id']?.toString() ?? '',
      boqId: json['boq_id']?.toString() ?? json['boq_item_id']?.toString(),
      itemName: json['item_name']?.toString() ?? 'N/A',
      requestedQty:
          (json['requested_qty'] ?? json['qty_requested'] ?? 0.0) is num
          ? (json['requested_qty'] ?? json['qty_requested'] ?? 0.0).toDouble()
          : double.tryParse(json['requested_qty']?.toString() ?? '0') ?? 0.0,
      unit: json['unit']?.toString(),
      imageUrl: json['image_url']?.toString(),
      description: json['description']?.toString(),
      status: parseStatus(json['status']?.toString()),
      createdAt: json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'project_id': projectId,
    'boq_id': boqId,
    'item_name': itemName,
    'requested_qty': requestedQty,
    'unit': unit,
    'image_url': imageUrl,
    'description': description,
    'status': status.name,
  };
}
