// functions/index.js
// Cloud Functions - 当 booking 创建或状态更新时自动发送通知
// ✨ Admin 通知系统 - 只查询 admin collection
// ⭐ Technician 通知优化 - 只接收分配和支付完成通知
// 🛡️ 防重复通知机制 + 详细日志

const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// ========================================
// 📅 格式化日期函数
// ========================================
function formatDate(timestamp) {
  if (!timestamp) return 'scheduled date';
  
  try {
    if (timestamp.toDate && typeof timestamp.toDate === 'function') {
      const date = timestamp.toDate();
      return date.toLocaleDateString('en-US', { 
        year: 'numeric', 
        month: 'long', 
        day: 'numeric' 
      });
    }
    
    if (typeof timestamp === 'string') {
      return timestamp;
    }
    
    return 'scheduled date';
    
  } catch (error) {
    console.error('❌ 日期格式化错误:', error);
    return 'scheduled date';
  }
}

// ========================================
// 🔔 发送通知到所有 Admin
// ========================================
async function sendNotificationToAllAdmins(bookingId, title, message, type, bookingData) {
  try {
    console.log('========================================');
    console.log('📢 [ADMIN] 开始发送通知');
    console.log('   Type: ' + type);
    console.log('   Booking: ' + bookingId);
    console.log('   Title: ' + title);
    console.log('   Message: ' + message);
    console.log('========================================');
    
    const adminQuery = await admin.firestore()
      .collection('admin')
      .where('role', '==', 'admin')
      .get();
    
    if (adminQuery.empty) {
      console.log('⚠️ [ADMIN] 没有找到 admin 用户');
      return false;
    }
    
    console.log(`✅ [ADMIN] 找到 ${adminQuery.docs.length} 个 admin`);
    
    const promises = adminQuery.docs.map(async (adminDoc) => {
      const adminId = adminDoc.id;
      const adminData = adminDoc.data();
      
      let fcmTokens = adminData.fcmTokens || [];
      
      if (!adminData.fcmTokens) {
        await admin.firestore()
          .collection('admin')
          .doc(adminId)
          .set({ fcmTokens: [] }, { merge: true });
      }
      
      console.log(`   👤 [ADMIN] ${adminId} - Tokens: ${fcmTokens.length}`);
      
      const notificationRef = await admin.firestore()
        .collection('admin_notifications')
        .add({
          adminId: adminId,
          bookingId: bookingId,
          title: title,
          message: message,
          type: type,
          isRead: false,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          data: {
            bookingId: bookingId,
            serviceType: bookingData.serviceType || '',
            userId: bookingData.userId || '',
            technicianId: bookingData.technicianId || null,
            status: bookingData.status || '',
            userName: bookingData.userName || '',
            bookingDate: bookingData.bookingDate || '',
            bookingTime: bookingData.bookingTime || '',
          },
        });
      
      console.log(`   ✅ [ADMIN] 通知已创建: ${notificationRef.id}`);
      
      if (fcmTokens.length === 0) {
        console.log('   ⚠️ [ADMIN] 没有 FCM tokens');
        return;
      }
      
      const messagePayload = {
        notification: {
          title: title,
          body: message,
        },
        data: {
          notificationId: notificationRef.id,
          bookingId: bookingId,
          type: type,
          recipient: 'admin',
        },
        tokens: fcmTokens,
      };
      
      const response = await admin.messaging().sendEachForMulticast(messagePayload);
      console.log(`   📱 [ADMIN] 推送: 成功 ${response.successCount}, 失败 ${response.failureCount}`);
      
      if (response.failureCount > 0) {
        const tokensToRemove = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            tokensToRemove.push(fcmTokens[idx]);
          }
        });
        
        if (tokensToRemove.length > 0) {
          await admin.firestore()
            .collection('admin')
            .doc(adminId)
            .update({
              fcmTokens: admin.firestore.FieldValue.arrayRemove(...tokensToRemove)
            });
        }
      }
    });
    
    await Promise.all(promises);
    console.log('✅ [ADMIN] 通知处理完成\n');
    return true;
    
  } catch (error) {
    console.error('❌ [ADMIN] 发送失败:', error);
    return false;
  }
}

