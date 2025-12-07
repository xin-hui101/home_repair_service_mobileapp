// lib/screens/admin_servicerequestpage.dart 
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:home_service_system/screens/admin_header.dart';
import 'package:home_service_system/screens/admin_sidebar.dart';
import 'package:home_service_system/firebase_service/booking_service.dart';
import 'package:home_service_system/firebase_service/technician_service.dart';
import 'package:home_service_system/firebase_service/quotation_service.dart';
import 'package:home_service_system/models/models.dart';
import 'package:home_service_system/models/rating_model.dart';
import 'package:home_service_system/models/quotation_models.dart';
import 'package:home_service_system/firebase_service/fcm_sercive.dart';
import 'package:home_service_system/screens/admin_notifications_sidebar.dart';

class ServiceRequestManagementPage extends StatefulWidget {
  const ServiceRequestManagementPage({super.key});

  @override
  _ServiceRequestManagementPageState createState() => _ServiceRequestManagementPageState();
}

class _ServiceRequestManagementPageState extends State<ServiceRequestManagementPage> {
  bool _showNotifications = false;
  int _selectedIndex = 1;
  int _selectedTabIndex = 0;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  DateTime? _selectedDate;
  String? _selectedServiceType;

  bool _isSidebarCollapsed = false;
  
  // Firebase data
  List<BookingData> _allBookings = [];
  List<TechnicianModel> _technicians = [];
  Map<String, RatingModel> _ratings = {};
  bool _isLoading = true;

  // Service references
  BookingService? _bookingService;
  TechnicianService? _technicianService;
  QuotationService? _quotationService;

  // Service categories for filtering
  final List<String> serviceCategories = [
    'All Services',
    'Plumbing Services',
    'Roof Services',
    'Painting',
    'Wall Maintenance'
  ];
  

  @override
  void initState() {
    super.initState();
    _initializeFCM();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeServices();
      _loadData();
    });
    
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Initialize service references
  void _initializeServices() {
    if (mounted) {
      _bookingService = Provider.of<BookingService>(context, listen: false);
      _technicianService = Provider.of<TechnicianService>(context, listen: false);
      _quotationService = Provider.of<QuotationService>(context, listen: false);
    }
  }

  // Load all data from Firebase
Future<void> _loadData() async {
  try {
    print('=== Loading Service Requests ===');
    print('Current user: ${FirebaseAuth.instance.currentUser?.uid}');
    print('Current user email: ${FirebaseAuth.instance.currentUser?.email}');
    
    setState(() {
      _isLoading = true;
    });

    if (_bookingService == null || _technicianService == null || _quotationService == null) {
      _initializeServices();
    }
    
    final bookings = await _bookingService!.getAllBookings();
    print('Loaded ${bookings.length} bookings');
    
    final technicians = await _technicianService!.getAllTechnicians();
    print('Loaded ${technicians.length} technicians');
    
    // Load ratings data
    await _loadRatingsData();
    
    // 打印技术员信息
    for (var tech in technicians) {
      print('Technician: ${tech.technicianName} (ID: ${tech.technicianID})');
    }

    if (mounted) {
      setState(() {
        _allBookings = bookings;
        _technicians = technicians;
        _isLoading = false;
      });
    }
  } catch (e) {
    print('❌ Error loading data: $e');
    print('Stack trace: ${StackTrace.current}');
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
      print('Loaded ${_ratings.length} ratings');
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

  // View quotation details
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

  // Show quotation details dialog
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

  // Pull to refresh
  Future<void> _handleRefresh() async {
    await _loadData();
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedServiceType = null;
      _selectedDate = null;
    });
  }


  // Get technician model by ID
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

  // Show booking detail dialog (UPDATED to match technician schedule style)
