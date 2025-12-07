import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:home_service_system/screens/user_profilepage.dart';
import 'package:home_service_system/screens/user_historypage.dart';
import 'package:home_service_system/screens/user_bookingselectpage.dart'; 
import 'package:home_service_system/screens/user_notificationpage.dart';
import 'package:home_service_system/firebase_service/auth_service.dart';
import 'package:home_service_system/models/models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class UserHomePage extends StatefulWidget {
  final bool showBookingSuccess;
  final String? bookingID;
  
  const UserHomePage({
    super.key,
    this.showBookingSuccess = false,
    this.bookingID,
  });

  @override
  _UserHomePageState createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  int index = 0;
  UserModel? currentUser;
  bool isLoading = true;
  int unreadNotificationCount = 0;
  StreamSubscription? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    print('UserHomePage initState - showBookingSuccess: ${widget.showBookingSuccess}, bookingID: ${widget.bookingID}');
    _loadUserData();
    _listenToUnreadNotifications();
    
    // 检查是否需要显示预订成功消息
    if (widget.showBookingSuccess && widget.bookingID != null) {
      print('准备显示预订成功对话框');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        print('PostFrameCallback 被调用，Widget mounted: $mounted');
        if (mounted) {
          _showBookingSuccessDialog(widget.bookingID!);
        } else {
          print('Widget在PostFrameCallback中已经unmounted');
        }
      });
    } else {
      print('不显示对话框 - showBookingSuccess: ${widget.showBookingSuccess}, bookingID: ${widget.bookingID}');
    }
  }

  @override
  void dispose() {
    print('UserHomePage disposed');
    _notificationSubscription?.cancel();
    super.dispose();
  }

  // 监听未读通知数量
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

  Future<void> _loadUserData() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userData = await authService.getUserData(role: 'user');
      
      if (mounted) {
        setState(() {
          currentUser = userData;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // 显示预订成功对话框
  void _showBookingSuccessDialog(String bookingID) {
    print('显示预订成功对话框，ID: $bookingID, Widget mounted: $mounted');
    
    if (!mounted) {
      print('Widget未mounted，无法显示dialog');
      return;
    }
    
    try {
      // 显示SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Booking Confirmed! ID: #$bookingID',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green[600],
          duration: Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: EdgeInsets.all(16),
        ),
      );
      
      print('SnackBar显示成功，尝试显示dialog');
      
      // 直接显示dialog，不延迟
      showDialog(
        context: context,
        barrierDismissible: true, // 允许点击外部关闭
        builder: (BuildContext dialogContext) {
          print('Dialog builder被调用，开始3秒倒计时');
          
          // 3秒后自动关闭
          Timer(Duration(seconds: 3), () {
            if (Navigator.of(dialogContext).canPop()) {
              print('自动关闭dialog');
              Navigator.of(dialogContext).pop();
            }
          });
          
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Column(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 64,
                ),
                SizedBox(height: 16),
                Text(
                  'Booking Confirmed!',
                  style: TextStyle(
                    color: Colors.blue[900],
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Your service has been booked successfully.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Booking ID: #$bookingID',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                      fontSize: 16,
                    ),
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Tap outside or wait 3 seconds to close',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.red[600],
                  ),
                ),
              ],
            ),
          );
        },
      ).then((_) {
        print('Dialog已关闭');
      }).catchError((error) {
        print('Dialog显示错误: $error');
      });
      
    } catch (e) {
      print('显示成功消息时出错: $e');
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good Morning';
    } else if (hour < 17) {
      return 'Good Afternoon';
    } else {
      return 'Good Evening';
    }
  }

  String _getUserName() {
    if (currentUser != null && currentUser!.name.isNotEmpty) {
      // Extract first name if full name is provided
      final nameParts = currentUser!.name.split(' ');
      return nameParts.first;
    }
    return 'User';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
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
                  // Custom top area with notification icon
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Stack(
                          children: [
                            IconButton(
                              icon: Icon(Icons.notifications_outlined),
                              iconSize: 35,
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  CupertinoPageRoute(
                                    builder: (context) => NotificationPage(),
                                  ),
                                );
                              },
                            ),
                            // 未读通知数量徽章
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
                                    borderRadius: BorderRadius.circular(10),
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
                  
                  // Main content area
                  Expanded(
                    child: isLoading 
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                color: Colors.yellow[600],
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Loading...',
                                style: TextStyle(
                                  color: Colors.blue[900],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadUserData,
                          color: Colors.yellow[600],
                          child: SingleChildScrollView(
                            physics: AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Welcome section
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${_getGreeting()},',
                                        style: TextStyle(
                                          fontSize: 20,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        _getUserName(),
                                        style: TextStyle(
                                          fontSize: 34,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue[900],
                                        ),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'What service do you need today?',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                SizedBox(height: 24),
                                
                                // Services Section
                                Text(
                                  'Choose a service:',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                SizedBox(height: 16),
                                
                                // Service Cards Grid
                                GridView.count(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  shrinkWrap: true,
                                  physics: NeverScrollableScrollPhysics(),
                                  childAspectRatio: 0.85, // Adjust card proportions
                                  children: [
                                    _buildServiceCard(context, 'Plumbing Services', Icons.plumbing),
                                    _buildServiceCard(context, 'Roof Services', Icons.house),
                                    _buildServiceCard(context, 'Painting', Icons.format_paint),
                                    _buildServiceCard(context, 'Wall Maintenance', Icons.dashboard_customize),
                                  ],
                                ),
                                
                                // Add some bottom padding for better scrolling experience
                                SizedBox(height: 20),
                              ],
                            ),
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
              setState(() {
                index = selectedIndex;
              });
              
              if (selectedIndex != 0) {
                // Reset index to 0 when navigating to maintain home as active state
                Future.delayed(Duration(milliseconds: 300), () {
                  if (mounted) {
                    setState(() {
                      index = 0;
                    });
                  }
                });
                
                // Navigate to different pages
                if (selectedIndex == 1) {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => UserHistoryPage(),
                    ),
                  );
                } else if (selectedIndex == 2) {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => UserProfilePage(),
                    ),
                  );
                }
              }
            },
          ),
        );
      },
    );
  }
  
  Widget _buildServiceCard(BuildContext context, String title, IconData icon) {
    // Service background images mapping
    final Map<String, String> serviceImages = {
      'Plumbing Services': 'assets/images/paiprepair.png',
      'Roof Services': 'assets/images/repairpic.png',
      'Painting': 'assets/images/painting.png',
      'Wall Maintenance': 'assets/images/wallrepair.png',
    };

    return GestureDetector(
      onTap: () {
        // Navigate to service selection page with user data
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => BookingSelectPage(
              selectedService: title,
            ),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
          // Use corresponding service background image
          image: serviceImages[title] != null
              ? DecorationImage(
                  image: AssetImage(serviceImages[title]!),
                  fit: BoxFit.cover,
                  // Add dark overlay for better text visibility
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.5),
                    BlendMode.darken,
                  ),
                )
              : null,
          // Fallback background color if image is not available
          color: serviceImages[title] == null ? Colors.yellow[100] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 48,
                color: serviceImages[title] != null ? Colors.white : Colors.blue[900],
              ),
            ),
            SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: serviceImages[title] != null ? Colors.white : Colors.blue[900],
                shadows: serviceImages[title] != null
                    ? [
                        Shadow(
                          offset: Offset(1, 1),
                          blurRadius: 3,
                          color: Colors.black.withOpacity(0.7),
                        ),
                      ]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}