// lib/firebase_service/material_service.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/material_model.dart';

class MaterialService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _generateMaterialID() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'MAT${timestamp.toString().substring(timestamp.toString().length - 8)}';
  }

  // Create a new material
  Future<String?> createMaterial(MaterialModel material) async {
    try {
      final materialId = _generateMaterialID();
      final newMaterial = material.copyWith(
        materialID: materialId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('materials')
          .doc(materialId)
          .set(newMaterial.toMap());

      print('Created material: $materialId');
      notifyListeners();
      return materialId;
    } catch (e) {
      print('Error creating material: $e');
      return null;
    }
  }

  // Get all materials
  Future<List<MaterialModel>> getAllMaterials() async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('materials')
          .get();

      List<MaterialModel> materials = querySnapshot.docs
          .map((doc) => MaterialModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
      
      // Sort in memory instead of using Firestore orderBy
      materials.sort((a, b) => a.materialName.compareTo(b.materialName));
      
      return materials;
    } catch (e) {
      print('Error getting all materials: $e');
      return [];
    }
  }

  // Get active materials only
  Future<List<MaterialModel>> getActiveMaterials() async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('materials')
          .where('is_active', isEqualTo: true)
          .get();

      List<MaterialModel> materials = querySnapshot.docs
          .map((doc) => MaterialModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
      
      // Sort in memory instead of using Firestore orderBy
      materials.sort((a, b) => a.materialName.compareTo(b.materialName));
      
      return materials;
    } catch (e) {
      print('Error getting active materials: $e');
      return [];
    }
  }

  // Get material by ID
  Future<MaterialModel?> getMaterialById(String materialId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('materials')
          .doc(materialId)
          .get();

      if (doc.exists) {
        return MaterialModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      print('Error getting material: $e');
      return null;
    }
  }

  // Update material
  Future<bool> updateMaterial(MaterialModel material) async {
    try {
      final updatedMaterial = material.copyWith(
        updatedAt: DateTime.now(),
      );

      await _firestore
          .collection('materials')
          .doc(material.materialID)
          .update(updatedMaterial.toMap());

      print('Updated material: ${material.materialID}');
      notifyListeners();
      return true;
    } catch (e) {
      print('Error updating material: $e');
      return false;
    }
  }

  // Delete material (soft delete by setting isActive to false)
  Future<bool> deleteMaterial(String materialId) async {
    try {
      await _firestore
          .collection('materials')
          .doc(materialId)
          .update({
        'is_active': false,
        'updated_at': FieldValue.serverTimestamp(),
      });

      print('Deleted material: $materialId');
      notifyListeners();
      return true;
    } catch (e) {
      print('Error deleting material: $e');
      return false;
    }
  }

  // Search materials by name
  Future<List<MaterialModel>> searchMaterials(String searchQuery) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('materials')
          .where('is_active', isEqualTo: true)
          .get();

      List<MaterialModel> allMaterials = querySnapshot.docs
          .map((doc) => MaterialModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();

      // Filter by search query
      String query = searchQuery.toLowerCase();
      return allMaterials.where((material) {
        return material.materialName.toLowerCase().contains(query);
      }).toList();
    } catch (e) {
      print('Error searching materials: $e');
      return [];
    }
  }

  // Get material statistics
  Future<Map<String, dynamic>> getMaterialStatistics() async {
    try {
      QuerySnapshot allMaterials = await _firestore
          .collection('materials')
          .get();

      QuerySnapshot activeMaterials = await _firestore
          .collection('materials')
          .where('is_active', isEqualTo: true)
          .get();

      return {
        'total': allMaterials.docs.length,
        'active': activeMaterials.docs.length,
        'inactive': allMaterials.docs.length - activeMaterials.docs.length,
      };
    } catch (e) {
      print('Error getting material statistics: $e');
      return {};
    }
  }
}