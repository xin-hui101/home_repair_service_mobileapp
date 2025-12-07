// lib/screens/admin_reports_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'admin_header.dart';
import 'package:home_service_system/screens/admin_sidebar.dart';
import 'package:home_service_system/firebase_service/booking_service.dart';
import 'package:home_service_system/firebase_service/technician_service.dart';
import 'package:home_service_system/models/models.dart';
import 'package:home_service_system/models/rating_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:home_service_system/firebase_service/fcm_sercive.dart';
import 'package:home_service_system/screens/admin_notifications_sidebar.dart';


class AdminReportsPage extends StatefulWidget {
  const AdminReportsPage({super.key});

  @override
  _AdminReportsPageState createState() => _AdminReportsPageState();
}

class _AdminReportsPageState extends State<AdminReportsPage> {
  int _selectedIndex = 4; // Reports page index
  bool _isLoading = true;

  bool _isSidebarCollapsed = false;
  bool _showNotifications = false;
  
  // Date filters
  DateTime? _startDate;
  DateTime? _endDate;
  
  // Data
  List<BookingData> _allBookings = [];
  List<BookingData> _filteredBookings = [];
  List<TechnicianModel> _technicians = [];
  Map<String, RatingModel> _ratings = {};
  
  // KPI Data
  int _totalBookings = 0;
  double _totalRevenue = 0;
  double _avgRating = 0;
  double _completionRate = 0;
  
