// lib/screens/admin_techniciansch.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import "admin_header.dart";
import 'package:home_service_system/screens/admin_sidebar.dart';
import 'package:home_service_system/firebase_service/booking_service.dart';
import 'package:home_service_system/firebase_service/technician_service.dart';
import 'package:home_service_system/firebase_service/quotation_service.dart';
import 'package:home_service_system/models/models.dart';
import 'package:home_service_system/models/rating_model.dart';
import 'package:home_service_system/models/quotation_models.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:home_service_system/firebase_service/fcm_sercive.dart';
import 'package:home_service_system/screens/admin_notifications_sidebar.dart';

class TechnicianSchedulePage extends StatefulWidget {
  const TechnicianSchedulePage({super.key});

  @override
  _TechnicianSchedulePageState createState() => _TechnicianSchedulePageState();
}

class _TechnicianSchedulePageState extends State<TechnicianSchedulePage> {
  int _selectedIndex = 2;
  DateTime _selectedDate = DateTime.now();
  String? _selectedTechnicianId;
  bool _showNotifications = false;
  bool _isSidebarCollapsed = false;

  // Firebase data
  List<BookingData> _allBookings = [];
  List<TechnicianModel> _technicians = [];
  Map<String, RatingModel> _ratings = {};
  bool _isLoading = true;
  int _totalTechnicians = 0;

