// lib/models/models.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SubService {
  final String subservicesID;
  final String subserviceName;
  final String subserviceDescription;
  final double subserviceApproxAmount;
  final String serviceTypesID;
  final IconData icon;

  SubService({
    required this.subservicesID,
    required this.subserviceName,
    required this.subserviceDescription,
    required this.subserviceApproxAmount,
    required this.serviceTypesID,
    required this.icon,
  });

  Map<String, dynamic> toMap() {
    return {
      'subservices_ID': subservicesID,
      'subservice_name': subserviceName,
      'subservice_description': subserviceDescription,
      'subservice_approx_amount': subserviceApproxAmount,
      'service_types_ID': serviceTypesID,
      'icon_code': icon.codePoint,
    };
  }

  factory SubService.fromMap(Map<String, dynamic> map) {
    return SubService(
      subservicesID: map['subservices_ID'] ?? '',
      subserviceName: map['subservice_name'] ?? '',
      subserviceDescription: map['subservice_description'] ?? '',
      subserviceApproxAmount: map['subservice_approx_amount']?.toDouble() ?? 0.0,
      serviceTypesID: map['service_types_ID'] ?? '',
      icon: IconData(map['icon_code'] ?? Icons.build.codePoint, fontFamily: 'MaterialIcons'),
    );
  }
}

class ServiceType {
  final String serviceTypesID;
  final String serviceTypesName;

  ServiceType({
    required this.serviceTypesID,
    required this.serviceTypesName,
  });

  Map<String, dynamic> toMap() {
    return {
      'service_types_ID': serviceTypesID,
      'service_types_name': serviceTypesName,
    };
  }

  factory ServiceType.fromMap(Map<String, dynamic> map) {
    return ServiceType(
      serviceTypesID: map['service_types_ID'] ?? '',
      serviceTypesName: map['service_types_name'] ?? '',
    );
  }
}

class TechnicianModel {
  final String technicianID;
  final String technicianName;
  final String technicianEmail;
  final String technicianPhoneNumber;
  final String status;
  final DateTime? createdAt;
  final List<String> specializations;
  final int? activeJobs;

  TechnicianModel({
    required this.technicianID,
    required this.technicianName,
    required this.technicianEmail,
    required this.technicianPhoneNumber,
    this.status = 'active',
    this.createdAt,
    this.specializations = const [],
    this.activeJobs = 0,
  });

  factory TechnicianModel.fromMap(Map<String, dynamic> map) {
    return TechnicianModel(
      technicianID: map['technician_ID'] ?? '',
      technicianName: map['technician_name'] ?? '',
      technicianEmail: map['technician_email'] ?? '',
      technicianPhoneNumber: map['technician_phone_number'] ?? '',
      status: map['status'] ?? 'active',
      createdAt: map['created_at']?.toDate(),
      specializations: List<String>.from(map['specializations'] ?? []),
      activeJobs: map['active_jobs'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'technician_ID': technicianID,
      'technician_name': technicianName,
      'technician_email': technicianEmail,
      'technician_phone_number': technicianPhoneNumber,
      'status': status,
      'created_at': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'specializations': specializations,
      'active_jobs': activeJobs ?? 0,
    };
  }

  TechnicianModel copyWith({
    String? technicianID,
    String? technicianName,
    String? technicianEmail,
    String? technicianPhoneNumber,
    String? status,
    DateTime? createdAt,
    List<String>? specializations,
    int? activeJobs,
  }) {
    return TechnicianModel(
      technicianID: technicianID ?? this.technicianID,
      technicianName: technicianName ?? this.technicianName,
      technicianEmail: technicianEmail ?? this.technicianEmail,
      technicianPhoneNumber: technicianPhoneNumber ?? this.technicianPhoneNumber,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      specializations: specializations ?? this.specializations,
      activeJobs: activeJobs ?? this.activeJobs,
    );
  }
}

class BookingData {
  final String? bookingID;
  final String bookingAddress;
  final DateTime bookingDate;
  final TimeOfDay bookingTime;
  final String bookingDescription;
  final double bookingQuotation;
  final String subserviceID;
  final String statusID;
  final String userID;
  final String? technicianID;
  final List<String> imageUrls;
  
