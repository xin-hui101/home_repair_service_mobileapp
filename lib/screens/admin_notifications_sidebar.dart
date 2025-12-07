// lib/screens/admin_notifications_sidebar.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:home_service_system/firebase_service/fcm_sercive.dart';

class AdminNotificationsSidebar extends StatefulWidget {
  final VoidCallback onClose;
  final String adminId;

  const AdminNotificationsSidebar({
    super.key,
    required this.onClose,
    required this.adminId,
  });

  @override
  State<AdminNotificationsSidebar> createState() => _AdminNotificationsSidebarState();
}

class _AdminNotificationsSidebarState extends State<AdminNotificationsSidebar> {
  bool _showOnlyUnread = false;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      right: 0,
      bottom: 0,
      width: 380,
      child: Material(
        elevation: 16,
        shadowColor: Colors.black38,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              left: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Notifications',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                          Row(
                            children: [
                              // Mark all as read button
                              TextButton.icon(
                                onPressed: () async {
                                  await FCMService.markAllNotificationsAsRead(
                                    widget.adminId,
                                    UserType.admin,
                                  );
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('All notifications marked as read'),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.done_all, size: 18),
                                label: const Text('Mark all read'),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.blue,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 22),
                                onPressed: widget.onClose,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                tooltip: 'Close',
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Filter toggle
                      Row(
                        children: [
                          FilterChip(
                            label: const Text('Unread only'),
                            selected: _showOnlyUnread,
                            onSelected: (selected) {
                              setState(() {
                                _showOnlyUnread = selected;
                              });
                            },
                            selectedColor: Colors.blue.shade100,
                            checkmarkColor: Colors.blue,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Notifications list
                Expanded(
                  child: StreamBuilder<List<NotificationData>>(
                    stream: FCMService.getNotifications(
                      widget.adminId,
                      UserType.admin,
                      limit: 100,
                    ),
                    builder: (context, snapshot) {
                          print('==================================');
    print('🔍 AdminNotificationsSidebar 调试');
    print('   Admin ID: ${widget.adminId}');
    print('   Stream 状态: ${snapshot.connectionState}');
    print('   有错误: ${snapshot.hasError}');
    if (snapshot.hasError) {
      print('   错误详情: ${snapshot.error}');
      print('   错误堆栈: ${snapshot.stackTrace}');
    }
    print('   有数据: ${snapshot.hasData}');
    if (snapshot.hasData) {
      print('   通知数量: ${snapshot.data!.length}');
      for (var n in snapshot.data!) {
        print('   - 通知: ${n.title} (isRead: ${n.isRead})');
      }
    }
    print('==================================');
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                              const SizedBox(height: 16),
                              Text(
                                'Error loading notifications',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                snapshot.error.toString(),
                                style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      List<NotificationData> notifications = snapshot.data ?? [];

                      // Filter by unread if toggle is on
                      if (_showOnlyUnread) {
                        notifications = notifications.where((n) => !n.isRead).toList();
                      }

                      if (notifications.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _showOnlyUnread ? Icons.notifications_off : Icons.notifications_none,
                                size: 64,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _showOnlyUnread ? 'No unread notifications' : 'No notifications yet',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: notifications.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          color: Colors.grey[200],
                        ),
                        itemBuilder: (context, index) {
                          final notification = notifications[index];
                          return _buildNotificationItem(notification);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationItem(NotificationData notification) {
    return InkWell(
      onTap: () async {
        // Mark as read
        if (!notification.isRead) {
          await FCMService.markNotificationAsRead(
            notification.id,
            UserType.admin,
          );
        }

        // Navigate to booking detail if bookingId exists
        if (notification.bookingId != null) {
          // TODO: Navigate to booking detail page
          print('Navigate to booking: ${notification.bookingId}');
          // Navigator.push(
          //   context,
          //   MaterialPageRoute(
          //     builder: (context) => ServiceRequestManagementPage(
          //       initialBookingId: notification.bookingId,
          //     ),
          //   ),
          // );
        }
      },
      child: Container(
        color: notification.isRead ? Colors.white : Colors.blue.shade50,
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon based on notification type
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _getNotificationColor(notification.type).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getNotificationIcon(notification.type),
                color: _getNotificationColor(notification.type),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: notification.isRead ? FontWeight.w500 : FontWeight.w600,
                            color: const Color(0xFF1F2937),
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 12, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Text(
                        _formatTimestamp(notification.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                      if (notification.bookingId != null) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'ID: ${notification.bookingId}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Actions menu
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 18, color: Colors.grey[600]),
              padding: EdgeInsets.zero,
              onSelected: (value) async {
                if (value == 'mark_read') {
                  await FCMService.markNotificationAsRead(
                    notification.id,
                    UserType.admin,
                  );
                } else if (value == 'delete') {
                  await FCMService.deleteNotification(
                    notification.id,
                    UserType.admin,
                  );
                }
              },
              itemBuilder: (context) => [
                if (!notification.isRead)
                  const PopupMenuItem(
                    value: 'mark_read',
                    child: Row(
                      children: [
                        Icon(Icons.check, size: 18),
                        SizedBox(width: 8),
                        Text('Mark as read'),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'new_booking':
        return Icons.add_circle_outline;
      case 'STATUS005': // In Progress - Payment
        return Icons.payments;
      case 'STATUS006': // Completed
        return Icons.check_circle_outline;
      case 'booking_assigned':
        return Icons.person_add;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'new_booking':
        return Colors.blue;
      case 'STATUS005': // In Progress - Payment
        return Colors.green;
      case 'STATUS006': // Completed
        return Colors.purple;
      case 'booking_assigned':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(timestamp);
    }
  }
}