  // Service references
  BookingService? _bookingService;
  TechnicianService? _technicianService;
  QuotationService? _quotationService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeServices();
      _loadData();
      _initializeFCM();
    });
  }

  void _initializeServices() {
    if (mounted) {
      _bookingService = Provider.of<BookingService>(context, listen: false);
      _technicianService = Provider.of<TechnicianService>(context, listen: false);
      _quotationService = Provider.of<QuotationService>(context, listen: false);
    }
  }

  Future<void> _loadData() async {
    try {
      print('=== Loading Technician Schedule Data ===');
      setState(() {
        _isLoading = true;
      });

      if (_bookingService == null || _technicianService == null || _quotationService == null) {
        _initializeServices();
      }
      
      // Load all bookings and technicians
      final bookings = await _bookingService!.getAllBookings();
      final technicians = await _technicianService!.getAllTechnicians();
      
      // Load ratings data
      await _loadRatingsData();

      print('Loaded ${bookings.length} bookings');
      print('Loaded ${technicians.length} technicians');
      print('Loaded ${_ratings.length} ratings');

      if (mounted) {
        setState(() {
          _allBookings = bookings;
          _technicians = technicians;
          _totalTechnicians = technicians.length;
          _isLoading = false;
        });
      }

      print('✓ Data loaded successfully');
    } catch (e) {
      print('❌ Error loading data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

Future<void> _initializeFCM() async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    await FCMService.initialize(
      userType: UserType.admin,
      userId: currentUser.uid,
    );
  }
}
  // Load ratings data from Firebase
  Future<void> _loadRatingsData() async {
    try {
      final ratingsSnapshot = await FirebaseFirestore.instance
          .collection('ratings')
          .get();
      
      Map<String, RatingModel> ratingsMap = {};
      for (var doc in ratingsSnapshot.docs) {
        final rating = RatingModel.fromMap(doc.data());
        ratingsMap[rating.bookingId] = rating;
      }
      
      _ratings = ratingsMap;
    } catch (e) {
      print('Error loading ratings: $e');
    }
  }

  // Get rating for a booking
  RatingModel? _getRatingForBooking(String? bookingId) {
    if (bookingId == null) return null;
    return _ratings[bookingId];
  }

  // Get star display widget
  Widget _buildStarRating(int rating, {double size = 16}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating ? Icons.star : Icons.star_border,
          color: index < rating ? Colors.amber[600] : Colors.grey[400],
          size: size,
        );
      }),
    );
  }

  // Get rating text
  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return 'Not Rated';
    }
  }



  // NEW: View quotation details
  Future<void> _viewQuotationDetails(String bookingId) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final quotations = await _quotationService!.getQuotationsForBooking(bookingId);
      
      Navigator.pop(context); // Close loading dialog

      if (quotations.isNotEmpty) {
        final quotation = quotations.first;
        _showQuotationDetailsDialog(quotation);
      } else {
        _showErrorMessage('No quotation found for this booking');
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      print('Error viewing quotation: $e');
      _showErrorMessage('Error loading quotation details');
    }
  }

  // NEW: Show quotation details dialog
  void _showQuotationDetailsDialog(QuotationData quotation) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    color: Colors.yellow[300],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.description, color: Colors.black, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quotation Details',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ID: ${quotation.quotationId}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.black, size: 20),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                
                // Content
                Expanded(
                  child: Container(
                    color: Colors.white,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Assessment Section
                          Text(
                            'Assessment',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildQuotationDetailRow('Problem Assessment', quotation.problemAssessment),
                          _buildQuotationDetailRow('Recommended Solution', quotation.recommendedSolution),
                          
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 24),
                          
                          // Materials
                          if (quotation.materialItems.isNotEmpty) ...[
                            Text(
                              'Material Items',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...quotation.materialItems.map((item) => 
                              _buildMaterialItemRow(item)
                            ).toList(),
                            const SizedBox(height: 8),
                            Divider(color: Colors.grey[300]),
                            const SizedBox(height: 8),
                            _buildQuotationInfoRow('Material Subtotal', 'RM${quotation.materialSubtotal.toStringAsFixed(2)}'),
                            const SizedBox(height: 24),
                            const Divider(),
                            const SizedBox(height: 24),
                          ],
                          
                          // Labor Items
                          if (quotation.laborItems.isNotEmpty) ...[
                            Text(
                              'Labor Items',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...quotation.laborItems.map((item) => 
                              _buildMaterialItemRow(item)
                            ).toList(),
                            const SizedBox(height: 8),
                            Divider(color: Colors.grey[300]),
                            const SizedBox(height: 8),
                            _buildQuotationInfoRow('Labor Subtotal', 'RM${quotation.laborSubtotal.toStringAsFixed(2)}'),
                            const SizedBox(height: 24),
                            const Divider(),
                            const SizedBox(height: 24),
                          ],
                          
                          // Cost Summary
                          Text(
                            'Cost Summary',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (quotation.installationFee > 0)
                            _buildQuotationInfoRow('Installation Fee', 'RM${quotation.installationFee.toStringAsFixed(2)}'),
                          if (quotation.transportationFee > 0)
                            _buildQuotationInfoRow('Transportation Fee', 'RM${quotation.transportationFee.toStringAsFixed(2)}'),
                          _buildQuotationInfoRow('Subtotal', 'RM${quotation.subtotal.toStringAsFixed(2)}'),
                          _buildQuotationInfoRow('Tax (8%)', 'RM${quotation.taxAmount.toStringAsFixed(2)}'),
                          if (quotation.discountAmount > 0)
                            _buildQuotationInfoRow('Discount', '-RM${quotation.discountAmount.toStringAsFixed(2)}'),
                          const SizedBox(height: 12),
                          Divider(thickness: 2, color: Colors.grey[400]),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.yellow[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'TOTAL AMOUNT',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                  ),
                                ),
                                Text(
                                  'RM${quotation.grandTotal.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.yellow[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Footer with Close Button
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          side: BorderSide(color: Colors.yellow[700]!, width: 1.5),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        ),
                        child: const Text('Close', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuotationInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotationDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialItemRow(QuotationItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              item.description,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              '${item.quantity}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'RM${item.unitPrice.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              'RM${item.totalPrice.toStringAsFixed(2)}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _handleRefresh() async {
    await _loadData();
  }

  void _resetFilters() {
    setState(() {
      _selectedDate = DateTime.now();
      _selectedTechnicianId = null;
    });
  }

  String _getTechnicianNameById(String? technicianID) {
    if (technicianID == null || technicianID.isEmpty) return 'Unassigned';
    
    try {
      return _technicians.firstWhere(
        (t) => t.technicianID == technicianID
      ).technicianName;
    } catch (e) {
      return technicianID;
    }
  }

  TechnicianModel? _getTechnicianById(String? technicianID) {
    if (technicianID == null || technicianID.isEmpty) return null;
    
    try {
      return _technicians.firstWhere(
        (t) => t.technicianID == technicianID
      );
    } catch (e) {
      return null;
    }
  }

  // Filter bookings for selected date and with assigned technician
  List<BookingData> _getFilteredBookings() {
    return _allBookings.where((booking) {
      bool hasDate = booking.bookingDate.year == _selectedDate.year &&
                     booking.bookingDate.month == _selectedDate.month &&
                     booking.bookingDate.day == _selectedDate.day;
      bool hasTechnician = booking.technicianID != null && booking.technicianID!.isNotEmpty;
      
      // Apply technician filter if selected
      bool matchesTechnician = _selectedTechnicianId == null || 
                               booking.technicianID == _selectedTechnicianId;
      
      return hasDate && hasTechnician && matchesTechnician;
    }).toList();
  }

  void _showBookingDetailDialog(BookingData booking) {
    TechnicianModel? technician = _getTechnicianById(booking.technicianID);
    RatingModel? rating = _getRatingForBooking(booking.bookingID);
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 700,
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 30,
                offset: Offset(0, 15),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Section
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.yellow[700]!,
                      Colors.yellow[300]!,
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.assignment,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Booking Details',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            booking.bookingID ?? 'N/A',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content Section
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Badge Row
                      Row(
                        children: [
                          _buildLargerStatusBadge(booking.statusID),
                          Spacer(),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                                SizedBox(width: 4),
                                Text(
                                DateFormat('MM/dd/yyyy').format(booking.bookingDate),
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                              SizedBox(width: 4),
                              Text(
                                '${booking.bookingTime.hour.toString().padLeft(2, '0')}:${booking.bookingTime.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      SizedBox(height: 24),
                      
                      // Customer Information Card
                      _buildInfoCard(
                        title: 'Customer Information',
                        icon: Icons.person,
                        iconColor: Colors.blue,
                        children: [
                          _buildDetailItem(Icons.person_outline, 'Customer Name', booking.userName),
                          _buildDetailItem(Icons.email_outlined, 'Email', booking.userEmail),
                          _buildDetailItem(Icons.phone_outlined, 'Phone', booking.userPhone),
                          _buildDetailItem(Icons.location_on_outlined, 'Address', booking.bookingAddress),
                        ],
                      ),
                      
                      SizedBox(height: 20),
                      
                      // Service Information Card
                      _buildInfoCard(
                        title: 'Service Information',
                        icon: Icons.build,
                        iconColor: Colors.orange,
                        children: [
                          _buildDetailItem(Icons.category_outlined, 'Service Type', booking.serviceName),
                          _buildDetailItem(Icons.settings_outlined, 'Sub-service', booking.subService.subserviceName),
                        ],
                      ),
                      
                      SizedBox(height: 20),
                      
                      // Technician Information Card (removed active jobs)
                      if (technician != null) ...[
                        _buildInfoCard(
                          title: 'Assigned Technician',
                          icon: Icons.engineering,
                          iconColor: Colors.green,
                          children: [
                            _buildDetailItem(Icons.badge_outlined, 'Technician ID', technician.technicianID),
                            _buildDetailItem(Icons.person_outline, 'Name', technician.technicianName),
                            _buildDetailItem(Icons.email_outlined, 'Email', technician.technicianEmail),
                            _buildDetailItem(Icons.phone_outlined, 'Phone', technician.technicianPhoneNumber),
                            _buildDetailItem(Icons.work_outline, 'Specializations', 
                              technician.specializations.join(', ')),
                          ],
                        ),
                        SizedBox(height: 20),
                      ],
                      
                      // Quotation Information Card (NEW: Properly implemented)
                      FutureBuilder<List<QuotationData>>(
                        future: _quotationService!.getQuotationsForBooking(booking.bookingID!),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                            final quotation = snapshot.data!.first;
                            return Column(
                              children: [
                                _buildInfoCard(
                                  title: 'Quotation Information',
                                  icon: Icons.description,
                                  iconColor: Colors.yellow[700]!,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Row(
                                        children: [
                                          Icon(Icons.attach_money, color: Colors.yellow[700], size: 20),
                                          SizedBox(width: 8),
                                          Text(
                                            'Total Amount: ',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                          Text(
                                            'RM${quotation.grandTotal.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.yellow[700],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: ElevatedButton.icon(
                                        icon: Icon(Icons.visibility, size: 16),
                                        label: Text('View Quotation Details'),
                                        onPressed: () {
                                          Navigator.pop(context); // Close current dialog
                                          _viewQuotationDetails(booking.bookingID!);
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.yellow[300],
                                          foregroundColor: Colors.black,
                                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 20),
                              ],
                            );
                          }
                          return SizedBox.shrink();
                        },
                      ),
                      
                      // Rating Information Card
                      if (rating != null) ...[
                        _buildInfoCard(
                          title: 'Customer Rating & Feedback',
                          icon: Icons.star,
                          iconColor: Colors.amber[700]!,
                          children: [
                            // Rating stars and text
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      Icons.star_outlined,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      'Rating',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[700],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            _buildStarRating(rating.rating, size: 18),
                                            SizedBox(width: 8),
                                            Text(
                                              '${rating.rating}/5',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Colors.amber[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          _getRatingText(rating.rating),
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Rating comment
                            if (rating.comment.isNotEmpty)
                              _buildDetailItem(Icons.comment_outlined, 'Comment', rating.comment),
                            // Rating date
                            _buildDetailItem(Icons.schedule_outlined, 'Rated On', 
                              DateFormat('MMM dd, yyyy HH:mm').format(rating.createdAt)),
                          ],
                        ),
                        SizedBox(height: 20),
                      ],
                      
                      // Scheduling Information Card
                      _buildInfoCard(
                        title: 'Scheduling Information',
                        icon: Icons.schedule,
                        iconColor: Colors.purple,
                        children: [
                          _buildDetailItem(Icons.calendar_today_outlined, 'Appointment Date', 
                            DateFormat('MM/dd/yyyy').format(booking.bookingDate)),
                          _buildDetailItem(Icons.access_time_outlined, 'Appointment Time', 
                            '${booking.bookingTime.hour}:${booking.bookingTime.minute.toString().padLeft(2, '0')}'),
                        ],
                      ),
                      
                      SizedBox(height: 20),
                      
                      // Images Section
                      if (booking.imageUrls.isNotEmpty) ...[
                        _buildInfoCard(
                          title: 'Attached Images',
                          icon: Icons.photo,
                          iconColor: Colors.pink,
                          children: [
                            Container(
                              height: 120,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: booking.imageUrls.length,
                                itemBuilder: (context, index) {
                                  return Container(
                                    margin: EdgeInsets.only(right: 12),
                                    width: 120,
                                    height: 120,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.grey[200]!, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 8,
                                          offset: Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(
                                        booking.imageUrls[index],
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            color: Colors.grey[100],
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.broken_image, color: Colors.grey[400], size: 32),
                                                SizedBox(height: 4),
                                                Text('Image Error', 
                                                  style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                      ],
                    ],
                  ),
                ),
              ),
              
              // Footer Section
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('Close', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[600],
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLargerStatusBadge(String statusID) {
    String displayName = BookingStatusConstants.getDisplayName(statusID);
    Color color = BookingStatusConstants.getStatusColor(statusID);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Text(
        displayName,
        style: TextStyle(
          color: color,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: iconColor,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              size: 16,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: TextStyle(
                color: Colors.black87,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<BookingData> filteredBookings = _getFilteredBookings();
    
    return Scaffold(
      body: Row(
        children: [
       AdminSidebar(
          selectedIndex: _selectedIndex,
          onItemSelected: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          isCollapsed: _isSidebarCollapsed,
          onToggleCollapse: () {
            setState(() {
              _isSidebarCollapsed = !_isSidebarCollapsed;
            });
          },
        ),
          Expanded(
child: Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.yellow[50]!,
        Colors.white,
        Colors.yellow[50]!,
      ],
    ),
  ),
  child: Stack(  // ⭐ 添加 Stack
    children: [
      SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 0),
              child: _buildHeader(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 0),
              child: _buildDateSelector(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 0),
              child: _buildStatsRow(filteredBookings.length),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: RefreshIndicator(
                  onRefresh: _handleRefresh,
                  child: _buildDailySchedule(filteredBookings),
                ),
              ),
            ),
          ],
        ),
      ),
      // ⭐ 添加通知 Sidebar
      if (_showNotifications)
        AdminNotificationsSidebar(
          adminId: FirebaseAuth.instance.currentUser?.uid ?? '',
          onClose: () {
            setState(() {
              _showNotifications = false;
            });
          },
        ),
    ],
  ),
),
          ),
        ],
      ),
    );
  }


Widget _buildHeader() {
  return AdminHeaderWithNotification(
    title: 'Technician Schedule',
    isSidebarCollapsed: _isSidebarCollapsed,
    onToggleSidebar: () {
      setState(() {
        _isSidebarCollapsed = !_isSidebarCollapsed;
      });
    },
    onNotificationTap: () {
      setState(() {
        _showNotifications = !_showNotifications;
      });
    },
  );
}

  Widget _buildDateSelector() {
    return Column(
      children: [
        // First row with date selector, technician filter, and Today button
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 16),
                    onPressed: () {
                      setState(() {
                        _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    DateFormat('MMMM d, yyyy').format(_selectedDate),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios, size: 16),
                    onPressed: () {
                      setState(() {
                        _selectedDate = _selectedDate.add(const Duration(days: 1));
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Technician Filter
            Container(
              width: 250,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedTechnicianId,
                  icon: const Icon(Icons.keyboard_arrow_down),
                  isExpanded: true,
                  hint: Row(
                    children: [
                      Icon(Icons.engineering, size: 16, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Filter by Technician', style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                  items: [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Row(
                        children: [
                          Icon(Icons.engineering, size: 16, color: Colors.green),
                          SizedBox(width: 8),
                          Text('All Technicians'),
                        ],
                      ),
                    ),
                    ..._technicians.map((technician) {
                      return DropdownMenuItem<String>(
                        value: technician.technicianID,
                        child: Row(
                          children: [
                            Icon(Icons.person, size: 16, color: Colors.cyan[700]),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                technician.technicianName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedTechnicianId = newValue;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.today, size: 16),
              label: const Text('Today'),
              onPressed: () {
                setState(() {
                  _selectedDate = DateTime.now();
                });
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.grey[700],
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                side: BorderSide(color: Colors.grey[300]!),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Second row with Reset button
        Row(
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.restart_alt, size: 16),
              label: const Text('Reset'),
              onPressed: _resetFilters,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.grey[700],
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                side: BorderSide(color: Colors.grey[300]!),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsRow(int appointmentCount) {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.engineering, color: Colors.green, size: 24),
          const SizedBox(width: 8),
          Text(
            'Total Technicians: ',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
          Text(
            '$_totalTechnicians',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(width: 32),
          Icon(Icons.assignment, color: Colors.orange[600], size: 24),
          const SizedBox(width: 8),
          Text(
            'Total Appointments: ',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[700],
            ),
          ),
          Text(
            '$appointmentCount',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.orange[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDailySchedule(List<BookingData> filteredBookings) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.blue[600]),
            const SizedBox(height: 16),
            Text(
              'Loading schedule...',
              style: TextStyle(
                color: Colors.blue[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Appointments for ${DateFormat('MMMM d, yyyy').format(_selectedDate)}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: filteredBookings.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.event_busy,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No appointments scheduled for this date',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: filteredBookings.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final appointment = filteredBookings[index];
                        return _buildAppointmentItem(appointment);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentItem(BookingData appointment) {
    RatingModel? rating = _getRatingForBooking(appointment.bookingID);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 249, 252, 255),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.access_time,
                      color: Colors.blue,
                      size: 20,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${appointment.bookingTime.hour}:${appointment.bookingTime.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          appointment.bookingID ?? 'N/A',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _buildStatusBadge(appointment.statusID),
                        // Show rating indicator if available
                        if (rating != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber[200]!),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star, size: 12, color: Colors.amber[600]),
                                SizedBox(width: 2),
                                Text(
                                  '${rating.rating}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      appointment.subService.subserviceName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          appointment.userName,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          appointment.userPhone,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            appointment.bookingAddress,
                            style: const TextStyle(fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.engineering, size: 16, color: Colors.green),
                        const SizedBox(width: 4),
                        Text(
                          'Technician: ${_getTechnicianNameById(appointment.technicianID)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    // REMOVED: Description section is completely removed from here
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.remove_red_eye, size: 16),
              label: const Text('View Detail'),
              onPressed: () => _showBookingDetailDialog(appointment),
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue[700],
                backgroundColor: Colors.blue[50],
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String statusID) {
    String displayName = BookingStatusConstants.getDisplayName(statusID);
    Color color = BookingStatusConstants.getStatusColor(statusID);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        displayName,
        style: TextStyle(
          color: color.withOpacity(0.8),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}