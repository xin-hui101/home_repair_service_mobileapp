import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'package:home_service_system/models/models.dart';
import 'package:home_service_system/screens/user_confirmpage.dart';
import 'package:home_service_system/firebase_service/booking_service.dart';
import 'package:home_service_system/firebase_service/auth_service.dart';

class FillDetailPage extends StatefulWidget {
  final String selectedService;
  final SubService selectedSubService;
  
  const FillDetailPage({
    super.key, 
    required this.selectedService, 
    required this.selectedSubService
  });

  @override
  _FillDetailPageState createState() => _FillDetailPageState();
}

class _FillDetailPageState extends State<FillDetailPage> {
  // Current step
  final int _currentStep = 1; // 0: Select services, 1: Fill Details, 2: Confirm booking
  
  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  
  // Date and time selection
  late DateTime _selectedDate;
  TimeOfDay _selectedTime = TimeOfDay(hour: 10, minute: 0);
  
  // Use registered info checkbox
  bool _useRegisteredInfo = false;
  UserModel? _currentUser;
  
  // Image picker
  final ImagePicker _picker = ImagePicker();
  List<File> _selectedImages = [];
  
  // Loading state for upload
  bool _isUploading = false;
  
  // Available time slots
  final List<TimeOfDay> _availableTimeSlots = [
    TimeOfDay(hour: 9, minute: 0),
    TimeOfDay(hour: 10, minute: 0),
    TimeOfDay(hour: 11, minute: 0),
    TimeOfDay(hour: 13, minute: 0),
    TimeOfDay(hour: 14, minute: 0),
    TimeOfDay(hour: 15, minute: 0),
    TimeOfDay(hour: 16, minute: 0),
  ];
  
  // NEW: Track booked time slots for selected date
  List<TimeOfDay> _bookedTimeSlots = [];
  bool _isLoadingTimeSlots = false;
  
  // Form key for validation
  final _formKey = GlobalKey<FormState>();
  