  // Added quotation fields
  final String? quotationFileName;
  final String? quotationFileUrl;
  final DateTime? quotationUploadedAt;
  
  // NEW: Added rating status field
  final bool hasRated; // 追踪用户是否已评分
  
  final String userName;
  final String userEmail;
  final String userPhone;
  final String serviceName;
  final SubService subService;

  BookingData({
    this.bookingID,
    required this.bookingAddress,
    required this.bookingDate,
    required this.bookingTime,
    required this.bookingDescription,
    required this.bookingQuotation,
    required this.subserviceID,
    required this.statusID,
    required this.userID,
    this.technicianID,
    this.imageUrls = const [],
    this.quotationFileName,
    this.quotationFileUrl,
    this.quotationUploadedAt,
    this.hasRated = false, // 默认为 false
    required this.userName,
    required this.userEmail,
    required this.userPhone,
    required this.serviceName,
    required this.subService,
  });

  Map<String, dynamic> toMap() {
    return {
      'booking_ID': bookingID,
      'booking_address': bookingAddress,
      'booking_date': Timestamp.fromDate(bookingDate),
      'booking_time': '${bookingTime.hour.toString().padLeft(2, '0')}:${bookingTime.minute.toString().padLeft(2, '0')}',
      'booking_description': bookingDescription,
      'booking_quotation': bookingQuotation,
      'subservice_ID': subserviceID,
      'status_ID': statusID,
      'user_ID': userID,
      'technician_ID': technicianID,
      'image_urls': imageUrls,
      'quotation_file_name': quotationFileName,
      'quotation_file_url': quotationFileUrl,
      'quotation_uploaded_at': quotationUploadedAt != null ? Timestamp.fromDate(quotationUploadedAt!) : null,
      'has_rated': hasRated, // 添加到 Firebase 映射
      'user_name': userName,
      'user_email': userEmail,
      'user_phone': userPhone,
      'service_name': serviceName,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }

  factory BookingData.fromMap(Map<String, dynamic> map, {SubService? subService}) {
    TimeOfDay parseTime = TimeOfDay(hour: 9, minute: 0);
    if (map['booking_time'] != null) {
      final timeParts = map['booking_time'].split(':');
      if (timeParts.length == 2) {
        parseTime = TimeOfDay(
          hour: int.tryParse(timeParts[0]) ?? 9,
          minute: int.tryParse(timeParts[1]) ?? 0,
        );
      }
    }

    List<String> imageUrls = [];
    if (map['image_urls'] != null) {
      if (map['image_urls'] is List) {
        imageUrls = List<String>.from(map['image_urls']);
      }
    }

    return BookingData(
      bookingID: map['booking_ID'],
      bookingAddress: map['booking_address'] ?? '',
      bookingDate: (map['booking_date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      bookingTime: parseTime,
      bookingDescription: map['booking_description'] ?? '',
      bookingQuotation: map['booking_quotation']?.toDouble() ?? 0.0,
      subserviceID: map['subservice_ID'] ?? '',
      statusID: map['status_ID'] ?? '',
      userID: map['user_ID'] ?? '',
      technicianID: map['technician_ID'],
      imageUrls: imageUrls,
      quotationFileName: map['quotation_file_name'],
      quotationFileUrl: map['quotation_file_url'],
      quotationUploadedAt: (map['quotation_uploaded_at'] as Timestamp?)?.toDate(),
      hasRated: map['has_rated'] ?? false, // 从 Firebase 读取评分状态，默认为 false
      userName: map['user_name'] ?? '',
      userEmail: map['user_email'] ?? '',
      userPhone: map['user_phone'] ?? '',
      serviceName: map['service_name'] ?? '',
      subService: subService ?? SubService(
        subservicesID: '',
        subserviceName: 'Unknown Service',
        subserviceDescription: '',
        subserviceApproxAmount: 0.0,
        serviceTypesID: '',
        icon: Icons.build,
      ),
    );
  }

  BookingData copyWith({
    String? bookingID,
    String? bookingAddress,
    DateTime? bookingDate,
    TimeOfDay? bookingTime,
    String? bookingDescription,
    double? bookingQuotation,
    String? subserviceID,
    String? statusID,
    String? userID,
    String? technicianID,
    List<String>? imageUrls,
    String? quotationFileName,
    String? quotationFileUrl,
    DateTime? quotationUploadedAt,
    bool? hasRated, // 添加到 copyWith 方法
    String? userName,
    String? userEmail,
    String? userPhone,
    String? serviceName,
    SubService? subService,
  }) {
    return BookingData(
      bookingID: bookingID ?? this.bookingID,
      bookingAddress: bookingAddress ?? this.bookingAddress,
      bookingDate: bookingDate ?? this.bookingDate,
      bookingTime: bookingTime ?? this.bookingTime,
      bookingDescription: bookingDescription ?? this.bookingDescription,
      bookingQuotation: bookingQuotation ?? this.bookingQuotation,
      subserviceID: subserviceID ?? this.subserviceID,
      statusID: statusID ?? this.statusID,
      userID: userID ?? this.userID,
      technicianID: technicianID ?? this.technicianID,
      imageUrls: imageUrls ?? this.imageUrls,
      quotationFileName: quotationFileName ?? this.quotationFileName,
      quotationFileUrl: quotationFileUrl ?? this.quotationFileUrl,
      quotationUploadedAt: quotationUploadedAt ?? this.quotationUploadedAt,
      hasRated: hasRated ?? this.hasRated, // 包含在 copyWith 中
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      userPhone: userPhone ?? this.userPhone,
      serviceName: serviceName ?? this.serviceName,
      subService: subService ?? this.subService,
    );
  }
}

enum BookingStatus {
  pending,
  accepted,
  quotationSent,
  scheduled,
  inProgress,
  completed,
  cancelled,
}

extension BookingStatusExtension on BookingStatus {
  String get displayName {
    switch (this) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.accepted:
        return 'Accepted';
      case BookingStatus.quotationSent:
        return 'Quotation Sent';
      case BookingStatus.scheduled:
        return 'Scheduled';
      case BookingStatus.inProgress:
        return 'In Progress';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get statusID {
    switch (this) {
      case BookingStatus.pending:
        return 'STATUS001';
      case BookingStatus.accepted:
        return 'STATUS002';
      case BookingStatus.quotationSent:
        return 'STATUS003';
      case BookingStatus.scheduled:
        return 'STATUS004';
      case BookingStatus.inProgress:
        return 'STATUS005';
      case BookingStatus.completed:
        return 'STATUS006';
      case BookingStatus.cancelled:
        return 'STATUS007';
    }
  }

  Color get color {
    switch (this) {
      case BookingStatus.pending:
        return Colors.blue;
      case BookingStatus.accepted:
        return Colors.purple;
      case BookingStatus.quotationSent:
        return Colors.indigo;
      case BookingStatus.scheduled:
        return Colors.cyan;
      case BookingStatus.inProgress:
        return Colors.amber;
      case BookingStatus.completed:
        return Colors.green;
      case BookingStatus.cancelled:
        return Colors.red;
    }
  }

  static BookingStatus? fromStatusID(String statusID) {
    switch (statusID) {
      case 'STATUS001':
        return BookingStatus.pending;
      case 'STATUS002':
        return BookingStatus.accepted;
      case 'STATUS003':
        return BookingStatus.quotationSent;
      case 'STATUS004':
        return BookingStatus.scheduled;
      case 'STATUS005':
        return BookingStatus.inProgress;
      case 'STATUS006':
        return BookingStatus.completed;
      case 'STATUS007':
        return BookingStatus.cancelled;
      default:
        return null;
    }
  }

  static String getDisplayNameFromStatusID(String statusID) {
    final status = fromStatusID(statusID);
    return status?.displayName ?? 'Unknown';
  }

  static Color getColorFromStatusID(String statusID) {
    final status = fromStatusID(statusID);
    return status?.color ?? Colors.grey;
  }
}

class UserModel {
  final String id;
  final String name;
  final String email;
  final String? phoneNumber;
  final String? address;
  final String? role;
  final String? status;
  final DateTime? registrationDate;
  final DateTime? lastLogin;
  final DateTime? deactivatedAt;
  final String? profilePictureUrl; // NEW: Added profile picture URL

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phoneNumber,
    this.address,
    this.role,
    this.status,
    this.registrationDate,
    this.lastLogin,
    this.deactivatedAt,
    this.profilePictureUrl, // NEW
  });

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['user_ID'] ?? map['firebase_uid'] ?? '',
      name: map['user_name'] ?? map['name'] ?? '',
      email: map['user_email'] ?? map['email'] ?? '',
      phoneNumber: map['user_phone_number'],
      address: map['user_address'],
      role: map['role'],
      status: map['status'] ?? 'active',
      registrationDate: map['user_registration_date']?.toDate(),
      lastLogin: map['last_login']?.toDate(),
      deactivatedAt: map['deactivated_at']?.toDate(),
      profilePictureUrl: map['profile_picture_url'], // NEW
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_ID': id,
      'firebase_uid': id,
      'user_name': name,
      'user_email': email,
      'user_phone_number': phoneNumber,
      'user_address': address,
      'role': role,
      'status': status ?? 'active',
      'user_registration_date': registrationDate,
      'last_login': lastLogin,
      'deactivated_at': deactivatedAt,
      'profile_picture_url': profilePictureUrl, // NEW
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phoneNumber,
    String? address,
    String? role,
    String? status,
    DateTime? registrationDate,
    DateTime? lastLogin,
    DateTime? deactivatedAt,
    String? profilePictureUrl, // NEW
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      address: address ?? this.address,
      role: role ?? this.role,
      status: status ?? this.status,
      registrationDate: registrationDate ?? this.registrationDate,
      lastLogin: lastLogin ?? this.lastLogin,
      deactivatedAt: deactivatedAt ?? this.deactivatedAt,
      profilePictureUrl: profilePictureUrl ?? this.profilePictureUrl, // NEW
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, name: $name, email: $email, phoneNumber: $phoneNumber, address: $address, role: $role, status: $status, profilePictureUrl: $profilePictureUrl)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel &&
        other.id == id &&
        other.name == name &&
        other.email == email &&
        other.phoneNumber == phoneNumber &&
        other.address == address &&
        other.role == role &&
        other.status == status &&
        other.registrationDate == registrationDate &&
        other.lastLogin == lastLogin &&
        other.deactivatedAt == deactivatedAt &&
        other.profilePictureUrl == profilePictureUrl; // NEW
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        email.hashCode ^
        phoneNumber.hashCode ^
        address.hashCode ^
        role.hashCode ^
        status.hashCode ^
        registrationDate.hashCode ^
        lastLogin.hashCode ^
        deactivatedAt.hashCode ^
        profilePictureUrl.hashCode; // NEW
  }
}

class BookingStatusConstants {
  static const Map<String, String> statusIdToDisplayName = {
    'STATUS001': 'Pending',
    'STATUS002': 'Accepted',
    'STATUS003': 'Quotation Sent',
    'STATUS004': 'Scheduled',
    'STATUS005': 'In Progress',
    'STATUS006': 'Completed',
    'STATUS007': 'Cancelled',
  };

