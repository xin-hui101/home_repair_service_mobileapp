// lib/firebase_service/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'package:home_service_system/firebase_service/fcm_sercive.dart'; 

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? _currentUser;

  UserModel? get currentUser => _currentUser;

  Future<void> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String phoneNumber,
  }) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      User? user = userCredential.user;

      if (user != null) {
        await user.updateDisplayName(name.trim());

        await _firestore.collection('users').doc(user.uid).set({
          'firebase_uid': user.uid,
          'user_ID': user.uid,
          'user_name': name.trim(),
          'user_email': email.trim(),
          'user_phone_number': phoneNumber.trim(),
          'role': 'user',
          'status': 'active',
          'user_registration_date': FieldValue.serverTimestamp(),
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });

        await _populateCurrentUser(user);
        
        // ✅ 新用户注册后立即初始化 FCM
        await _initializeFCM(UserType.customer, user.uid);
        
        notifyListeners();
      }
    } on FirebaseAuthException catch (e) {
      print('Registration failed: ${e.message}');
      rethrow;
    } catch (e) {
      print('An unexpected error occurred: $e');
      rethrow;
    }
  }

  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
    required String expectedRole,
  }) async {
    try {
      print('Attempting login for role: $expectedRole with email: $email');
      
      // First authenticate with Firebase Auth
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      User? user = userCredential.user;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'auth-failed',
          message: 'Authentication failed.',
        );
      }

      print('Firebase Auth successful for UID: ${user.uid}');

      // Handle admin login differently
      if (expectedRole.toLowerCase() == 'admin') {
        print('🔑 Processing Admin login...');
        
        // For admin, check by email instead of UID
        QuerySnapshot adminQuery = await _firestore
            .collection('admin')
            .where('email', isEqualTo: email.trim())
            .limit(1)
            .get();
        
        if (adminQuery.docs.isEmpty) {
          print('❌ No admin account found for email: $email');
          await _auth.signOut();
          throw FirebaseAuthException(
            code: 'user-not-found',
            message: 'No admin account found with this email address.',
          );
        }

        // Check if admin account is active
        Map<String, dynamic> adminData = adminQuery.docs.first.data() as Map<String, dynamic>;
        if (adminData['status'] != 'active') {
          print('❌ Admin account is not active');
          await _auth.signOut();
          throw FirebaseAuthException(
            code: 'user-disabled',
            message: 'Admin account is deactivated.',
          );
        }

        // ⭐ 获取 Firestore 中的 admin 文档 ID（这是关键！）
        String adminDocId = adminQuery.docs.first.id;
        
        print('✅ Admin 验证成功');
        print('   📧 Email: $email');
        print('   🔑 Firebase Auth UID: ${user.uid}');
        print('   📄 Firestore Admin Doc ID: $adminDocId');

        // Update last login for admin
        await adminQuery.docs.first.reference.update({
          'last_login': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });

        print('Admin login successful');
        await _populateCurrentUser(user);
        
        // ⭐ 初始化 FCM - 使用 Firestore 文档 ID（admin_000）而非 Firebase Auth UID
        print('🔔 开始初始化 Admin FCM...');
        await _initializeFCM(UserType.admin, adminDocId);
        print('✅ Admin FCM 初始化完成');
        
      } else if (expectedRole.toLowerCase() == 'technician') {
        // Technician login
        String collectionName = _getCollectionName(expectedRole);
        DocumentSnapshot doc = await _firestore.collection(collectionName).doc(user.uid).get();
        
        if (!doc.exists) {
          print('No ${expectedRole.toLowerCase()} document found for UID: ${user.uid}');
          await _auth.signOut();
          throw FirebaseAuthException(
            code: 'user-not-found',
            message: 'No ${expectedRole.toLowerCase()} account found with this email address.',
          );
        }

        // Update last login time
        await _firestore.collection(collectionName).doc(user.uid).update({
          'last_login': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });

        print('Found ${expectedRole.toLowerCase()} data for user');
        await _populateCurrentUser(user);
        
        // ✅ 技术员登录后立即初始化 FCM
        await _initializeFCM(UserType.technician, user.uid);
        
      } else {
        // Customer login
        String collectionName = _getCollectionName(expectedRole);
        DocumentSnapshot doc = await _firestore.collection(collectionName).doc(user.uid).get();
        
        if (!doc.exists) {
          print('No ${expectedRole.toLowerCase()} document found for UID: ${user.uid}');
          await _auth.signOut();
          throw FirebaseAuthException(
            code: 'user-not-found',
            message: 'No ${expectedRole.toLowerCase()} account found with this email address.',
          );
        }

        // Update last login time
        await _firestore.collection(collectionName).doc(user.uid).update({
          'last_login': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });

        print('Found ${expectedRole.toLowerCase()} data for user');
        await _populateCurrentUser(user);
        
        // ✅ 客户登录后立即初始化 FCM
        await _initializeFCM(UserType.customer, user.uid);
      }

      notifyListeners();
      
    } on FirebaseAuthException catch (e) {
      print('Sign in failed: ${e.message}');
      rethrow;
    } catch (e) {
      print('An unexpected error occurred: $e');
      rethrow;
    }
  }

  // ========================================
  // ✅ 初始化 FCM 的独立函数
  // ========================================
  Future<void> _initializeFCM(UserType userType, String userId) async {
    try {
      print('🔧 正在初始化 FCM...');
      print('   User Type: ${_getUserTypeString(userType)}');
      print('   User ID: $userId');
      
      await FCMService.initialize(
        userType: userType,
        userId: userId,
      );
      
      print('✅ FCM 初始化完成');
    } catch (e) {
      print('❌ FCM 初始化失败: $e');
      // 不抛出异常，让登录继续进行
    }
  }

  // ========================================
  // ✅ 获取用户类型字符串（用于日志）
  // ========================================
  String _getUserTypeString(UserType userType) {
    switch (userType) {
      case UserType.customer:
        return 'Customer';
      case UserType.technician:
        return 'Technician';
      case UserType.admin:
        return 'Admin';
    }
  }

  String _getCollectionName(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'admin';
      case 'technician':
        return 'technicians';
      case 'user':
        return 'users';
      default:
        return 'users';
    }
  }

  Future<void> signOut() async {
    try {
      print('🚪 正在登出...');
      
      // ✅ 登出前删除 FCM token
      await FCMService.deleteToken();
      
      await _auth.signOut();
      _currentUser = null;
      
      print('✅ 登出成功');
      notifyListeners();
    } catch (e) {
      print('❌ 登出失败: $e');
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      print('Failed to send password reset email: ${e.message}');
      rethrow;
    } catch (e) {
      print('An unexpected error occurred: $e');
      rethrow;
    }
  }

  Future<UserModel?> getUserData({
    String? userId, 
    String? role,
  }) async {
    try {
      String uid = userId ?? _currentUser?.id ?? '';
      if (uid.isEmpty) return null;

      String collectionName = role != null ? _getCollectionName(role) : 'users';
      
      DocumentSnapshot doc = await _firestore.collection(collectionName).doc(uid).get();
      
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }

      QuerySnapshot querySnapshot = await _firestore
          .collection(collectionName)
          .where('firebase_uid', isEqualTo: uid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return UserModel.fromMap(querySnapshot.docs.first.data() as Map<String, dynamic>);
      }
      
      return null;
    } catch (e) {
      print('Error getting user data: $e');
      return null;
    }
  }

  Future<bool> updateUserData({
    required String userId,
    required Map<String, dynamic> data,
    String? role,
  }) async {
    try {
      String collectionName = role != null ? _getCollectionName(role) : 'users';
      data['updated_at'] = FieldValue.serverTimestamp();
      await _firestore.collection(collectionName).doc(userId).update(data);
      return true;
    } catch (e) {
      print('Error updating user data: $e');
      return false;
    }
  }

  Future<void> deleteAccount() async {
    try {
      String? userId = _currentUser?.id;
      if (userId != null) {
        // ✅ 删除账户前先删除 FCM token
        await FCMService.deleteToken();
        
        await _firestore.collection('users').doc(userId).delete();
        await _auth.currentUser?.delete();
        _currentUser = null;
        notifyListeners();
      }
    } on FirebaseAuthException catch (e) {
      print('Failed to delete account: ${e.message}');
      rethrow;
    } catch (e) {
      print('An unexpected error occurred: $e');
      rethrow;
    }
  }

  Future<bool> checkEmailExists(String email) async {
    try {
      final list = await _auth.fetchSignInMethodsForEmail(email);
      return list.isNotEmpty;
    } catch (e) {
      print('Error checking email existence: $e');
      return false;
    }
  }

  Future<void> _populateCurrentUser(User? user) async {
    if (user != null) {
      // Try to get user from users collection first
      DocumentSnapshot snapshot = await _firestore.collection('users').doc(user.uid).get();
      
      if (snapshot.exists) {
        _currentUser = UserModel.fromMap(snapshot.data() as Map<String, dynamic>);
      } else {
        // Check if it's an admin by email
        QuerySnapshot adminQuery = await _firestore
            .collection('admin')
            .where('email', isEqualTo: user.email ?? '')
            .limit(1)
            .get();
        
        if (adminQuery.docs.isNotEmpty) {
          Map<String, dynamic> adminData = adminQuery.docs.first.data() as Map<String, dynamic>;
          _currentUser = UserModel(
            id: user.uid,
            name: adminData['name'] ?? 'Admin',
            email: adminData['email'] ?? user.email ?? '',
            role: 'admin',
            status: 'active',
          );
        } else {
          // Check technicians collection
          DocumentSnapshot techSnapshot = await _firestore.collection('technicians').doc(user.uid).get();
          if (techSnapshot.exists) {
            Map<String, dynamic> techData = techSnapshot.data() as Map<String, dynamic>;
            _currentUser = UserModel(
              id: user.uid,
              name: techData['technician_name'] ?? user.displayName ?? '',
              email: techData['technician_email'] ?? user.email ?? '',
              role: 'technician',
              status: techData['status'] ?? 'active',
            );
          } else {
            // Default user model
            _currentUser = UserModel(
              id: user.uid,
              name: user.displayName ?? '',
              email: user.email ?? '',
            );
          }
        }
      }
    }
  }

  // Get all users with debugging functionality
  Future<List<UserModel>> getAllUsers({String status = 'active'}) async {
    try {
      print('=== DEBUG: getAllUsers ===');
      print('Querying users with status: $status');
      
      // First check if users collection exists and has data
      QuerySnapshot allUsersSnapshot = await _firestore
          .collection('users')
          .limit(5)
          .get();
      
      print('Total documents in users collection: ${allUsersSnapshot.docs.length}');
      
      // If no data, return empty list
      if (allUsersSnapshot.docs.isEmpty) {
        print('No users found in database!');
        return [];
      }
      
      // Print first few document structures
      for (var doc in allUsersSnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        print('Document ${doc.id}: fields = ${data.keys.toList()}');
        print('  Status field exists: ${data.containsKey('status')}');
        print('  Status value: ${data['status']}');
        print('  Name: ${data['user_name'] ?? 'N/A'}');
      }
      
      // Try to query users with status field
      QuerySnapshot querySnapshot;
      try {
        querySnapshot = await _firestore
            .collection('users')
            .where('status', isEqualTo: status)
            .get();
        
        print('Query with status filter result: ${querySnapshot.docs.length} documents');
      } catch (e) {
        print('Error with status filter, trying without filter: $e');
        querySnapshot = await _firestore
            .collection('users')
            .get();
      }
      
      // If no results, try getting all users
      if (querySnapshot.docs.isEmpty) {
        print('No users found with status filter, getting all users...');
        querySnapshot = await _firestore
            .collection('users')
            .get();
        print('All users without filter: ${querySnapshot.docs.length} documents');
      }

      List<UserModel> users = [];
      for (var doc in querySnapshot.docs) {
        try {
          Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
          print('Processing user: ${data['user_name']} (${doc.id})');
          
          // If no status field, add manually
          if (!data.containsKey('status')) {
            data['status'] = 'active';
            print('Added default status for user: ${data['user_name']}');
          }
          
          // Only add users matching status condition
          if (data['status'] == status) {
            UserModel user = UserModel.fromMap(data);
            users.add(user);
            print('Successfully added user: ${user.name}');
          } else {
            print('Skipping user ${data['user_name']} (status: ${data['status']})');
          }
        } catch (e) {
          print('Error parsing user document ${doc.id}: $e');
        }
      }
      
      print('Total users loaded with status "$status": ${users.length}');
      print('=== END DEBUG ===');
      
      return users;
    } catch (e) {
      print('Error in getAllUsers: $e');
      print('Error type: ${e.runtimeType}');
      return [];
    }
  }

  // Deactivate user account
  Future<bool> deactivateUser(String userId) async {
    try {
      print('Deactivating user: $userId');
      await _firestore.collection('users').doc(userId).update({
        'status': 'deactivated',
        'deactivated_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });
      print('User deactivated successfully');
      return true;
    } catch (e) {
      print('Error deactivating user: $e');
      return false;
    }
  }

  // Reactivate user account
  Future<bool> reactivateUser(String userId) async {
    try {
      print('Reactivating user: $userId');
      await _firestore.collection('users').doc(userId).update({
        'status': 'active',
        'deactivated_at': null,
        'updated_at': FieldValue.serverTimestamp(),
      });
      print('User reactivated successfully');
      return true;
    } catch (e) {
      print('Error reactivating user: $e');
      return false;
    }
  }

  // Get user statistics
  Future<Map<String, int>> getUserStatistics() async {
    try {
      // Get active users count
      QuerySnapshot activeUsers = await _firestore
          .collection('users')
          .where('status', isEqualTo: 'active')
          .get();

      // Get deactivated users count
      QuerySnapshot deactivatedUsers = await _firestore
          .collection('users')
          .where('status', isEqualTo: 'deactivated')
          .get();

      // Get total users count
      QuerySnapshot totalUsers = await _firestore
          .collection('users')
          .get();

      return {
        'active': activeUsers.docs.length,
        'deactivated': deactivatedUsers.docs.length,
        'total': totalUsers.docs.length,
      };
    } catch (e) {
      print('Error getting user statistics: $e');
      return {'active': 0, 'deactivated': 0, 'total': 0};
    }
  }

  // Search users by name, email, or ID
  Future<List<UserModel>> searchUsers(String query, {String status = 'active'}) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('users')
          .get(); // Get all users, then filter locally

      List<UserModel> allUsers = [];
      for (var doc in querySnapshot.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        // Add default status if doesn't exist
        if (!data.containsKey('status')) {
          data['status'] = 'active';
        }
        
        allUsers.add(UserModel.fromMap(data));
      }

      // Filter users: first by status, then by search criteria
      String lowerQuery = query.toLowerCase();
      List<UserModel> filteredUsers = allUsers.where((user) {
        bool statusMatch = user.status == status;
        bool searchMatch = user.id.toLowerCase().contains(lowerQuery) ||
                          user.name.toLowerCase().contains(lowerQuery) ||
                          user.email.toLowerCase().contains(lowerQuery);
        return statusMatch && searchMatch;
      }).toList();

      return filteredUsers;
    } catch (e) {
      print('Error searching users: $e');
      return [];
    }
  }

  // Improved data migration script
  Future<void> migrateExistingUsers() async {
    try {
      print('=== Starting user migration ===');
      
      // Get all user documents
      QuerySnapshot allUsers = await _firestore.collection('users').get();
      
      print('Found ${allUsers.docs.length} user documents');
      
      if (allUsers.docs.isEmpty) {
        print('No users to migrate');
        return;
      }
      
      WriteBatch batch = _firestore.batch();
      int updateCount = 0;
      
      for (var doc in allUsers.docs) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        print('Checking user: ${doc.id}');
        
        Map<String, dynamic> updates = {};
        
        // Add missing fields
        if (!data.containsKey('status')) {
          updates['status'] = 'active';
          print('  Adding status field');
        }
        
        if (!data.containsKey('updated_at')) {
          updates['updated_at'] = FieldValue.serverTimestamp();
          print('  Adding updated_at field');
        }
        
        // Ensure field name consistency
        if (data.containsKey('firebase_uid') && !data.containsKey('user_ID')) {
          updates['user_ID'] = data['firebase_uid'];
          print('  Adding user_ID field');
        }
        
        if (data.containsKey('user_ID') && !data.containsKey('firebase_uid')) {
          updates['firebase_uid'] = data['user_ID'];
          print('  Adding firebase_uid field');
        }
        
        if (updates.isNotEmpty) {
          batch.update(doc.reference, updates);
          updateCount++;
        }
      }
      
      if (updateCount > 0) {
        await batch.commit();
        print('Migration completed: Updated $updateCount users');
      } else {
        print('No migration needed: All users have required fields');
      }
      
      print('=== Migration finished ===');
    } catch (e) {
      print('Error during migration: $e');
      rethrow;
    }
  }

  // Test Firestore connection method
  Future<bool> testFirestoreConnection() async {
    try {
      print('Testing Firestore connection...');
      
      // Try simple read operation
      QuerySnapshot testQuery = await _firestore
          .collection('users')
          .limit(1)
          .get();
      
      print('Firestore connection successful');
      print('Found ${testQuery.docs.length} documents in users collection');
      
      return true;
    } catch (e) {
      print('Firestore connection failed: $e');
      return false;
    }
  }

  // Debug method for admin authentication
  Future<void> debugAdminLogin(String email) async {
    try {
      print('=== ADMIN LOGIN DEBUG ===');
      print('Checking admin account for email: $email');
      
      QuerySnapshot adminQuery = await _firestore
          .collection('admin')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();
      
      print('Admin documents found: ${adminQuery.docs.length}');
      
      if (adminQuery.docs.isNotEmpty) {
        Map<String, dynamic> adminData = adminQuery.docs.first.data() as Map<String, dynamic>;
        print('Admin data: $adminData');
        print('Admin status: ${adminData['status']}');
      }
      
      print('=== END ADMIN DEBUG ===');
    } catch (e) {
      print('Error in admin debug: $e');
    }
  }
}