  @override
  void initState() {
    super.initState();
    // Initialize selected date with tomorrow's date
    _selectedDate = DateTime.now().add(Duration(days: 1));
    
    // If selected date is a Sunday, move to Monday
    if (_selectedDate.weekday == DateTime.sunday) {
      _selectedDate = _selectedDate.add(Duration(days: 1));
    }

    // Load user data and pre-fill form data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserData();
      _prefillFormData();
      _loadBookedTimeSlots(); // NEW: Load booked time slots
    });
  }

  Future<void> _loadUserData() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userData = await authService.getUserData(role: 'user');
      
      if (mounted) {
        setState(() {
          _currentUser = userData;
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  void _prefillFormData() {
    final bookingService = Provider.of<BookingService>(context, listen: false);
    final currentBooking = bookingService.currentBooking;
    
    if (currentBooking != null) {
      setState(() {
        // Only prefill non-personal information
        if (currentBooking.bookingDescription.isNotEmpty) {
          _notesController.text = currentBooking.bookingDescription;
        }
        _selectedDate = currentBooking.bookingDate;
        _selectedTime = currentBooking.bookingTime;
        
        // Leave personal information fields empty by default
        // User needs to check the checkbox to fill them
      });
    }
  }

  // NEW: Load booked time slots for the selected date
  Future<void> _loadBookedTimeSlots() async {
    setState(() {
      _isLoadingTimeSlots = true;
    });
    
    try {
      final bookingService = Provider.of<BookingService>(context, listen: false);
      List<TimeOfDay> bookedSlots = await bookingService.getBookedTimeSlotsForDate(_selectedDate);
      
      if (mounted) {
        setState(() {
          _bookedTimeSlots = bookedSlots;
          _isLoadingTimeSlots = false;
          
          // If the currently selected time is booked, select the first available time
          if (_isTimeSlotBooked(_selectedTime)) {
            TimeOfDay? firstAvailable = _getFirstAvailableTimeSlot();
            if (firstAvailable != null) {
              _selectedTime = firstAvailable;
            }
          }
        });
      }
    } catch (e) {
      print('Error loading booked time slots: $e');
      if (mounted) {
        setState(() {
          _isLoadingTimeSlots = false;
        });
      }
    }
  }

  // NEW: Check if a time slot is booked
  bool _isTimeSlotBooked(TimeOfDay time) {
    return _bookedTimeSlots.any((bookedTime) => 
      bookedTime.hour == time.hour && bookedTime.minute == time.minute
    );
  }

  // NEW: Get first available time slot
  TimeOfDay? _getFirstAvailableTimeSlot() {
    for (TimeOfDay slot in _availableTimeSlots) {
      if (!_isTimeSlotBooked(slot)) {
        return slot;
      }
    }
    return null;
  }

  // Helper method to check if user has saved address
  bool _hasUserSavedAddress() {
    return _currentUser != null && 
           _currentUser!.address != null && 
           _currentUser!.address!.isNotEmpty;
  }

  void _toggleUseRegisteredInfo(bool? value) {  
    setState(() {
      _useRegisteredInfo = value ?? false;  
      
      if (_useRegisteredInfo && _currentUser != null) {
        // Fill name and phone with registered info
        _nameController.text = _currentUser!.name;
        _phoneController.text = _currentUser!.phoneNumber ?? '';
        
        // Check if user has a saved address
        if (_hasUserSavedAddress()) {
          // User has saved address, use it
          _addressController.text = _currentUser!.address!;
        } else {
          // User doesn't have saved address, keep field empty for manual entry
          _addressController.clear();
        }
      } else {
        // Clear all fields for manual entry
        _nameController.clear();
        _phoneController.clear();
        _addressController.clear();
      }
    });
  }

  // Permission check method
  Future<bool> _requestPermissions() async {
    // Check Android version and request appropriate permissions
    if (Platform.isAndroid) {
      // Android 13+ requires different permissions
      Map<Permission, PermissionStatus> statuses = await [
        Permission.camera,
        Permission.photos, // Replace storage for Android 13+
      ].request();

      bool cameraGranted = statuses[Permission.camera]?.isGranted == true;
      bool storageGranted = statuses[Permission.photos]?.isGranted == true;
      
      if (!storageGranted) {
        // If new permission is denied, try legacy storage permission
        var legacyStatus = await Permission.storage.request();
        storageGranted = legacyStatus.isGranted;
      }
      
      return cameraGranted && storageGranted;
    } else {
      // iOS permission handling
      Map<Permission, PermissionStatus> statuses = await [
        Permission.camera,
        Permission.photos,
      ].request();

      return statuses[Permission.camera]?.isGranted == true &&
             statuses[Permission.photos]?.isGranted == true;
    }
  }

  // Check file size
  Future<int?> _getFileSize(File file) async {
    try {
      return await file.length();
    } catch (e) {
      print('Error getting file size: $e');
      return null;
    }
  }

  Future<void> _pickImages() async {
    try {
      print('Checking permissions...');
      
      // Check permissions
      bool hasPermission = await _requestPermissions();
      if (!hasPermission) {
        _showErrorDialog('Camera and storage permissions are required to select photos. Please allow permissions in settings and try again.');
        return;
      }

      print('Attempting to pick images from gallery...');
      
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      print('Selected ${images.length} images');
      
      if (images.isNotEmpty) {
        // Check file size and filter valid images
        List<File> validFiles = [];
        List<String> oversizedFiles = [];
        
        for (XFile image in images) {
          File file = File(image.path);
          int? fileSize = await _getFileSize(file);
          
          // Check file size (5MB limit)
          if (fileSize != null && fileSize <= 5 * 1024 * 1024) {
            validFiles.add(file);
          } else {
            String fileName = image.name;
            oversizedFiles.add(fileName);
          }
        }
        
        if (validFiles.isNotEmpty) {
          setState(() {
            _selectedImages.addAll(validFiles);
          });
          print('Added ${validFiles.length} valid images, current total: ${_selectedImages.length}');
        }
        
        if (oversizedFiles.isNotEmpty) {
          _showErrorDialog('The following image files are too large (over 5MB) and have been skipped:\n${oversizedFiles.join(', ')}\n\nPlease select smaller image files.');
        } else if (validFiles.isEmpty) {
          _showErrorDialog('All selected image files are too large (over 5MB). Please select smaller image files.');
        }
      } else {
        print('No images selected');
      }
    } catch (e, stackTrace) {
      print('Error picking images: $e');
      print('Error stack trace: $stackTrace');
      
      // More specific error handling
      String errorMessage = 'Failed to select images';
      if (e.toString().contains('channel-error')) {
        errorMessage = 'Image selection service is temporarily unavailable. Please restart the app and try again.';
      } else if (e.toString().contains('permission')) {
        errorMessage = 'Gallery access permission is required. Please allow permission in settings.';
      } else if (e.toString().contains('No implementation found')) {
        errorMessage = 'Image selection feature is temporarily unavailable. Please try again later.';
      }
      
      _showErrorDialog(errorMessage);
    }
  }

  Future<void> _pickImageFromCamera() async {
    try {
      print('Checking permissions...');
      
      // Check permissions
      bool hasPermission = await _requestPermissions();
      if (!hasPermission) {
        _showErrorDialog('Camera and storage permissions are required to take photos. Please allow permissions in settings and try again.');
        return;
      }

      print('Attempting to take photo with camera...');
      
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (image != null) {
        File file = File(image.path);
        
        // Check file size
        int? fileSize = await _getFileSize(file);
        if (fileSize != null && fileSize <= 5 * 1024 * 1024) {
          print('Photo taken successfully: ${image.path}');
          setState(() {
            _selectedImages.add(file);
          });
          print('Photo added successfully, current total: ${_selectedImages.length}');
        } else {
          _showErrorDialog('The captured photo is too large (over 5MB). Please try taking another photo or select a different image.');
        }
      } else {
        print('User cancelled camera');
      }
    } catch (e, stackTrace) {
      print('Error taking photo: $e');
      print('Error stack trace: $stackTrace');
      
      // More specific error handling
      String errorMessage = 'Failed to take photo';
      if (e.toString().contains('channel-error')) {
        errorMessage = 'Camera service is temporarily unavailable. Please restart the app and try again.';
      } else if (e.toString().contains('permission')) {
        errorMessage = 'Camera access permission is required. Please allow permission in settings.';
      } else if (e.toString().contains('No implementation found')) {
        errorMessage = 'Camera feature is temporarily unavailable. Please try again later.';
      }
      
      _showErrorDialog(errorMessage);
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  // Handle booking submission method with detailed debugging
  Future<void> _handleBookingSubmission(BookingService bookingService) async {
    print('=== DEBUG: Preparing booking data for confirmation ===');
    
    // NEW: Check if selected time slot is available before proceeding
    bool isAvailable = await bookingService.isTimeSlotAvailable(_selectedDate, _selectedTime);
    
    if (!isAvailable) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Time Slot Unavailable'),
                ],
              ),
              content: Text(
                'This time slot has just been booked by another user. Please select a different time.',
                style: TextStyle(fontSize: 16),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Reload booked time slots
                    _loadBookedTimeSlots();
                  },
                  child: Text('OK', style: TextStyle(fontSize: 16)),
                ),
              ],
            );
          },
        );
      }
      return;
    }
    
    setState(() {
      _isUploading = true;
    });

    try {
      // Ensure we have user data
      if (_currentUser == null) {
        throw Exception('User data is null. Please log in again.');
      }
      
      // Create/update booking data with form information and images
      BookingData bookingData;
      
      if (bookingService.currentBooking == null) {
        print('Creating new booking data...');
        bookingData = BookingData(
          userID: _currentUser!.id,
          userName: _nameController.text.isNotEmpty ? _nameController.text : _currentUser!.name,
          userEmail: _currentUser!.email,
          userPhone: _phoneController.text.isNotEmpty ? _phoneController.text : (_currentUser!.phoneNumber ?? ''),
          serviceName: widget.selectedService,
          subService: widget.selectedSubService,
          subserviceID: widget.selectedSubService.subservicesID,
          bookingAddress: _addressController.text,
          bookingDate: _selectedDate,
          bookingTime: _selectedTime,
          bookingDescription: _notesController.text,
          bookingQuotation: widget.selectedSubService.subserviceApproxAmount,
          statusID: BookingStatus.pending.statusID,
          imageUrls: [], // Will be set after images are uploaded in ConfirmPage
        );
      } else {
        print('Updating existing booking data...');
        bookingData = bookingService.currentBooking!.copyWith(
          bookingAddress: _addressController.text,
          bookingDate: _selectedDate,
          bookingTime: _selectedTime,
          bookingDescription: _notesController.text,
        );
      }

      // Store the selected images in BookingService for later upload
      bookingService.setSelectedImages(_selectedImages);
      
      // Set the booking data in BookingService (not create the actual booking yet)
      bookingService.setCurrentBooking(bookingData);
      
      print('Booking data prepared successfully');
      print('Selected images: ${_selectedImages.length}');
      
      // Navigate to confirmation page
      if (mounted) {
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => ConfirmPage(),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('=== ERROR in booking preparation ===');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      print('=== END ERROR ===');
      
      if (mounted) {
        _showErrorDialog('An error occurred while preparing your booking: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _showImagePickerBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(
                'Add Photos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _pickImageFromCamera();
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blue[900]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.camera_alt, size: 32, color: Colors.blue[900]),
                            SizedBox(height: 8),
                            Text(
                              'Camera',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue[900],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _pickImages();
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blue[900]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.photo_library, size: 32, color: Colors.blue[900]),
                            SizedBox(height: 8),
                            Text(
                              'Gallery',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue[900],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Notice'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
            if (message.contains('permission')) ...[
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  openAppSettings(); // Open app settings
                },
                child: Text('Go to Settings'),
              ),
            ],
          ],
        );
      },
    );
  }
  
  // Build progress indicator
  Widget _buildProgressIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Step 1
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue[900],
                border: Border.all(color: Colors.blue[900]!, width: 2),
              ),
              child: Center(
                child: Icon(
                  Icons.check,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(height: 6),
            SizedBox(
              width: 75,
              child: Text(
                'Select services',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.normal,
                  color: Colors.blue[900],
                ),
              ),
            ),
          ],
        ),
        
        // First connecting line
        Container(
          width: 45,
          height: 2,
          margin: EdgeInsets.symmetric(horizontal: 4),
          color: Colors.blue[900],
        ),
        
        // Step 2
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentStep == 1 ? Colors.yellow[600] : Colors.grey[300],
                border: Border.all(color: _currentStep == 1 ? Colors.blue[900]! : Colors.grey[300]!, width: 2),
              ),
              child: Center(
                child: Text(
                  '2',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            SizedBox(height: 6),
            SizedBox(
              width: 65,
              child: Text(
                'Fill Details',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: _currentStep == 1 ? FontWeight.bold : FontWeight.normal,
                  color: _currentStep == 1 ? Colors.blue[900] : Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
        
        // Second connecting line
        Container(
          width: 45,
          height: 2,
          margin: EdgeInsets.symmetric(horizontal: 4),
          color: _currentStep > 1 ? Colors.blue[900] : Colors.grey[300],
        ),
        
        // Step 3
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _currentStep == 2 ? Colors.yellow[600] : Colors.grey[300],
                border: Border.all(color: _currentStep == 2 ? Colors.blue[900]! : Colors.grey[300]!, width: 2),
              ),
              child: Center(
                child: Text(
                  '3',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            SizedBox(height: 6),
            SizedBox(
              width: 85,
              child: Text(
                'Confirm booking',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: _currentStep == 2 ? FontWeight.bold : FontWeight.normal,
                  color: _currentStep == 2 ? Colors.blue[900] : Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Build address field with smart handling
  Widget _buildAddressField() {
    // Address field should be enabled if:
    // 1. Not using registered info, OR
    // 2. Using registered info but user doesn't have saved address
    bool isAddressFieldEnabled = !_useRegisteredInfo || !_hasUserSavedAddress();
    
    return _buildTextField(
      controller: _addressController,
      labelText: 'Full Address',
      prefixIcon: Icons.location_on,
      maxLines: 3,
      enabled: isAddressFieldEnabled,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your address';
        }
        return null;
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Consumer<BookingService>(
      builder: (context, bookingService, child) {
        return Scaffold(
          backgroundColor: Colors.white,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios, size: 24),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.all(16),
                  ),
                  
                  // Progress bar
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width,
                      child: _buildProgressIndicator(),
                    ),
                  ),
                  
                  // Service title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Booking Details',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                  
                  // Service information
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Card(
                      elevation: 2,
                      color: Colors.white, 
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Selected Service',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.yellow[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    widget.selectedSubService.icon,
                                    size: 24,
                                    color: Colors.blue[900],
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.selectedService,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        widget.selectedSubService.subserviceName,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue[900],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Form
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(16),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Personal information section
                            _buildSectionTitle('Personal Information'),
                            
                            // Use registered info checkbox
                            if (_currentUser != null) ...[
                               Row(
                                  children: [
                                    Checkbox(
                                      value: _useRegisteredInfo,
                                      activeColor: Colors.blue[900],
                                      onChanged: _toggleUseRegisteredInfo,
                                    ),
                                    Expanded(
                                      child: Text(
                                        'Use my registered information',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.blue[900],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              SizedBox(height: 5),
                            ],
                            
                            _buildTextField(
                              controller: _nameController,
                              labelText: 'Full Name',
                              prefixIcon: Icons.person,
                              enabled: !_useRegisteredInfo,
                              validator: (value) {
                                if (!_useRegisteredInfo && (value == null || value.isEmpty)) {
                                  return 'Please enter your name';
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 16),
                            _buildTextField(
                              controller: _phoneController,
                              labelText: 'Phone Number',
                              prefixIcon: Icons.phone,
                              keyboardType: TextInputType.phone,
                              enabled: !_useRegisteredInfo,
                              validator: (value) {
                                if (!_useRegisteredInfo) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your phone number';
                                  }
                                  if (value.length < 10) {
                                    return 'Please enter a valid phone number';
                                  }
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 24),
                            
                            // Address field with smart handling
                            _buildAddressField(),
                            
                            // If using registered info but no saved address, show helpful text
                            if (_useRegisteredInfo && !_hasUserSavedAddress()) ...[
                              SizedBox(height: 8),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color.fromARGB(255, 249, 144, 144)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline, color: const Color.fromARGB(255, 210, 25, 25), size: 20),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'No saved address found. Enter your address manually.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.black,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            SizedBox(height: 24),
                            
                            // Date and time section
                            _buildSectionTitle('Preferred Date & Time'),
                            _buildDatePicker(context),
                            SizedBox(height: 16),
                            _buildTimeDropdown(),
                            
                            // NEW: Show loading indicator while fetching time slots
                            if (_isLoadingTimeSlots) ...[
                              SizedBox(height: 8),
                              Row(
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Checking availability...',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            
                            SizedBox(height: 24),
                            
                            // Additional information
                            _buildSectionTitle('Additional Information'),
                            _buildTextField(
                              controller: _notesController,
                              labelText: 'Write some additional information (Optional)',
                              maxLines: 3,
                            ),
                            SizedBox(height: 16),
                            
                            // Photo upload section
                            _buildPhotoUploadSection(),
                            SizedBox(height: 32),
                            
                            // Submit button with loading state
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: (_isUploading || _isLoadingTimeSlots) ? null : () async {
                                  if (_formKey.currentState!.validate()) {
                                    await _handleBookingSubmission(bookingService);
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: (_isUploading || _isLoadingTimeSlots) ? Colors.grey : Colors.yellow[600],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: _isUploading 
                                    ? Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[900]!),
                                            ),
                                          ),
                                          SizedBox(width: 10),
                                          Text(
                                            _selectedImages.isNotEmpty ? 'Uploading images...' : 'Submitting...',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue[900],
                                            ),
                                          ),
                                        ],
                                      )
                                    : Text(
                                        'Next',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue[900],
                                        ),
                                      ),
                              ),
                            ),
                            SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPhotoUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.camera_alt, color: Colors.blue[900], size: 20),
            SizedBox(width: 8),
            Text(
              'Upload Photos (Optional)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Text(
          'Maximum 10 photos, each under 5MB',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: 12),
        
        // Add photo button
        InkWell(
          onTap: _showImagePickerBottomSheet,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.blue[300]!,
                style: BorderStyle.solid,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
              color: Colors.blue[50],
            ),
            child: Column(
              children: [
                Icon(
                  Icons.add_a_photo,
                  size: 32,
                  color: Colors.blue[900],
                ),
                SizedBox(height: 8),
                Text(
                  'Tap to add photos',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.blue[900],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Display selected images
        if (_selectedImages.isNotEmpty) ...[
          SizedBox(height: 16),
          Text(
            'Selected Photos (${_selectedImages.length})',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          Container(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedImages.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: EdgeInsets.only(right: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _selectedImages[index],
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeImage(index),
                          child: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue[900],
        ),
      ),
    );
  }
  
  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    IconData? prefixIcon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: TextStyle(color: enabled ? Colors.grey[600] : Colors.grey[400]),
        prefixIcon: prefixIcon != null 
            ? Icon(prefixIcon, color: enabled ? Colors.blue[900] : Colors.grey[400])
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[200]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.blue[900]!),
        ),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey[50],
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: maxLines > 1 ? 16 : 0),
      ),
      validator: validator,
    );
  }
  
  Widget _buildDatePicker(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final DateTime? picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime.now(),
          lastDate: DateTime.now().add(Duration(days: 30)),
          selectableDayPredicate: (DateTime date) {
            return date.weekday != DateTime.sunday;
          },
          builder: (BuildContext context, Widget? child) {
            return Theme(
              data: ThemeData.light().copyWith(
                primaryColor: Colors.blue[900],
                colorScheme: ColorScheme.light(primary: Colors.blue[900]!),
                buttonTheme: ButtonThemeData(textTheme: ButtonTextTheme.primary),
              ),
              child: child!,
            );
          },
        );
        
        if (picked != null && picked != _selectedDate) {
          setState(() {
            _selectedDate = picked;
          });
          // NEW: Reload booked time slots when date changes
          await _loadBookedTimeSlots();
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: Colors.blue[900]),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Date: ${DateFormat('EEE, MMM d, yyyy').format(_selectedDate)}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTimeDropdown() {
    // NEW: Build dropdown items with disabled state for booked slots
    List<DropdownMenuItem<TimeOfDay>> timeItems = _availableTimeSlots.map((timeSlot) {
      bool isBooked = _isTimeSlotBooked(timeSlot);
      
      String formattedTime = '';
      if (timeSlot.hour < 12) {
        formattedTime = '${timeSlot.hour}:${timeSlot.minute.toString().padLeft(2, '0')} AM';
      } else if (timeSlot.hour == 12) {
        formattedTime = '12:${timeSlot.minute.toString().padLeft(2, '0')} PM';
      } else {
        formattedTime = '${timeSlot.hour - 12}:${timeSlot.minute.toString().padLeft(2, '0')} PM';
      }
      
      return DropdownMenuItem<TimeOfDay>(
        value: timeSlot,
        enabled: !isBooked, // NEW: Disable if booked
        child: Row(
          children: [
            Text(
              formattedTime,
              style: TextStyle(
                color: isBooked ? Colors.grey[400] : Colors.black87,
                decoration: isBooked ? TextDecoration.lineThrough : null,
              ),
            ),
            if (isBooked) ...[
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Text(
                  'Booked',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.red[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Time Slot',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: 8),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<TimeOfDay>(
              isExpanded: true,
              value: _selectedTime,
              icon: Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
              iconSize: 24,
              elevation: 16,
              style: TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
              onChanged: (TimeOfDay? newValue) {
                if (newValue != null && !_isTimeSlotBooked(newValue)) {
                  setState(() {
                    _selectedTime = newValue;
                  });
                }
              },
              items: timeItems,
            ),
          ),
        ),
        
        // NEW: Show availability summary
        if (_bookedTimeSlots.isNotEmpty) ...[
          SizedBox(height: 8),
          Text(
            '${_availableTimeSlots.length - _bookedTimeSlots.length} of ${_availableTimeSlots.length} slots available',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}