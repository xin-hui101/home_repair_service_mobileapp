// lib/firebase_service/technician_service.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/models.dart';

class TechnicianService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Available service specializations
  static const List<String> availableSpecializations = [
    'Plumbing Services',
    'Roof Services',
    'Painting',
    'Wall Maintenance',
    'Electrical',
    'Carpentry',
    'General Maintenance',
  ];

  // Create new technician account
  Future<String?> createTechnician({
    required String name,
    required String email,
    required String phoneNumber,
    required String password,
    required List<String> specializations,
  }) async {
    try {
      print('Creating technician account for: $email');
      
      // Create Firebase Auth account
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      User? user = userCredential.user;
      if (user == null) {
        throw Exception('Failed to create user account');
      }

      // Update display name
      await user.updateDisplayName(name.trim());

      // Generate technician ID
      String technicianID = 'TECH${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

      // Create technician document
      TechnicianModel technician = TechnicianModel(
        technicianID: technicianID,
        technicianName: name.trim(),
        technicianEmail: email.trim(),
        technicianPhoneNumber: phoneNumber.trim(),
        status: 'active',
        createdAt: DateTime.now(),
        specializations: specializations,
        activeJobs: 0,
      );

      // Save to Firestore
      await _firestore.collection('technicians').doc(user.uid).set(technician.toMap());

      print('✓ Technician created successfully: $technicianID');
      notifyListeners();
      
      return technicianID;
    } catch (e) {
      print('❌ Error creating technician: $e');
      return null;
    }
  }

  // Get all technicians
  Future<List<TechnicianModel>> getAllTechnicians() async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('technicians')
          .where('status', isEqualTo: 'active')
          .get();

      List<TechnicianModel> technicians = [];
      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        technicians.add(TechnicianModel.fromMap(data));
      }

      return technicians;
    } catch (e) {
      print('Error getting technicians: $e');
      return [];
    }
  }

  // Get technician statistics
  Future<Map<String, int>> getTechnicianStatistics() async {
    try {
      QuerySnapshot active = await _firestore
          .collection('technicians')
          .where('status', isEqualTo: 'active')
          .get();

      QuerySnapshot total = await _firestore
          .collection('technicians')
          .get();

      // Count technicians with active jobs
      int busyTechnicians = 0;
      for (var doc in active.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        int activeJobs = data['active_jobs'] ?? 0;
        if (activeJobs > 0) busyTechnicians++;
      }

      return {
        'active': active.docs.length,
        'total': total.docs.length,
        'busy': busyTechnicians,
        'available': active.docs.length - busyTechnicians,
      };
    } catch (e) {
      print('Error getting technician statistics: $e');
      return {};
    }
  }

  // Update technician active jobs count
  Future<bool> updateTechnicianJobCount(String technicianId, int jobCount) async {
    try {
      QuerySnapshot query = await _firestore
          .collection('technicians')
          .where('technician_ID', isEqualTo: technicianId)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        await query.docs.first.reference.update({
          'active_jobs': jobCount,
          'updated_at': FieldValue.serverTimestamp(),
        });
        return true;
      }
      return false;
    } catch (e) {
      print('Error updating technician job count: $e');
      return false;
    }
  }

  // Get technicians by specialization
  Future<List<TechnicianModel>> getTechniciansBySpecialization(String specialization) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('technicians')
          .where('status', isEqualTo: 'active')
          .where('specializations', arrayContains: specialization)
          .get();

      List<TechnicianModel> technicians = [];
      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        technicians.add(TechnicianModel.fromMap(data));
      }

      return technicians;
    } catch (e) {
      print('Error getting technicians by specialization: $e');
      return [];
    }
  }
}