  static const Map<String, String> displayNameToStatusId = {
    'Pending': 'STATUS001',
    'Accepted': 'STATUS002',
    'Quotation Sent': 'STATUS003',
    'Scheduled': 'STATUS004',
    'In Progress': 'STATUS005',
    'Completed': 'STATUS006',
    'Cancelled': 'STATUS007',
  };

  static const Map<String, Color> statusColors = {
    'STATUS001': Colors.blue,
    'STATUS002': Colors.purple,
    'STATUS003': Colors.indigo,
    'STATUS004': Colors.cyan,
    'STATUS005': Colors.amber,
    'STATUS006': Colors.green,
    'STATUS007': Colors.red,
  };

  static String getDisplayName(String statusID) {
    return statusIdToDisplayName[statusID] ?? 'Unknown';
  }

  static String getStatusID(String displayName) {
    return displayNameToStatusId[displayName] ?? 'STATUS001';
  }

  static Color getStatusColor(String statusID) {
    return statusColors[statusID] ?? Colors.grey;
  }

  static Color getDisplayStatusColor(String displayName) {
    String statusID = getStatusID(displayName);
    return getStatusColor(statusID);
  }

  static List<String> getAllDisplayStatuses() {
    return displayNameToStatusId.keys.toList();
  }

  static List<String> getAllStatusIDs() {
    return statusIdToDisplayName.keys.toList();
  }
}