void _showBookingDetailDialog(BookingData booking) {
  TechnicianModel? technician = _getTechnicianById(booking.technicianID);
  RatingModel? rating = _getRatingForBooking(booking.bookingID);
  
  // Check if booking is cancelled
  bool isCancelled = BookingStatusConstants.getDisplayName(booking.statusID) == 'Cancelled';
  
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
                              Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
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
                    
                    // Service Information Card (removed quotation)
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
                    
                    // Quotation Information Card (matching technician schedule style)
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
            
            // Action Buttons Section
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
                  // Assign Technician button - only show if Pending and unassigned
                  if (BookingStatusConstants.getDisplayName(booking.statusID) == 'Pending' && 
                      booking.technicianID == null) ...[
                    Container(
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showAssignTechnicianDialog(booking);
                        },
                        icon: Icon(Icons.person_add, size: 18, color: Colors.white),
                        label: Text('Assign Technician', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shadowColor: Colors.green.withOpacity(0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                  ],
                  
                  // Update Status button - hide if Cancelled
                  if (!isCancelled)
                    Container(
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _showUpdateStatusDialog(booking);
                        },
                        icon: Icon(Icons.edit, size: 18, color: Colors.white),
                        label: Text('Update Status', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shadowColor: Colors.blue.withOpacity(0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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

// New method for larger status badge
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

// Helper method for info cards
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

// Helper method for detail items
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


// Helper method for displaying info rows in dialog
Widget _buildInfoRowInDialog(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

void _showUpdateStatusDialog(BookingData booking) {
  final bookingService = _bookingService;
  if (bookingService == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Service not available. Please try again.'),
        backgroundColor: Colors.red,
      ),
    );
    return;
  }

  String currentDisplayStatus = BookingStatusConstants.getDisplayName(booking.statusID);
  
  // If current status is one of the excluded statuses, default to 'Accepted'
  String newStatus = (currentDisplayStatus == 'Pending' || 
                      currentDisplayStatus == 'Quotation Sent' || 
                      currentDisplayStatus == 'In Progress')
      ? 'Accepted'
      : currentDisplayStatus;
  
  String? selectedTime;
  DateTime? selectedDate;
  final TextEditingController cancellationReasonController = TextEditingController();
  
  final List<String> timeSlots = [
    '9am',
    '10am', 
    '11am',
    '12pm',
    '1pm',
    '2pm',
    '3pm',
    '4pm',
  ];
  
  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setStateDialog) => AlertDialog(
        backgroundColor: Colors.white,
        title: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Update Status for ',
                style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text: '${booking.bookingID}',
                style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        content: Container(
          width: double.maxFinite,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Customer: ',
                        style: TextStyle(color: Colors.black, fontSize: 14),
                      ),
                      TextSpan(
                        text: '${booking.userName}',
                        style: TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Text('Service: ${booking.subService.subserviceName}'),
                Text('Current Status: $newStatus'),
                const SizedBox(height: 16),
                
                // Status Dropdown - excluding Pending, Quotation Sent, In Progress
                DropdownButtonFormField<String>(
                  value: newStatus,
                  decoration: const InputDecoration(
                    labelText: 'New Status',
                    border: OutlineInputBorder(),
                  ),
                  items: BookingStatusConstants.getAllDisplayStatuses()
                    .where((status) => 
                      status != 'Pending' && 
                      status != 'Quotation Sent' && 
                      status != 'In Progress'
                    )
                    .map((status) => DropdownMenuItem(
                      value: status,
                      child: Text(status),
                    ))
                    .toList(),
                  onChanged: (value) {
                    setStateDialog(() {
                      newStatus = value!;
                      if (newStatus != 'Scheduled') {
                        selectedTime = null;
                        selectedDate = null;
                      }
                      if (newStatus != 'Cancelled') {
                        cancellationReasonController.clear();
                      }
                    });
                  },
                ),
                
                // Scheduled 状态的字段
                if (newStatus == 'Scheduled') ...[
                  const SizedBox(height: 16),
                  
                  // Current Booking Information Section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.yellow[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.yellow[500]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Current Booking Information',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRowInDialog('Current Date', DateFormat('MM/dd/yyyy').format(booking.bookingDate)),
                        _buildInfoRowInDialog('Current Time', '${booking.bookingTime.hour.toString().padLeft(2, '0')}:${booking.bookingTime.minute.toString().padLeft(2, '0')}'),
                        if (booking.technicianID != null && _getTechnicianById(booking.technicianID!) != null)
                          _buildInfoRowInDialog('Technician', _getTechnicianById(booking.technicianID!)!.technicianName),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // New Schedule Section
                  Text(
                    'New Schedule',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  InkWell(
                    onTap: () async {
                      final DateTime? pickedDate = await showDatePicker(
                        context: context,
                        initialDate: selectedDate ?? DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (pickedDate != null) {
                        setStateDialog(() {
                          selectedDate = pickedDate;
                          selectedTime = null; // Reset time when date changes
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.grey),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedDate != null 
                                  ? DateFormat('MM/dd/yyyy').format(selectedDate!)
                                  : 'Select New Date *',
                              style: TextStyle(
                                color: selectedDate != null ? Colors.black : Colors.grey[600],
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Time slot dropdown with availability check
                  FutureBuilder<List<TimeOfDay>>(
                    future: selectedDate != null 
                        ? bookingService.getBookedTimeSlotsForDate(selectedDate!)
                        : Future.value([]),
                    builder: (context, snapshot) {
                      List<TimeOfDay> bookedSlots = snapshot.data ?? [];
                      
                      return DropdownButtonFormField<String>(
                        value: selectedTime,
                        decoration: InputDecoration(
                          labelText: 'Select New Time Slot *',
                          border: OutlineInputBorder(),
                          hintText: selectedDate == null 
                              ? 'Please select a date first' 
                              : 'Required for scheduling',
                        ),
                        items: timeSlots.map((time) {
                          // Parse time string to TimeOfDay
                          int hour;
                          if (time.contains('pm') && !time.startsWith('12')) {
                            hour = int.parse(time.replaceAll('pm', '')) + 12;
                          } else if (time.contains('am') && time.startsWith('12')) {
                            hour = 0;
                          } else {
                            hour = int.parse(time.replaceAll(RegExp(r'[ap]m'), ''));
                          }
                          
                          TimeOfDay timeOfDay = TimeOfDay(hour: hour, minute: 0);
                          bool isBooked = bookedSlots.any((booked) => 
                            booked.hour == timeOfDay.hour && booked.minute == timeOfDay.minute
                          );
                          
                          return DropdownMenuItem(
                            value: time,
                            enabled: !isBooked && selectedDate != null,
                            child: Row(
                              children: [
                                Text(
                                  time,
                                  style: TextStyle(
                                    color: isBooked 
                                        ? Colors.grey 
                                        : (selectedDate == null ? Colors.grey : Colors.black),
                                  ),
                                ),
                                if (isBooked) ...[
                                  const SizedBox(width: 8),
                                  Text(
                                    '(Booked)',
                                    style: TextStyle(
                                      color: Colors.red[600],
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: selectedDate == null 
                            ? null 
                            : (value) {
                                setStateDialog(() {
                                  selectedTime = value;
                                });
                              },
                      );
                    },
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Reschedule Reason
                  TextField(
                    controller: cancellationReasonController,
                    maxLines: 3,
                    maxLength: 500,
                    decoration: InputDecoration(
                      labelText: 'Reschedule Reason',
                      hintText: 'Provide a reason for rescheduling',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                  
                ],
                
                // Cancelled 状态的原因输入字段
                if (newStatus == 'Cancelled') ...[
                  const SizedBox(height: 12),
                  Text(
                    'Cancellation Reason (Optional)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: cancellationReasonController,
                    maxLines: 3,
                    maxLength: 500,
                    decoration: InputDecoration(
                      hintText: 'Provide a reason for cancellation (optional)',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // ✨ 在下一帧 dispose,确保对话框完全关闭
              WidgetsBinding.instance.addPostFrameCallback((_) {
                cancellationReasonController.dispose();
              });
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color.fromARGB(255, 145, 240, 116),
            ),
            onPressed: () {
              // ✨ 1. 先保存所有需要的值
              final String currentStatus = newStatus;
              final String? reason = newStatus == 'Cancelled' 
                  ? cancellationReasonController.text.trim() 
                  : null;
              final DateTime? scheduleDate = selectedDate;
              final String? scheduleTime = selectedTime;
              
              // ✨ 2. 立即关闭对话框
              Navigator.pop(context);
              
              // ✨ 3. 在下一帧 dispose,确保对话框完全关闭
              WidgetsBinding.instance.addPostFrameCallback((_) {
                cancellationReasonController.dispose();
              });
              
              // ✨ 4. 异步处理后续逻辑
              _handleStatusUpdate(
                booking,
                bookingService,
                currentStatus,
                reason,
                scheduleDate,
                scheduleTime,
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    ),
  );
}

// ✨ 新增:独立的处理方法
Future<void> _handleStatusUpdate(
  BookingData booking,
  BookingService bookingService,
  String currentStatus,
  String? reason,
  DateTime? scheduleDate,
  String? scheduleTime,
) async {
  // 如果选择 Cancelled
  if (currentStatus == 'Cancelled') {
    // 显示加载
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: CircularProgressIndicator(color: Colors.red[600]),
      ),
    );
    
    bool success;
    if (reason != null && reason.isNotEmpty) {
      success = await bookingService.cancelBookingWithReason(
        booking.bookingID!,
        cancelledBy: 'admin',
        cancellationReason: reason,
      );
    } else {
      success = await bookingService.cancelBooking(
        booking.bookingID!,
        cancelledBy: 'admin',
      );
    }
    
    if (mounted) Navigator.pop(context);
    
    if (success) {
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to cancel booking'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    return;
  }
  
  // 验证:Accepted 需要技术员
  if (currentStatus == 'Accepted' && booking.technicianID == null) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please assign a technician before accepting'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
    }
    return;
  }
  
  // 验证:Scheduled 需要日期和时间
  if (currentStatus == 'Scheduled') {
    if (scheduleDate == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a schedule date'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    if (scheduleTime == null || scheduleTime.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a time slot'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
    
    // Check if the selected time slot is available
    // Parse time string to TimeOfDay
    int hour;
    if (scheduleTime.contains('pm') && !scheduleTime.startsWith('12')) {
      hour = int.parse(scheduleTime.replaceAll('pm', '')) + 12;
    } else if (scheduleTime.contains('am') && scheduleTime.startsWith('12')) {
      hour = 0;
    } else {
      hour = int.parse(scheduleTime.replaceAll(RegExp(r'[ap]m'), ''));
    }
    
    TimeOfDay selectedTimeOfDay = TimeOfDay(hour: hour, minute: 0);
    
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
    
    // Check availability
    bool isAvailable = await bookingService.isTimeSlotAvailable(scheduleDate, selectedTimeOfDay);
    
    if (mounted) Navigator.pop(context);
    
    if (!isAvailable) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('The selected time slot is already booked. Please choose another time.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }
  }
  
  // 更新其他状态
  String statusID = BookingStatusConstants.getStatusID(currentStatus);
  
  // Prepare update data
  Map<String, dynamic> updateData = {
    'status_ID': statusID,
    'updated_at': FieldValue.serverTimestamp(),
  };
  
  // Add reschedule reason if provided for Scheduled status
  if (currentStatus == 'Scheduled' && reason != null && reason.isNotEmpty) {
    updateData['reschedule_reason'] = reason;
    updateData['reschedule_date'] = Timestamp.fromDate(scheduleDate!);
    updateData['reschedule_time'] = scheduleTime;
  }
  
  // Update booking
  try {
    await FirebaseFirestore.instance
        .collection('bookings')
        .doc(booking.bookingID!)
        .update(updateData);
    
    if (!mounted) return;
    
    // Reload data after successful update
    await _loadData();
    
    String message = currentStatus == 'Scheduled' 
        ? 'Status updated to $currentStatus for ${DateFormat('MM/dd/yyyy').format(scheduleDate!)} at $scheduleTime'
        : 'Status updated to $currentStatus';
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.green),
      );
    }
  } catch (e) {
    print('Error updating booking status: $e');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

void _showAssignTechnicianDialog(BookingData booking) {
  // Get service reference before showing dialog
  final bookingService = _bookingService;
  if (bookingService == null) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Service not available. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
    return;
  }

  String? selectedTechnicianId;
  
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.white,
      title: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: 'Assign Technician for ',
              style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text: '${booking.bookingID}',
              style: TextStyle(color: Colors.red, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Customer: ',
                  style: TextStyle(color: Colors.black, fontSize: 14),
                ),
                TextSpan(
                  text: '${booking.userName}',
                  style: TextStyle(color: Colors.red, fontSize: 14),
                ),
              ],
            ),
          ),
          Text('Service: ${booking.subService.subserviceName}'),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: const InputDecoration(
              labelText: 'Select Technician',
              border: OutlineInputBorder(),
            ),
            items: _technicians.map((technician) => DropdownMenuItem(
              value: technician.technicianID,
              child: Text(technician.technicianName),
            )).toList(),
            onChanged: (value) {
              selectedTechnicianId = value;
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color.fromARGB(255, 145, 240, 116),
          ),
          onPressed: () async {
            if (selectedTechnicianId == null) {
              // Show error message in dialog context
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(
                  content: Text('Please select a technician'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            // Close dialog first
            Navigator.pop(dialogContext);
            
            try {
              // Show loading indicator
              if (mounted) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              // Assign technician
              bool assignSuccess = await bookingService.assignTechnician(
                booking.bookingID!,
                selectedTechnicianId!,
              );
              
              // Update status to Accepted
              bool statusSuccess = await bookingService.updateBookingStatusById(
                booking.bookingID!,
                BookingStatus.accepted.statusID,
              );
              
              // Close loading dialog
              if (mounted) {
                Navigator.pop(context);
              }
              
              // Check if widget is still mounted before proceeding with UI updates
              if (!mounted) return;
              
              if (assignSuccess && statusSuccess) {
                await _loadData(); // Reload data
                
                // Find technician name safely
                String techName = 'Unknown';
                for (var tech in _technicians) {
                  if (tech.technicianID == selectedTechnicianId) {
                    techName = tech.technicianName;
                    break;
                  }
                }
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Technician $techName assigned successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to assign technician. Please try again.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            } catch (e) {
              // Close loading dialog if it's still open
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          child: const Text('Assign'),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
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
child: Stack(
  children: [
    SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 0),
            child: _buildHeader(),
          ),
          Container(
            height: 40,
            margin: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 0),
            child: _buildTabs(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 0),
            child: _buildSearchAndFilter(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 0),
            child: _buildBookingStats(),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: RefreshIndicator(
                onRefresh: _handleRefresh,
                child: _buildServiceRequestsTable(),
              ),
            ),
          ),
        ],
      ),
    ),
    // ⭐ 替换为新的通知 Sidebar
    if (_showNotifications)
      AdminNotificationsSidebar(
          adminId: 'admin_000',
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
    title: 'Service Request Management',
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

  Widget _buildTabs() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            SizedBox(width: 60, child: _buildTabItem(0, 'All')),
            SizedBox(width: 80, child: _buildTabItem(1, 'Pending')),
            SizedBox(width: 90, child: _buildTabItem(2, 'Accepted')),
            SizedBox(width: 120, child: _buildTabItem(3, 'Quotation Sent')),
            SizedBox(width: 100, child: _buildTabItem(4, 'Scheduled')),
            SizedBox(width: 100, child: _buildTabItem(5, 'In Progress')),
            SizedBox(width: 100, child: _buildTabItem(6, 'Completed')),
            SizedBox(width: 100, child: _buildTabItem(7, 'Cancelled')),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(int index, String title) {
    bool isSelected = _selectedTabIndex == index;
    
    Color backgroundColor;
    if (isSelected) {
      backgroundColor = BookingStatusConstants.getDisplayStatusColor(title);
    } else {
      backgroundColor = Colors.transparent;
    }
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTabIndex = index;
        });
      },
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: Colors.black,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search by ID or customer name',
                    prefixIcon: Icon(Icons.search),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedServiceType ?? serviceCategories[0],
                    icon: const Icon(Icons.keyboard_arrow_down),
                    isExpanded: true,
                    hint: const Text('Filter by service'),
                    items: serviceCategories.map((String item) {
                      return DropdownMenuItem<String>(
                        value: item,
                        child: Text(item),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        _selectedServiceType = newValue == 'All Services' ? null : newValue;
                      });
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: InkWell(
                  onTap: () async {
                    final DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (pickedDate != null && pickedDate != _selectedDate) {
                      setState(() {
                        _selectedDate = pickedDate;
                      });
                    }
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.date_range, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _selectedDate != null 
                              ? DateFormat('MM/dd/yyyy').format(_selectedDate!)
                              : 'Select Date',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_selectedDate != null)
                        InkWell(
                          onTap: () {
                            setState(() {
                              _selectedDate = null;
                            });
                          },
                          child: const Icon(Icons.close, color: Colors.grey, size: 16),
                        )
                      else
                        const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: TextButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.restart_alt, size: 18),
                label: const Text('Reset'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBookingStats() {
    List<BookingData> currentBookings = [];
    String currentStatusName = 'All';
    
    final statusMap = [
      'All',
      'Pending',
      'Accepted',
      'Quotation Sent',
      'Scheduled',
      'In Progress',
      'Completed',
      'Cancelled',
    ];
    
    currentStatusName = statusMap[_selectedTabIndex];
    
    if (_selectedTabIndex == 0) {
      currentBookings = _allBookings;
    } else {
      String targetStatus = statusMap[_selectedTabIndex];
      String statusID = BookingStatusConstants.getStatusID(targetStatus);
      currentBookings = _allBookings.where((booking) => booking.statusID == statusID).toList();
    }
    
    if (_searchQuery.isNotEmpty) {
      currentBookings = currentBookings.where((booking) {
        return (booking.bookingID?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
               booking.userName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               booking.subService.subserviceName.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }
    
    if (_selectedServiceType != null && _bookingService != null) {
      currentBookings = currentBookings.where((booking) {
        return booking.subService.serviceTypesID == _bookingService!.serviceTypeMapping[_selectedServiceType];
      }).toList();
    }
    
    if (_selectedDate != null) {
      currentBookings = currentBookings.where((booking) {
        return booking.bookingDate.year == _selectedDate!.year && 
               booking.bookingDate.month == _selectedDate!.month && 
               booking.bookingDate.day == _selectedDate!.day;
      }).toList();
    }
    
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment,
            color: Colors.black,
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            'Total ${currentStatusName} Bookings: ${currentBookings.length}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceRequestsTable() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.blue[600]),
            const SizedBox(height: 16),
            Text(
              'Loading service requests...',
              style: TextStyle(
                color: Colors.blue[600],
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    List<BookingData> filteredRequests = [];
    
    final statusMap = [
      null,
      'Pending',
      'Accepted',
      'Quotation Sent',
      'Scheduled',
      'In Progress',
      'Completed',
      'Cancelled',
    ];
    
    if (_selectedTabIndex == 0) {
      filteredRequests = _allBookings;
    } else {
      String targetStatus = statusMap[_selectedTabIndex]!;
      String statusID = BookingStatusConstants.getStatusID(targetStatus);
      filteredRequests = _allBookings.where((booking) => booking.statusID == statusID).toList();
    }
    
    if (_searchQuery.isNotEmpty) {
      filteredRequests = filteredRequests.where((booking) {
        return (booking.bookingID?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
               booking.userName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               booking.subService.subserviceName.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }
    
    if (_selectedServiceType != null && _bookingService != null) {
      filteredRequests = filteredRequests.where((booking) {
        return booking.subService.serviceTypesID == _bookingService!.serviceTypeMapping[_selectedServiceType];
      }).toList();
    }
    
    if (_selectedDate != null) {
      filteredRequests = filteredRequests.where((booking) {
        return booking.bookingDate.year == _selectedDate!.year && 
               booking.bookingDate.month == _selectedDate!.month && 
               booking.bookingDate.day == _selectedDate!.day;
      }).toList();
    }

    if (filteredRequests.isEmpty) {
      return SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _searchQuery.isNotEmpty ? Icons.search_off : Icons.assignment_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                _searchQuery.isNotEmpty 
                    ? 'No service requests found matching "$_searchQuery"'
                    : 'No service requests found',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (_searchQuery.isNotEmpty) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                    });
                  },
                  child: Text('Clear search'),
                ),
              ],
            ],
          ),
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
              'Service Requests',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: Center(
                  child: Container(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: 1000), // Reduced from 1200
                        child: DataTable(
                          columnSpacing: 0,
                          dataRowMinHeight: 48,
                          dataRowMaxHeight: 64,
                          headingTextStyle: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                          dataTextStyle: const TextStyle(
                            color: Color(0xFF1F2937),
                            fontSize: 13,
                          ),
                          columns: [
                            DataColumn(
                              label: Expanded(
                                flex: 2,
                                child: Center(child: Text('ID')),
                              ),
                            ),
                            DataColumn(
                              label: Expanded(
                                flex: 2,
                                child: Center(child: Text('Date')),
                              ),
                            ),
                            DataColumn(
                              label: Expanded(
                                flex: 3,
                                child: Center(child: Text('Customer')),
                              ),
                            ),
                            DataColumn(
                              label: Expanded(
                                flex: 3,
                                child: Center(child: Text('Service')),
                              ),
                            ),
                            DataColumn(
                              label: Expanded(
                                flex: 2,
                                child: Center(child: Text('Status')),
                              ),
                            ),
                            // REMOVED: Rating column
                            DataColumn(
                              label: Expanded(
                                flex: 2,
                                child: Center(child: Text('Actions')),
                              ),
                            ),
                          ],
                          rows: filteredRequests.map((booking) {
                            return DataRow(
                              cells: [
                                DataCell(Container(
                                  width: double.infinity,
                                  child: Center(
                                    child: Text(
                                      booking.bookingID?.length != null && booking.bookingID!.length > 8 
                                          ? '${booking.bookingID!.substring(0, 8)}...' 
                                          : booking.bookingID ?? 'N/A',
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                )),
                                DataCell(Container(
                                  width: double.infinity,
                                  child: Center(
                                    child: Text(DateFormat('MM/dd/yyyy').format(booking.bookingDate)),
                                  ),
                                )),
                                DataCell(Container(
                                  width: double.infinity,
                                  child: Center(
                                    child: Text(
                                      booking.userName.length > 15 
                                          ? '${booking.userName.substring(0, 15)}...' 
                                          : booking.userName,
                                    ),
                                  ),
                                )),
                                DataCell(Container(
                                  width: double.infinity,
                                  child: Center(
                                    child: Text(
                                      booking.subService.subserviceName.length > 20 
                                          ? '${booking.subService.subserviceName.substring(0, 20)}...' 
                                          : booking.subService.subserviceName,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )),
                                DataCell(Container(
                                  width: double.infinity,
                                  child: Center(
                                    child: _buildStatusBadge(booking.statusID),
                                  ),
                                )),
                                // REMOVED: Rating cell
                                DataCell(Container(
                                  width: double.infinity,
                                  child: Center(
                                    child: Tooltip(
                                      message: 'View Details',
                                      child: IconButton(
                                        icon: const Icon(Icons.remove_red_eye, size: 18, color: Colors.yellow),
                                        onPressed: () => _showBookingDetailDialog(booking),
                                        constraints: const BoxConstraints(),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ),
                                )),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
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
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}