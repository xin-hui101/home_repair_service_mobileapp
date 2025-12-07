// lib/models/quotation_models.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class QuotationItem {
  final String description;
  final int quantity;
  final double unitPrice;
  final String unit;

  QuotationItem({
    required this.description,
    required this.quantity,
    required this.unitPrice,
    required this.unit,
  });

  double get totalPrice => quantity * unitPrice;

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'quantity': quantity,
      'unit_price': unitPrice,
      'unit': unit,
      'total_price': totalPrice,
    };
  }

  factory QuotationItem.fromMap(Map<String, dynamic> map) {
    return QuotationItem(
      description: map['description'] ?? '',
      quantity: map['quantity'] ?? 0,
      unitPrice: map['unit_price']?.toDouble() ?? 0.0,
      unit: map['unit'] ?? '',
    );
  }
}

class QuotationData {
  final String quotationId;
  final String bookingId;
  final String technicianId;
  final String technicianName;
  
  final String problemAssessment;
  final String recommendedSolution;
  final List<String> assessmentPhotos;
  
  final List<QuotationItem> materialItems;
  final List<QuotationItem> laborItems;
  
  final double installationFee;
  final double transportationFee;
  
  final double taxRate; // Fixed 0.08 (8%)
  final double discountAmount;
  
  final String status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? sentAt;

  QuotationData({
    required this.quotationId,
    required this.bookingId,
    required this.technicianId,
    required this.technicianName,
    required this.problemAssessment,
    required this.recommendedSolution,
    this.assessmentPhotos = const [],
    this.materialItems = const [],
    this.laborItems = const [],
    this.installationFee = 0.0,
    this.transportationFee = 0.0,
    this.taxRate = 0.08,
    this.discountAmount = 0.0,
    this.status = 'draft',
    required this.createdAt,
    this.updatedAt,
    this.sentAt,
  });

  double get materialSubtotal => materialItems.fold(0.0, (sum, item) => sum + item.totalPrice);
  double get laborSubtotal => laborItems.fold(0.0, (sum, item) => sum + item.totalPrice);
  double get otherFeesSubtotal => installationFee + transportationFee;
  double get subtotal => materialSubtotal + laborSubtotal + otherFeesSubtotal;
  double get taxAmount => subtotal * taxRate;
  double get totalBeforeDiscount => subtotal + taxAmount;
  double get grandTotal => totalBeforeDiscount - discountAmount;

  Map<String, dynamic> toMap() {
    return {
      'quotation_id': quotationId,
      'booking_id': bookingId,
      'technician_id': technicianId,
      'technician_name': technicianName,
      'problem_assessment': problemAssessment,
      'recommended_solution': recommendedSolution,
      'assessment_photos': assessmentPhotos,
      'material_items': materialItems.map((item) => item.toMap()).toList(),
      'labor_items': laborItems.map((item) => item.toMap()).toList(),
      'installation_fee': installationFee,
      'transportation_fee': transportationFee,
      'tax_rate': taxRate,
      'discount_amount': discountAmount,
      'status': status,
      'created_at': Timestamp.fromDate(createdAt),
      'updated_at': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'sent_at': sentAt != null ? Timestamp.fromDate(sentAt!) : null,
      'material_subtotal': materialSubtotal,
      'labor_subtotal': laborSubtotal,
      'other_fees_subtotal': otherFeesSubtotal,
      'subtotal': subtotal,
      'tax_amount': taxAmount,
      'grand_total': grandTotal,
    };
  }

  factory QuotationData.fromMap(Map<String, dynamic> map) {
    return QuotationData(
      quotationId: map['quotation_id'] ?? '',
      bookingId: map['booking_id'] ?? '',
      technicianId: map['technician_id'] ?? '',
      technicianName: map['technician_name'] ?? '',
      problemAssessment: map['problem_assessment'] ?? '',
      recommendedSolution: map['recommended_solution'] ?? '',
      assessmentPhotos: List<String>.from(map['assessment_photos'] ?? []),
      materialItems: (map['material_items'] as List<dynamic>?)
          ?.map((item) => QuotationItem.fromMap(item))
          .toList() ?? [],
      laborItems: (map['labor_items'] as List<dynamic>?)
          ?.map((item) => QuotationItem.fromMap(item))
          .toList() ?? [],
      installationFee: map['installation_fee']?.toDouble() ?? 0.0,
      transportationFee: map['transportation_fee']?.toDouble() ?? 0.0,
      taxRate: map['tax_rate']?.toDouble() ?? 0.08,
      discountAmount: map['discount_amount']?.toDouble() ?? 0.0,
      status: map['status'] ?? 'draft',
      createdAt: (map['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (map['updated_at'] as Timestamp?)?.toDate(),
      sentAt: (map['sent_at'] as Timestamp?)?.toDate(),
    );
  }

  QuotationData copyWith({
    String? quotationId,
    String? bookingId,
    String? technicianId,
    String? technicianName,
    String? problemAssessment,
    String? recommendedSolution,
    List<String>? assessmentPhotos,
    List<QuotationItem>? materialItems,
    List<QuotationItem>? laborItems,
    double? installationFee,
    double? transportationFee,
    double? taxRate,
    double? discountAmount,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? sentAt,
  }) {
    return QuotationData(
      quotationId: quotationId ?? this.quotationId,
      bookingId: bookingId ?? this.bookingId,
      technicianId: technicianId ?? this.technicianId,
      technicianName: technicianName ?? this.technicianName,
      problemAssessment: problemAssessment ?? this.problemAssessment,
      recommendedSolution: recommendedSolution ?? this.recommendedSolution,
      assessmentPhotos: assessmentPhotos ?? this.assessmentPhotos,
      materialItems: materialItems ?? this.materialItems,
      laborItems: laborItems ?? this.laborItems,
      installationFee: installationFee ?? this.installationFee,
      transportationFee: transportationFee ?? this.transportationFee,
      taxRate: taxRate ?? this.taxRate,
      discountAmount: discountAmount ?? this.discountAmount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sentAt: sentAt ?? this.sentAt,
    );
  }
}