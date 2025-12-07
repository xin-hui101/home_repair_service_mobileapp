// lib/models/material_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class MaterialModel {
  final String materialID;
  final String materialName;
  final String unit;
  final double unitPrice;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;

  MaterialModel({
    required this.materialID,
    required this.materialName,
    required this.unit,
    required this.unitPrice,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
  });

  // Convert MaterialModel to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'material_id': materialID,
      'material_name': materialName,
      'unit': unit,
      'unit_price': unitPrice,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': Timestamp.fromDate(updatedAt),
      'is_active': isActive,
    };
  }

  // Create MaterialModel from Firestore document
  factory MaterialModel.fromMap(Map<String, dynamic> map) {
    return MaterialModel(
      materialID: map['material_id'] ?? '',
      materialName: map['material_name'] ?? '',
      unit: map['unit'] ?? 'pieces',
      unitPrice: (map['unit_price'] ?? 0.0).toDouble(),
      createdAt: (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isActive: map['is_active'] ?? true,
    );
  }

  // CopyWith method for easy updates
  MaterialModel copyWith({
    String? materialID,
    String? materialName,
    String? unit,
    double? unitPrice,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return MaterialModel(
      materialID: materialID ?? this.materialID,
      materialName: materialName ?? this.materialName,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

// Material units
class MaterialUnit {
  static const String pieces = 'pieces';
  static const String meters = 'meters';
  static const String liters = 'liters';
  static const String kilograms = 'kilograms';
  static const String boxes = 'boxes';
  static const String rolls = 'rolls';
  static const String sets = 'sets';
  static const String packs = 'packs';

  static List<String> getAllUnits() {
    return [
      pieces,
      meters,
      liters,
      kilograms,
      boxes,
      rolls,
      sets,
      packs,
    ];
  }
}