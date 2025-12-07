import 'package:curved_navigation_bar/curved_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'user_homepage.dart';
import 'package:home_service_system/screens/user_historypage.dart';
import 'package:home_service_system/screens/welcome_page.dart';
import 'package:home_service_system/screens/user_notificationpage.dart';
import 'package:home_service_system/screens/user_editprofile.dart';
import 'package:home_service_system/firebase_service/auth_service.dart';
import 'package:home_service_system/models/models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  _UserProfilePageState createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  int index = 2;
  UserModel? currentUser;
  bool isLoading = true;
  int unreadNotificationCount = 0;
  StreamSubscription? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _listenToUnreadNotifications();
  }

  @override
  void dispose() {
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
        
        // Show error message to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load profile data. Please try again.'),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Get user's display name or initials for avatar
  String _getUserDisplayName() {
    if (currentUser != null && currentUser!.name.isNotEmpty) {
      return currentUser!.name;
    }
    return 'User';
  }

  // Get initials for avatar when no profile picture
  String _getUserInitials() {
    if (currentUser != null && currentUser!.name.isNotEmpty) {
      List<String> nameParts = currentUser!.name.trim().split(' ');
      if (nameParts.length >= 2) {
        return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
      } else if (nameParts.length == 1 && nameParts[0].isNotEmpty) {
        return nameParts[0][0].toUpperCase();
      }
    }
    return 'U';
  }

  // NEW: Build profile avatar widget with image or initials
  Widget _buildProfileAvatar({double radius = 50}) {
    if (currentUser?.profilePictureUrl != null && 
        currentUser!.profilePictureUrl!.isNotEmpty) {
      // Show profile picture
      return CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white,
        child: ClipOval(
          child: Image.network(
            currentUser!.profilePictureUrl!,
            width: radius * 2,
            height: radius * 2,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                  color: Colors.yellow[600],
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              // Fallback to initials if image fails to load
              return _buildInitialsAvatar(radius);
            },
          ),
        ),
      );
    } else {
      // Show initials
      return _buildInitialsAvatar(radius);
    }
  }

  // Helper to build initials avatar
  Widget _buildInitialsAvatar(double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: Colors.white,
      child: Text(
        _getUserInitials(),
        style: TextStyle(
          fontSize: radius * 0.7,
          fontWeight: FontWeight.bold,
          color: Colors.blue[900],
        ),
      ),
    );
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
                  // Custom top area with centered title and notification icon
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Empty spacer for balance
                        SizedBox(width: 35),
                        // Centered title
                        Text(
                          'My Profile',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                        ),
                        // Notification icon with badge
                        Stack(
                          children: [
                            IconButton(
                              icon: Icon(Icons.notifications_outlined),
                              iconSize: 35,
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  CupertinoPageRoute(builder: (context) => NotificationPage()),
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
                  
                  // Main content
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
                                  'Loading profile...',
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
                              child: Column(
                                children: [
                                  // Profile Header - UPDATED with profile picture
                                  Container(
                                    margin: EdgeInsets.all(16),
                                    width: 300,
                                    height: 230,
                                    decoration: BoxDecoration(
                                      color: Colors.yellow[600]!,
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        // Profile Avatar - UPDATED
                                        _buildProfileAvatar(radius: 50),
                                        SizedBox(height: 16),
                                        Text(
                                          _getUserDisplayName(),
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue[900]!,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  
                                  // Profile Cards
                                  Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Column(
                                      children: [
                                        // Phone Number Card
                                        _buildProfileCard(
                                          icon: Icons.phone,
                                          title: 'Phone Number',
                                          content: currentUser?.phoneNumber ?? 'Not provided',
                                        ),
                                        
                                        // Email Card
                                        _buildProfileCard(
                                          icon: Icons.email,
                                          title: 'Email',
                                          content: currentUser?.email ?? 'Not provided',
                                        ),
                                        
                                        // Address Card
                                        _buildProfileCard(
                                          icon: Icons.location_on,
                                          title: 'Address',
                                          content: currentUser?.address ?? 'Not provided',
                                        ),
                                        
                                        // Booking History Card
                                        _buildProfileCard(
                                          icon: Icons.history,
                                          title: 'Booking History',
                                          content: 'View your booking history',
                                          isActionable: true,
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              CupertinoPageRoute(builder: (context) => UserHistoryPage()),
                                            );
                                          }
                                        ),
                                        
                                        // Edit Profile Card
                                        _buildProfileCard(
                                          icon: Icons.edit,
                                          title: 'Edit Profile',
                                          content: 'Update your profile information',
                                          isActionable: true,
                                          onTap: () async {
                                            final result = await Navigator.push(
                                              context,
                                              CupertinoPageRoute(
                                                builder: (context) => EditProfilePage(),
                                              ),
                                            );
                                            
                                            // Reload data if profile was updated
                                            if (result == true) {
                                              _loadUserData();
                                            }
                                          },
                                        ),
                                        
                                        SizedBox(height: 24),
                                        
                                        // Logout Button
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: () {
                                              _showLogoutDialog(authService);
                                            },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red[600],
                                              padding: EdgeInsets.symmetric(vertical: 16),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                            ),
                                            child: Text(
                                              'Logout',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
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
              
              if (selectedIndex != 2) {
                // Use CupertinoPageRoute for sliding effect
                if (selectedIndex == 0) {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (context) => UserHomePage()),
                  );
                } else if (selectedIndex == 1) {
                  Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (context) => UserHistoryPage()),
                  );
                }
              }
            },
          ),
        );
      },
    );
  }
  
  // Profile card component
  Widget _buildProfileCard({
    required IconData icon,
    required String title,
    required String content,
    bool isActionable = false,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.yellow[600],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.black),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.blue[900],
          ),
        ),
        subtitle: Text(
          content,
          style: TextStyle(
            color: isActionable ? Colors.black87 : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: isActionable ? Icon(Icons.arrow_forward_ios, size: 16) : null,
        onTap: onTap,
      ),
    );
  }

  // Show logout confirmation dialog
  void _showLogoutDialog(AuthService authService) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
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
              children: [
                // Icon with animated container
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.logout_rounded,
                    size: 40,
                    color: Colors.red[600],
                  ),
                ),
                
                SizedBox(height: 20),
                
                // Title
                Text(
                  'Sign Out',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                
                SizedBox(height: 12),
                
                // Subtitle
                Text(
                  'Are you sure you want to sign out from your account?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
                
                SizedBox(height: 30),
                
                // Action buttons
                Row(
                  children: [
                    // Cancel button
                    Expanded(
                      child: Container(
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: Colors.white,
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    SizedBox(width: 12),
                    
                    // Logout button
                    Expanded(
                      child: Container(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context); // Close dialog
                            
                            try {
                              // Show modern loading indicator
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => Dialog(
                                  backgroundColor: Colors.transparent,
                                  child: Container(
                                    padding: EdgeInsets.all(32),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircularProgressIndicator(
                                          color: Colors.yellow[600],
                                          strokeWidth: 3,
                                        ),
                                        SizedBox(height: 20),
                                        Text(
                                          'Signing out...',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                              
                              await authService.signOut();
                              
                              // Close loading indicator
                              Navigator.pop(context);
                              
                              // Navigate to welcome page and clear all previous pages
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(builder: (context) => WelcomePage()),
                                (route) => false,
                              );
                            } catch (e) {
                              // Close loading indicator
                              Navigator.pop(context);
                              
                              // Show modern error message
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Failed to sign out. Please try again.',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Colors.red[600],
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  margin: EdgeInsets.all(16),
                                  duration: Duration(seconds: 4),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red[600],
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            'Sign Out',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
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
}