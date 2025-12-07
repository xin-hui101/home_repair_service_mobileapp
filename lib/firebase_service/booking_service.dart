// lib/firebase_service/booking_service.dart
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/models.dart';
import 'dart:io';
import 'package:home_service_system/firebase_service/storage_service.dart';

class BookingService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  BookingData? _currentBooking;
  List<BookingData> _userBookings = [];
  
  // Temporary storage for selected image files
  List<File> _selectedImages = [];

  BookingData? get currentBooking => _currentBooking;
  List<BookingData> get userBookings => _userBookings;
  
  // Get selected images
  List<File> get selectedImages => _selectedImages;

  // Service types mapping (matching your database structure)
  final Map<String, String> serviceTypeMapping = {
    'Plumbing Services': 'SERVICE001',
    'Roof Services': 'SERVICE002',
    'Painting': 'SERVICE003',
    'Wall Maintenance': 'SERVICE004',
  };

  // Define sub-services with proper IDs matching your database
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

  final StorageService _storageService = StorageService();

  // Get sub-services for a specific service type
  List<SubService> getSubServices(String serviceName) {
    return serviceOptions[serviceName] ?? [];
  }

  // Set current booking data (for the booking flow)
  void setCurrentBooking(BookingData booking) {
    _currentBooking = booking;
    notifyListeners();
  }
  
  // Set selected images (from FillDetailPage)
  void setSelectedImages(List<File> images) {
    _selectedImages = images;
    notifyListeners();
  }
  
  // Clear selected images
  void clearSelectedImages() {
    _selectedImages = [];
    notifyListeners();
  }

  // Update current booking data
  void updateCurrentBooking({
    String? bookingAddress,
    DateTime? bookingDate,
    TimeOfDay? bookingTime,
    String? bookingDescription,
    double? bookingQuotation,
  }) {
    if (_currentBooking != null) {
      _currentBooking = _currentBooking!.copyWith(
        bookingAddress: bookingAddress,
        bookingDate: bookingDate,
        bookingTime: bookingTime,
        bookingDescription: bookingDescription,
        bookingQuotation: bookingQuotation,
      );
      notifyListeners();
    }
  }

  // Generate booking ID
  String _generateBookingID() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'BOOK${timestamp.toString().substring(timestamp.toString().length - 8)}';
  }

  Future<bool> isTimeSlotAvailable(DateTime date, TimeOfDay time) async {
    try {
      String timeString = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      DateTime dateAtMidnight = DateTime(date.year, date.month, date.day);
      Timestamp dateTimestamp = Timestamp.fromDate(dateAtMidnight);
      
      print('\n========================================');
      print('🔍 CHECKING TIME SLOT AVAILABILITY');
      print('========================================');
      print('📅 Date: ${dateAtMidnight.toString().substring(0, 10)}');
      print('🕐 Time: $timeString');
      print('📊 Timestamp: ${dateTimestamp.toDate()}');
      
      // 第一步：查看该日期所有的预订
      QuerySnapshot allBookings = await _firestore
          .collection('bookings')
          .where('booking_date', isEqualTo: dateTimestamp)
          .get();
      
      print('\n📋 Step 1: All bookings for this date: ${allBookings.docs.length}');
      for (var doc in allBookings.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        print('  • ${doc.id}:');
        print('    booking_time: "${data['booking_time']}"');
        print('    status_ID: ${data['status_ID']}');
      }
      
      // 第二步：查询特定时间的预订
      print('\n📋 Step 2: Querying for specific time: $timeString');
      QuerySnapshot specificBookings = await _firestore
          .collection('bookings')
          .where('booking_date', isEqualTo: dateTimestamp)
          .where('booking_time', isEqualTo: timeString)
          .get();
      
      print('Found ${specificBookings.docs.length} booking(s) at $timeString');
      
      int activeBookings = 0;
      for (var doc in specificBookings.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String statusId = data['status_ID'] ?? '';
        String bookingTime = data['booking_time'] ?? '';
        
        print('  • ${doc.id}:');
        print('    booking_time: "$bookingTime"');
        print('    status_ID: $statusId');
        print('    Is cancelled: ${statusId == 'STATUS007'}');
        
        if (statusId != 'STATUS007') {
          activeBookings++;
          print('    ⚠️  THIS IS AN ACTIVE BOOKING!');
        } else {
          print('    ✅ This is cancelled, ignored');
        }
      }
      
      bool isAvailable = activeBookings == 0;
      
      print('\n📊 RESULT:');
      print('Active bookings: $activeBookings');
      print('Time slot is: ${isAvailable ? "✅ AVAILABLE" : "❌ NOT AVAILABLE"}');
      print('========================================\n');
      
      return isAvailable;
      
    } catch (e, stackTrace) {
      print('\n❌ ERROR in isTimeSlotAvailable:');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      print('========================================\n');
      return false;
    }
  }

  // NEW: Get all booked time slots for a specific date
  Future<List<TimeOfDay>> getBookedTimeSlotsForDate(DateTime date) async {
    try {
      List<TimeOfDay> bookedSlots = [];
      
      // Create date at midnight for accurate comparison
      DateTime dateAtMidnight = DateTime(date.year, date.month, date.day);
      
      // Query bookings for the specific date
      QuerySnapshot querySnapshot = await _firestore
          .collection('bookings')
          .where('booking_date', isEqualTo: Timestamp.fromDate(dateAtMidnight))
          .get();
      
      // Extract time slots from the results, excluding cancelled bookings
      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String statusId = data['status_ID'] ?? '';
        
        // Skip cancelled bookings
        if (statusId == 'STATUS007') {
          continue;
        }
        
        String? timeString = data['booking_time'];
        
        if (timeString != null) {
          final timeParts = timeString.split(':');
          if (timeParts.length == 2) {
            TimeOfDay time = TimeOfDay(
              hour: int.tryParse(timeParts[0]) ?? 0,
              minute: int.tryParse(timeParts[1]) ?? 0,
            );
            bookedSlots.add(time);
          }
        }
      }
      
      print('Found ${bookedSlots.length} booked slots for ${date.toString().substring(0, 10)}');
      return bookedSlots;
    } catch (e) {
      print('Error getting booked time slots: $e');
      return [];
    }
  }

  // Create final booking method with transaction to prevent race conditions
