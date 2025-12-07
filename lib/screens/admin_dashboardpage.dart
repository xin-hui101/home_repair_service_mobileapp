import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:home_service_system/screens/admin_manageuserpage.dart';
import 'package:home_service_system/screens/admin_servicerequestpage.dart';
import 'package:home_service_system/screens/admin_techniciansch.dart';
import 'package:home_service_system/screens/admin_managematerial.dart';
import 'package:home_service_system/firebase_service/booking_service.dart';
import 'package:home_service_system/firebase_service/auth_service.dart';
import 'package:home_service_system/firebase_service/technician_service.dart';
import 'package:home_service_system/screens/admin_reports_page.dart';
import 'package:home_service_system/models/models.dart';
import 'package:home_service_system/screens/admin_sidebar.dart'; 
import 'package:home_service_system/screens/admin_header.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:home_service_system/firebase_service/fcm_sercive.dart';
import 'package:home_service_system/screens/admin_notifications_sidebar.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  _AdminDashboardPageState createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  bool _showNotifications = false;
  int _selectedIndex = 0;
  bool _showAddTechnicianDialog = false;
  bool _isLoading = true;
  bool _isSidebarCollapsed = false; // ✨ New: Track sidebar collapsed state
  
  // Services
  final BookingService _bookingService = BookingService();
  final TechnicianService _technicianService = TechnicianService();
  final AuthService _authService = AuthService();

  // Data from Firebase
  List<BookingData> _todayAppointments = [];
  List<BookingData> _pendingOrders = [];
  List<TechnicianModel> _activeTechnicians = [];
  Map<String, int> _userStatistics = {};
  Map<String, int> _technicianStatistics = {};

  // Available specializations
  static const List<String> availableSpecializations = [
    'Plumbing Services',
    'Roof Services',
    'Painting',
    'Wall Maintenance',
  ];



  @override
  void initState() {
    super.initState();
    _initializeFCM();
    _loadDashboardData();

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

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('=== Loading Dashboard Data ===');
      
      // Load all bookings
      List<BookingData> allBookings = await _bookingService.getAllBookings();
      print('Loaded ${allBookings.length} total bookings');
      
      // Filter today's appointments
      DateTime today = DateTime.now();
      _todayAppointments = allBookings.where((booking) {
        bool isToday = booking.bookingDate.year == today.year &&
                      booking.bookingDate.month == today.month &&
                      booking.bookingDate.day == today.day;
        bool isActiveStatus = booking.statusID == BookingStatus.scheduled.statusID ||
                             booking.statusID == BookingStatus.inProgress.statusID;
        return isToday && isActiveStatus;
      }).toList();
      
      print('Found ${_todayAppointments.length} appointments for today');

      // Filter pending orders
      _pendingOrders = allBookings.where((booking) {
        return booking.statusID == BookingStatus.pending.statusID;
      }).toList();
      
      print('Found ${_pendingOrders.length} pending orders');

      // Load active technicians
      _activeTechnicians = await _technicianService.getAllTechnicians();
      print('Loaded ${_activeTechnicians.length} active technicians');

      // Load user statistics
      _userStatistics = await _authService.getUserStatistics();
      print('User statistics: $_userStatistics');

      // Load technician statistics
      _technicianStatistics = await _technicianService.getTechnicianStatistics();
      print('Technician statistics: $_technicianStatistics');

      print('=== Dashboard Data Loaded Successfully ===');
    } catch (e) {
      print('❌ Error loading dashboard data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading dashboard data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // ✨ New: Use the reusable sidebar component
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
          
          // Main content
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
          // Fixed header at the top
          Padding(
            padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 0),
            child: _buildHeader(),
          ),
          // Scrollable content area with RefreshIndicator
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadDashboardData,
                    child: ListView(
                      padding: const EdgeInsets.all(24.0),
                      children: [
                        const SizedBox(height: 8),
                        _buildStatCards(),
                        const SizedBox(height: 32),
                        // Divider line above actions
                        Container(
                          height: 1,
                          color: Colors.grey[300],
                          margin: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        _buildActionButtons(),
                        const SizedBox(height: 24),
                        _buildTodayAppointmentsCard(),
                        const SizedBox(height: 24),
                        _buildPendingOrdersCard(),
                        const SizedBox(height: 24),
                      ],
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
    if (_showAddTechnicianDialog) _buildAddTechnicianDialog(),
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
    title: 'Dashboard',
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

  Widget _buildStatCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Today\'s Appointments',
            value: _todayAppointments.length.toString(),
            icon: Icons.calendar_today,
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            title: 'Total Users',
            value: _userStatistics['total']?.toString() ?? '0',
            icon: Icons.people_outline,
            color: Colors.purple,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            title: 'Total Technicians',
            value: _activeTechnicians.length.toString(),
            icon: Icons.engineering_outlined,
            color: Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            title: 'Pending Orders',
            value: _pendingOrders.length.toString(),
            icon: Icons.warning_amber_rounded,
            color: Colors.amber,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
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
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // First row - 3 actions
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                title: 'Add Technician',
                icon: Icons.person_add,
                color: Colors.green,
                onTap: () {
                  setState(() {
                    _showAddTechnicianDialog = true;
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionButton(
                title: 'Service Requests',
                icon: Icons.assignment,
                color: Colors.blue,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ServiceRequestManagementPage()),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionButton(
                title: 'Manage Users',
                icon: Icons.manage_accounts,
                color: Colors.indigo,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const UserManagementPage()),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Second row - 3 actions centered
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.18,
              child: _buildActionButton(
                title: 'Technician Schedule',
                icon: Icons.calendar_today,
                color: Colors.orange,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TechnicianSchedulePage()),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.18,
              child: _buildActionButton(
                title: 'Material Management',
                icon: Icons.inventory_2,
                color: Colors.teal,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MaterialManagementPage()),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.18,
              child: _buildActionButton(
                title: 'View Reports',
                icon: Icons.assessment,
                color: Colors.purple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AdminReportsPage()),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodayAppointmentsCard() {
    final today = DateFormat('MMMM dd, yyyy').format(DateTime.now());
    
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
              'Today\'s Appointments ($today)',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _todayAppointments.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text(
                        'No appointments scheduled for today',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 20,
                      headingTextStyle: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      dataTextStyle: const TextStyle(
                        color: Color(0xFF1F2937),
                        fontSize: 13,
                      ),
                      columns: const [
                        DataColumn(label: Text('ID')),
                        DataColumn(label: Text('Time')),
                        DataColumn(label: Text('Customer')),
                        DataColumn(label: Text('Technician')),
                        DataColumn(label: Text('Service')),
                      ],
                      rows: _todayAppointments.map((appointment) {
                        // Find technician name from the list
                        String technicianName = 'Not Assigned';
                        if (appointment.technicianID != null) {
                          final technician = _activeTechnicians.firstWhere(
                            (tech) => tech.technicianID == appointment.technicianID,
                            orElse: () => TechnicianModel(
                              technicianID: '',
                              technicianName: 'Unknown',
                              technicianEmail: '',
                              technicianPhoneNumber: '',
                            ),
                          );
                          technicianName = technician.technicianName.isNotEmpty 
                              ? technician.technicianName 
                              : appointment.technicianID!;
                        }
                        
                        return DataRow(
                          cells: [
                            DataCell(Text(
                              appointment.bookingID ?? 'N/A',
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.w500,
                              ),
                            )),
                            DataCell(Text(appointment.bookingTime.format(context))),
                            DataCell(Text(appointment.userName)),
                            DataCell(Text(technicianName)),
                            DataCell(Text(appointment.subService.subserviceName)),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingOrdersCard() {
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
            const Text(
              'Pending Orders',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _pendingOrders.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text(
                        'No pending orders',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 20,
                      headingTextStyle: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      dataTextStyle: const TextStyle(
                        color: Color(0xFF1F2937),
                        fontSize: 13,
                      ),
                      columns: const [
                        DataColumn(label: Text('ID')),
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Time')),
                        DataColumn(label: Text('Customer')),
                        DataColumn(label: Text('Service')),
                        DataColumn(label: Text('Action')),
                      ],
                      rows: _pendingOrders.map((order) {
                        return DataRow(
                          cells: [
                            DataCell(Text(
                              order.bookingID ?? 'N/A',
                              style: const TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.w500,
                              ),
                            )),
                            DataCell(Text(
                              DateFormat('MM/dd/yyyy').format(order.bookingDate)
                            )),
                            DataCell(Text(order.bookingTime.format(context))),
                            DataCell(Text(order.userName)),
                            DataCell(Text(order.subService.subserviceName)),
                            DataCell(
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const ServiceRequestManagementPage(),
                                      settings: RouteSettings(
                                        arguments: {'bookingId': order.bookingID}
                                      ),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  minimumSize: Size.zero,
                                ),
                                child: const Text(
                                  'View Details',
                                  style: TextStyle(fontSize: 11, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ],
        ),
      ),
    );
  }


  Future<String?> _createTechnician({
    required String name,
    required String email,
    required String phoneNumber,
    required String password,
    required List<String> specializations,
  }) async {
    try {
      print('Creating technician account for: $email');
      
      String? technicianId = await _technicianService.createTechnician(
        name: name,
        email: email,
        phoneNumber: phoneNumber,
        password: password,
        specializations: specializations,
      );
      
      if (technicianId != null) {
        // Refresh technician list
        _activeTechnicians = await _technicianService.getAllTechnicians();
        _technicianStatistics = await _technicianService.getTechnicianStatistics();
        setState(() {});
      }
      
      return technicianId;
    } catch (e) {
      print('Error creating technician: $e');
      return null;
    }
  }

  Widget _buildAddTechnicianDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    List<String> selectedSpecializations = [];
    bool isLoading = false;

    return StatefulBuilder(
      builder: (context, setDialogState) {
        return Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: Card(
                margin: const EdgeInsets.all(24),
                child: Container(
                  width: 500,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Add New Technician',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              setState(() {
                                _showAddTechnicianDialog = false;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full Name',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email Address',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: passwordController,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Specializations:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: availableSpecializations.map((spec) {
                          return FilterChip(
                            label: Text(spec),
                            selected: selectedSpecializations.contains(spec),
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) {
                                  selectedSpecializations.add(spec);
                                } else {
                                  selectedSpecializations.remove(spec);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: isLoading ? null : () {
                              setState(() {
                                _showAddTechnicianDialog = false;
                              });
                            },
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: isLoading ? null : () async {
                              if (nameController.text.trim().isEmpty ||
                                  emailController.text.trim().isEmpty ||
                                  phoneController.text.trim().isEmpty ||
                                  passwordController.text.trim().isEmpty ||
                                  selectedSpecializations.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please fill all fields and select at least one specialization'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              setDialogState(() {
                                isLoading = true;
                              });

                              try {
                                String? technicianId = await _createTechnician(
                                  name: nameController.text.trim(),
                                  email: emailController.text.trim(),
                                  phoneNumber: phoneController.text.trim(),
                                  password: passwordController.text.trim(),
                                  specializations: selectedSpecializations,
                                );

                                if (technicianId != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Technician created successfully! ID: $technicianId'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  setState(() {
                                    _showAddTechnicianDialog = false;
                                  });
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Failed to create technician. Please try again.'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error: ${e.toString()}'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }

                              setDialogState(() {
                                isLoading = false;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Create Technician', style: TextStyle(color: Colors.white)),
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
      },
    );
  }
}