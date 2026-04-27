import 'package:flutter/foundation.dart';

class FactoryModel {
  final String id;
  final String name;
  final String email;
  final String? location;
  final String? specialization;
  final int? productionCapacity;
  final DateTime createdAt;

  FactoryModel({
    required this.id,
    required this.name,
    required this.email,
    this.location,
    this.specialization,
    this.productionCapacity,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'location': location,
      'specialization': specialization,
      'production_capacity': productionCapacity,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory FactoryModel.fromMap(Map<String, dynamic> map) {
    return FactoryModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      location: map['location'],
      specialization: map['specialization'],
      productionCapacity: map['production_capacity'],
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at']) 
          : DateTime.now(),
    );
  }

  FactoryModel copyWith({
    String? id,
    String? name,
    String? email,
    String? location,
    String? specialization,
    int? productionCapacity,
    DateTime? createdAt,
  }) {
    return FactoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      location: location ?? this.location,
      specialization: specialization ?? this.specialization,
      productionCapacity: productionCapacity ?? this.productionCapacity,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
