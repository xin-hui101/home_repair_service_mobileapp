// lib/firebase_service/storage_service.dart
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';


class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// 上传单张图片到Firebase Storage
  /// [file] - 要上传的图片文件
  /// [path] - 存储路径（例如：'bookings/booking_id/image_1.jpg'）
  /// 返回下载URL字符串，失败时返回null
  Future<String?> uploadImage(File file, String path) async {
    try {
      print('Uploading image to path: $path');
      
      // 创建存储引用
      Reference ref = _storage.ref().child(path);
      
      // 上传文件
      UploadTask uploadTask = ref.putFile(file);
      
      // 监听上传进度（可选）
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
        print('Upload progress: ${progress.toStringAsFixed(2)}%');
      });
      
      // 等待上传完成
      TaskSnapshot snapshot = await uploadTask;
      
      // 获取下载URL
      String downloadUrl = await snapshot.ref.getDownloadURL();
      print('Upload successful. Download URL: $downloadUrl');
      
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  /// 批量上传多张图片
  /// [files] - 图片文件列表
  /// [bookingId] - 预订ID，用于创建文件夹
  /// 返回下载URL列表
  Future<List<String>> uploadMultipleImages(List<File> files, String bookingId) async {
    List<String> downloadUrls = [];
    
    for (int i = 0; i < files.length; i++) {
      File file = files[i];
      
      // 生成文件名：booking_id/image_timestamp_index.jpg
      String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      String fileName = 'image_${timestamp}_$i.jpg';
      String path = 'bookings/$bookingId/$fileName';
      
      String? downloadUrl = await uploadImage(file, path);
      if (downloadUrl != null) {
        downloadUrls.add(downloadUrl);
      }
    }
    
    return downloadUrls;
  }

  /// 删除Firebase Storage中的图片
  /// [downloadUrl] - 图片的下载URL
  Future<bool> deleteImage(String downloadUrl) async {
    try {
      Reference ref = _storage.refFromURL(downloadUrl);
      await ref.delete();
      print('Image deleted successfully');
      return true;
    } catch (e) {
      print('Error deleting image: $e');
      return false;
    }
  }

  /// 删除整个预订文件夹及其所有图片
  /// [bookingId] - 预订ID
  Future<bool> deleteBookingImages(String bookingId) async {
    try {
      Reference folderRef = _storage.ref().child('bookings/$bookingId');
      ListResult result = await folderRef.listAll();
      
      // 删除文件夹中的所有文件
      for (Reference fileRef in result.items) {
        await fileRef.delete();
      }
      
      print('All images in booking $bookingId deleted successfully');
      return true;
    } catch (e) {
      print('Error deleting booking images: $e');
      return false;
    }
  }

  /// 获取图片文件大小（字节）
  Future<int?> getImageSize(File file) async {
    try {
      return await file.length();
    } catch (e) {
      print('Error getting file size: $e');
      return null;
    }
  }

  /// 检查文件大小是否在允许范围内（默认最大5MB）
  Future<bool> isFileSizeValid(File file, {int maxSizeInMB = 5}) async {
    int? fileSize = await getImageSize(file);
    if (fileSize == null) return false;
    
    int maxSizeInBytes = maxSizeInMB * 1024 * 1024;
    return fileSize <= maxSizeInBytes;
  }

  /// 验证所有图片文件大小
  Future<List<File>> validateImageSizes(List<File> files, {int maxSizeInMB = 5}) async {
    List<File> validFiles = [];
    
    for (File file in files) {
      bool isValid = await isFileSizeValid(file, maxSizeInMB: maxSizeInMB);
      if (isValid) {
        validFiles.add(file);
      } else {
        print('File too large: ${file.path}');
      }
    }
    
    return validFiles;
  }
}