// ========================================
// 发送通知到用户
// ========================================
async function sendNotificationToUser(userId, bookingId, title, message, statusID, bookingData) {
  try {
    const notificationRef = await admin.firestore()
      .collection('notifications')
      .add({
        userId: userId,
        bookingId: bookingId,
        title: title,
        message: message,
        type: statusID,
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        data: {
          bookingId: bookingId,
          serviceType: bookingData ? (bookingData.service_name || 'service') : 'service',
          technicianId: bookingData ? (bookingData.technician_ID || null) : null,
          status: statusID,
        }
      });
    
    console.log('✅ [USER] 通知已创建: ' + notificationRef.id);
    
    const userDoc = await admin.firestore()
      .collection('users')
      .doc(userId)
      .get();
    
    if (!userDoc.exists) {
      console.log('⚠️ [USER] 用户不存在: ' + userId);
      return false;
    }
    
    const userData = userDoc.data();
    const fcmTokens = userData && userData.fcmTokens ? userData.fcmTokens : [];
    
    if (fcmTokens.length === 0) {
      console.log('⚠️ [USER] 没有 FCM tokens');
      return false;
    }
    
    const messagePayload = {
      notification: {
        title: title,
        body: message,
      },
      data: {
        notificationId: notificationRef.id,
        bookingId: bookingId,
        type: statusID,
        recipient: 'customer',
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      tokens: fcmTokens,
    };
    
    const response = await admin.messaging().sendEachForMulticast(messagePayload);
    console.log('✅ [USER] 成功: ' + response.successCount + ', 失败: ' + response.failureCount);
    
    if (response.failureCount > 0) {
      const tokensToRemove = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          tokensToRemove.push(fcmTokens[idx]);
        }
      });
      
      if (tokensToRemove.length > 0) {
        await admin.firestore()
          .collection('users')
          .doc(userId)
          .update({
            fcmTokens: admin.firestore.FieldValue.arrayRemove(...tokensToRemove)
          });
      }
    }
    
    return true;
    
  } catch (error) {
    console.error('❌ [USER] 发送失败:', error);
    return false;
  }
}

