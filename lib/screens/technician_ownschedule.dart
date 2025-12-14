// lib/screens/technician_ownschedule.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:home_service_system/screens/quotation_form_page.dart';
import 'package:home_service_system/screens/technician_sidebar.dart';
import 'package:home_service_system/screens/technician_notifications_sidebar.dart';
import '../firebase_service/technician_booking_service.dart';
import '../firebase_service/quotation_service.dart';
import 'package:home_service_system/firebase_service/fcm_sercive.dart';
import '../models/models.dart';
import '../models/quotation_models.dart';

class TechnicianOwnSchedulePage extends StatefulWidget {
  const TechnicianOwnSchedulePage({super.key});

  @override
  _TechnicianOwnSchedulePageState createState() => _TechnicianOwnSchedulePageState();
}

class _TechnicianOwnSchedulePageState extends State<TechnicianOwnSchedulePage> {
  int _selectedIndex = 0;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;
  bool _isSidebarCollapsed = true;
  bool _showNotifications = false;
  
  TechnicianModel? _technicianInfo;
  List<BookingData> _scheduleData = [];
  String? _technicianFirebaseUid;

  @override
  void initState() {
    super.initState();
    _loadTechnicianData();
    _initializeNotifications();
  }

Future<void> _initializeNotifications() async {
  User? user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    // ⭐ 保存 Firebase UID
    _technicianFirebaseUid = user.uid;
    
    // ✅ 使用 Firebase UID 初始化 FCM
    await FCMService.initialize(
      userType: UserType.technician,
      userId: user.uid,  // ⭐ 使用 Firebase UID
    );
    
    print('🔔 FCM 初始化完成');
    print('   Firebase UID: ${user.uid}');
  }
}

  Future<void> _loadTechnicianData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final technicianBookingService = Provider.of<TechnicianBookingService>(context, listen: false);
      
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _technicianInfo = await technicianBookingService.getTechnicianByAuthUID(user.uid);
        
        if (_technicianInfo != null) {
          await _loadBookingsForDate(_selectedDate);
        } else {
          print('No technician info found for user: ${user.uid}');
        }
      }
    } catch (e) {
      print('Error loading technician data: $e');
      _showErrorMessage('Failed to load technician data');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadBookingsForDate(DateTime date) async {
    if (_technicianInfo == null) return;
    
    try {
      final technicianBookingService = Provider.of<TechnicianBookingService>(context, listen: false);
      
      List<BookingData> bookings = await technicianBookingService.getTechnicianBookings(
        _technicianInfo!.technicianID,
        date: date,
      );
      
    bookings.sort((a, b) {
     if (a.bookingTime.hour != b.bookingTime.hour) {
    return a.bookingTime.hour.compareTo(b.bookingTime.hour);
    }
    return a.bookingTime.minute.compareTo(b.bookingTime.minute);
    });

      print('=== Loaded ${bookings.length} bookings for ${date.toString()} ===');
      for (var booking in bookings) {
        print('Booking: ${booking.bookingID}, Status: ${booking.statusID}');
      }
      print('=== End booking load ===');
      
      setState(() {
        _scheduleData = bookings;
      });
    } catch (e) {
      print('Error loading bookings: $e');
      _showErrorMessage('Failed to load schedule');
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _uploadQuotation(String bookingId) async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QuotationFormPage(
            booking: _scheduleData.firstWhere((booking) => booking.bookingID == bookingId),
            technician: _technicianInfo!,
          ),
        ),
      );

      if (result == true) {
        print('Quotation upload successful, refreshing data...');
        await _loadBookingsForDate(_selectedDate);
        _showSuccessMessage('Quotation created successfully');
        setState(() {});
      }
    } catch (e) {
      print('Error creating quotation: $e');
      _showErrorMessage('Error creating quotation. Please try again.');
    }
  }


  Future<bool> _hasQuotationForBooking(String bookingId) async {
    try {
      print('=== Checking quotation for booking: $bookingId ===');
      
      final quotationService = Provider.of<QuotationService>(context, listen: false);
      final quotations = await quotationService.getQuotationsForBooking(bookingId);
      print('Found ${quotations.length} quotations for booking $bookingId');
      
      for (var q in quotations) {
        print('  - Quotation ID: ${q.quotationId}, Status: ${q.status}');
      }
      
      bool hasQuotation = quotations.isNotEmpty;
      print('Final result: hasQuotation = $hasQuotation');
      print('=== End quotation check ===');
      
      return hasQuotation;
    } catch (e) {
      print('Error checking quotation for $bookingId: $e');
      return false;
    }
  }

  Future<void> _viewQuotation(String bookingId) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      final quotationService = Provider.of<QuotationService>(context, listen: false);
      final quotations = await quotationService.getQuotationsForBooking(bookingId);
      
      Navigator.pop(context);

      if (quotations.isNotEmpty) {
        final quotation = quotations.first;
        _showQuotationDetailsDialog(quotation);
      } else {
        _showErrorMessage('No quotation found for this booking');
      }
    } catch (e) {
      Navigator.pop(context);
      print('Error viewing quotation: $e');
      _showErrorMessage('Error loading quotation details');
    }
  }

