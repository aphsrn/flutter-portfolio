class BOQItem {
  final String id;
  final String projectId;
  final String name;
  final String? category;
  final double budgetAmount;
  final double actualCost;
  final double progressPercent;

  const BOQItem({
    required this.id,
    required this.projectId,
    required this.name,
    this.category,
    required this.budgetAmount,
    required this.actualCost,
    required this.progressPercent,
  });

  // 🚀 คำนวณงบประมาณที่เหลือ
  double get remainingBudget => budgetAmount - actualCost;
  
  // 🚀 เช็คว่าเกินงบหรือไม่
  bool get isOverBudget => actualCost > budgetAmount;

  factory BOQItem.fromJson(Map<String, dynamic> json) => BOQItem(
        id: json['id'] as String,
        projectId: json['project_id'] as String,
        name: json['name'] as String,
        category: json['category'] as String?,
        budgetAmount: (json['budget_amount'] as num?)?.toDouble() ?? 0.0,
        actualCost: (json['actual_cost'] as num?)?.toDouble() ?? 0.0,
        progressPercent: (json['progress_percent'] as num?)?.toDouble() ?? 0.0,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'project_id': projectId,
        'name': name,
        'category': category,
        'budget_amount': budgetAmount,
        'actual_cost': actualCost,
        'progress_percent': progressPercent,
      };
}