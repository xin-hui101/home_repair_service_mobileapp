// lib/firebase_service/quotation_service.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/quotation_models.dart';

class QuotationService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _generateQuotationID() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'QUO${timestamp.toString().substring(timestamp.toString().length - 8)}';
  }

  Future<String?> createQuotation(QuotationData quotation) async {
    try {
      final quotationId = _generateQuotationID();
      final newQuotation = quotation.copyWith(
        quotationId: quotationId,
        createdAt: DateTime.now(),
        status: 'draft',
      );

      await _firestore
          .collection('quotations')
          .doc(quotationId)
          .set(newQuotation.toMap());

      print('Created quotation: $quotationId');
      return quotationId;
    } catch (e) {
      print('Error creating quotation: $e');
      return null;
    }
  }

  Future<bool> saveDraftQuotation(QuotationData quotation) async {
    try {
      final updatedQuotation = quotation.copyWith(
        updatedAt: DateTime.now(),
        status: 'draft',
      );

      await _firestore
          .collection('quotations')
          .doc(quotation.quotationId)
          .set(updatedQuotation.toMap());

      print('Saved draft quotation: ${quotation.quotationId}');
      return true;
    } catch (e) {
      print('Error saving draft quotation: $e');
      return false;
    }
  }

  Future<bool> sendQuotation(String quotationId) async {
    try {
      await _firestore
          .collection('quotations')
          .doc(quotationId)
          .update({
            'status': 'sent',
            'sent_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          });

      final quotation = await getQuotationById(quotationId);
      if (quotation != null) {
        await _firestore
            .collection('bookings')
            .doc(quotation.bookingId)
            .update({
              'status_ID': 'STATUS003',
              'updated_at': FieldValue.serverTimestamp(),
            });
      }

      print('Sent quotation: $quotationId');
      return true;
    } catch (e) {
      print('Error sending quotation: $e');
      return false;
    }
  }

  Future<QuotationData?> getQuotationById(String quotationId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('quotations')
          .doc(quotationId)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return QuotationData.fromMap(data);
      }
      return null;
    } catch (e) {
      print('Error getting quotation: $e');
      return null;
    }
  }

  Future<List<QuotationData>> getQuotationsForBooking(String bookingId) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('quotations')
          .where('booking_id', isEqualTo: bookingId)
          .orderBy('created_at', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => QuotationData.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting quotations for booking: $e');
      return [];
    }
  }

  Future<List<QuotationData>> getQuotationsByTechnician(String technicianId) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('quotations')
          .where('technician_id', isEqualTo: technicianId)
          .orderBy('created_at', descending: true)
          .get();

      return querySnapshot.docs
          .map((doc) => QuotationData.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting quotations by technician: $e');
      return [];
    }
  }

  Future<bool> updateQuotation(QuotationData quotation) async {
    try {
      final updatedQuotation = quotation.copyWith(
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('quotations')
          .doc(quotation.quotationId)
          .update(updatedQuotation.toMap());

      print('Updated quotation: ${quotation.quotationId}');
      return true;
    } catch (e) {
      print('Error updating quotation: $e');
      return false;
    }
  }

  Future<bool> deleteQuotation(String quotationId) async {
    try {
      await _firestore
          .collection('quotations')
          .doc(quotationId)
          .delete();

      print('Deleted quotation: $quotationId');
      return true;
    } catch (e) {
      print('Error deleting quotation: $e');
      return false;
    }
  }

  Future<Map<String, int>> getQuotationStats(String technicianId) async {
    try {
      QuerySnapshot allQuotations = await _firestore
          .collection('quotations')
          .where('technician_id', isEqualTo: technicianId)
          .get();

      Map<String, int> stats = {
        'total': allQuotations.docs.length,
        'draft': 0,
        'sent': 0,
        'accepted': 0,
        'rejected': 0,
      };

      for (var doc in allQuotations.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String status = data['status'] ?? 'draft';
        stats[status] = (stats[status] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      print('Error getting quotation stats: $e');
      return {};
    }
  }

  Future<bool> hasQuotation(String bookingId) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('quotations')
          .where('booking_id', isEqualTo: bookingId)
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking if booking has quotation: $e');
      return false;
    }
  }
}