void _onNotificationTap() {
  setState(() {
    _showNotifications = !_showNotifications;
  });
}

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
                
                Expanded(
                  child: Container(
                    color: Colors.white,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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

  void _showImageDialog(String imageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 800,
              maxHeight: 600,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppBar(
                  title: const Text(
                    'Image Preview',
                    style: TextStyle(color: Colors.black),
                  ),
                  backgroundColor: Colors.white,
                  automaticallyImplyLeading: false,
                  elevation: 1,
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.black),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                Expanded(
                  child: InteractiveViewer(
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.broken_image, size: 64, color: Colors.grey),
                              const SizedBox(height: 8),
                              Text('Failed to load image', style: TextStyle(color: Colors.grey[600])),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

@override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // 当屏幕宽度小于1000px时，使用overlay模式；否则使用并排模式
    final useOverlayMode = screenWidth < 1000;

    if (useOverlayMode) {
      // 小屏幕模式：侧边栏叠加在主内容上方
      return Scaffold(
        body: Stack(
          children: [
            // 主内容区域
            SafeArea(
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
                child: _isLoading ? _buildLoadingWidget() : _buildMainContent(),
              ),
            ),
            
            // 侧边栏 - 叠加模式，保持在SafeArea内
            if (!_isSidebarCollapsed)
              SafeArea(
                child: Row(
                  children: [
                    TechnicianSidebar(
                      selectedIndex: _selectedIndex,
                      onItemSelected: (index) {
                        setState(() {
                          _selectedIndex = index;
                        });
                      },
                      isCollapsed: false,
                      technicianName: _technicianInfo?.technicianName ?? 'Loading...',
                      onCollapse: () {
                        setState(() {
                          _isSidebarCollapsed = true;
                        });
                      },
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _isSidebarCollapsed = true;
                          });
                        },
                        child: Container(
                          color: Colors.black.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

             if (_showNotifications && _technicianFirebaseUid != null)
          TechnicianNotificationsSidebar(
            technicianId: _technicianFirebaseUid!,
            onClose: () {
              setState(() {
                _showNotifications = false;
              });
            },
          ),
          ],
        ),
      );
    } else {
  // 大屏幕模式：侧边栏并排显示
  return Scaffold(
    body: Stack(
      children: [
        // 原来的 Row
        Row(
          children: [
            TechnicianSidebar(
              selectedIndex: _selectedIndex,
              onItemSelected: (index) {
                setState(() {
                  _selectedIndex = index;
                });
              },
              isCollapsed: _isSidebarCollapsed,
              technicianName: _technicianInfo?.technicianName ?? 'Loading...',
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
                child: SafeArea(
                  child: _isLoading ? _buildLoadingWidget() : _buildMainContent(),
                ),
              ),
            ),
          ],
        ),
        
        // ⭐ 通知 Sidebar（叠加）
        if (_showNotifications && _technicianInfo != null)
          TechnicianNotificationsSidebar(
            technicianId: _technicianFirebaseUid!,
            onClose: () {
              setState(() {
                _showNotifications = false;
              });
            },
          ),
      ],
    ),
  );
}
  }

  Widget _buildLoadingWidget() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Loading schedule...'),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return RefreshIndicator(
      onRefresh: () async {
        await _loadBookingsForDate(_selectedDate);
      },
      color: Colors.yellow[700],
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
          
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: _buildDailySchedule(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    if (_technicianFirebaseUid == null) {
      return TechnicianHeader(
        title: 'My Schedule',
        isSidebarCollapsed: _isSidebarCollapsed,
        onToggleSidebar: () {
          setState(() {
            _isSidebarCollapsed = !_isSidebarCollapsed;
          });
        },
      );
    }

    return StreamBuilder<int>(
      stream: FCMService.getUnreadNotificationCount(
        _technicianFirebaseUid!,
        UserType.technician,
      ),
      builder: (context, snapshot) {
        final notificationCount = snapshot.data ?? 0;
        
        return TechnicianHeaderWithNotification(
          title: 'My Schedule',
          isSidebarCollapsed: _isSidebarCollapsed,
          onToggleSidebar: () {
            setState(() {
              _isSidebarCollapsed = !_isSidebarCollapsed;
            });
          },
          notificationCount: notificationCount,
          onNotificationTap: _onNotificationTap,
        );
      },
    );
  }
  
  Widget _buildDateSelector() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 600;
    
    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, size: 16),
                  onPressed: () {
                    setState(() {
                      _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                    });
                    _loadBookingsForDate(_selectedDate);
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    DateFormat('MMMM d, yyyy').format(_selectedDate),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios, size: 16),
                  onPressed: () {
                    setState(() {
                      _selectedDate = _selectedDate.add(const Duration(days: 1));
                    });
                    _loadBookingsForDate(_selectedDate);
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.today, size: 16),
            label: const Text('Today'),
            onPressed: () {
              setState(() {
                _selectedDate = DateTime.now();
              });
              _loadBookingsForDate(_selectedDate);
            },
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.grey[700],
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              side: BorderSide(color: Colors.grey[300]!),
            ),
          ),
        ],
      );
    }
    
    return Row(
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
                  _loadBookingsForDate(_selectedDate);
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
                  _loadBookingsForDate(_selectedDate);
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
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
            _loadBookingsForDate(_selectedDate);
          },
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.grey[700],
            backgroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            side: BorderSide(color: Colors.grey[300]!),
          ),
        ),
      ],
    );
  }

  Widget _buildDailySchedule() {
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'My Appointments for ${DateFormat('MMMM d, yyyy').format(_selectedDate)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_scheduleData.length} appointments',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _scheduleData.isEmpty
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
                      itemCount: _scheduleData.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final appointment = _scheduleData[index];
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
    String timeString = '${appointment.bookingTime.hour.toString().padLeft(2, '0')}:${appointment.bookingTime.minute.toString().padLeft(2, '0')}';
    
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompactLayout = screenWidth < 900;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 249, 252, 255),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: isCompactLayout 
          ? _buildCompactAppointmentLayout(appointment, timeString)
          : _buildWideAppointmentLayout(appointment, timeString),
    );
  }

  Widget _buildWideAppointmentLayout(BookingData appointment, String timeString) {
    return Row(
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
              const Icon(Icons.access_time, color: Colors.blue, size: 20),
              const SizedBox(height: 4),
              Text(
                timeString,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        
        Expanded(
          child: _buildAppointmentContent(appointment),
        ),
        
        const SizedBox(width: 16),
        
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildStatusBadge(BookingStatusExtension.getDisplayNameFromStatusID(appointment.statusID)),
            const SizedBox(height: 12),
            _buildActionButtons(appointment, isCompact: false),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactAppointmentLayout(BookingData appointment, String timeString) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.access_time, color: Colors.blue, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    timeString,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
            _buildStatusBadge(BookingStatusExtension.getDisplayNameFromStatusID(appointment.statusID)),
          ],
        ),
        
        const SizedBox(height: 12),
        
        _buildAppointmentContent(appointment),
        
        const SizedBox(height: 12),
        
        _buildActionButtons(appointment, isCompact: true),
      ],
    );
  }

  Widget _buildAppointmentContent(BookingData appointment) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              appointment.bookingID ?? 'N/A',
              style: const TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            Text(
              appointment.serviceName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 8),
        
        Row(
          children: [
            const Icon(Icons.person_outline, size: 16, color: Colors.grey),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                appointment.userName,
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 4),
        
        Row(
          children: [
            const Icon(Icons.phone_outlined, size: 16, color: Colors.grey),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                appointment.userPhone,
                style: const TextStyle(fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 4),
        
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
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
        
        if (appointment.bookingDescription.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notes, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    appointment.bookingDescription,
                    style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
        
        if (appointment.imageUrls.isNotEmpty) ...[
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.photo_library, size: 16, color: Colors.black),
                  SizedBox(width: 4),
                  Text(
                    'Customer Images',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: appointment.imageUrls.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () => _showImageDialog(appointment.imageUrls[index]),
                      child: Container(
                        width: 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            appointment.imageUrls[index],
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: Colors.grey[200],
                                child: const Icon(
                                  Icons.broken_image,
                                  color: Colors.grey,
                                  size: 24,
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                  strokeWidth: 2,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

// ========================================
// 构建操作按钮（Quotation + Status）
// ========================================
Widget _buildActionButtons(BookingData appointment, {bool isCompact = false}) {
  if (isCompact) {
    // ========================================
    // 📱 Compact Layout（小屏幕）
    // ========================================
    
    // ⭐ 如果是 In Progress，显示两个按钮
    if (appointment.statusID == 'STATUS005') {
      return Row(
        children: [
          // Quotation 按钮
          Expanded(
            child: FutureBuilder<bool>(
              key: ValueKey('quotation_${appointment.bookingID}_${DateTime.now().millisecondsSinceEpoch}'),
              future: _hasQuotationForBooking(appointment.bookingID!),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return ElevatedButton(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.grey,
                      backgroundColor: Colors.grey[300],
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    ),
                    child: const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                
                bool hasQuotation = snapshot.data ?? false;
                
                if (hasQuotation) {
                  return ElevatedButton.icon(
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View', style: TextStyle(fontSize: 12)),
                    onPressed: () => _viewQuotation(appointment.bookingID!),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.black,
                      backgroundColor: Colors.yellow[300],
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  );
                } else {
                  return ElevatedButton.icon(
                    icon: const Icon(Icons.upload_file, size: 16),
                    label: const Text('Upload', style: TextStyle(fontSize: 12)),
                    onPressed: () => _uploadQuotation(appointment.bookingID!),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.black,
                      backgroundColor: Colors.yellow[300],
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  );
                }
              },
            ),
          ),
          
          const SizedBox(width: 8),
          
          // Complete 按钮
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.check_circle_outline, size: 16, color:Colors.white,),
              label: const Text('Complete', style: TextStyle(fontSize: 12)),
              onPressed: () => _showCompleteConfirmationDialog(appointment.bookingID!),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.green[600],
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              ),
            ),
          ),
        ],
      );
    }
    
    // ⭐ 如果不是 In Progress，只显示 Quotation 按钮
    return FutureBuilder<bool>(
      key: ValueKey('quotation_${appointment.bookingID}_${DateTime.now().millisecondsSinceEpoch}'),
      future: _hasQuotationForBooking(appointment.bookingID!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ElevatedButton(
            onPressed: null,
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.grey,
              backgroundColor: Colors.grey[300],
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            ),
            child: const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        
        bool hasQuotation = snapshot.data ?? false;
        
        if (hasQuotation) {
          return ElevatedButton.icon(
            icon: const Icon(Icons.visibility, size: 16),
            label: const Text('View Quotation', style: TextStyle(fontSize: 12)),
            onPressed: () => _viewQuotation(appointment.bookingID!),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.black,
              backgroundColor: Colors.yellow[300],
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          );
        } else {
          return ElevatedButton.icon(
            icon: const Icon(Icons.upload_file, size: 16),
            label: const Text('Upload Quotation', style: TextStyle(fontSize: 12)),
            onPressed: () => _uploadQuotation(appointment.bookingID!),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.black,
              backgroundColor: Colors.yellow[300],
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          );
        }
      },
    );
  }
  
  // ========================================
  // 🖥️ Wide Layout（大屏幕）
  // ========================================
  
  // ⭐ 如果是 In Progress，显示两个按钮
  if (appointment.statusID == 'STATUS005') {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Quotation 按钮
        SizedBox(
          width: 120,
          child: FutureBuilder<bool>(
            key: ValueKey('quotation_${appointment.bookingID}_${DateTime.now().millisecondsSinceEpoch}'),
            future: _hasQuotationForBooking(appointment.bookingID!),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.grey,
                    backgroundColor: Colors.grey[300],
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    minimumSize: const Size(0, 32),
                  ),
                  child: const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              
              bool hasQuotation = snapshot.data ?? false;
              
              if (hasQuotation) {
                return ElevatedButton.icon(
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('View', style: TextStyle(fontSize: 12)),
                  onPressed: () => _viewQuotation(appointment.bookingID!),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.black,
                    backgroundColor: Colors.yellow[300],
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    minimumSize: const Size(0, 32),
                  ),
                );
              } else {
                return ElevatedButton.icon(
                  icon: const Icon(Icons.upload_file, size: 16),
                  label: const Text('Upload', style: TextStyle(fontSize: 12)),
                  onPressed: () => _uploadQuotation(appointment.bookingID!),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.black,
                    backgroundColor: Colors.yellow[300],
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    minimumSize: const Size(0, 32),
                  ),
                );
              }
            },
          ),
        ),
        
        const SizedBox(height: 6),
        
        // Complete 按钮
        SizedBox(
          width: 120,
          child: ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_outline, size: 16),
            label: const Text('Complete', style: TextStyle(fontSize: 12)),
            onPressed: () => _showCompleteConfirmationDialog(appointment.bookingID!),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: Colors.green[600],
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              minimumSize: const Size(0, 32),
            ),
          ),
        ),
      ],
    );
  }
  
  // ⭐ 如果不是 In Progress，只显示 Quotation 按钮
  return SizedBox(
    width: 120,
    child: FutureBuilder<bool>(
      key: ValueKey('quotation_${appointment.bookingID}_${DateTime.now().millisecondsSinceEpoch}'),
      future: _hasQuotationForBooking(appointment.bookingID!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ElevatedButton(
            onPressed: null,
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.grey,
              backgroundColor: Colors.grey[300],
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              minimumSize: const Size(0, 32),
            ),
            child: const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        
        bool hasQuotation = snapshot.data ?? false;
        
        if (hasQuotation) {
          return ElevatedButton.icon(
            icon: const Icon(Icons.visibility, size: 16),
            label: const Text('View', style: TextStyle(fontSize: 12)),
            onPressed: () => _viewQuotation(appointment.bookingID!),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.black,
              backgroundColor: Colors.yellow[300],
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              minimumSize: const Size(0, 32),
            ),
          );
        } else {
          return ElevatedButton.icon(
            icon: const Icon(Icons.upload_file, size: 16),
            label: const Text('Upload', style: TextStyle(fontSize: 12)),
            onPressed: () => _uploadQuotation(appointment.bookingID!),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.black,
              backgroundColor: Colors.yellow[300],
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              minimumSize: const Size(0, 32),
            ),
          );
        }
      },
    ),
  );
}

