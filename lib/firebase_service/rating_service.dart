// lib/firebase_service/rating_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:home_service_system/models/rating_model.dart';

class RatingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'ratings';

  // Submit a new rating
  Future<bool> submitRating({
    required String bookingId,
    required String userId,
    required String technicianId,
    required int rating,
    required String comment,
  }) async {
    try {
      final ratingId = _firestore.collection(_collection).doc().id;
      final now = DateTime.now();

      final ratingData = RatingModel(
        ratingId: ratingId,
        bookingId: bookingId,
        userId: userId,
        technicianId: technicianId,
        rating: rating,
        comment: comment,
        createdAt: now,
        updatedAt: now,
      );

      await _firestore
          .collection(_collection)
          .doc(ratingId)
          .set(ratingData.toMap());

      print('✅ Rating submitted successfully: $ratingId');
      return true;
    } catch (e) {
      print('❌ Error submitting rating: $e');
      return false;
    }
  }

  // Check if user has already rated a booking
  Future<RatingModel?> getRatingForBooking({
    required String bookingId,
    required String userId,
  }) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('booking_id', isEqualTo: bookingId)
          .where('user_id', isEqualTo: userId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return RatingModel.fromMap(querySnapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      print('❌ Error getting rating for booking: $e');
      return null;
    }
  }

  // Update existing rating
  Future<bool> updateRating({
    required String ratingId,
    required int rating,
    required String comment,
  }) async {
    try {
      await _firestore.collection(_collection).doc(ratingId).update({
        'rating': rating,
        'comment': comment,
        'updated_at': DateTime.now(),
      });

      print('✅ Rating updated successfully: $ratingId');
      return true;
    } catch (e) {
      print('❌ Error updating rating: $e');
      return false;
    }
  }

  // Get all ratings for a technician
  Future<List<RatingModel>> getRatingsForTechnician(String technicianId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('technician_id', isEqualTo: technicianId)
          .orderBy('created_at', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => RatingModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      print('❌ Error getting ratings for technician: $e');
      return [];
    }
  }

  // Get average rating for a technician
  Future<double> getAverageRatingForTechnician(String technicianId) async {
    try {
      final ratings = await getRatingsForTechnician(technicianId);
      if (ratings.isEmpty) return 0.0;

      final total = ratings.map((r) => r.rating).reduce((a, b) => a + b);
      return total / ratings.length;
    } catch (e) {
      print('❌ Error calculating average rating: $e');
      return 0.0;
    }
  }

  // Delete rating
  Future<bool> deleteRating(String ratingId) async {
    try {
      await _firestore.collection(_collection).doc(ratingId).delete();
      print('✅ Rating deleted successfully: $ratingId');
      return true;
    } catch (e) {
      print('❌ Error deleting rating: $e');
      return false;
    }
  }
}