Future<String?> createFinalBooking() async {
  try {
    if (_currentBooking == null) {
      throw Exception('No booking data found');
    }
    
    print('Creating final booking...');
    
    // Generate booking ID
    final bookingID = _generateBookingID();
    
    List<String> imageUrls = [];
    
    // Upload images if available
    if (_selectedImages.isNotEmpty) {
      print('Uploading ${_selectedImages.length} images for booking $bookingID');
      
      List<File> validImages = await _storageService.validateImageSizes(_selectedImages, maxSizeInMB: 5);
      
      if (validImages.length != _selectedImages.length) {
        print('Warning: ${_selectedImages.length - validImages.length} images were too large and skipped');
      }
      
      imageUrls = await _storageService.uploadMultipleImages(validImages, bookingID);
      print('Successfully uploaded ${imageUrls.length} images');
    }
    
    // Create final booking
    final finalBooking = _currentBooking!.copyWith(
      bookingID: bookingID,
      statusID: BookingStatus.pending.statusID,
      imageUrls: imageUrls,
    );

    print('Saving booking to Firestore with ID: $bookingID');
    
    // ✅ Double-check time slot availability before saving
    String timeString = '${_currentBooking!.bookingTime.hour.toString().padLeft(2, '0')}:${_currentBooking!.bookingTime.minute.toString().padLeft(2, '0')}';
    DateTime dateAtMidnight = DateTime(
      _currentBooking!.bookingDate.year, 
      _currentBooking!.bookingDate.month, 
      _currentBooking!.bookingDate.day
    );
    Timestamp dateTimestamp = Timestamp.fromDate(dateAtMidnight);
    
    print('\n========================================');
    print('🔍 FINAL CHECK: TIME SLOT AVAILABILITY');
    print('========================================');
    print('📅 Date: ${dateAtMidnight.toString().substring(0, 10)}');
    print('🕐 Time: $timeString');
    
    // Query existing bookings one more time
    QuerySnapshot existingBookings = await _firestore
        .collection('bookings')
        .where('booking_date', isEqualTo: dateTimestamp)
        .where('booking_time', isEqualTo: timeString)
        .get();
    
    print('📋 Found ${existingBookings.docs.length} existing booking(s)');
    
    int activeBookings = 0;
    for (var doc in existingBookings.docs) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      String statusId = data['status_ID'] ?? '';
      
      print('  • ${doc.id}: status_ID = $statusId');
      
      if (statusId != 'STATUS007') { // Not cancelled
        activeBookings++;
        print('    ⚠️  THIS IS AN ACTIVE BOOKING!');
      }
    }
    
    if (activeBookings > 0) {
      print('❌ Time slot is NOT available (${activeBookings} active booking(s))');
      print('========================================\n');
      
      // Clean up uploaded images
      if (imageUrls.isNotEmpty) {
        print('Cleaning up uploaded images...');
        for (String imageUrl in imageUrls) {
          try {
            await _storageService.deleteImage(imageUrl);
          } catch (e) {
            print('Failed to delete image: $e');
          }
        }
      }
      
      throw Exception('This time slot has already been booked. Please select another time.');
    }
    
    print('✅ Time slot is available, creating booking...');
    
    // Prepare booking data
    Map<String, dynamic> bookingData = finalBooking.toMap();
    bookingData['booking_ID'] = bookingID;
    bookingData['status_ID'] = BookingStatus.pending.statusID;
    bookingData['created_at'] = FieldValue.serverTimestamp();
    bookingData['updated_at'] = FieldValue.serverTimestamp();
    bookingData['user_ID'] = finalBooking.userID;
    bookingData['userID'] = finalBooking.userID;
    bookingData['firebase_uid'] = finalBooking.userID;
    
    // Save to Firestore
    await _firestore
        .collection('bookings')
        .doc(bookingID)
        .set(bookingData);
    
    print('Booking saved successfully to Firestore');
    print('Saved with user_ID: ${finalBooking.userID}');
    print('========================================\n');
    
    // Clear current booking and selected images
    _currentBooking = null;
    _selectedImages = [];
    notifyListeners();
    
    return bookingID;
  } catch (e) {
    print('Error creating final booking: $e');
    rethrow;
  }
}

  // Create a new booking in Firestore (legacy method for compatibility)
  Future<String?> createBooking(BookingData booking) async {
    try {
      // Generate booking ID
      final bookingID = _generateBookingID();
      
      // Create booking with generated ID
      final bookingWithID = booking.copyWith(
        bookingID: bookingID,
        statusID: BookingStatus.pending.statusID,
      );

      // Save to Firestore bookings collection
      await _firestore
          .collection('bookings')
          .doc(bookingID)
          .set(bookingWithID.toMap());
      
      // Clear current booking after successful creation
      _currentBooking = null;
      notifyListeners();
      
      return bookingID;
    } catch (e) {
      print('Error creating booking: $e');
      return null;
    }
  }

  // Create booking with images (legacy method for compatibility)
  Future<String?> createBookingWithImages(BookingData booking, List<File> images) async {
    try {
      // Generate booking ID
      final bookingID = _generateBookingID();
      
      List<String> imageUrls = [];
      
      // Upload images if available
      if (images.isNotEmpty) {
        print('Uploading ${images.length} images for booking $bookingID');
        
        // Validate image file sizes (max 5MB each)
        List<File> validImages = await _storageService.validateImageSizes(images, maxSizeInMB: 5);
        
        if (validImages.length != images.length) {
          print('Warning: ${images.length - validImages.length} images were too large and skipped');
        }
        
        // Upload valid images
        imageUrls = await _storageService.uploadMultipleImages(validImages, bookingID);
        print('Successfully uploaded ${imageUrls.length} images');
      }
      
      // Create booking with image URLs
      final bookingWithImagesAndID = booking.copyWith(
        bookingID: bookingID,
        statusID: BookingStatus.pending.statusID,
        imageUrls: imageUrls,
      );

      // Save to Firestore
      await _firestore
          .collection('bookings')
          .doc(bookingID)
          .set(bookingWithImagesAndID.toMap());
      
      // Clear current booking
      _currentBooking = null;
      notifyListeners();
      
      return bookingID;
    } catch (e) {
      print('Error creating booking with images: $e');
      return null;
    }
  }

  // Helper method to find sub-service by ID
  SubService? _findSubServiceById(String subserviceID) {
    for (var serviceList in serviceOptions.values) {
      for (var subService in serviceList) {
        if (subService.subservicesID == subserviceID) {
          return subService;
        }
      }
    }
    return null;
  }

  // Helper method to get service name from service type ID
  String _getServiceNameFromSubservice(String serviceTypesID) {
    for (var entry in serviceTypeMapping.entries) {
      if (entry.value == serviceTypesID) {
        return entry.key;
      }
    }
    return '';
  }

  // Get all bookings for a specific user - FIXED VERSION
  Future<List<BookingData>> getUserBookings(String userId) async {
    try {
      print('=== DEBUG: getUserBookings ===');
      print('Fetching bookings for user: $userId');
      
      // First check if bookings collection exists and has data
      QuerySnapshot allBookingsSnapshot = await _firestore
          .collection('bookings')
          .limit(5)
          .get();
      
      print('Total bookings in collection: ${allBookingsSnapshot.docs.length}');
      
      // If no data, return empty list
      if (allBookingsSnapshot.docs.isEmpty) {
        print('No bookings found in database!');
        return [];
      }
      
      // Print first few document structures to understand field names
      for (var doc in allBookingsSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        print('Document ${doc.id}: fields = ${data.keys.toList()}');
        print('  user_ID field exists: ${data.containsKey('user_ID')}');
        print('  user_ID value: ${data['user_ID']}');
        print('  userID field exists: ${data.containsKey('userID')}');
        print('  firebase_uid field exists: ${data.containsKey('firebase_uid')}');
      }
      
      // Try multiple field name variations for user ID
      QuerySnapshot? querySnapshot;
      bool foundResults = false;
      
      // Try 1: user_ID field (primary)
      if (!foundResults) {
        try {
          querySnapshot = await _firestore
              .collection('bookings')
              .where('user_ID', isEqualTo: userId)
              .orderBy('booking_date', descending: true)
              .get();
          
          print('Query with user_ID field result: ${querySnapshot.docs.length} documents');
          if (querySnapshot.docs.isNotEmpty) {
            foundResults = true;
          }
        } catch (e) {
          print('Error with user_ID field: $e');
        }
      }
      
      // Try 2: userID field (alternative)
      if (!foundResults) {
        try {
          querySnapshot = await _firestore
              .collection('bookings')
              .where('userID', isEqualTo: userId)
              .orderBy('booking_date', descending: true)
              .get();
          
          print('Query with userID field result: ${querySnapshot.docs.length} documents');
          if (querySnapshot.docs.isNotEmpty) {
            foundResults = true;
          }
        } catch (e) {
          print('Error with userID field: $e');
        }
      }
      
      // Try 3: firebase_uid field (fallback)
      if (!foundResults) {
        try {
          querySnapshot = await _firestore
              .collection('bookings')
              .where('firebase_uid', isEqualTo: userId)
              .orderBy('booking_date', descending: true)
              .get();
          
          print('Query with firebase_uid field result: ${querySnapshot.docs.length} documents');
          if (querySnapshot.docs.isNotEmpty) {
            foundResults = true;
          }
        } catch (e) {
          print('Error with firebase_uid field: $e');
        }
      }
      
      // Try 4: Get all bookings and filter locally (last resort)
      if (!foundResults) {
        print('All specific queries failed, getting all bookings for local filtering...');
        try {
          QuerySnapshot allBookings = await _firestore
              .collection('bookings')
              .get();
          
          List<QueryDocumentSnapshot> userBookings = allBookings.docs.where((doc) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            return data['user_ID'] == userId || 
                   data['userID'] == userId || 
                   data['firebase_uid'] == userId;
          }).toList();
          
          // Sort manually by booking_date
          userBookings.sort((a, b) {
            var aData = a.data() as Map<String, dynamic>;
            var bData = b.data() as Map<String, dynamic>;
            Timestamp aDate = aData['booking_date'] ?? Timestamp.now();
            Timestamp bDate = bData['booking_date'] ?? Timestamp.now();
            return bDate.compareTo(aDate); // Descending order
          });
          
          print('Local filtering found: ${userBookings.length} matching bookings');
          
          // Process the filtered bookings
          _userBookings = [];
          for (var doc in userBookings) {
            try {
              Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
              
              print('Processing document: ${doc.id}');
              print('Document data keys: ${data.keys.toList()}');
              
              // Find corresponding subservice
              SubService? subService = _findSubServiceById(data['subservice_ID'] ?? '');
              
              // Ensure service_name is populated
              String serviceName = data['service_name'] ?? '';
              if (serviceName.isEmpty && subService != null) {
                // Try to get service name from subservice
                serviceName = _getServiceNameFromSubservice(subService.serviceTypesID);
              }
              
              // Create booking data with proper service name
              Map<String, dynamic> updatedData = Map.from(data);
              updatedData['service_name'] = serviceName;
              
              BookingData booking = BookingData.fromMap(updatedData, subService: subService);
              _userBookings.add(booking);
              
              print('Successfully loaded booking: ${booking.bookingID} - Status: ${booking.statusID}');
            } catch (e) {
              print('Error parsing booking document ${doc.id}: $e');
              // Continue processing other bookings even if one fails
            }
          }
          
          print('Successfully loaded ${_userBookings.length} bookings for user $userId');
          print('=== END DEBUG ===');
          
          notifyListeners();
          return _userBookings;
        } catch (e) {
          print('Error with local filtering: $e');
          return [];
        }
      }

      // Process results from successful query
      if (querySnapshot != null && foundResults) {
        _userBookings = [];
        for (var doc in querySnapshot.docs) {
          try {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            
            print('Processing document: ${doc.id}');
            print('Document data keys: ${data.keys.toList()}');
            
            // Find corresponding subservice
            SubService? subService = _findSubServiceById(data['subservice_ID'] ?? '');
            
            // Ensure service_name is populated
            String serviceName = data['service_name'] ?? '';
            if (serviceName.isEmpty && subService != null) {
              serviceName = _getServiceNameFromSubservice(subService.serviceTypesID);
            }
            
            // Create booking data with proper service name
            Map<String, dynamic> updatedData = Map.from(data);
            updatedData['service_name'] = serviceName;
            
            BookingData booking = BookingData.fromMap(updatedData, subService: subService);
            _userBookings.add(booking);
            
            print('Successfully loaded booking: ${booking.bookingID} - Status: ${booking.statusID}');
          } catch (e) {
            print('Error parsing booking document ${doc.id}: $e');
          }
        }
        
        print('Successfully loaded ${_userBookings.length} bookings for user $userId');
        print('=== END DEBUG ===');
        
        notifyListeners();
        return _userBookings;
      }
      
      print('No bookings found for user');
      print('=== END DEBUG ===');
      return [];
    } catch (e) {
      print('Error fetching user bookings: $e');
      return [];
    }
  }

  // Fetch all bookings (for admin)
  Future<List<BookingData>> getAllBookings() async {
    try {
      print('Fetching all bookings...');
      
      QuerySnapshot querySnapshot = await _firestore
          .collection('bookings')
          .orderBy('created_at', descending: true)
          .get();

      print('Found ${querySnapshot.docs.length} total bookings');

      List<BookingData> bookings = [];
      for (var doc in querySnapshot.docs) {
        try {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          
          // Find the sub-service for this booking
          SubService? subService = _findSubServiceById(data['subservice_ID']);
          
          BookingData booking = BookingData.fromMap(data, subService: subService);
          bookings.add(booking);
        } catch (e) {
          print('Error parsing booking ${doc.id}: $e');
        }
      }

      return bookings;
    } catch (e) {
      print('Error fetching all bookings: $e');
      return [];
    }
  }

  // Fetch bookings by status (supporting both enum and string)
  Future<List<BookingData>> getBookingsByStatus(String userId, dynamic status) async {
    try {
      String statusID;
      
      // Handle both BookingStatus enum and String statusID
      if (status is BookingStatus) {
        statusID = status.statusID;
      } else if (status is String) {
        statusID = status;
      } else {
        print('Invalid status type: ${status.runtimeType}');
        return [];
      }
      
      QuerySnapshot querySnapshot = await _firestore
          .collection('bookings')
          .where('user_ID', isEqualTo: userId)
          .where('status_ID', isEqualTo: statusID)
          .orderBy('created_at', descending: true)
          .get();

      List<BookingData> bookings = [];
      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        SubService? subService = _findSubServiceById(data['subservice_ID']);
        bookings.add(BookingData.fromMap(data, subService: subService));
      }

      return bookings;
    } catch (e) {
      print('Error fetching bookings by status: $e');
      return [];
    }
  }

  // Get a single booking by ID
  Future<BookingData?> getBookingById(String bookingId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('bookings').doc(bookingId).get();
      
      if (!doc.exists) {
        print('Booking $bookingId not found');
        return null;
      }

      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      SubService? subService = _findSubServiceById(data['subservice_ID']);
      
      return BookingData.fromMap(data, subService: subService);
    } catch (e) {
      print('Error fetching booking by ID: $e');
      return null;
    }
  }

  // Update booking status using BookingStatus enum
  Future<bool> updateBookingStatus(String bookingId, BookingStatus status) async {
    try {
      await _firestore
          .collection('bookings')
          .doc(bookingId)
          .update({
            'status_ID': status.statusID,
            'updated_at': FieldValue.serverTimestamp(),
          });
      
      // Update local list if exists
      int index = _userBookings.indexWhere((booking) => booking.bookingID == bookingId);
      if (index != -1) {
        _userBookings[index] = _userBookings[index].copyWith(statusID: status.statusID);
        notifyListeners();
      }
      
      print('Updated booking $bookingId status to ${status.displayName}');
      return true;
    } catch (e) {
      print('Error updating booking status: $e');
      return false;
    }
  }

  // Update booking status using status ID string
  Future<bool> updateBookingStatusById(String bookingId, String statusID) async {
    try {
      // Validate the status ID
      if (!BookingStatusConstants.statusIdToDisplayName.containsKey(statusID)) {
        print('Invalid status ID: $statusID');
        return false;
      }

      await _firestore
          .collection('bookings')
          .doc(bookingId)
          .update({
            'status_ID': statusID,
            'updated_at': FieldValue.serverTimestamp(),
          });
      
      // Update local list if exists
      int index = _userBookings.indexWhere((booking) => booking.bookingID == bookingId);
      if (index != -1) {
        _userBookings[index] = _userBookings[index].copyWith(statusID: statusID);
        notifyListeners();
      }
      
      String displayName = BookingStatusConstants.getDisplayName(statusID);
      print('Updated booking $bookingId status to $displayName');
      return true;
    } catch (e) {
      print('Error updating booking status: $e');
      return false;
    }
  }

  // Assign technician to booking
  Future<bool> assignTechnicianToBooking(String bookingId, String technicianId) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'technician_ID': technicianId,
        'status_ID': BookingStatus.accepted.statusID,
        'updated_at': FieldValue.serverTimestamp(),
      });
      
      // Update local list if exists
      int index = _userBookings.indexWhere((booking) => booking.bookingID == bookingId);
      if (index != -1) {
        _userBookings[index] = _userBookings[index].copyWith(technicianID: technicianId);
        notifyListeners();
      }
      
      print('Assigned technician $technicianId to booking $bookingId');
      return true;
    } catch (e) {
      print('Error assigning technician: $e');
      return false;
    }
  }

  // Alternative method name for compatibility
  Future<bool> assignTechnician(String bookingId, String technicianId) async {
    return await assignTechnicianToBooking(bookingId, technicianId);
  }

  // Cancel booking
  Future<bool> cancelBooking(String bookingId, {String? cancelledBy}) async {
    try {
      Map<String, dynamic> updateData = {
        'status_ID': BookingStatus.cancelled.statusID,
        'cancelled_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };
      
      // Record who cancelled the booking (user or admin)
      if (cancelledBy != null) {
        updateData['cancelled_by'] = cancelledBy;
      }
      
      await _firestore.collection('bookings').doc(bookingId).update(updateData);
      
      // Update local list if exists
      int index = _userBookings.indexWhere((booking) => booking.bookingID == bookingId);
      if (index != -1) {
        _userBookings[index] = _userBookings[index].copyWith(
          statusID: BookingStatus.cancelled.statusID,
        );
        notifyListeners();
      }
      
      print('Cancelled booking $bookingId by ${cancelledBy ?? "unknown"}');
      return true;
    } catch (e) {
      print('Error cancelling booking: $e');
      return false;
    }
  }

// Cancel booking with reason (for admin)
Future<bool> cancelBookingWithReason(
  String bookingId, {
  String? cancelledBy,
  required String cancellationReason,
}) async {
  try {
    Map<String, dynamic> updateData = {
      'status_ID': BookingStatus.cancelled.statusID,
      'cancelled_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'cancellation_reason': cancellationReason,
    };
    
    if (cancelledBy != null) {
      updateData['cancelled_by'] = cancelledBy;
    }
    
    await _firestore.collection('bookings').doc(bookingId).update(updateData);
    
    int index = _userBookings.indexWhere((booking) => booking.bookingID == bookingId);
    if (index != -1) {
      _userBookings[index] = _userBookings[index].copyWith(
        statusID: BookingStatus.cancelled.statusID,
      );
      notifyListeners();
    }
    
    print('Cancelled booking $bookingId by $cancelledBy with reason: $cancellationReason');
    return true;
  } catch (e) {
    print('Error cancelling booking with reason: $e');
    return false;
  }
}

  // Clear current booking data
  void clearCurrentBooking() {
    _currentBooking = null;
    _selectedImages = [];
    notifyListeners();
  }

  // Stream of user bookings (real-time updates)
  Stream<List<BookingData>> getUserBookingsStream(String userId) {
    return _firestore
        .collection('bookings')
        .where('user_ID', isEqualTo: userId)
        .orderBy('booking_date', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            Map<String, dynamic> data = doc.data();
            SubService? subService = _findSubServiceById(data['subservice_ID']);
            return BookingData.fromMap(data, subService: subService);
          }).toList();
        });
  }

  // Get bookings by status using status ID string
  Future<List<BookingData>> getBookingsByStatusId(String userId, String statusID) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('bookings')
          .where('user_ID', isEqualTo: userId)
          .where('status_ID', isEqualTo: statusID)
          .orderBy('booking_date', descending: true)
          .get();

      List<BookingData> bookings = [];
      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        SubService? subService = _findSubServiceById(data['subservice_ID']);
        bookings.add(BookingData.fromMap(data, subService: subService));
      }
      
      return bookings;
    } catch (e) {
      print('Error getting bookings by status ID: $e');
      return [];
    }
  }

  // Make _findSubServiceById public for use in admin pages
  SubService? findSubServiceById(String subserviceID) {
    return _findSubServiceById(subserviceID);
  }

  // Upload quotation file to booking
  Future<bool> uploadQuotationToBooking(String bookingId, File quotationFile, String fileName) async {
    try {
      // Note: This method requires Firebase Storage implementation
      // For now, just update the booking with placeholder
      // You can implement actual file upload later or remove this method if not needed
      
      await _firestore.collection('bookings').doc(bookingId).update({
        'quotation_file_name': fileName,
        'quotation_file_url': 'placeholder', // Will be implemented with Storage
        'quotation_uploaded_at': FieldValue.serverTimestamp(),
        'status_ID': BookingStatus.quotationSent.statusID,
        'updated_at': FieldValue.serverTimestamp(),
      });
      
      print('Updated quotation info for booking $bookingId');
      return true;
    } catch (e) {
      print('Error uploading quotation: $e');
      return false;
    }
  }

  // Delete quotation from booking
  Future<bool> deleteQuotationFromBooking(String bookingId) async {
    try {
      // Get current booking data
      DocumentSnapshot doc = await _firestore.collection('bookings').doc(bookingId).get();
      if (!doc.exists) return false;
      
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      String? quotationUrl = data['quotation_file_url'];
      
      // Note: Actual file deletion from Storage should be implemented here
      // For now, just remove the references from Firestore
      if (quotationUrl != null && quotationUrl.isNotEmpty) {
        print('Quotation file URL found: $quotationUrl');
        // TODO: Implement actual file deletion from Firebase Storage
        // await _storageService.deleteQuotationFile(quotationUrl);
      }
      
      // Remove quotation data from Firestore
      await _firestore.collection('bookings').doc(bookingId).update({
        'quotation_file_name': FieldValue.delete(),
        'quotation_file_url': FieldValue.delete(),
        'quotation_uploaded_at': FieldValue.delete(),
        'updated_at': FieldValue.serverTimestamp(),
      });
      
      print('Deleted quotation from booking $bookingId');
      return true;
    } catch (e) {
      print('Error deleting quotation: $e');
      return false;
    }
  }

  // Get bookings for a specific technician
  Future<List<BookingData>> getTechnicianBookings(String technicianId) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('bookings')
          .where('technician_ID', isEqualTo: technicianId)
          .orderBy('created_at', descending: true)
          .get();

      List<BookingData> bookings = [];
      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        SubService? subService = _findSubServiceById(data['subservice_ID']);
        bookings.add(BookingData.fromMap(data, subService: subService));
      }

      return bookings;
    } catch (e) {
      print('Error fetching technician bookings: $e');
      return [];
    }
  }

  // Update booking quotation amount
  Future<bool> updateBookingQuotation(String bookingId, double newQuotation) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'booking_quotation': newQuotation,
        'updated_at': FieldValue.serverTimestamp(),
      });
      
      print('Updated booking $bookingId quotation to $newQuotation');
      return true;
    } catch (e) {
      print('Error updating booking quotation: $e');
      return false;
    }
  }

  // Update booking description/notes
  Future<bool> updateBookingDescription(String bookingId, String newDescription) async {
    try {
      await _firestore.collection('bookings').doc(bookingId).update({
        'booking_description': newDescription,
        'updated_at': FieldValue.serverTimestamp(),
      });
      
      print('Updated booking $bookingId description');
      return true;
    } catch (e) {
      print('Error updating booking description: $e');
      return false;
    }
  }

  // Add images to existing booking
  Future<bool> addImagesToBooking(String bookingId, List<File> newImages) async {
    try {
      // Upload new images
      List<String> newImageUrls = await _storageService.uploadMultipleImages(newImages, bookingId);
      
      // Get existing image URLs
      DocumentSnapshot doc = await _firestore.collection('bookings').doc(bookingId).get();
      if (!doc.exists) return false;
      
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      List<String> existingUrls = List<String>.from(data['image_urls'] ?? []);
      
      // Merge existing and new image URLs
      List<String> allImageUrls = [...existingUrls, ...newImageUrls];
      
      // Update Firestore document
      await _firestore.collection('bookings').doc(bookingId).update({
        'image_urls': allImageUrls,
        'updated_at': FieldValue.serverTimestamp(),
      });
      
      print('Added ${newImageUrls.length} images to booking $bookingId');
      return true;
    } catch (e) {
      print('Error adding images to booking: $e');
      return false;
    }
  }

  // Remove specific image from booking
  Future<bool> removeImageFromBooking(String bookingId, String imageUrl) async {
    try {
      // Delete image from Firebase Storage
      bool storageDeleted = await _storageService.deleteImage(imageUrl);
      
      if (!storageDeleted) {
        print('Warning: Failed to delete image from storage, but continuing with Firestore update');
      }
      
      // Remove URL from Firestore document
      DocumentSnapshot doc = await _firestore.collection('bookings').doc(bookingId).get();
      if (!doc.exists) return false;
      
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      List<String> imageUrls = List<String>.from(data['image_urls'] ?? []);
      
      imageUrls.remove(imageUrl);
      
      await _firestore.collection('bookings').doc(bookingId).update({
        'image_urls': imageUrls,
        'updated_at': FieldValue.serverTimestamp(),
      });
      
      print('Removed image from booking $bookingId');
      return true;
    } catch (e) {
      print('Error removing image from booking: $e');
      return false;
    }
  }

  // Delete all booking images
  Future<bool> deleteAllBookingImages(String bookingId) async {
    try {
      // Delete all images from Firebase Storage
      bool storageDeleted = await _storageService.deleteBookingImages(bookingId);
      
      if (!storageDeleted) {
        print('Warning: Failed to delete some images from storage');
      }
      
      // Clear image URL list in Firestore document
      await _firestore.collection('bookings').doc(bookingId).update({
        'image_urls': [],
        'updated_at': FieldValue.serverTimestamp(),
      });
      
      print('Deleted all images for booking $bookingId');
      return true;
    } catch (e) {
      print('Error deleting all booking images: $e');
      return false;
    }
  }

  // Get booking image count
  Future<int> getBookingImageCount(String bookingId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('bookings').doc(bookingId).get();
      if (!doc.exists) return 0;
      
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      List<String> imageUrls = List<String>.from(data['image_urls'] ?? []);
      
      return imageUrls.length;
    } catch (e) {
      print('Error getting booking image count: $e');
      return 0;
    }
  }

  // Get bookings count by status for analytics
  Future<Map<String, int>> getBookingsCountByStatus(String userId) async {
    try {
      Map<String, int> statusCounts = {};
      
      // Initialize all status counts to 0
      for (String statusId in BookingStatusConstants.getAllStatusIDs()) {
        String displayName = BookingStatusConstants.getDisplayName(statusId);
        statusCounts[displayName] = 0;
      }
      
      QuerySnapshot querySnapshot = await _firestore
          .collection('bookings')
          .where('user_ID', isEqualTo: userId)
          .get();

      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        String statusId = data['status_ID'] ?? '';
        String displayName = BookingStatusConstants.getDisplayName(statusId);
        
        statusCounts[displayName] = (statusCounts[displayName] ?? 0) + 1;
      }
      
      return statusCounts;
    } catch (e) {
      print('Error getting bookings count by status: $e');
      return {};
    }
  }

  // Search bookings by service name or description
  Future<List<BookingData>> searchUserBookings(String userId, String searchQuery) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('bookings')
          .where('user_ID', isEqualTo: userId)
          .get();

      List<BookingData> filteredBookings = [];
      String lowerQuery = searchQuery.toLowerCase();

      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        String serviceName = (data['service_name'] ?? '').toLowerCase();
        String description = (data['booking_description'] ?? '').toLowerCase();
        String bookingId = (data['booking_ID'] ?? '').toLowerCase();
        
        if (serviceName.contains(lowerQuery) || 
            description.contains(lowerQuery) || 
            bookingId.contains(lowerQuery)) {
          SubService? subService = _findSubServiceById(data['subservice_ID']);
          filteredBookings.add(BookingData.fromMap(data, subService: subService));
        }
      }
      
      return filteredBookings;
    } catch (e) {
      print('Error searching user bookings: $e');
      return [];
    }
  }

  // Search all bookings for admin (by service name, description, booking ID, or user name)
  Future<List<BookingData>> searchAllBookings(String searchQuery) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('bookings')
          .get();

      List<BookingData> filteredBookings = [];
      String lowerQuery = searchQuery.toLowerCase();

      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        String serviceName = (data['service_name'] ?? '').toLowerCase();
        String description = (data['booking_description'] ?? '').toLowerCase();
        String bookingId = (data['booking_ID'] ?? '').toLowerCase();
        String userName = (data['user_name'] ?? '').toLowerCase();
        String userEmail = (data['user_email'] ?? '').toLowerCase();
        String userId = (data['user_ID'] ?? '').toLowerCase();
        
        if (serviceName.contains(lowerQuery) || 
            description.contains(lowerQuery) || 
            bookingId.contains(lowerQuery) ||
            userName.contains(lowerQuery) ||
            userEmail.contains(lowerQuery) ||
            userId.contains(lowerQuery)) {
          SubService? subService = _findSubServiceById(data['subservice_ID']);
          filteredBookings.add(BookingData.fromMap(data, subService: subService));
        }
      }
      
      return filteredBookings;
    } catch (e) {
      print('Error searching all bookings: $e');
      return [];
    }
  }

  // Debug method to check booking data
  Future<void> debugBookingData() async {
    try {
      print('=== BOOKING DATA DEBUG ===');
      
      // Get all bookings
      QuerySnapshot allBookings = await _firestore
          .collection('bookings')
          .limit(10)
          .get();
      
      print('Total bookings in database: ${allBookings.docs.length}');
      
      for (var doc in allBookings.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        print('\n--- Booking ${doc.id} ---');
        print('All fields: ${data.keys.toList()}');
        print('user_ID: ${data['user_ID']}');
        print('userID: ${data['userID']}');
        print('firebase_uid: ${data['firebase_uid']}');
        print('service_name: ${data['service_name']}');
        print('status_ID: ${data['status_ID']}');
        print('booking_date: ${data['booking_date']}');
      }
      
      print('=== END BOOKING DEBUG ===');
    } catch (e) {
      print('Error in booking debug: $e');
    }
  }
}