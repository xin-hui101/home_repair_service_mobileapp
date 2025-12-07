// lib/screens/admin_header.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:home_service_system/firebase_service/fcm_sercive.dart';

class AdminHeader extends StatelessWidget {
  final String title;
  final bool isSidebarCollapsed;
  final VoidCallback onToggleSidebar;
  final Widget? trailing;
  final int? notificationCount;

  const AdminHeader({
    super.key,
    required this.title,
    required this.isSidebarCollapsed,
    required this.onToggleSidebar,
    this.trailing,
    this.notificationCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            // Menu toggle button
            IconButton(
              icon: Icon(
                isSidebarCollapsed ? Icons.menu : Icons.menu_open,
                size: 28,
                color: const Color(0xFF1F2937),
              ),
              onPressed: onToggleSidebar,
              tooltip: isSidebarCollapsed ? 'Expand sidebar' : 'Collapse sidebar',
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
          ],
        ),
        trailing ?? const SizedBox(),
      ],
    );
  }
}

class AdminHeaderWithNotification extends StatelessWidget {
  final String title;
  final bool isSidebarCollapsed;
  final VoidCallback onToggleSidebar;
  final VoidCallback onNotificationTap;

  const AdminHeaderWithNotification({
    super.key,
    required this.title,
    required this.isSidebarCollapsed,
    required this.onToggleSidebar,
    required this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    // ⭐ 直接使用 FirebaseAuth 获取当前用户
    final User? currentUser = FirebaseAuth.instance.currentUser;

    return AdminHeader(
      title: title,
      isSidebarCollapsed: isSidebarCollapsed,
      onToggleSidebar: onToggleSidebar,
      trailing: currentUser != null
          ? StreamBuilder<int>(
              stream: FCMService.getUnreadNotificationCount(
                currentUser.uid,
                UserType.admin,
              ),
              builder: (context, snapshot) {
                final unreadCount = snapshot.data ?? 0;

                return Stack(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.notifications_outlined,
                        size: 28,
                      ),
                      onPressed: onNotificationTap,
                      tooltip: 'Notifications',
                    ),
                    if (unreadCount > 0)
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            unreadCount > 99 ? '99+' : unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                );
              },
            )
          : const SizedBox(),
    );
  }
}