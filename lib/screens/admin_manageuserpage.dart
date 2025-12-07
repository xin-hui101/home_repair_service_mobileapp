// lib/screens/user_management_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:home_service_system/screens/admin_servicerequestpage.dart';
import 'package:home_service_system/screens/admin_header.dart';
import 'package:home_service_system/screens/admin_sidebar.dart';
import 'package:home_service_system/firebase_service/auth_service.dart';
import 'package:home_service_system/models/models.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:home_service_system/firebase_service/fcm_sercive.dart';
import 'package:home_service_system/screens/admin_notifications_sidebar.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  _UserManagementPageState createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  bool _showNotifications = false;
  int _selectedIndex = 3;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  
  bool _isSidebarCollapsed = false;

  // Firebase data
  List<UserModel> _allUsers = [];
  List<UserModel> _deactivatedUsers = [];
  bool _isLoading = true;
  bool _showDeactivatedUsers = false;

  final List<Map<String, dynamic>> recentLogs = [
    {'id': 1, 'type': 'appointment', 'message': 'New appointment from John Doe', 'time': '10 minutes ago'},
    {'id': 2, 'type': 'service', 'message': 'Service request #SR-1092 payment made', 'time': '45 minutes ago'},
  ];

  @override
  void initState() {
    super.initState();
    _initializeFCM();
    
    // 延迟执行初始化，确保 context 可用
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeUserManagement();
    });
    
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  // 初始化用户管理
  Future<void> _initializeUserManagement() async {
    await _testFirestoreAndMigrate();
  }

  // 测试 Firestore 连接并运行迁移
  Future<void> _testFirestoreAndMigrate() async {
    try {
      print('=== Initializing User Management ===');
      setState(() {
        _isLoading = true;
      });

      final authService = Provider.of<AuthService>(context, listen: false);
      
      // 1. 测试 Firestore 连接
      bool connectionOk = await authService.testFirestoreConnection();
      if (!connectionOk) {
        throw Exception('Firestore connection failed');
      }

      // 2. 运行数据迁移
      await authService.migrateExistingUsers();

      // 3. 加载用户数据
      await _loadUsersFromFirebase();

      print('✓ User management initialized successfully');
    } catch (e) {
      print('❌ Error initializing user management: $e');
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error initializing: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  // Load users from Firebase using AuthService
  Future<void> _loadUsersFromFirebase() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      print('Loading users from Firebase...');
      
      // Load active and deactivated users
      final activeUsers = await authService.getAllUsers(status: 'active');
      final deactivatedUsers = await authService.getAllUsers(status: 'deactivated');

      print('Loaded ${activeUsers.length} active users');
      print('Loaded ${deactivatedUsers.length} deactivated users');

      setState(() {
        _allUsers = activeUsers;
        _deactivatedUsers = deactivatedUsers;
        _isLoading = false;
      });

      print('✓ User data loaded successfully');
    } catch (e) {
      print('❌ Error loading users: $e');
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading users: $e'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  // Pull to refresh functionality
  Future<void> _handleRefresh() async {
    await _loadUsersFromFirebase();
  }

  // Get user's total bookings count
  Future<int> _getUserBookingCount(String userId) async {
    try {
      QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('user_ID', isEqualTo: userId)
          .get();
      return snapshot.docs.length;
    } catch (e) {
      print('Error getting booking count: $e');
      return 0;
    }
  }

  // Deactivate user using AuthService
  Future<void> _deactivateUser(UserModel user) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      bool success = await authService.deactivateUser(user.id);
      
      if (success) {
        // Reload users
        await _loadUsersFromFirebase();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User ${user.name} has been deactivated'),
            backgroundColor: Colors.red,
          ),
        );
      } else {
        throw Exception('Failed to deactivate user');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deactivating user: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Reactivate user method
  Future<void> _reactivateUser(UserModel user) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      bool success = await authService.reactivateUser(user.id);
      
      if (success) {
        // Reload users
        await _loadUsersFromFirebase();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('User ${user.name} has been reactivated'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception('Failed to reactivate user');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error reactivating user: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  // NEW: Get user initials for avatar
  String _getUserInitials(UserModel user) {
    if (user.name.isNotEmpty) {
      List<String> nameParts = user.name.trim().split(' ');
      if (nameParts.length >= 2) {
        return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
      } else if (nameParts.length == 1 && nameParts[0].isNotEmpty) {
        return nameParts[0][0].toUpperCase();
      }
    }
    return 'U';
  }

  // NEW: Build user avatar widget with image or initials
  Widget _buildUserAvatar(UserModel user, {double radius = 40}) {
    if (user.profilePictureUrl != null && user.profilePictureUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.blue[100],
        child: ClipOval(
          child: Image.network(
            user.profilePictureUrl!,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: SizedBox(
                  width: radius * 0.6,
                  height: radius * 0.6,
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                    strokeWidth: 2,
                    color: Colors.blue[600],
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Text(
                _getUserInitials(user),
                style: TextStyle(
                  fontSize: radius * 0.8,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              );
            },
          ),
        ),
      );
    } else {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.blue[100],
        child: Text(
          _getUserInitials(user),
          style: TextStyle(
            fontSize: radius * 0.8,
            fontWeight: FontWeight.bold,
            color: Colors.blue[900],
          ),
        ),
      );
    }
  }

  // Show user detail dialog
  void _showUserDetailDialog(UserModel user) async {
    int bookingCount = await _getUserBookingCount(user.id);
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 500,
          padding: EdgeInsets.all(24),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'User Details',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.yellow[900],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              
              SizedBox(height: 20),
              
              // User avatar and basic info
              Row(
                children: [
                  _buildUserAvatar(user, radius: 40),
                  SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              SizedBox(height: 20),
              
              // User details
              _buildDetailRow('User ID', user.id),
              _buildDetailRow('Email', user.email),
              _buildDetailRow('Phone', user.phoneNumber ?? 'Not provided'),
              _buildDetailRow('Address', user.address ?? 'Not provided'),
              _buildDetailRow('Registration Date', 
                  user.registrationDate?.toString().split(' ')[0] ?? 'Not available'),
              _buildDetailRow('Last Login', 
                  user.lastLogin?.toString().split(' ')[0] ?? 'Never'),
              _buildDetailRow('Status', user.status ?? 'active'),
              
              SizedBox(height: 20),
              
              // Booking information
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.yellow[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.yellow[200]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Bookings',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.yellow[900],
                          ),
                        ),
                        Text(
                          '$bookingCount',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.yellow[700],
                          ),
                        ),
                      ],
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        // Navigate to service request page with user filter
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ServiceRequestManagementPage(),
                          ),
                        );
                      },
                      child: Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
  child: Text(
    'View All Bookings',
    style: TextStyle(fontSize: 12),
  ),
),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow[600],
                        foregroundColor: Colors.white,
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Show deactivate confirmation dialog
  void _showDeleteConfirmationDialog(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Center(
          child: Text(
            'Deactivate User Account Confirmation',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                'Are you sure you want to deactivate this user?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConfirmationRow('User ID:', user.id),
                  _buildConfirmationRow('Name:', user.name),
                  _buildConfirmationRow('Email:', user.email),
                  _buildConfirmationRow('Phone:', user.phoneNumber ?? 'Not provided'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[700],
            ),
            child: const Text('Cancel'),
          ),
          SizedBox(
            width: 120,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () {
                Navigator.pop(context);
                _deactivateUser(user);
              },
              child: const Text(
                'Deactivate',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Show reactivate confirmation dialog for deactivated users
  void _showReactivateConfirmationDialog(UserModel user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Center(
          child: Text(
            'Reactivate User Account Confirmation',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                'Are you sure you want to reactivate this user?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildConfirmationRow('User ID:', user.id),
                  _buildConfirmationRow('Name:', user.name),
                  _buildConfirmationRow('Email:', user.email),
                  _buildConfirmationRow('Phone:', user.phoneNumber ?? 'Not provided'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[700],
            ),
            child: const Text('Cancel'),
          ),
          SizedBox(
            width: 120,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () {
                Navigator.pop(context);
                _reactivateUser(user);
              },
              child: const Text(
                'Reactivate',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmationRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
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
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 0),
                          child: _buildSearch(),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 0),
                          child: _buildUserStats(),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: RefreshIndicator(
                              onRefresh: _handleRefresh,
                              child: _buildUsersTable(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_showNotifications)
      AdminNotificationsSidebar(
          adminId: 'admin_000',
        onClose: () {
          setState(() {
            _showNotifications = false;
          });
        },
      ),
                  // Floating action button for deactivated users
                  Positioned(
                    bottom: 20,
                    right: 20,
                    child: FloatingActionButton.extended(
                      onPressed: () {
                        setState(() {
                          _showDeactivatedUsers = !_showDeactivatedUsers;
                        });
                      },
                      backgroundColor: _showDeactivatedUsers ? Colors.yellow[600] : Colors.grey[600],
                      foregroundColor: _showDeactivatedUsers ? Colors.black : Colors.white,
                      icon: Icon(_showDeactivatedUsers ? Icons.people : Icons.person_off),
                      label: Text(_showDeactivatedUsers ? 'View Active Users' : 'View Deactivated Users'),
                    ),
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
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // 使用新的 header 组件
      AdminHeaderWithNotification(
        title: _showDeactivatedUsers ? 'Deactivated Users' : 'User Management',
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
      ),
      
      // 保留原有的 loading 提示
      if (_isLoading)
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 48),  // 48px 左边距给菜单按钮留空间
          child: Text(
            'Loading user data...',
            style: TextStyle(
              fontSize: 14,
              color: Colors.blue[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
    ],
  );
}

  Widget _buildSearch() {
    return Row(
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
                hintText: 'Search by name, email, or ID...',
                prefixIcon: Icon(Icons.search),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
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
            onPressed: () {
              setState(() {
                _searchController.clear();
                _searchQuery = '';
              });
            },
            icon: const Icon(Icons.restart_alt, size: 18),
            label: const Text('Reset'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[700],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserStats() {
    List<UserModel> currentUsers = _showDeactivatedUsers ? _deactivatedUsers : _allUsers;
    
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _showDeactivatedUsers ? Icons.person_off : Icons.people,
            color: Colors.black,
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            'Total ${_showDeactivatedUsers ? 'Deactivated' : 'Active'} Users: ${currentUsers.length}',
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

Widget _buildUsersTable() {
  if (_isLoading) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.blue[600]),
          const SizedBox(height: 16),
          Text(
            'Loading user data...',
            style: TextStyle(
              color: Colors.blue[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  List<UserModel> currentUsers = _showDeactivatedUsers ? _deactivatedUsers : _allUsers;
  List<UserModel> filteredUsers = currentUsers;
  
  if (_searchQuery.isNotEmpty) {
    filteredUsers = filteredUsers.where((user) {
      return user.id.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             user.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             user.email.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  if (filteredUsers.isEmpty) {
    return SingleChildScrollView(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty ? Icons.search_off : Icons.people_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty 
                  ? 'No users found matching "$_searchQuery"'
                  : _showDeactivatedUsers 
                      ? 'No deactivated users found'
                      : 'No active users found',
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

  // 修改后的布局：卡片占满全宽，但内容居中
  return Card(
    margin: EdgeInsets.zero, // 移除边距让卡片占满全宽
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
          // 标题部分也居中对齐
          Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: 1200),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_showDeactivatedUsers ? 'Deactivated' : 'Active'} Users',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Center(
              child: Container(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: 1200),
                    child: DataTable(
                      columnSpacing: 0, // 设置为0，让列自动调整
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
                            flex: 3,
                            child: Center(child: Text('Name')),
                          ),
                        ),
                        DataColumn(
                          label: Expanded(
                            flex: 4,
                            child: Center(child: Text('Email')),
                          ),
                        ),
                        DataColumn(
                          label: Expanded(
                            flex: 2,
                            child: Center(child: Text('Phone')),
                          ),
                        ),
                        DataColumn(
                          label: Expanded(
                            flex: 2,
                            child: Center(child: Text('Actions')),
                          ),
                        ),
                      ],
                      rows: filteredUsers.map((user) {
                        return DataRow(
                          cells: [
                            DataCell(Container(
                              width: double.infinity,
                              child: Center(
                                child: Text(
                                  user.id.length > 10 ? '${user.id.substring(0, 10)}...' : user.id,
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            )),
                            DataCell(Container(
                              width: double.infinity,
                              child: Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _buildUserAvatar(user, radius: 16),
                                    SizedBox(width: 8),
                                    Text(user.name),
                                  ],
                                ),
                              ),
                            )),
                            DataCell(Container(
                              width: double.infinity,
                              child: Center(
                                child: Text(
                                  user.email,
                                ),
                              ),
                            )),
                            DataCell(Container(
                              width: double.infinity,
                              child: Center(
                                child: Text(
                                  user.phoneNumber ?? 'Not provided',
                                ),
                              ),
                            )),
                            DataCell(Container(
                              width: double.infinity,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Tooltip(
                                    message: 'View Details',
                                    child: IconButton(
                                      icon: const Icon(Icons.remove_red_eye, size: 18, color: Colors.yellow),
                                      onPressed: () => _showUserDetailDialog(user),
                                      constraints: const BoxConstraints(),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  if (_showDeactivatedUsers)
                                    Tooltip(
                                      message: 'Reactivate Account',
                                      child: IconButton(
                                        icon: const Icon(Icons.restore, size: 18, color: Colors.green),
                                        onPressed: () => _showReactivateConfirmationDialog(user),
                                        constraints: const BoxConstraints(),
                                        padding: EdgeInsets.zero,
                                      ),
                                    )
                                  else
                                    Tooltip(
                                      message: 'Deactivate Account',
                                      child: IconButton(
                                        icon: const Icon(Icons.person_off, size: 18, color: Colors.red),
                                        onPressed: () => _showDeleteConfirmationDialog(user),
                                        constraints: const BoxConstraints(),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ),
                                ],
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
        ],
      ),
    ),
  );
}

}