// ========================================
// ⭐ 发送通知到技术员
// ========================================
async function sendNotificationToTechnician(
  technicianCustomId, 
  bookingId, 
  title, 
  message, 
  type, 
  bookingData
) {
  try {
    console.log('========================================');
    console.log('👨‍🔧 [TECHNICIAN] 开始发送通知');
    console.log('   Type: ' + type);
    console.log('   Technician ID: ' + technicianCustomId);
    console.log('   Booking: ' + bookingId);
    console.log('   Title: ' + title);
    console.log('   Message: ' + message);
    console.log('========================================');
    
    const technicianQuery = await admin.firestore()
      .collection('technicians')
      .where('technician_ID', '==', technicianCustomId)
      .limit(1)
      .get();
    
    if (technicianQuery.empty) {
      console.log('❌ [TECHNICIAN] 未找到: ' + technicianCustomId);
      return false;
    }
    
    const technicianDoc = technicianQuery.docs[0];
    const technicianFirebaseUid = technicianDoc.id;
    const technicianData = technicianDoc.data();
    
    console.log('✅ [TECHNICIAN] 找到 Firebase UID: ' + technicianFirebaseUid);
    console.log('   Name: ' + (technicianData.technician_name || 'N/A'));
    
    const notificationRef = await admin.firestore()
      .collection('technician_notifications')
      .add({
        technicianId: technicianFirebaseUid,
        bookingId: bookingId,
        title: title,
        message: message,
        type: type,
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        data: {
          bookingId: bookingId,
          serviceType: bookingData ? (bookingData.service_name || 'service') : 'service',
          userId: bookingData ? (bookingData.user_ID || null) : null,
          status: type,
          technicianCustomId: technicianCustomId,
        }
      });
    
    console.log('✅ [TECHNICIAN] 通知已创建: ' + notificationRef.id);
    
    const fcmTokens = technicianData && technicianData.fcmTokens 
      ? technicianData.fcmTokens 
      : [];
    
    if (fcmTokens.length === 0) {
      console.log('⚠️ [TECHNICIAN] 没有 FCM tokens');
      console.log('========================================\n');
      return false;
    }
    
    console.log('📱 [TECHNICIAN] Tokens: ' + fcmTokens.length);
    
    const messagePayload = {
      notification: {
        title: title,
        body: message,
      },
      data: {
        notificationId: notificationRef.id,
        bookingId: bookingId,
        type: type,
        recipient: 'technician',
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
      tokens: fcmTokens,
    };
    
    const response = await admin.messaging().sendEachForMulticast(messagePayload);
    console.log('✅ [TECHNICIAN] 成功: ' + response.successCount + ', 失败: ' + response.failureCount);
    
    if (response.failureCount > 0) {
      const tokensToRemove = [];
      response.responses.forEach((resp, idx) => {
        if (!resp.success) {
          console.log('   ⚠️ [TECHNICIAN] Token 失效: ' + resp.error?.code);
          tokensToRemove.push(fcmTokens[idx]);
        }
      });
      
      if (tokensToRemove.length > 0) {
        await admin.firestore()
          .collection('technicians')
          .doc(technicianFirebaseUid)
          .update({
            fcmTokens: admin.firestore.FieldValue.arrayRemove(...tokensToRemove)
          });
        console.log('   🗑️ [TECHNICIAN] 已移除 ' + tokensToRemove.length + ' 个失效 tokens');
      }
    }
    
    console.log('========================================\n');
    return true;
    
  } catch (error) {
    console.error('❌ [TECHNICIAN] 发送失败:', error);
    console.log('========================================\n');
    return false;
  }
}

// ========================================
// 监听 Booking 创建
// ========================================
exports.sendBookingCreatedNotification = functions.firestore
  .document('bookings/{bookingId}')
  .onCreate(async (snapshot, context) => {
    const bookingData = snapshot.data();
    const bookingId = context.params.bookingId;
    const userId = bookingData.user_ID;
    
    console.log('========================================');
    console.log('🆕 NEW BOOKING CREATED');
    console.log('   Booking ID: ' + bookingId);
    console.log('   User ID: ' + userId);
    console.log('   Status: ' + bookingData.status_ID);
    console.log('   Service: ' + bookingData.service_name);
    console.log('========================================');
    
    const userTitle = 'Booking Received';
    const userMessage = 'Your booking request has been received and is being processed. We will notify you once it\'s confirmed.';
    const statusID = bookingData.status_ID || 'STATUS001';
    
    await sendNotificationToUser(userId, bookingId, userTitle, userMessage, statusID, bookingData);
    
    const adminTitle = '🆕 New Booking Request';
    const adminMessage = `New ${bookingData.service_name || 'service'} booking from ${bookingData.user_name || 'customer'}`;
    
    await sendNotificationToAllAdmins(
      bookingId,
      adminTitle,
      adminMessage,
      'new_booking',
      bookingData
    );
    
    return null;
  });

// ========================================
// ⭐ 监听技术员分配
// ========================================
exports.sendTechnicianAssignedNotification = functions.firestore
  .document('bookings/{bookingId}')
  .onUpdate(async (change, context) => {
    const newData = change.after.data();
    const oldData = change.before.data();
    const bookingId = context.params.bookingId;
    
    const wasAssigned = !oldData.technician_ID && newData.technician_ID;
    const reassigned = oldData.technician_ID && newData.technician_ID && 
                       oldData.technician_ID !== newData.technician_ID;
    
    if (!wasAssigned && !reassigned) {
      return null;
    }
    
    const technicianCustomId = newData.technician_ID;
    
    console.log('========================================');
    console.log('👨‍🔧 TECHNICIAN ' + (wasAssigned ? 'ASSIGNED' : 'REASSIGNED'));
    console.log('   Booking: ' + bookingId);
    console.log('   Custom ID: ' + newData.booking_ID);
    console.log('   Technician: ' + technicianCustomId);
    console.log('   Service: ' + newData.service_name);
    console.log('   Date: ' + formatDate(newData.booking_date));
    console.log('========================================');
    
    const title = wasAssigned ? '🔧 New Booking Assigned' : '🔄 Booking Reassigned';
    const formattedDate = formatDate(newData.booking_date);
    const message = `You have been assigned to a ${newData.service_name || 'service'} booking ${newData.booking_ID || bookingId} on ${formattedDate}. Please complete the site assessment as scheduled.`;
    
    await sendNotificationToTechnician(
      technicianCustomId,
      bookingId,
      title,
      message,
      'booking_assigned',
      newData
    );
    
    return null;
  });

// ========================================
// ⭐ 监听 Booking 状态更新
// ========================================
exports.sendBookingNotification = functions.firestore
  .document('bookings/{bookingId}')
  .onUpdate(async (change, context) => {
    const newData = change.after.data();
    const oldData = change.before.data();
    
    if (newData.status_ID === oldData.status_ID) {
      return null;
    }
    
    const bookingId = context.params.bookingId;
    const userId = newData.user_ID;
    const newStatus = newData.status_ID;
    const technicianCustomId = newData.technician_ID;
    
    console.log('========================================');
    console.log('🔔 BOOKING STATUS CHANGED');
    console.log('   Booking: ' + bookingId);
    console.log('   Status: ' + oldData.status_ID + ' → ' + newStatus);
    console.log('   Technician: ' + (technicianCustomId || 'None'));
    console.log('========================================');
    
    // 1️⃣ 通知用户
    const userNotification = getNotificationContent(newStatus, newData);
    console.log('\n📱 [USER] 准备发送通知');
    console.log('   Title: ' + userNotification.title);
    console.log('   Message: ' + userNotification.message);
    
    await sendNotificationToUser(
      userId, 
      bookingId, 
      userNotification.title, 
      userNotification.message, 
      newStatus,
      newData
    );
    
    // 2️⃣ 特定状态通知 Admin
    if (newStatus === 'STATUS005' || newStatus === 'STATUS006') {
      const adminNotification = getAdminNotificationContent(newStatus, newData);
      console.log('\n📢 [ADMIN] 准备发送通知');
      console.log('   Title: ' + adminNotification.title);
      console.log('   Message: ' + adminNotification.message);
      
      await sendNotificationToAllAdmins(
        bookingId,
        adminNotification.title,
        adminNotification.message,
        newStatus,
        newData
      );
    }
    
    // 3️⃣ ⭐ 只在支付完成时通知技术员
    if (newStatus === 'STATUS005' && technicianCustomId) {
      console.log('\n💰 [TECHNICIAN] 准备发送支付完成通知');
      
      const techTitle = '💰 Payment Received - Ready to Start';
      const formattedDate = formatDate(newData.booking_date);
      const techMessage = `Customer has paid for ${newData.service_name || 'service'} booking ${newData.booking_ID || bookingId} on ${formattedDate}. You can now proceed with the service.`;
      
      console.log('   Tech Title: ' + techTitle);
      console.log('   Tech Message: ' + techMessage);
      
      await sendNotificationToTechnician(
        technicianCustomId,
        bookingId,
        techTitle,
        techMessage,
        'payment_received',
        newData
      );
    }
    
    return null;
  });

// ========================================
// 通知内容映射
// ========================================
function getNotificationContent(statusID, bookingData) {
  const serviceType = bookingData.service_name || 'service';
  
  const contentMap = {
    'STATUS001': {
      title: 'Booking Received',
      message: 'Your booking request has been received and is being processed'
    },
    'STATUS002': {
      title: 'Booking Confirmed',
      message: 'Great news! Your ' + serviceType + ' booking has been confirmed'
    },
    'STATUS003': {
      title: 'Quotation Ready',
      message: 'Your quotation for ' + serviceType + ' is ready for review'
    },
    'STATUS004': {
      title: 'Service Scheduled',
      message: 'Your ' + serviceType + ' service has been scheduled'
    },
    'STATUS005': {
      title: 'Service Started',
      message: 'Your technician has started working on your ' + serviceType + ' service'
    },
    'STATUS006': {
      title: 'Service Completed',
      message: 'Your service has been completed successfully. Please rate your experience!'
    },
    'STATUS007': {
      title: 'Booking Cancelled',
      message: 'Your booking has been cancelled. If you have any questions, please contact us.'
    },
    'STATUS008': {
      title: 'Payment Required',
      message: 'Please complete your payment for the ' + serviceType + ' service'
    },
  };
  
  return contentMap[statusID] || {
    title: 'Booking Update',
    message: 'Your booking status has been updated'
  };
}

function getAdminNotificationContent(statusID, bookingData) {
  const serviceType = bookingData.service_name || 'service';
  const userName = bookingData.user_name || 'Customer';
  const bookingID = bookingData.booking_ID || 'N/A';
  
  const contentMap = {
    'STATUS005': {
      title: '💰 Payment Received',
      message: `${userName} paid for ${serviceType} (${bookingID}). Service is now in progress.`
    },
    'STATUS006': {
      title: '✅ Service Completed',
      message: `${serviceType} booking (${bookingID}) has been completed.`
    },
  };
  
  return contentMap[statusID] || {
    title: '📋 Booking Update',
    message: `Booking ${bookingID} status changed`
  };
}

// ========================================
// 手动发送通知
// ========================================
exports.sendCustomNotification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  const userId = data.userId;
  const title = data.title;
  const message = data.message;
  const bookingId = data.bookingId;
  const type = data.type;
  
  if (!userId || !title || !message) {
    throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
  }
  
  try {
    const success = await sendNotificationToUser(userId, bookingId || null, title, message, type || 'custom', null);
    return { success: success };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// ========================================
// 欢迎通知
// ========================================
exports.sendWelcomeNotification = functions.auth.user().onCreate(async (user) => {
  try {
    await admin.firestore()
      .collection('notifications')
      .add({
        userId: user.uid,
        title: 'Welcome to Home Service!',
        message: 'Thank you for joining us. Book your first service today!',
        type: 'welcome',
        isRead: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    
    console.log('✅ 欢迎通知已发送: ' + user.uid);
  } catch (error) {
    console.error('❌ 发送欢迎通知失败:', error);
  }
  
  return null;
});