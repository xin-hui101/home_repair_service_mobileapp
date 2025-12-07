import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:home_service_system/firebase_service/auth_service.dart';
import 'package:home_service_system/firebase_service/storage_service.dart';
import 'package:home_service_system/models/models.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  
  bool _isLoading = false;
  bool _isInitialLoading = true;
  UserModel? currentUser;
  
  // NEW: Image picker and storage service
  final ImagePicker _imagePicker = ImagePicker();
  final StorageService _storageService = StorageService();
  File? _selectedImage;
  bool _isUploadingImage = false;
  bool _shouldRemoveImage = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  // 从Firebase加载用户数据
  Future<void> _loadUserData() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userData = await authService.getUserData(role: 'user');
      
      if (mounted && userData != null) {
        setState(() {
          currentUser = userData;
          // 预填充表单字段
          _nameController.text = userData.name;
          _phoneController.text = userData.phoneNumber ?? '';
          _emailController.text = userData.email;
          _addressController.text = userData.address ?? '';
          _isInitialLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _isInitialLoading = false;
        });
        _showErrorMessage('Failed to load user data');
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
        });
        _showErrorMessage('Failed to load user data. Please try again.');
      }
    }
  }

  // NEW: Pick image from gallery or camera
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        File imageFile = File(pickedFile.path);
        
        // Validate file size (max 5MB)
        bool isValid = await _storageService.isFileSizeValid(imageFile, maxSizeInMB: 5);
        
        if (!isValid) {
          _showErrorMessage('Image size must be less than 5MB');
          return;
        }

        setState(() {
          _selectedImage = imageFile;
          _shouldRemoveImage = false;
        });
      }
    } catch (e) {
      print('Error picking image: $e');
      _showErrorMessage('Failed to pick image. Please try again.');
    }
  }

  // NEW: Show image source selection dialog
  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Choose Profile Picture',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue[900],
              ),
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.camera_alt, color: Colors.yellow[700]),
              title: Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_library, color: Colors.yellow[700]),
              title: Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (currentUser?.profilePictureUrl != null || _selectedImage != null)
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red[600]),
                title: Text('Remove Photo'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedImage = null;
                    _shouldRemoveImage = true;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  // 显示错误消息
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // 显示成功消息
  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // 获取用户头像缩写
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

  // 验证手机号码
  String? _validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your phone number';
    }
    if (!RegExp(r'^\+?[\d\s\-\(\)]+$').hasMatch(value)) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  // 验证邮箱
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  // 检查是否有数据更改
  bool _hasChanges() {
    if (currentUser == null) return false;
    
    return _nameController.text.trim() != currentUser!.name ||
           _phoneController.text.trim() != (currentUser!.phoneNumber ?? '') ||
           _emailController.text.trim() != currentUser!.email ||
           _addressController.text.trim() != (currentUser!.address ?? '') ||
           _selectedImage != null ||
           _shouldRemoveImage;
  }

  // UPDATED: 保存个人资料到Firebase with image upload
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // 检查是否有更改
    if (!_hasChanges()) {
      _showSuccessMessage('No changes to save');
      Navigator.pop(context, false);
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      String? profilePictureUrl = currentUser?.profilePictureUrl;

      // NEW: Upload profile picture if selected
      if (_selectedImage != null) {
        setState(() {
          _isUploadingImage = true;
        });

        // Delete old profile picture if exists
        if (currentUser?.profilePictureUrl != null && 
            currentUser!.profilePictureUrl!.isNotEmpty) {
          await _storageService.deleteImage(currentUser!.profilePictureUrl!);
        }

        // Upload new profile picture
        String path = 'profile_pictures/${currentUser!.id}/profile.jpg';
        String? uploadedUrl = await _storageService.uploadImage(_selectedImage!, path);
        
        if (uploadedUrl != null) {
          profilePictureUrl = uploadedUrl;
          print('Profile picture uploaded: $uploadedUrl');
        } else {
          throw Exception('Failed to upload profile picture');
        }

        setState(() {
          _isUploadingImage = false;
        });
      }
      // NEW: Handle profile picture deletion
      else if (_shouldRemoveImage && 
               currentUser?.profilePictureUrl != null &&
               currentUser!.profilePictureUrl!.isNotEmpty) {
        // User wants to remove profile picture
        await _storageService.deleteImage(currentUser!.profilePictureUrl!);
        profilePictureUrl = null;
      }
      
      // 准备更新数据
      Map<String, dynamic> updateData = {
        'user_name': _nameController.text.trim(),
        'user_phone_number': _phoneController.text.trim(),
        'user_email': _emailController.text.trim(),
        'user_address': _addressController.text.trim(),
        'profile_picture_url': profilePictureUrl, // NEW
      };

      // 更新用户数据
      bool success = await authService.updateUserData(
        userId: currentUser!.id,
        data: updateData,
        role: 'user',
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        if (success) {
          _showSuccessMessage('Profile updated successfully!');
          // 返回上一页，传递true表示数据已更新
          Navigator.pop(context, true);
        } else {
          _showErrorMessage('Failed to update profile. Please try again.');
        }
      }
    } catch (e) {
      print('Error saving profile: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isUploadingImage = false;
        });
        _showErrorMessage('An error occurred. Please try again.');
      }
    }
  }

  // 显示未保存更改的确认对话框
  Future<bool> _showUnsavedChangesDialog() async {
    if (!_hasChanges()) {
      return true;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange[600]),
            SizedBox(width: 8),
            Text('Unsaved Changes'),
          ],
        ),
        content: Text('You have unsaved changes. Are you sure you want to leave?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[600],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Leave',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  // NEW: Build profile picture widget with upload button
  Widget _buildProfilePictureSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 32),
      child: Stack(
        children: [
          // Profile Picture
          _selectedImage != null
              ? CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: FileImage(_selectedImage!),
                )
              : (_shouldRemoveImage 
                  ? CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.yellow[600],
                      child: Text(
                        _getUserInitials(),
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : (currentUser?.profilePictureUrl != null && 
                     currentUser!.profilePictureUrl!.isNotEmpty)
                      ? CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.grey[300],
                          child: ClipOval(
                            child: Image.network(
                              currentUser!.profilePictureUrl!,
                              width: 120,
                              height: 120,
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
                                return CircleAvatar(
                                  radius: 60,
                                  backgroundColor: Colors.yellow[600],
                                  child: Text(
                                    _getUserInitials(),
                                    style: TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        )
                      : CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.yellow[600],
                          child: Text(
                            _getUserInitials(),
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        )
              ),
          
          // Edit button
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _isLoading ? null : _showImageSourceDialog,
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.yellow[600],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
          
          // Upload progress indicator
          if (_isUploadingImage)
            Positioned.fill(
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.black54,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _showUnsavedChangesDialog,
      child: Scaffold(
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
                // 自定义顶部栏
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      // 返回按钮
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.black87,
                          size: 24,
                        ),
                        onPressed: () async {
                          final shouldPop = await _showUnsavedChangesDialog();
                          if (shouldPop) {
                            Navigator.pop(context, false);
                          }
                        },
                      ),
                      // 标题
                      Expanded(
                        child: Text(
                          'Edit Profile',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                        ),
                      ),
                      // 占位符以保持标题居中
                      const SizedBox(width: 40),
                    ],
                  ),
                ),
                
                // 主要内容
                Expanded(
                  child: _isInitialLoading
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
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                // Profile Picture Section - UPDATED
                                _buildProfilePictureSection(),
                                
                                // 表单字段
                                _buildTextField(
                                  controller: _nameController,
                                  label: 'Full Name',
                                  icon: Icons.person,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter your name';
                                    }
                                    return null;
                                  },
                                ),
                                
                                const SizedBox(height: 16),
                                
                                _buildTextField(
                                  controller: _phoneController,
                                  label: 'Phone Number',
                                  icon: Icons.phone,
                                  keyboardType: TextInputType.phone,
                                  validator: _validatePhone,
                                ),
                                
                                const SizedBox(height: 16),
                                
                                _buildTextField(
                                  controller: _emailController,
                                  label: 'Email Address',
                                  icon: Icons.email,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: _validateEmail,
                                ),
                                
                                const SizedBox(height: 16),
                                
                                _buildTextField(
                                  controller: _addressController,
                                  label: 'Address',
                                  icon: Icons.location_on,
                                  maxLines: 2,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Please enter your address';
                                    }
                                    return null;
                                  },
                                ),
                                
                                const SizedBox(height: 32),
                                
                                // 保存按钮
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _saveProfile,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.yellow[600],
                                      foregroundColor: Colors.blue[900],
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      elevation: 2,
                                    ),
                                    child: _isLoading
                                        ? Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              SizedBox(
                                                height: 20,
                                                width: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                ),
                                              ),
                                              SizedBox(width: 12),
                                              Text(
                                                _isUploadingImage ? 'Uploading...' : 'Saving...',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          )
                                        : const Text(
                                            'Save Changes',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ),
                                
                                const SizedBox(height: 16),
                                
                                // 取消按钮
                                SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: OutlinedButton(
                                    onPressed: _isLoading ? null : () async {
                                      final shouldPop = await _showUnsavedChangesDialog();
                                      if (shouldPop) {
                                        Navigator.pop(context, false);
                                      }
                                    },
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.grey[700],
                                      side: BorderSide(color: Colors.grey[300]!),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      'Cancel',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
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
      ),
    );
  }

  // 构建文本输入字段
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.yellow[700]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.yellow[600]!, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        labelStyle: TextStyle(color: Colors.grey[700]),
      ),
    );
  }
}