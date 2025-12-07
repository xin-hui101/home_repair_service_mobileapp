// lib/models/rating_model.dart
class RatingModel {
  final String ratingId;
  final String bookingId;
  final String userId;
  final String technicianId;
  final int rating; // 1-5 stars
  final String comment;
  final DateTime createdAt;
  final DateTime updatedAt;

  RatingModel({
    required this.ratingId,
    required this.bookingId,
    required this.userId,
    required this.technicianId,
    required this.rating,
    required this.comment,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convert to Map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'rating_id': ratingId,
      'booking_id': bookingId,
      'user_id': userId,
      'technician_id': technicianId,
      'rating': rating,
      'comment': comment,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  // Create from Firebase Map
  factory RatingModel.fromMap(Map<String, dynamic> map) {
    return RatingModel(
      ratingId: map['rating_id'] ?? '',
      bookingId: map['booking_id'] ?? '',
      userId: map['user_id'] ?? '',
      technicianId: map['technician_id'] ?? '',
      rating: map['rating']?.toInt() ?? 0,
      comment: map['comment'] ?? '',
      createdAt: map['created_at']?.toDate() ?? DateTime.now(),
      updatedAt: map['updated_at']?.toDate() ?? DateTime.now(),
    );
  }

  // Copy with method for updates
  RatingModel copyWith({
    String? ratingId,
    String? bookingId,
    String? userId,
    String? technicianId,
    int? rating,
    String? comment,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RatingModel(
      ratingId: ratingId ?? this.ratingId,
      bookingId: bookingId ?? this.bookingId,
      userId: userId ?? this.userId,
      technicianId: technicianId ?? this.technicianId,
      rating: rating ?? this.rating,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}