// ========================================
// 显示完成确认对话框
// ========================================
void _showCompleteConfirmationDialog(String bookingId) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_outline,
                  size: 40,
                  color: Colors.green[600],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Title
              Text(
                'Complete Service',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Message
              Text(
                'Mark this service as completed?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Buttons
              Row(
                children: [
                  // Cancel
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.grey[300]!, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Confirm
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context); // Close dialog
                        
                        // Update status to Completed (STATUS006)
                        final technicianBookingService = Provider.of<TechnicianBookingService>(
                          context,
                          listen: false,
                        );
                        
                        bool success = await technicianBookingService.updateBookingStatus(
                          bookingId,
                          'Completed',
                        );
                        
                        if (success) {
                          _showSuccessMessage('Service update as completed');
                          await _loadBookingsForDate(_selectedDate);
                        } else {
                          _showErrorMessage('Failed to update status');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Confirm',
                        style: TextStyle(
                          fontSize: 15,
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
      );
    },
  );
}

  Widget _buildStatusBadge(String status) {
    Color backgroundColor;
    Color textColor;

    switch (status) {
      case 'Scheduled':
        backgroundColor = Colors.blue[50]!;
        textColor = Colors.blue[800]!;
        break;
      case 'Accepted':
        backgroundColor = Colors.purple[50]!;
        textColor = Colors.purple[800]!;
        break;
      case 'Quotation Sent':
        backgroundColor = Colors.indigo[50]!;
        textColor = Colors.indigo[800]!;
        break;
      case 'In Progress':
        backgroundColor = Colors.amber[50]!;
        textColor = Colors.amber[800]!;
        break;
      case 'Completed':
        backgroundColor = Colors.green[50]!;
        textColor = Colors.green[800]!;
        break;
      case 'Cancelled':
        backgroundColor = Colors.red[50]!;
        textColor = Colors.red[800]!;
        break;
      default:
        backgroundColor = Colors.grey[50]!;
        textColor = Colors.grey[800]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}