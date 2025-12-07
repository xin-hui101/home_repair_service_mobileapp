//lib/firebase_service/fcm_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// 后台消息处理（顶级函数）
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('后台消息: ${message.messageId}');
}

// ✨ 用户类型枚举 - 添加 Admin
enum UserType { customer, technician, admin }

class FCMService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // ✨ 存储当前用户类型和ID
  static UserType? _currentUserType;
  static String? _currentUserId;

  // ========================================
  // ✨ 初始化（需要指定用户类型）
  // ========================================
  static Future<void> initialize({
    required UserType userType,
    required String userId,
  }) async {
    _currentUserType = userType;
    _currentUserId = userId;

    print('🔧 初始化 FCM - 用户类型: ${_getUserTypeString(userType)}, ID: $userId');

    // 1. 注册后台处理器
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 2. 初始化本地通知
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings();
    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(settings);

    // 3. 创建 Android 通知频道
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'booking_updates', // id
      'Booking Updates', // name
      description: 'Notifications for booking status updates',
      importance: Importance.high,
    );
    
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 4. 请求权限
    NotificationSettings settings2 = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings2.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ 通知权限已授予');

      // 5. 获取 FCM Token
      String? token = await _fcm.getToken();
      if (token != null) {
        print('📱 FCM Token 获取成功: ${token.substring(0, 20)}...');
        await _saveTokenToFirestore(token);
      }

      // 6. 监听 token 刷新
      _fcm.onTokenRefresh.listen(_saveTokenToFirestore);

      // 7. 监听前台消息
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        print('📩 前台收到消息: ${message.notification?.title}');
        
        // 保存到 Firestore
        _saveNotificationToFirestore(message);
        
        // 显示本地通知
        if (message.notification != null) {
          _showLocalNotification(message);
        }
      });

      // 8. 监听通知点击
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        print('🔔 用户点击了通知');
        _handleNotificationClick(message);
      });

      // 9. 检查从终止状态启动
      RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationClick(initialMessage);
      }
    } else {
      print('❌ 用户拒绝了通知权限');
    }
  }

  // ========================================
  // ✨ 获取用户类型字符串
  // ========================================
  static String _getUserTypeString(UserType userType) {
    switch (userType) {
      case UserType.customer:
        return 'Customer';
      case UserType.technician:
        return 'Technician';
      case UserType.admin:
        return 'Admin';
    }
  }

  // ========================================
  // ✨ 获取 Collection 名称
  // ========================================
  static String _getCollectionName(UserType userType) {
    switch (userType) {
      case UserType.customer:
        return 'users';
      case UserType.technician:
        return 'technicians';
      case UserType.admin:
        return 'admin';  // ⭐ Admin 使用 admin collection
    }
  }

  // ========================================
  // ✨ 获取通知 Collection 名称
  // ========================================
  static String _getNotificationCollection(UserType userType) {
    switch (userType) {
      case UserType.customer:
        return 'notifications';
      case UserType.technician:
        return 'technician_notifications';
      case UserType.admin:
        return 'admin_notifications';
    }
  }

  // ========================================
  // ✨ 获取 ID 字段名称
  // ========================================
  static String _getIdField(UserType userType) {
    switch (userType) {
      case UserType.customer:
        return 'userId';
      case UserType.technician:
        return 'technicianId';
      case UserType.admin:
        return 'adminId';
    }
  }

  // ========================================
  // ✨ 保存 token 到 Firestore（支持 admin collection）
  // ========================================
  static Future<void> _saveTokenToFirestore(String token) async {
    if (_currentUserType == null || _currentUserId == null) {
      print('⚠️ 用户类型或ID未设置，无法保存 token');
      return;
    }

    try {
      final collection = _getCollectionName(_currentUserType!);
      print('📝 开始保存 FCM token 到 $collection...');

      // ⭐ 处理 Technician（可能需要查询）
      if (_currentUserType == UserType.technician) {
        print('🔍 处理技术员 token: $_currentUserId');
        
        // 方法 1: 先尝试直接用 UID 访问
        final directDoc = await _firestore
            .collection(collection)
            .doc(_currentUserId)
            .get();
        
        if (directDoc.exists) {
          // 文档 ID 就是 Firebase UID
          await _firestore.collection(collection).doc(_currentUserId).set({
            'fcmTokens': FieldValue.arrayUnion([token]),
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          print('✅ Token 已保存到 $collection/$_currentUserId (直接访问)');
        } else {
          // 方法 2: 文档 ID 是自定义 ID，需要查询
          print('⚠️ 直接访问失败，尝试通过 technician_ID 查询');
          
          final querySnapshot = await _firestore
              .collection(collection)
              .where('technician_ID', isEqualTo: _currentUserId)
              .limit(1)
              .get();
          
          if (querySnapshot.docs.isNotEmpty) {
            final docId = querySnapshot.docs.first.id;
            await _firestore.collection(collection).doc(docId).set({
              'fcmTokens': FieldValue.arrayUnion([token]),
              'lastTokenUpdate': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            print('✅ Token 已保存到 $collection/$docId (通过查询)');
          } else {
            print('❌ 未找到技术员文档: $_currentUserId');
          }
        }
      } 
      // ⭐ 处理 Admin（直接保存到 admin collection）
      else if (_currentUserType == UserType.admin) {
        print('👑 处理 Admin token: $_currentUserId');
        
        // 检查文档是否存在
        final adminDoc = await _firestore
            .collection(collection)
            .doc(_currentUserId)
            .get();
        
        if (adminDoc.exists) {
          // 文档存在，更新 fcmTokens
          await _firestore.collection(collection).doc(_currentUserId).set({
            'fcmTokens': FieldValue.arrayUnion([token]),
            'lastTokenUpdate': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          print('✅ Token 已保存到 $collection/$_currentUserId');
        } else {
          print('❌ Admin 文档不存在: $collection/$_currentUserId');
          print('💡 请确保 Firestore 中存在此 Admin 文档并有 role="admin" 字段');
        }
      } 
      // ⭐ 处理普通用户（直接保存）
      else {
        print('👤 处理用户 token: $_currentUserId');
        await _firestore.collection(collection).doc(_currentUserId).set({
          'fcmTokens': FieldValue.arrayUnion([token]),
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        print('✅ Token 已保存到 $collection/$_currentUserId');
      }
    } catch (e) {
      print('❌ 保存 token 失败: $e');
      print('   - Collection: ${_getCollectionName(_currentUserType!)}');
      print('   - Document ID: $_currentUserId');
      print('   - User Type: ${_getUserTypeString(_currentUserType!)}');
    }
  }

  // ========================================
  // ✨ 保存通知到 Firestore（根据用户类型）
  // ========================================
  static Future<void> _saveNotificationToFirestore(RemoteMessage message) async {
    if (_currentUserType == null || _currentUserId == null) {
      print('⚠️ 用户类型或ID未设置');
      return;
    }

    try {
      final collection = _getNotificationCollection(_currentUserType!);
      final idField = _getIdField(_currentUserType!);

      await _firestore.collection(collection).add({
        idField: _currentUserId,
        'title': message.notification?.title ?? '',
        'message': message.notification?.body ?? '',
        'type': message.data['type'] ?? 'general',
        'bookingId': message.data['bookingId'],
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'data': message.data,
      });
      print('✅ 通知已保存到 $collection');
    } catch (e) {
      print('❌ 保存通知失败: $e');
    }
  }

  // 显示本地通知
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'booking_updates',
      'Booking Updates',
      channelDescription: 'Notifications for booking status updates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      details,
      payload: message.data['bookingId'],
    );
  }

  // 处理通知点击
  static void _handleNotificationClick(RemoteMessage message) {
    final bookingId = message.data['bookingId'];
    if (bookingId != null) {
      print('🔗 导航到 booking: $bookingId');
      // TODO: 使用你的导航方法跳转到 BookingDetailPage
      // Navigator.push(context, MaterialPageRoute(
      //   builder: (context) => BookingDetailPage(bookingId: bookingId)
      // ));
    }
  }

  // ========================================
  // ✨ 删除 token（登出时调用）
  // ========================================
  static Future<void> deleteToken() async {
    if (_currentUserType == null || _currentUserId == null) {
      print('⚠️ 用户类型或ID未设置');
      return;
    }

    String? token = await _fcm.getToken();
    if (token != null) {
      final collection = _getCollectionName(_currentUserType!);

      try {
        await _firestore.collection(collection).doc(_currentUserId).update({
          'fcmTokens': FieldValue.arrayRemove([token]),
        });
        print('✅ Token 已从 Firestore 移除');
      } catch (e) {
        print('❌ 移除 token 失败: $e');
      }
    }

    await _fcm.deleteToken();
    _currentUserType = null;
    _currentUserId = null;
    print('✅ FCM Token 已删除');
  }

  // ========================================
  // ✨ 获取未读通知数量
  // ========================================
  static Stream<int> getUnreadNotificationCount(String userId, UserType userType) {
    final collection = _getNotificationCollection(userType);
    final idField = _getIdField(userType);

    return _firestore
        .collection(collection)
        .where(idField, isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // ========================================
  // ✨ 获取所有通知
  // ========================================
  static Stream<List<NotificationData>> getNotifications(
    String userId, 
    UserType userType, {
    int limit = 50,
  }) {
    final collection = _getNotificationCollection(userType);
    final idField = _getIdField(userType);

    return _firestore
        .collection(collection)
        .where(idField, isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return NotificationData.fromFirestore(doc);
      }).toList();
    });
  }

  // ========================================
  // ✨ 标记通知为已读
  // ========================================
  static Future<void> markNotificationAsRead(
    String notificationId, 
    UserType userType,
  ) async {
    try {
      final collection = _getNotificationCollection(userType);

      await _firestore
          .collection(collection)
          .doc(notificationId)
          .update({'isRead': true});
      
      print('✅ 通知已标记为已读: $notificationId');
    } catch (e) {
      print('❌ 标记通知失败: $e');
    }
  }

  // ========================================
  // ✨ 标记所有通知为已读
  // ========================================
  static Future<void> markAllNotificationsAsRead(
    String userId, 
    UserType userType,
  ) async {
    try {
      final collection = _getNotificationCollection(userType);
      final idField = _getIdField(userType);

      final querySnapshot = await _firestore
          .collection(collection)
          .where(idField, isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      
      for (var doc in querySnapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      await batch.commit();
      
      print('✅ 所有通知已标记为已读');
    } catch (e) {
      print('❌ 批量标记通知失败: $e');
    }
  }

  // ========================================
  // ✨ 删除通知
  // ========================================
  static Future<void> deleteNotification(
    String notificationId, 
    UserType userType,
  ) async {
    try {
      final collection = _getNotificationCollection(userType);

      await _firestore
          .collection(collection)
          .doc(notificationId)
          .delete();
      
      print('🗑️ 通知已删除: $notificationId');
    } catch (e) {
      print('❌ 删除通知失败: $e');
    }
  }
}

// ========================================
// ✨ 通知数据模型（统一用于用户、技术员和 Admin）
// ========================================
class NotificationData {
  final String id;
  final String userId;  // 可以是 userId、technicianId 或 adminId
  final String? bookingId;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? data;

  NotificationData({
    required this.id,
    required this.userId,
    this.bookingId,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.data,
  });

  factory NotificationData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return NotificationData(
      id: doc.id,
      userId: data['userId'] ?? data['technicianId'] ?? data['adminId'] ?? '',  // 支持三种字段
      bookingId: data['bookingId'],
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: data['type'] ?? 'general',
      isRead: data['isRead'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      data: data['data'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'bookingId': bookingId,
      'title': title,
      'message': message,
      'type': type,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
      'data': data,
    };
  }
}