  // Chart Data
  Map<String, int> _serviceDistribution = {};
  List<Map<String, dynamic>> _monthlyTrends = [];
  List<Map<String, dynamic>> _revenueTrends = [];
  Map<int, int> _ratingDistribution = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};

  @override
  void initState() {
    super.initState();
    _initializeFCM();
    // Set default date range (last 6 months)
    _endDate = DateTime.now();
    _startDate = DateTime(_endDate!.year, _endDate!.month - 5, 1);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllData();
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

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    
    try {
      final bookingService = Provider.of<BookingService>(context, listen: false);
      final technicianService = Provider.of<TechnicianService>(context, listen: false);
      
      // Load bookings
      final bookings = await bookingService.getAllBookings();
      
      // Load technicians
      final technicians = await technicianService.getAllTechnicians();
      
      // Load ratings
      final ratingsSnapshot = await FirebaseFirestore.instance
          .collection('ratings')
          .get();
      
      Map<String, RatingModel> ratingsMap = {};
      for (var doc in ratingsSnapshot.docs) {
        final rating = RatingModel.fromMap(doc.data());
        ratingsMap[rating.bookingId] = rating;
      }
      
      if (mounted) {
        setState(() {
          _allBookings = bookings;
          _technicians = technicians;
          _ratings = ratingsMap;
        });
        
        _applyDateFilter();
        
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _applyDateFilter() {
    if (_startDate == null || _endDate == null) {
      _filteredBookings = _allBookings;
    } else {
      _filteredBookings = _allBookings.where((booking) {
        return booking.bookingDate.isAfter(_startDate!.subtract(Duration(days: 1))) &&
               booking.bookingDate.isBefore(_endDate!.add(Duration(days: 1)));
      }).toList();
    }
    
    _calculateKPIs();
    _calculateChartData();
  }

  void _calculateKPIs() {
    // Total bookings
    _totalBookings = _filteredBookings.length;
    
    // Total revenue (from completed bookings with quotations)
    _totalRevenue = 0;
    for (var booking in _filteredBookings) {
      if (BookingStatusConstants.getDisplayName(booking.statusID) == 'Completed') {
        _totalRevenue += 150; // Placeholder - replace with actual quotation data
      }
    }
    
    // Average rating
    if (_ratings.isNotEmpty) {
      double totalRating = 0;
      int ratingCount = 0;
      _filteredBookings.forEach((booking) {
        if (_ratings.containsKey(booking.bookingID)) {
          totalRating += _ratings[booking.bookingID]!.rating;
          ratingCount++;
        }
      });
      _avgRating = ratingCount > 0 ? totalRating / ratingCount : 0;
    }
    
    // Completion rate
    int completedBookings = _filteredBookings.where((b) => 
        BookingStatusConstants.getDisplayName(b.statusID) == 'Completed'
    ).length;
    _completionRate = _totalBookings > 0 
        ? (completedBookings / _totalBookings) * 100 
        : 0;
    
    // Active technicians (from filtered bookings)
    Set<String> activeTechIds = {};
    for (var booking in _filteredBookings) {
      if (booking.technicianID != null && booking.technicianID!.isNotEmpty) {
        activeTechIds.add(booking.technicianID!);
      }
    }
  }

  void _calculateChartData() {
    // Service distribution
    _serviceDistribution.clear();
    for (var booking in _filteredBookings) {
      String serviceName = booking.serviceName;
      _serviceDistribution[serviceName] = (_serviceDistribution[serviceName] ?? 0) + 1;
    }
    
    // Rating distribution
    _ratingDistribution = {5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    _filteredBookings.forEach((booking) {
      if (_ratings.containsKey(booking.bookingID)) {
        int rating = _ratings[booking.bookingID]!.rating;
        _ratingDistribution[rating] = (_ratingDistribution[rating] ?? 0) + 1;
      }
    });
    
    // Monthly trends based on filtered date range
    _monthlyTrends.clear();
    _revenueTrends.clear();
    
    if (_startDate != null && _endDate != null) {
      DateTime current = DateTime(_startDate!.year, _startDate!.month, 1);
      DateTime end = DateTime(_endDate!.year, _endDate!.month, 1);
      
      while (current.isBefore(end) || current.isAtSameMomentAs(end)) {
        int bookingCount = _filteredBookings.where((b) => 
            b.bookingDate.year == current.year && 
            b.bookingDate.month == current.month
        ).length;
        
        double monthRevenue = 0;
        for (var booking in _filteredBookings) {
          if (booking.bookingDate.year == current.year && 
              booking.bookingDate.month == current.month &&
              BookingStatusConstants.getDisplayName(booking.statusID) == 'Completed') {
            monthRevenue += 150; // Replace with actual quotation amount
          }
        }
        
        _monthlyTrends.add({
          'month': DateFormat('MMM yy').format(current),
          'bookings': bookingCount,
        });
        
        _revenueTrends.add({
          'month': DateFormat('MMM yy').format(current),
          'revenue': monthRevenue,
        });
        
        current = DateTime(current.year, current.month + 1, 1);
      }
    }
  }

  Future<void> _selectDateRange() async {
    DateTime? tempStartDate = _startDate;
    DateTime? tempEndDate = _endDate;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.date_range, color: Colors.yellow[700]),
                  SizedBox(width: 12),
                  Text('Select Date Range'),
                ],
              ),
              content: Container(
                width: 300,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Start Date
                    InkWell(
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: tempStartDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: Colors.yellow[700]!,
                                  onPrimary: Colors.black,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setDialogState(() {
                            tempStartDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today, size: 20, color: Colors.grey[600]),
                            SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Start Date', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                SizedBox(height: 4),
                                Text(
                                  tempStartDate != null 
                                      ? DateFormat('MMM dd, yyyy').format(tempStartDate!)
                                      : 'Select start date',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    // End Date
                    InkWell(
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: tempEndDate ?? DateTime.now(),
                          firstDate: tempStartDate ?? DateTime(2020),
                          lastDate: DateTime.now(),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: Colors.yellow[700]!,
                                  onPrimary: Colors.black,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setDialogState(() {
                            tempEndDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.event, size: 20, color: Colors.grey[600]),
                            SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('End Date', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                SizedBox(height: 4),
                                Text(
                                  tempEndDate != null 
                                      ? DateFormat('MMM dd, yyyy').format(tempEndDate!)
                                      : 'Select end date',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: Colors.grey[600])),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (tempStartDate != null && tempEndDate != null) {
                      setState(() {
                        _startDate = tempStartDate;
                        _endDate = tempEndDate;
                        _applyDateFilter();
                      });
                      Navigator.pop(context);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please select both start and end dates')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow[700],
                    foregroundColor: Colors.black,
                  ),
                  child: Text('Apply'),
                ),
              ],
            );
          },
        );
      },
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
child: Stack(  // ⭐ 添加 Stack
  children: [
    _isLoading 
        ? Center(child: CircularProgressIndicator(color: Colors.yellow[700]))
        : SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  SizedBox(height: 24),
                  _buildDateFilter(),
                  SizedBox(height: 24),
                  _buildKPICards(),
                  SizedBox(height: 24),
                  _buildChartsSection(),
                  SizedBox(height: 24),
                  _buildTablesSection(),
                ],
              ),
            ),
          ),
    // ⭐ 添加通知 Sidebar
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
    title: 'Business & Performance Reports',
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

  Widget _buildDateFilter() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
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
          // Header
          Row(
            children: [
              Icon(Icons.filter_list, color: Colors.yellow[700], size: 24),
              SizedBox(width: 12),
              Text(
                'Filter Reports',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    _startDate != null && _endDate != null
                        ? '${DateFormat('MMM dd, yyyy').format(_startDate!)} - ${DateFormat('MMM dd, yyyy').format(_endDate!)}'
                        : 'All Time',
                    style: TextStyle(fontSize: 14, color: Colors.grey[800], fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          
          // Quick Filters - First Row
          Text(
            'Quick Select',
            style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickFilterButton('Last 30 Days', () => _setLastNDays(30)),
              _buildQuickFilterButton('Last 3 Months', () => _setLastNMonths(3)),
              _buildQuickFilterButton('Last 6 Months', () => _setLastNMonths(6)),
              _buildQuickFilterButton('This Year', () => _setThisYear()),
              _buildQuickFilterButton('All Time', () => _setAllTime()),
            ],
          ),
          
          SizedBox(height: 16),
          Divider(color: Colors.grey[300]),
          SizedBox(height: 16),
          
          // Precise Selection - Second Row
          Text(
            'Precise Selection',
            style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildYearDropdown(),
              _buildMonthDropdown(),
              _buildCustomRangeButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFilterButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.yellow[100],
        foregroundColor: Colors.black,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildYearDropdown() {
    DateTime now = DateTime.now();
    return PopupMenuButton<int>(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today, size: 16, color: Colors.grey[700]),
            SizedBox(width: 8),
            Text('Select Year', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
            SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 18, color: Colors.grey[700]),
          ],
        ),
      ),
      itemBuilder: (context) {
        List<PopupMenuEntry<int>> items = [];
        for (int year = now.year; year >= 2020; year--) {
          items.add(
            PopupMenuItem<int>(
              value: year,
              child: Text('$year'),
            ),
          );
        }
        return items;
      },
      onSelected: (year) {
        _setSpecificYear(year);
      },
    );
  }

  Widget _buildMonthDropdown() {
    DateTime now = DateTime.now();
    List<String> months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    
    return PopupMenuButton<int>(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event, size: 16, color: Colors.grey[700]),
            SizedBox(width: 8),
            Text('Select Month', style: TextStyle(fontSize: 13, color: Colors.grey[700])),
            SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, size: 18, color: Colors.grey[700]),
          ],
        ),
      ),
      itemBuilder: (context) {
        List<PopupMenuEntry<int>> items = [];
        for (int i = 0; i < 12; i++) {
          items.add(
            PopupMenuItem<int>(
              value: i + 1,
              child: Text('${months[i]} ${now.year}'),
            ),
          );
        }
        return items;
      },
      onSelected: (month) {
        _setSpecificMonth(DateTime.now().year, month);
      },
    );
  }

  Widget _buildCustomRangeButton() {
    return ElevatedButton.icon(
      onPressed: _selectDateRange,
      icon: Icon(Icons.date_range, size: 16, color: Colors.yellow[700]),
      label: Text('Custom Range'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[700],
        elevation: 0,
        side: BorderSide(color: Colors.grey[300]!),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  void _setLastNDays(int days) {
    DateTime now = DateTime.now();
    setState(() {
      _startDate = now.subtract(Duration(days: days));
      _endDate = now;
      _applyDateFilter();
    });
  }

  void _setLastNMonths(int n) {
    DateTime now = DateTime.now();
    setState(() {
      _startDate = DateTime(now.year, now.month - n, now.day);
      _endDate = now;
      _applyDateFilter();
    });
  }

  void _setThisYear() {
    DateTime now = DateTime.now();
    setState(() {
      _startDate = DateTime(now.year, 1, 1);
      _endDate = now;
      _applyDateFilter();
    });
  }

  void _setAllTime() {
    setState(() {
      _startDate = DateTime(2020, 1, 1);
      _endDate = DateTime.now();
      _applyDateFilter();
    });
  }

  void _setSpecificYear(int year) {
    DateTime now = DateTime.now();
    setState(() {
      _startDate = DateTime(year, 1, 1);
      _endDate = year == now.year ? now : DateTime(year, 12, 31);
      _applyDateFilter();
    });
  }

  void _setSpecificMonth(int year, int month) {
    DateTime now = DateTime.now();
    setState(() {
      _startDate = DateTime(year, month, 1);
      if (year == now.year && month == now.month) {
        _endDate = now;
      } else {
        _endDate = DateTime(year, month + 1, 0);
      }
      _applyDateFilter();
    });
  }

  Widget _buildKPICards() {
    return Row(
      children: [
        Expanded(child: _buildKPICard('Total Bookings', _totalBookings.toString(), Icons.calendar_today, Colors.blue)),
        SizedBox(width: 16),
        Expanded(child: _buildKPICard('Total Revenue', 'RM ${_totalRevenue.toStringAsFixed(0)}', Icons.attach_money, Colors.green)),
        SizedBox(width: 16),
        Expanded(child: _buildKPICard('Avg Rating', _avgRating.toStringAsFixed(1), Icons.star, Colors.amber)),
        SizedBox(width: 16),
        Expanded(child: _buildKPICard('Completion Rate', '${_completionRate.toStringAsFixed(1)}%', Icons.check_circle, Colors.purple)),
      ],
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildChartsSection() {
    return Column(
      children: [
        _buildBookingTrendsChart(),
        SizedBox(height: 16),
        _buildRevenueTrendsChart(),
        SizedBox(height: 16),
        _buildServiceDistributionChart(),
        SizedBox(height: 16),
        _buildRatingDistributionChart(),
      ],
    );
  }

  Widget _buildBookingTrendsChart() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Booking Trends', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: _monthlyTrends.isEmpty 
                ? Center(child: Text('No data available'))
                : Padding(
                    padding: EdgeInsets.only(right: 16, top: 8),
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true, 
                          drawVerticalLine: false,
                          horizontalInterval: 5,
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true, 
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value.toInt().toString(),
                                  style: TextStyle(fontSize: 12),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 35,
                              getTitlesWidget: (value, meta) {
                                if (value.toInt() >= 0 && value.toInt() < _monthlyTrends.length) {
                                  return Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child: Text(
                                      _monthlyTrends[value.toInt()]['month'],
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  );
                                }
                                return Text('');
                              },
                            ),
                          ),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: _monthlyTrends.asMap().entries.map((entry) {
                              return FlSpot(entry.key.toDouble(), entry.value['bookings'].toDouble());
                            }).toList(),
                            isCurved: true,
                            color: Colors.blue,
                            barWidth: 3,
                            dotData: FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.blue.withOpacity(0.1),
                            ),
                          ),
                        ],
                        minY: 0,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueTrendsChart() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Revenue Trends', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: _revenueTrends.isEmpty 
                ? Center(child: Text('No data available'))
                : Padding(
                    padding: EdgeInsets.only(right: 16, top: 8),
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true, 
                          drawVerticalLine: false,
                          horizontalInterval: 100,
                        ),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true, 
                              reservedSize: 55,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  'RM ${value.toInt()}',
                                  style: TextStyle(fontSize: 11),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 35,
                              getTitlesWidget: (value, meta) {
                                if (value.toInt() >= 0 && value.toInt() < _revenueTrends.length) {
                                  return Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child: Text(
                                      _revenueTrends[value.toInt()]['month'],
                                      style: TextStyle(fontSize: 11),
                                    ),
                                  );
                                }
                                return Text('');
                              },
                            ),
                          ),
                          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: _revenueTrends.asMap().entries.map((entry) {
                              return FlSpot(entry.key.toDouble(), entry.value['revenue'].toDouble());
                            }).toList(),
                            isCurved: true,
                            color: Colors.green,
                            barWidth: 3,
                            dotData: FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.green.withOpacity(0.1),
                            ),
                          ),
                        ],
                        minY: 0,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceDistributionChart() {
    int totalBookings = _serviceDistribution.values.fold(0, (sum, value) => sum + value);
    
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Service Type Distribution', 
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.yellow[300],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Total: $totalBookings bookings',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          SizedBox(
            height: 300,
            child: _serviceDistribution.isEmpty 
                ? Center(child: Text('No data available'))
                : Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: PieChart(
                          PieChartData(
                            sections: _serviceDistribution.entries.map((entry) {
                              final colors = [Colors.blue, Colors.green, Colors.orange, Colors.red, Colors.purple, Colors.teal];
                              final index = _serviceDistribution.keys.toList().indexOf(entry.key);
                              final color = colors[index % colors.length];
                              double percentage = (entry.value / totalBookings) * 100;
                              
                              return PieChartSectionData(
                                value: entry.value.toDouble(),
                                title: '${percentage.toStringAsFixed(0)}%',
                                color: color,
                                radius: 100,
                                titleStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                              );
                            }).toList(),
                            sectionsSpace: 2,
                            centerSpaceRadius: 60,
                          ),
                        ),
                      ),
                      SizedBox(width: 24),
                      Expanded(
                        flex: 1,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _serviceDistribution.entries.map((entry) {
                            final colors = [Colors.blue, Colors.green, Colors.orange, Colors.red, Colors.purple, Colors.teal];
                            final index = _serviceDistribution.keys.toList().indexOf(entry.key);
                            final color = colors[index % colors.length];
                            
                            return Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 16, 
                                    height: 16, 
                                    decoration: BoxDecoration(
                                      color: color, 
                                      shape: BoxShape.circle
                                    )
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${entry.key}\n(${entry.value} bookings)', 
                                      style: TextStyle(fontSize: 12),
                                      maxLines: 2,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingDistributionChart() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Customer Rating Distribution', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 24),
          ..._ratingDistribution.entries.toList().reversed.map((entry) {
            int total = _ratingDistribution.values.fold(0, (sum, value) => sum + value);
            double percentage = total > 0 ? (entry.value / total) * 100 : 0;
            
            return Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Row(
                      children: [
                        Text('${entry.key}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        SizedBox(width: 4),
                        Icon(Icons.star, size: 16, color: Colors.amber),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: percentage / 100,
                          child: Container(
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.centerRight,
                            padding: EdgeInsets.only(right: 12),
                            child: percentage > 10 ? Text(
                              '${entry.value}',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                            ) : SizedBox.shrink(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),
                  SizedBox(
                    width: 60,
                    child: Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600], fontWeight: FontWeight.w500),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTablesSection() {
    return _buildTopTechniciansTable();
  }

  Widget _buildTopTechniciansTable() {
    Map<String, Map<String, dynamic>> techStats = {};
    
    for (var booking in _filteredBookings) {
      if (booking.technicianID != null && booking.technicianID!.isNotEmpty) {
        if (!techStats.containsKey(booking.technicianID)) {
          var tech = _technicians.firstWhere(
            (t) => t.technicianID == booking.technicianID,
            orElse: () => TechnicianModel(
              technicianID: booking.technicianID!,
              technicianName: 'Unknown',
              technicianEmail: '',
              technicianPhoneNumber: '',
              specializations: [],
            ),
          );
          
          techStats[booking.technicianID!] = {
            'name': tech.technicianName,
            'completed': 0,
            'rating': 0.0,
            'ratingCount': 0,
          };
        }
        
        if (BookingStatusConstants.getDisplayName(booking.statusID) == 'Completed') {
          techStats[booking.technicianID]!['completed']++;
          
          if (_ratings.containsKey(booking.bookingID)) {
            techStats[booking.technicianID]!['rating'] += _ratings[booking.bookingID]!.rating;
            techStats[booking.technicianID]!['ratingCount']++;
          }
        }
      }
    }
    
    techStats.forEach((key, value) {
      if (value['ratingCount'] > 0) {
        value['avgRating'] = value['rating'] / value['ratingCount'];
      } else {
        value['avgRating'] = 0.0;
      }
    });
    
    var sortedTechs = techStats.entries.toList()
      ..sort((a, b) => b.value['completed'].compareTo(a.value['completed']));
    
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Technicians' Performance", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          Table(
            columnWidths: {
              0: FlexColumnWidth(3),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(2),
              3: FlexColumnWidth(2),
            },
            border: TableBorder(
              horizontalInside: BorderSide(color: Colors.grey[200]!),
            ),
            children: [
              TableRow(
                decoration: BoxDecoration(color: Colors.grey[100]),
                children: [
                  _buildTableHeader('Technician Name'),
                  _buildTableHeader('Jobs Completed'),
                  _buildTableHeader('Avg Rating'),
                  _buildTableHeader('Performance'),
                ],
              ),
              ...sortedTechs.take(5).map((entry) {
                var data = entry.value;
                double avgRating = data['avgRating'];
                String performance = avgRating >= 4.7 ? 'Excellent' : 
                                   avgRating >= 4.5 ? 'Good' : 
                                   avgRating >= 4.0 ? 'Average' : 'Poor';
                Color performanceColor = avgRating >= 4.7 ? Colors.green : 
                                        avgRating >= 4.5 ? Colors.blue : 
                                        avgRating >= 4.0 ? Colors.orange : Colors.red;
                
                return TableRow(
                  children: [
                    _buildTableCell(data['name']),
                    _buildTableCell(data['completed'].toString(), center: true),
                    _buildTableCell(avgRating > 0 ? avgRating.toStringAsFixed(1) : 'N/A', center: true),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      child: Center(
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: performanceColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            performance,
                            style: TextStyle(
                              color: performanceColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }).toList(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: Colors.grey[700],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTableCell(String text, {bool center = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, color: Colors.black87),
        textAlign: center ? TextAlign.center : TextAlign.left,
      ),
    );
  }
}