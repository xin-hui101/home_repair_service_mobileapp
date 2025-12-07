
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:home_service_system/screens/user_homepage.dart';
import 'package:home_service_system/screens/user_profilepage.dart';
import 'package:home_service_system/screens/user_notificationpage.dart';
import 'package:home_service_system/screens/user_paymentsummary.dart';
import 'package:home_service_system/screens/user_bookingdetailpage.dart';
import 'package:home_service_system/screens/user_rating_page.dart';
import 'package:home_service_system/firebase_service/auth_service.dart';
import 'package:home_service_system/firebase_service/booking_service.dart';
import 'package:home_service_system/firebase_service/quotation_service.dart';
import 'package:home_service_system/models/models.dart';
import 'package:home_service_system/models/quotation_models.dart';

class UserHistoryPage extends StatefulWidget {
  const UserHistoryPage({super.key});

  @override
  _UserHistoryPageState createState() => _UserHistoryPageState();
}

class _UserHistoryPageState extends State<UserHistoryPage> {
  int index = 1;
  String _selectedFilter = 'All';
  List<BookingData> _allBookings = [];
  Map<String, TechnicianModel> _technicians = {};
  Map<String, QuotationData> _quotations = {};
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  int unreadNotificationCount = 0;
  StreamSubscription? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _loadBookingHistory();
    _listenToUnreadNotifications();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _listenToUnreadNotifications() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    _notificationSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        setState(() {
          unreadNotificationCount = snapshot.docs.length;
        });
      }
    });
  }

  Future<void> _loadBookingHistory() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      final authService = Provider.of<AuthService>(context, listen: false);
      final bookingService = Provider.of<BookingService>(context, listen: false);
      final quotationService = Provider.of<QuotationService>(context, listen: false);
      
      final userData = await authService.getUserData(role: 'user');
      
      if (userData != null) {
        final bookings = await bookingService.getUserBookings(userData.id);
        await _loadTechniciansInfo(bookings);
        await _loadQuotationsInfo(bookings, quotationService);
        await _loadRatingStatus(bookings, userData.id);
        
        if (mounted) {
          setState(() {
            _allBookings = bookings;
            _isLoading = false;
          });
        }
      } else {
        throw Exception('User data not found');
      }
    } catch (e) {
      print('Error loading booking history: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = 'Failed to load booking history. Please try again.';
        });
      }
    }
  }

  Future<void> _loadRatingStatus(List<BookingData> bookings, String userId) async {
    try {
      for (int i = 0; i < bookings.length; i++) {
        BookingData booking = bookings[i];
        if (booking.bookingID != null && booking.technicianID != null) {
          final ratingQuery = await FirebaseFirestore.instance
              .collection('ratings')
              .where('booking_id', isEqualTo: booking.bookingID)
              .where('user_id', isEqualTo: userId)
              .limit(1)
              .get();
          
          if (ratingQuery.docs.isNotEmpty) {
            bookings[i] = booking.copyWith(hasRated: true);
          }
        }
      }
    } catch (e) {
      print('Error loading rating status: $e');
    }
  }

  Future<void> _loadQuotationsInfo(List<BookingData> bookings, QuotationService quotationService) async {
    try {
      for (BookingData booking in bookings) {
        if (booking.bookingID != null) {
          final quotations = await quotationService.getQuotationsForBooking(booking.bookingID!);
          
          if (quotations.isNotEmpty) {
            QuotationData? selectedQuotation = quotations.firstWhere(
              (q) => q.status == 'sent',
              orElse: () => quotations.first,
            );
            
            _quotations[booking.bookingID!] = selectedQuotation;
          }
        }
      }
    } catch (e) {
      print('Error loading quotations info: $e');
    }
  }

  Future<void> _loadTechniciansInfo(List<BookingData> bookings) async {
    try {
      final technicianIds = bookings
          .where((b) => b.technicianID != null && b.technicianID!.isNotEmpty)
          .map((b) => b.technicianID!)
          .toSet()
          .toList();

      for (String techId in technicianIds) {
        if (!_technicians.containsKey(techId)) {
          final snapshot = await FirebaseFirestore.instance
              .collection('technicians')
              .where('technician_ID', isEqualTo: techId)
              .limit(1)
              .get();

          if (snapshot.docs.isNotEmpty) {
            _technicians[techId] = TechnicianModel.fromMap(snapshot.docs.first.data());
          }
        }
      }
    } catch (e) {
      print('Error loading technicians info: $e');
    }
  }

  String _getTechnicianName(String? technicianId) {
    if (technicianId == null || technicianId.isEmpty) {
      return 'Unassigned';
    }
    return _technicians[technicianId]?.technicianName ?? technicianId;
  }

  QuotationData? _getQuotationForBooking(String? bookingId) {
    if (bookingId == null) return null;
    return _quotations[bookingId];
  }

  List<BookingData> get filteredHistory {
    if (_selectedFilter == 'All') {
      return _allBookings;
    } else {
      return _allBookings.where((booking) {
        String displayStatus = BookingStatusConstants.getDisplayName(booking.statusID);
        return displayStatus == _selectedFilter;
      }).toList();
    }
  }

  Color getFilterColor(String status) {
    switch (status) {
      case 'All': return Colors.grey[600]!;
      case 'Pending': return Colors.amber[600]!;
      case 'Accepted': return Colors.lightGreen[600]!;
      case 'Quotation Sent': return Colors.blue[600]!;
      case 'Scheduled': return Colors.purple[600]!;
      case 'In Progress': return Colors.orange[600]!;
      case 'Completed': return Colors.teal[700]!;
      case 'Cancelled': return Colors.red[600]!;
      default: return Colors.grey[600]!;
    }
  }
  
  Color getFilterBackgroundColor(String status) {
    switch (status) {
      case 'All': return Colors.grey[50]!;
      case 'Pending': return Colors.amber[50]!;
      case 'Accepted': return Colors.lightGreen[50]!;
      case 'Quotation Sent': return Colors.blue[50]!;
      case 'Scheduled': return Colors.purple[50]!;
      case 'In Progress': return Colors.orange[50]!;
      case 'Completed': return Colors.teal[50]!;
      case 'Cancelled': return Colors.red[50]!;
      default: return Colors.grey[50]!;
    }
  }

  Color getStatusColor(String status) => getFilterColor(status);

  Color _getQuotationAmountColor(BookingData booking) {
    String status = BookingStatusConstants.getDisplayName(booking.statusID);
    if (status == 'In Progress' || status == 'Scheduled' || status == 'Completed') {
      return Colors.teal[700]!;
    }
    return Colors.red;
  }

  Color _getQuotationAmountBackgroundColor(BookingData booking) {
    String status = BookingStatusConstants.getDisplayName(booking.statusID);
    if (status == 'In Progress' || status == 'Scheduled' || status == 'Completed') {
      return Colors.teal[50]!;
    }
    return Colors.red[50]!;
  }

  Color _getQuotationAmountBorderColor(BookingData booking) {
    String status = BookingStatusConstants.getDisplayName(booking.statusID);
    if (status == 'In Progress' || status == 'Scheduled' || status == 'Completed') {
      return Colors.teal[200]!;
    }
    return Colors.red[200]!;
  }

  String _getDisplayAmount(BookingData booking) {
    String status = BookingStatusConstants.getDisplayName(booking.statusID);
    
    if (status == 'Pending' || status == 'Accepted' || status == 'Cancelled') {
      return '';
    }
    
    QuotationData? quotation = _getQuotationForBooking(booking.bookingID);
    if (quotation != null) {
      return 'RM${quotation.grandTotal.toStringAsFixed(2)}';
    }
    
    double amount = booking.bookingQuotation > 0 
        ? booking.bookingQuotation 
        : booking.subService.subserviceApproxAmount;
    
    return 'RM${amount.toStringAsFixed(2)}';
  }

  bool _shouldShowPayButton(BookingData booking) {
    String status = BookingStatusConstants.getDisplayName(booking.statusID);
    return status == 'Quotation Sent' && _getQuotationForBooking(booking.bookingID) != null;
  }

  bool _shouldShowRatingButton(BookingData booking) {
    String status = BookingStatusConstants.getDisplayName(booking.statusID);
    return status == 'Completed' && 
           booking.technicianID != null && 
           !booking.hasRated;
  }

  void _updateBookingRatingStatus(String bookingId) {
    setState(() {
      int index = _allBookings.indexWhere((b) => b.bookingID == bookingId);
      if (index != -1) {
        _allBookings[index] = _allBookings[index].copyWith(hasRated: true);
      }
    });
  }

  // 更新：Pending 和 Quotation Sent 都可以取消
  bool _canCancelBooking(BookingData booking) {
    String displayStatus = BookingStatusConstants.getDisplayName(booking.statusID);
    return displayStatus == 'Pending' || displayStatus == 'Quotation Sent';
  }

  void _showCancelBookingDialog(BookingData booking) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange[700],
                  size: 32,
                ),
              ),
              const SizedBox(height: 24),
              
              Text(
                'Cancel Booking?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              Text(
                booking.bookingID ?? 'N/A',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 20),
              
              Text(
                'Are you sure you want to cancel this booking?',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              
              Text(
                'This action cannot be undone.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        side: BorderSide(color: Colors.grey[300]!),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'No, Keep It',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _cancelBooking(booking);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Yes, Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _cancelBooking(BookingData booking) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Colors.yellow[600]),
                const SizedBox(height: 16),
                Text(
                  'Cancelling booking...',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.blue[900],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final bookingService = Provider.of<BookingService>(context, listen: false);
      final userId = FirebaseAuth.instance.currentUser?.uid;
      
      bool success = await bookingService.cancelBooking(
        booking.bookingID!,
        cancelledBy: 'user',
      );

      Navigator.pop(context);

      if (success) {
        setState(() {
          int index = _allBookings.indexWhere((b) => b.bookingID == booking.bookingID);
          if (index != -1) {
            _allBookings[index] = _allBookings[index].copyWith(
              statusID: 'STATUS007',
            );
          }
        });

        _showCancellationSuccessDialog();
        await _sendCancellationNotification(booking, userId);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text('Failed to cancel booking'),
              ],
            ),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red[600],
        ),
      );
    }
  }

  void _showCancellationSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.green[500],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 24),
              
              Text(
                'Booking Cancelled',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              Text(
                'Your booking has been cancelled successfully.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              
              Text(
                'The admin has been notified.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendCancellationNotification(BookingData booking, String? userId) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': 'admin',
        'title': 'Booking Cancelled by User',
        'body': 'User cancelled booking ${booking.bookingID} for ${booking.serviceName}',
        'bookingId': booking.bookingID,
        'type': 'booking_cancelled',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'cancelledBy': 'user',
        'originalUserId': userId,
      });
    } catch (e) {
      print('Error sending cancellation notification: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      Icon(Icons.home, size: 30),
      Icon(Icons.assignment_rounded, size: 30),
      Icon(Icons.person, size: 30),
    ];

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
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 40),
                    Text(
                      'Booking History',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                    ),
                    Stack(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.notifications_outlined,
                            size: 35,
                            color: Colors.black87,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              CupertinoPageRoute(builder: (context) => NotificationPage()),
                            );
                          },
                        ),
                        if (unreadNotificationCount > 0)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                              constraints: BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(
                                  color: Colors.white,
                                  width: 1.5,
                                ),
                              ),
                              child: Text(
                                unreadNotificationCount > 99 
                                    ? '99+' 
                                    : unreadNotificationCount.toString(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Filters
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('All'),
                        const SizedBox(width: 10),
                        _buildFilterChip('Pending'),
                        const SizedBox(width: 10),
                        _buildFilterChip('Accepted'),
                        const SizedBox(width: 10),
                        _buildFilterChip('Quotation Sent'),
                        const SizedBox(width: 10),
                        _buildFilterChip('Scheduled'),
                        const SizedBox(width: 10),
                        _buildFilterChip('In Progress'),
                        const SizedBox(width: 10),
                        _buildFilterChip('Completed'),
                        const SizedBox(width: 10),
                        _buildFilterChip('Cancelled'),
                      ],
                    ),
                  ),
                ),
              ),
              
              // List
              Expanded(
                child: _isLoading
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(color: Colors.yellow[600]),
                            const SizedBox(height: 16),
                            Text(
                              'Loading booking history...',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.blue[900],
                              ),
                            ),
                          ],
                        ),
                      )
                    : _hasError
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline, size: 80, color: Colors.red[400]),
                                const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 32),
                                  child: Text(
                                    _errorMessage,
                                    style: TextStyle(fontSize: 16, color: Colors.red[600]),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadBookingHistory,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.yellow[600],
                                    foregroundColor: Colors.blue[900],
                                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  ),
                                  child: Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        : filteredHistory.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.history, size: 80, color: Colors.grey[400]),
                                    const SizedBox(height: 16),
                                    Text(
                                      _selectedFilter == 'All' 
                                          ? 'No booking history found'
                                          : 'No $_selectedFilter bookings found',
                                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                                    ),
                                    if (_selectedFilter != 'All') ...[
                                      const SizedBox(height: 12),
                                      TextButton(
                                        onPressed: () {
                                          setState(() => _selectedFilter = 'All');
                                        },
                                        child: Text(
                                          'View all bookings',
                                          style: TextStyle(
                                            color: Colors.blue[900],
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            decoration: TextDecoration.underline,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _loadBookingHistory,
                                color: Colors.yellow[600],
                                child: ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: filteredHistory.length,
                                  itemBuilder: (context, index) {
                                    final booking = filteredHistory[index];
                                    return _buildServiceCard(booking);
                                  },
                                ),
                              ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CurvedNavigationBar(
        height: 60,
        index: index,
        items: items,
        color: Colors.white,
        buttonBackgroundColor: Colors.yellow[600],
        backgroundColor: Colors.yellow[50]!,
        onTap: (selectedIndex) {
          if (selectedIndex != index) {
            if (selectedIndex == 0) {
              Navigator.pushReplacement(
                context,
                CupertinoPageRoute(builder: (context) => UserHomePage()),
              );
            } else if (selectedIndex == 2) {
              Navigator.pushReplacement(
                context,
                CupertinoPageRoute(builder: (context) => UserProfilePage()),
              );
            }
          }
        },
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    final Color primaryColor = getFilterColor(label);
    final Color backgroundColor = getFilterBackgroundColor(label);
    
    return AnimatedContainer(
      duration: Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      child: InkWell(
        onTap: () => setState(() => _selectedFilter = label),
        borderRadius: BorderRadius.circular(25),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? backgroundColor : Colors.white,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: isSelected ? primaryColor : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: primaryColor.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                    spreadRadius: 1,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? primaryColor : Colors.grey[700],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceCard(BookingData booking) {
    String displayStatus = BookingStatusConstants.getDisplayName(booking.statusID);
    String displayAmount = _getDisplayAmount(booking);
    bool showPayButton = _shouldShowPayButton(booking);
    bool canCancel = _canCancelBooking(booking);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => BookingDetailPage(
              booking: booking,
              quotation: _getQuotationForBooking(booking.bookingID),
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 15,
              offset: const Offset(0, 4),
              spreadRadius: 1,
            ),
          ],
          border: Border.all(
            color: Colors.grey[100]!,
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: getStatusColor(displayStatus),
                  width: 4,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              booking.bookingID ?? 'N/A',
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('MMM dd, yyyy').format(booking.bookingDate),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: getStatusColor(displayStatus).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: getStatusColor(displayStatus).withOpacity(0.25),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          displayStatus,
                          style: TextStyle(
                            color: getStatusColor(displayStatus),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Service info
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey[25],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey[100]!,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            Icons.home_repair_service,
                            color: Colors.blue[600],
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                booking.serviceName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                booking.subService.subserviceName,
                                style: TextStyle(
                                  color: Colors.grey[700],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Time and technician
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.amber[50],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(
                                Icons.access_time, 
                                color: Colors.amber[700], 
                                size: 14
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${booking.bookingTime.hour.toString().padLeft(2, '0')}:${booking.bookingTime.minute.toString().padLeft(2, '0')}',
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (booking.technicianID != null && booking.technicianID!.isNotEmpty)
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.green[50],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(
                                Icons.person, 
                                color: Colors.green[600], 
                                size: 14
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _getTechnicianName(booking.technicianID),
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Address
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          Icons.location_on, 
                          color: Colors.red[600], 
                          size: 14
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          booking.bookingAddress,
                          style: TextStyle(
                            color: Colors.black87,
                            fontSize: 13,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Footer - 更新：Quotation Sent 显示 Cancel 和 Pay
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Price
                      if (displayAmount.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getQuotationAmountBackgroundColor(booking),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _getQuotationAmountBorderColor(booking)),
                          ),
                          child: Text(
                            displayAmount,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: _getQuotationAmountColor(booking),
                            ),
                          ),
                        )
                      else
                        const SizedBox(),
                      
                      // Buttons
                      Row(
                        children: [
                          // View Details (只在没有其他按钮时显示)
                          if (!canCancel && !showPayButton && !_shouldShowRatingButton(booking)) ...[
                            Text(
                              'View Details',
                              style: TextStyle(
                                color: Colors.blue[900],
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.blue[900],
                              size: 10,
                            ),
                          ],
                          
                          // Cancel按钮 (Pending 和 Quotation Sent)
                          if (canCancel) ...[
                            // 如果不是 Quotation Sent，显示 View Details
                            if (!showPayButton) ...[
                              Text(
                                'View Details',
                                style: TextStyle(
                                  color: Colors.blue[900],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.blue[900],
                                size: 10,
                              ),
                            ],
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => _showCancelBookingDialog(booking),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.red[500],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.cancel_outlined,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Cancel',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          
                          // Pay按钮 (Quotation Sent)
                          if (showPayButton) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (context) => PaymentSummaryPage(
                                      booking: booking,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.yellow[700],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.payment,
                                      color: Colors.blue[900],
                                      size: 14,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Pay',
                                      style: TextStyle(
                                        color: Colors.blue[900],
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          
                          // Rate按钮 (Completed)
                          if (_shouldShowRatingButton(booking)) ...[
                            Text(
                              'View Details',
                              style: TextStyle(
                                color: Colors.blue[900],
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.blue[900],
                              size: 10,
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (context) => UserRatingPage(
                                      booking: booking,
                                    ),
                                  ),
                                ).then((result) {
                                  if (result == true) { 
                                    _updateBookingRatingStatus(booking.bookingID!);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: [
                                            Icon(Icons.check_circle, color: Colors.white, size: 20),
                                            const SizedBox(width: 12),
                                            Text('Rating submitted successfully!'),
                                          ],
                                        ),
                                        backgroundColor: Colors.green[600],
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    );
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.amber[600],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star, color: Colors.white, size: 14),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Rate',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}