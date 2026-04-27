class RawMaterial {
  final String id;
  final String name;
  final String unit;
  final double currentStock;
  final double minStock;
  final double maxStock;
  final double costPerUnit;
  final String? supplierId;
  final DateTime lastUpdated;

  RawMaterial({
    required this.id,
    required this.name,
    required this.unit,
    required this.currentStock,
    required this.minStock,
    required this.maxStock,
    required this.costPerUnit,
    this.supplierId,
    required this.lastUpdated,
  });

  factory RawMaterial.fromJson(Map<String, dynamic> json) {
    return RawMaterial(
      id: json['id'] as String,
      name: json['name'] as String,
      unit: json['unit'] as String,
      currentStock: (json['current_stock'] as num).toDouble(),
      minStock: (json['min_stock'] as num).toDouble(),
      maxStock: (json['max_stock'] as num).toDouble(),
      costPerUnit: (json['cost_per_unit'] as num).toDouble(),
      supplierId: json['supplier_id'] as String?,
      lastUpdated: DateTime.parse(json['last_updated'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'unit': unit,
      'current_stock': currentStock,
      'min_stock': minStock,
      'max_stock': maxStock,
      'cost_per_unit': costPerUnit,
      'supplier_id': supplierId,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }
}