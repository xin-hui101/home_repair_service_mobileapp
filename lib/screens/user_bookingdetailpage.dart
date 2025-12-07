// lib/screens/user_bookingdetailpage.dart - Updated with Quotation Integration and Rating Feature
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:home_service_system/models/models.dart';
import 'package:home_service_system/models/quotation_models.dart';
import 'package:home_service_system/models/rating_model.dart';
import 'package:home_service_system/firebase_service/quotation_service.dart';
import 'package:home_service_system/firebase_service/rating_service.dart';
import 'package:home_service_system/firebase_service/auth_service.dart';
import 'package:home_service_system/screens/user_paymentsummary.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BookingDetailPage extends StatefulWidget {
  final BookingData booking;
  final QuotationData? quotation; // Optional quotation passed from history page

  const BookingDetailPage({super.key, required this.booking, this.quotation});

  @override
  State<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends State<BookingDetailPage> {
  TechnicianModel? _technician;
  QuotationData? _quotation;
  RatingModel? _existingRating;
  bool _isLoadingTechnician = false;
  bool _isLoadingQuotation = false;
  final RatingService _ratingService = RatingService();

  @override
  void initState() {
    super.initState();
    
    // Set quotation if passed from parent
    _quotation = widget.quotation;
    
    if (widget.booking.technicianID != null && widget.booking.technicianID!.isNotEmpty) {
      _loadTechnicianInfo();
    }
    
    // Load quotation if not provided
    if (_quotation == null) {
      _loadQuotationInfo();
    }
    
    // Load existing rating if booking is completed
    _loadExistingRating();
  }

  Future<void> _loadExistingRating() async {
    if (widget.booking.bookingID == null) return;
    
    String displayStatus = BookingStatusConstants.getDisplayName(widget.booking.statusID);
    if (displayStatus != 'Completed') return;

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userData = await authService.getUserData(role: 'user');
      
      if (userData != null) {
        final existingRating = await _ratingService.getRatingForBooking(
          bookingId: widget.booking.bookingID!,
          userId: userData.id,
        );
        
        setState(() {
          _existingRating = existingRating;
        });
      }
    } catch (e) {
      print('Error loading existing rating: $e');
    }
  }

  Future<void> _loadQuotationInfo() async {
    if (widget.booking.bookingID == null) return;
    
    setState(() {
      _isLoadingQuotation = true;
    });

    try {
      final quotationService = Provider.of<QuotationService>(context, listen: false);
      final quotations = await quotationService.getQuotationsForBooking(widget.booking.bookingID!);
      
      if (quotations.isNotEmpty) {
        // Get the latest sent quotation, or the first one if none are sent
        setState(() {
          _quotation = quotations.firstWhere(
            (q) => q.status == 'sent',
            orElse: () => quotations.first,
          );
          _isLoadingQuotation = false;
        });
        print('✅ Successfully loaded quotation: ${_quotation!.quotationId}');
      } else {
        print('❌ No quotation found for booking: ${widget.booking.bookingID}');
        setState(() {
          _isLoadingQuotation = false;
        });
      }
    } catch (e) {
      print('❌ Error loading quotation: $e');
      setState(() {
        _isLoadingQuotation = false;
      });
    }
  }

  Future<void> _loadTechnicianInfo() async {
    setState(() {
      _isLoadingTechnician = true;
    });

    try {
      print('📋 Attempting to load technician with ID: ${widget.booking.technicianID}');
      
      // Query technicians collection where technician_ID field matches
      final querySnapshot = await FirebaseFirestore.instance
          .collection('technicians')
          .where('technician_ID', isEqualTo: widget.booking.technicianID)
          .limit(1)
          .get();

      print('📋 Found ${querySnapshot.docs.length} documents');
      
      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        print('📋 Document data: ${doc.data()}');
        setState(() {
          _technician = TechnicianModel.fromMap(doc.data());
          _isLoadingTechnician = false;
        });
        print('✅ Successfully loaded technician: ${_technician!.technicianName}');
      } else {
        print('❌ No technician found with ID: ${widget.booking.technicianID}');
        setState(() {
          _isLoadingTechnician = false;
        });
      }
    } catch (e) {
      print('❌ Error loading technician: $e');
      setState(() {
        _isLoadingTechnician = false;
      });
    }
  }

  // Get status color (same as history page)
  Color getStatusColor(String status) {
    switch (status) {
      case 'All':
        return Colors.grey[600]!;
      case 'Pending':
        return Colors.amber[600]!;
      case 'Accepted':
        return Colors.lightGreen[600]!;
      case 'Quotation Sent':
        return Colors.blue[600]!;
      case 'Scheduled':
        return Colors.purple[600]!;
      case 'In Progress':
        return Colors.orange[600]!;
      case 'Completed':
        return Colors.teal[700]!;
      case 'Cancelled':
        return Colors.red[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  // NEW: Get quotation amount color based on booking status
  Color _getQuotationAmountColor() {
    String status = BookingStatusConstants.getDisplayName(widget.booking.statusID);
    
    // Use green color for In Progress, Scheduled, and Completed bookings
    if (status == 'In Progress' || status == 'Scheduled' || status == 'Completed') {
      return Colors.teal[700]!; // Green color (same as Completed status)
    }
    
    // Default red color for other statuses
    return Colors.red[600]!;
  }

  // Check if quotation amount should be displayed
  bool _shouldShowQuotation(String statusID) {
    // Show quotation for all statuses except Pending (STATUS001) and Accepted (STATUS002)
    return statusID != 'STATUS001' && statusID != 'STATUS002';
  }

  // Get quotation amount if available
  double? _getQuotationAmount() {
    if (_shouldShowQuotation(widget.booking.statusID) && _quotation != null) {
      return _quotation!.grandTotal;
    }
    return null;
  }

  // Check if Pay Now button should be shown
  bool _shouldShowPayButton() {
    String status = BookingStatusConstants.getDisplayName(widget.booking.statusID);
    return status == 'Quotation Sent' && _quotation != null;
  }



  @override
  Widget build(BuildContext context) {
    String displayStatus = BookingStatusConstants.getDisplayName(widget.booking.statusID);
    double? quotationAmount = _getQuotationAmount();
    bool showPayButton = _shouldShowPayButton();
    
    return Scaffold(
      body: Container(
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
        child: SafeArea(
          child: Column(
            children: [
              // Custom header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: Colors.black87,
                        size: 24,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        'Booking Details',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
              
              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header card with booking ID and status
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Booking ID',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.booking.bookingID ?? 'N/A',
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: getStatusColor(displayStatus).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: getStatusColor(displayStatus).withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    displayStatus,
                                    style: TextStyle(
                                      color: getStatusColor(displayStatus),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.purple[50],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Icon(
                                    Icons.calendar_today, 
                                    color: Colors.purple[600], 
                                    size: 18
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormat('EEEE, MMMM dd, yyyy').format(widget.booking.bookingDate),
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Service information
                      _buildInfoCard(
                        title: 'Service Information',
                        icon: Icons.home_repair_service,
                        iconColor: Colors.blue[600]!,
                        iconBgColor: Colors.blue[50]!,
                        children: [
                          _buildInfoRow('Service Type', widget.booking.serviceName),
                          _buildInfoRow('Sub-service', widget.booking.subService.subserviceName),
                          // Show quotation amount if available - UPDATED with conditional color
                          if (quotationAmount != null)
                            _buildInfoRow('Quotation Amount', 
                                'RM${quotationAmount.toStringAsFixed(2)}', 
                                highlight: true,
                                highlightColor: _getQuotationAmountColor()),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Schedule information
                      _buildInfoCard(
                        title: 'Schedule Information',
                        icon: Icons.schedule,
                        iconColor: Colors.amber[700]!,
                        iconBgColor: Colors.amber[50]!,
                        children: [
                          _buildInfoRow('Date', DateFormat('dd/MM/yyyy').format(widget.booking.bookingDate)),
                          _buildInfoRow('Time', 
                              '${widget.booking.bookingTime.hour.toString().padLeft(2, '0')}:${widget.booking.bookingTime.minute.toString().padLeft(2, '0')}'),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Location information
                      _buildInfoCard(
                        title: 'Location Information',
                        icon: Icons.location_on,
                        iconColor: Colors.red[600]!,
                        iconBgColor: Colors.red[50]!,
                        children: [
                          _buildInfoRow('Address', widget.booking.bookingAddress),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Customer information
                      _buildInfoCard(
                        title: 'Customer Information',
                        icon: Icons.person,
                        iconColor: Colors.green[600]!,
                        iconBgColor: Colors.green[50]!,
                        children: [
                          _buildInfoRow('Name', widget.booking.userName),
                          _buildInfoRow('Email', widget.booking.userEmail),
                          _buildInfoRow('Phone', widget.booking.userPhone),
                        ],
                      ),
                      
                      // Technician information (if assigned)
                      if (widget.booking.technicianID != null && widget.booking.technicianID!.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildInfoCard(
                          title: 'Technician Information',
                          icon: Icons.engineering,
                          iconColor: Colors.orange[600]!,
                          iconBgColor: Colors.orange[50]!,
                          children: [
                            if (_isLoadingTechnician)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else if (_technician != null) ...[
                              _buildInfoRow('Name', _technician!.technicianName),
                              _buildInfoRow('Phone', _technician!.technicianPhoneNumber),
                            ] else
                              _buildInfoRow('Technician ID', widget.booking.technicianID!),
                          ],
                        ),
                      ],
                      
                      // Quotation details (if available) - UPDATED with conditional colors
                      if (_quotation != null) ...[
                        const SizedBox(height: 16),
                        _buildInfoCard(
                          title: 'Quotation Details',
                          icon: Icons.description,
                          iconColor: Colors.indigo[600]!,
                          iconBgColor: Colors.indigo[50]!,
                          children: [
                            if (_isLoadingQuotation)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Center(
                                  child: CircularProgressIndicator(),
                                ),
                              )
                            else ...[
                              _buildInfoRow('Quotation ID', _quotation!.quotationId),
                              _buildInfoRow('Created Date', DateFormat('dd/MM/yyyy').format(_quotation!.createdAt)),
                              if (_quotation!.problemAssessment.isNotEmpty)
                                _buildInfoRow('Problem Assessment', _quotation!.problemAssessment),
                              if (_quotation!.recommendedSolution.isNotEmpty)
                                _buildInfoRow('Recommended Solution', _quotation!.recommendedSolution),
                              const SizedBox(height: 8),
                              
                              // Cost breakdown - keep original colors for breakdown items
                              if (_quotation!.materialSubtotal > 0)
                                _buildInfoRow('Material Cost', 'RM${_quotation!.materialSubtotal.toStringAsFixed(2)}'),
                              if (_quotation!.laborSubtotal > 0)
                                _buildInfoRow('Labor Cost', 'RM${_quotation!.laborSubtotal.toStringAsFixed(2)}'),
                              if (_quotation!.installationFee > 0)
                                _buildInfoRow('Installation Fee', 'RM${_quotation!.installationFee.toStringAsFixed(2)}'),
                              if (_quotation!.transportationFee > 0)
                                _buildInfoRow('Transportation Fee', 'RM${_quotation!.transportationFee.toStringAsFixed(2)}'),
                              
                              const Divider(height: 16),
                              _buildInfoRow('Subtotal', 'RM${_quotation!.subtotal.toStringAsFixed(2)}'),
                              _buildInfoRow('Tax (8%)', 'RM${_quotation!.taxAmount.toStringAsFixed(2)}'),
                              if (_quotation!.discountAmount > 0)
                                _buildInfoRow('Discount', '-RM${_quotation!.discountAmount.toStringAsFixed(2)}'),
                              
                              const SizedBox(height: 8),
                              _buildInfoRow('Grand Total', 'RM${_quotation!.grandTotal.toStringAsFixed(2)}', 
                                  highlight: true, highlightColor: _getQuotationAmountColor()),
                            ],
                          ],
                        ),
                      ],
                      
                      // Existing rating display (if any)
                      if (_existingRating != null) ...[
                        const SizedBox(height: 16),
                        _buildExistingRatingDisplay(),
                      ],
                      
                      // Additional notes (if any)
                      if (widget.booking.bookingDescription.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildInfoCard(
                          title: 'Additional Notes',
                          icon: Icons.description,
                          iconColor: Colors.purple[600]!,
                          iconBgColor: Colors.purple[50]!,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                widget.booking.bookingDescription,
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      
                      // Images (if any)
                      if (widget.booking.imageUrls.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildInfoCard(
                          title: 'Attached Images',
                          icon: Icons.photo_library,
                          iconColor: Colors.teal[600]!,
                          iconBgColor: Colors.teal[50]!,
                          children: [
                            const SizedBox(height: 8),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: 1,
                              ),
                              itemCount: widget.booking.imageUrls.length,
                              itemBuilder: (context, index) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    widget.booking.imageUrls[index],
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey[200],
                                        child: const Icon(
                                          Icons.broken_image,
                                          color: Colors.grey,
                                          size: 40,
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                      
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              
              // Pay Now button (if applicable)
              if (showPayButton)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => PaymentSummaryPage(
                            booking: widget.booking,
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.yellow[600],
                      foregroundColor: Colors.blue[900],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.payment, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Pay Now - RM${_quotation!.grandTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  // UPDATED: Modified to accept custom highlight color
  Widget _buildInfoRow(String label, String value, {bool highlight = false, Color? highlightColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: highlight ? (highlightColor ?? Colors.red[600]) : Colors.black87,
                fontSize: 15,
                fontWeight: highlight ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Existing rating display widget (read-only)
  Widget _buildExistingRatingDisplay() {
    if (_existingRating == null) return const SizedBox.shrink();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.star,
                  color: Colors.amber[600],
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Your Rating',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Star display
          Row(
            children: [
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    Icons.star,
                    size: 24,
                    color: index < _existingRating!.rating
                        ? Colors.amber[600]
                        : Colors.grey[300],
                  );
                }),
              ),
              const SizedBox(width: 12),
              Text(
                '${_existingRating!.rating}/5',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.amber[700],
                ),
              ),
            ],
          ),
          
          if (_existingRating!.comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Comment:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _existingRating!.comment,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}