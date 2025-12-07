// lib/firebase_service/technician_booking_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'; // Add this import for Icons
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../models/models.dart';

class TechnicianBookingService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  List<BookingData> _technicianBookings = [];
  List<BookingData> get technicianBookings => _technicianBookings;

  // Get bookings assigned to a specific technician
  Future<List<BookingData>> getTechnicianBookings(String technicianId, {DateTime? date}) async {
    try {
      print('=== DEBUG: getTechnicianBookings ===');
      print('Fetching bookings for technician: $technicianId');
      if (date != null) {
        print('Filtering by date: ${date.toIso8601String()}');
      }

      Query query = _firestore
          .collection('bookings')
          .where('technician_ID', isEqualTo: technicianId);

      // If date is provided, filter by that date
      if (date != null) {
        DateTime startOfDay = DateTime(date.year, date.month, date.day);
        DateTime endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
        
        query = query
            .where('booking_date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('booking_date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));
      }

      QuerySnapshot querySnapshot = await query
          .orderBy('booking_date')
          .orderBy('booking_time')
          .get();

      print('Query results: ${querySnapshot.docs.length} documents found');

      _technicianBookings = [];
      for (var doc in querySnapshot.docs) {
        try {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          print('Processing booking: ${data['booking_ID']}');
          
          // Find corresponding subservice
          SubService? subService = _findSubServiceById(data['subservice_ID']);
          
          BookingData booking = BookingData.fromMap(data, subService: subService);
          _technicianBookings.add(booking);
          
          print('Loaded booking: ${booking.bookingID} - Status: ${booking.statusID}');
        } catch (e) {
          print('Error parsing booking document ${doc.id}: $e');
        }
      }

      print('Successfully loaded ${_technicianBookings.length} bookings');
      print('=== END DEBUG ===');
      
      notifyListeners();
      return _technicianBookings;
    } catch (e) {
      print('Error getting technician bookings: $e');
      return [];
    }
  }

  // Get bookings for today
  Future<List<BookingData>> getTodayBookings(String technicianId) async {
    return await getTechnicianBookings(technicianId, date: DateTime.now());
  }

  // Update booking status
  Future<bool> updateBookingStatus(String bookingId, String newStatus) async {
    try {
      // Convert display name to status ID if needed
      String statusId = _getStatusIdFromDisplayName(newStatus);
      
      await _firestore
          .collection('bookings')
          .doc(bookingId)
          .update({
            'status_ID': statusId,
            'updated_at': FieldValue.serverTimestamp(),
          });
      
      // Update local list if exists
      int index = _technicianBookings.indexWhere((booking) => booking.bookingID == bookingId);
      if (index != -1) {
        _technicianBookings[index] = _technicianBookings[index].copyWith(statusID: statusId);
        notifyListeners();
      }
      
      print('Updated booking $bookingId status to $newStatus');
      return true;
    } catch (e) {
      print('Error updating booking status: $e');
      return false;
    }
  }

  // Upload quotation file
  Future<String?> uploadQuotation(String bookingId, PlatformFile file) async {
    try {
      print('Uploading quotation for booking: $bookingId');
      
      // Create file path
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String fileName = 'quotation_${timestamp}_${file.name}';
      String path = 'quotations/$bookingId/$fileName';
      
      // Create storage reference
      Reference ref = _storage.ref().child(path);
      
      // Upload file
      UploadTask uploadTask;
      if (file.bytes != null) {
        // Web platform
        uploadTask = ref.putData(file.bytes!);
      } else if (file.path != null) {
        // Mobile/Desktop platform
        File uploadFile = File(file.path!);
        uploadTask = ref.putFile(uploadFile);
      } else {
        throw Exception('File data not available');
      }
      
      // Wait for upload completion
      TaskSnapshot snapshot = await uploadTask;
      
      // Get download URL
      String downloadUrl = await snapshot.ref.getDownloadURL();
      
      // Update booking document with quotation info
      await _firestore
          .collection('bookings')
          .doc(bookingId)
          .update({
            'quotation_file_name': file.name,
            'quotation_file_url': downloadUrl,
            'quotation_uploaded_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
          });
      
      print('Quotation uploaded successfully: $fileName');
      return file.name;
    } catch (e) {
      print('Error uploading quotation: $e');
      return null;
    }
  }

  // Get technician info by ID
  Future<TechnicianModel?> getTechnicianInfo(String technicianId) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('technicians')
          .where('technician_ID', isEqualTo: technicianId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        Map<String, dynamic> data = querySnapshot.docs.first.data() as Map<String, dynamic>;
        return TechnicianModel.fromMap(data);
      }
      return null;
    } catch (e) {
      print('Error getting technician info: $e');
      return null;
    }
  }

  // Get technician info by Firebase Auth UID
  Future<TechnicianModel?> getTechnicianByAuthUID(String authUID) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('technicians')
          .doc(authUID)
          .get();

      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return TechnicianModel.fromMap(data);
      }
      return null;
    } catch (e) {
      print('Error getting technician by auth UID: $e');
      return null;
    }
  }

  // Stream of technician bookings for real-time updates
  Stream<List<BookingData>> getTechnicianBookingsStream(String technicianId, {DateTime? date}) {
    Query query = _firestore
        .collection('bookings')
        .where('technician_ID', isEqualTo: technicianId);

    // If date is provided, filter by that date
    if (date != null) {
      DateTime startOfDay = DateTime(date.year, date.month, date.day);
      DateTime endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
      
      query = query
          .where('booking_date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('booking_date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay));
    }

    return query
        .orderBy('booking_date')
        .orderBy('booking_time')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            SubService? subService = _findSubServiceById(data['subservice_ID']);
            return BookingData.fromMap(data, subService: subService);
          }).toList();
        });
  }

  // Helper method to find SubService by ID
  SubService? _findSubServiceById(String subserviceID) {
    // Define service options (same as in BookingService)
    final Map<String, List<SubService>> serviceOptions = {
      'Plumbing Services': [
        SubService(
          subservicesID: 'SUB001',
          subserviceName: 'Faucet Replacement and Repair',
          icon: Icons.water_drop,
          subserviceApproxAmount: 50,
          subserviceDescription: 'Repair or replace leaking or damaged faucets',
          serviceTypesID: 'SERVICE001',
        ),
        SubService(
          subservicesID: 'SUB002',
          subserviceName: 'Pipe Leak Detection and Repair/Replacement',
          icon: Icons.water_drop,
          subserviceApproxAmount: 120,
          subserviceDescription: 'Detect leaking pipes and provide necessary repairs or replacements',
          serviceTypesID: 'SERVICE001',
        ),
        SubService(
          subservicesID: 'SUB003',
          subserviceName: 'Pipe Unclogging',
          icon: Icons.water_drop,
          subserviceApproxAmount: 80,
          subserviceDescription: 'Clear clogged kitchen, bathroom, or outdoor drains',
          serviceTypesID: 'SERVICE001',
        ),
        SubService(
          subservicesID: 'SUB004',
          subserviceName: 'Sink/Basin Installation',
          icon: Icons.bathroom,
          subserviceApproxAmount: 100,
          subserviceDescription: 'Install or replace bathroom or kitchen sinks',
          serviceTypesID: 'SERVICE001',
        ),
      ],
      'Roof Services': [
        SubService(
          subservicesID: 'SUB005',
          subserviceName: 'Roof Inspection and Maintenance',
          icon: Icons.roofing,
          subserviceApproxAmount: 60,
          subserviceDescription: 'Regular inspection to ensure roof structure integrity',
          serviceTypesID: 'SERVICE002',
        ),
        SubService(
          subservicesID: 'SUB006',
          subserviceName: 'Roof Leak Repair',
          icon: Icons.roofing,
          subserviceApproxAmount: 200,
          subserviceDescription: 'Check and repair roof leaks caused by age or damage',
          serviceTypesID: 'SERVICE002',
        ),
        SubService(
          subservicesID: 'SUB007',
          subserviceName: 'Roof Replacement or Refurbishment',
          icon: Icons.roofing,
          subserviceApproxAmount: 500,
          subserviceDescription: 'Replace old roofing materials or reapply waterproofing',
          serviceTypesID: 'SERVICE002',
        ),
      ],
      'Painting': [
        SubService(
          subservicesID: 'SUB008',
          subserviceName: 'Interior Wall Painting',
          icon: Icons.format_paint,
          subserviceApproxAmount: 300,
          subserviceDescription: 'Paint or repaint interior rooms',
          serviceTypesID: 'SERVICE003',
        ),
        SubService(
          subservicesID: 'SUB009',
          subserviceName: 'Exterior Wall Painting',
          icon: Icons.format_paint,
          subserviceApproxAmount: 400,
          subserviceDescription: 'Waterproof paint treatment for the exterior walls of the house',
          serviceTypesID: 'SERVICE003',
        ),
      ],
      'Wall Maintenance': [
        SubService(
          subservicesID: 'SUB010',
          subserviceName: 'Crack Repairs',
          icon: Icons.auto_fix_high,
          subserviceApproxAmount: 80,
          subserviceDescription: 'Patch cracks using cement, filler, or sealant',
          serviceTypesID: 'SERVICE004',
        ),
        SubService(
          subservicesID: 'SUB011',
          subserviceName: 'Damp-Proofing',
          icon: Icons.water_damage,
          subserviceApproxAmount: 120,
          subserviceDescription: 'Apply moisture-proof paint on the wall to prevent moisture from penetrating',
          serviceTypesID: 'SERVICE004',
        ),
      ],
    };

    for (var serviceList in serviceOptions.values) {
      for (var subService in serviceList) {
        if (subService.subservicesID == subserviceID) {
          return subService;
        }
      }
    }
    
    // Return a default SubService if not found
    print('SubService not found for ID: $subserviceID');
    return SubService(
      subservicesID: subserviceID,
      subserviceName: 'Unknown Service',
      subserviceDescription: 'Service details not available',
      subserviceApproxAmount: 0.0,
      serviceTypesID: '',
      icon: Icons.help_outline,
    );
  }

  // Helper method to convert display name to status ID
  String _getStatusIdFromDisplayName(String displayName) {
    const Map<String, String> displayNameToStatusId = {
      'Pending': 'STATUS001',
      'Accepted': 'STATUS002',
      'Quotation Sent': 'STATUS003',
      'Scheduled': 'STATUS004',
      'In Progress': 'STATUS005',
      'Completed': 'STATUS006',
      'Cancelled': 'STATUS007',
    };
    
    return displayNameToStatusId[displayName] ?? 'STATUS001';
  }

  // Get booking statistics for technician
  Future<Map<String, int>> getTechnicianBookingStats(String technicianId) async {
    try {
      QuerySnapshot allBookings = await _firestore
          .collection('bookings')
          .where('technician_ID', isEqualTo: technicianId)
          .get();

      Map<String, int> stats = {
        'total': allBookings.docs.length,
        'pending': 0,
        'accepted': 0,
        'in_progress': 0,
        'completed': 0,
        'cancelled': 0,
      };

      for (var doc in allBookings.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String statusId = data['status_ID'] ?? '';
        
        switch (statusId) {
          case 'STATUS001':
            stats['pending'] = (stats['pending'] ?? 0) + 1;
            break;
          case 'STATUS002':
            stats['accepted'] = (stats['accepted'] ?? 0) + 1;
            break;
          case 'STATUS005':
            stats['in_progress'] = (stats['in_progress'] ?? 0) + 1;
            break;
          case 'STATUS006':
            stats['completed'] = (stats['completed'] ?? 0) + 1;
            break;
          case 'STATUS007':
            stats['cancelled'] = (stats['cancelled'] ?? 0) + 1;
            break;
        }
      }

      return stats;
    } catch (e) {
      print('Error getting technician booking stats: $e');
      return {};
    }
  }

  // Clear cached bookings
  void clearBookings() {
    _technicianBookings = [];
    notifyListeners();
  }
}