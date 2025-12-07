import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:home_service_system/screens/user_homepage.dart';
import 'package:home_service_system/firebase_service/booking_service.dart';
import 'dart:async';

class ConfirmPage extends StatefulWidget {
  const ConfirmPage({super.key});

  @override
  _ConfirmPageState createState() => _ConfirmPageState();
}

class _ConfirmPageState extends State<ConfirmPage> {
  // Current step
  final int _currentStep = 2; // 0: Select services, 1: Fill Details, 2: Confirm booking
  bool _agreedToTerms = false;
  bool _isSubmitting = false;
  
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
              width: 65,
              child: Text(
                'Fill Details',
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
        
        // Second connecting line
        Container(
          width: 45,
          height: 2,
          margin: EdgeInsets.symmetric(horizontal: 4),
          color: Colors.blue[900],
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

  // Information row for booking details
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    bool isHighlighted = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.yellow[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Colors.blue[900],
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                  color: isHighlighted ? Colors.blue[900] : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  // Navigate to homepage with booking success data
  void _showBookingSuccessAndNavigate(String bookingID) {
    print('Navigating to homepage with booking success: $bookingID');
    
    // Navigate to homepage and remove all previous routes
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => UserHomePage(
          showBookingSuccess: true,
          bookingID: bookingID,
        ),
      ),
      (Route<dynamic> route) => false, // Remove all previous routes
    );
  }

  // Show time conflict dialog
  void _showTimeConflictDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange[700], size: 28),
              SizedBox(width: 8),
              Text('Time Slot Unavailable'),
            ],
          ),
          content: Text(
            'Sorry, this time slot has just been booked by another user. Please go back and select a different time.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back to FillDetailPage
              },
              child: Text(
                'Select Another Time',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  // Show error dialog
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
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BookingService>(
      builder: (context, bookingService, child) {
        final currentBooking = bookingService.currentBooking;
        final selectedImages = bookingService.selectedImages;
        
        // If no current booking data, go back
        if (currentBooking == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pop(context);
          });
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        String formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(currentBooking.bookingDate);
        
        String formattedTime = '';
        if (currentBooking.bookingTime.hour < 12) {
          formattedTime = '${currentBooking.bookingTime.hour}:${currentBooking.bookingTime.minute.toString().padLeft(2, '0')} AM';
        } else if (currentBooking.bookingTime.hour == 12) {
          formattedTime = '12:${currentBooking.bookingTime.minute.toString().padLeft(2, '0')} PM';
        } else {
          formattedTime = '${currentBooking.bookingTime.hour - 12}:${currentBooking.bookingTime.minute.toString().padLeft(2, '0')} PM';
        }
      
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
                  
                  // Page title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Booking Summary',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                  
                  // Main content (scrollable)
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Service information card
                          Card(
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
                                    'Service Details',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[900],
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  _buildInfoRow(
                                    icon: Icons.category,
                                    label: 'Service',
                                    value: currentBooking.serviceName,
                                  ),
                                  Divider(height: 24),
                                  _buildInfoRow(
                                    icon: currentBooking.subService.icon,
                                    label: 'Selected Package',
                                    value: currentBooking.subService.subserviceName,
                                    isHighlighted: true,
                                  ),
                                  Divider(height: 24),
                                  _buildInfoRow(
                                    icon: Icons.calendar_today,
                                    label: 'Date',
                                    value: formattedDate,
                                  ),
                                  Divider(height: 24),
                                  _buildInfoRow(
                                    icon: Icons.access_time,
                                    label: 'Time',
                                    value: formattedTime,
                                  ),
                                  Divider(height: 24),
                                  _buildInfoRow(
                                    icon: Icons.attach_money,
                                    label: 'Estimated Cost',
                                    value: 'RM${currentBooking.bookingQuotation.toStringAsFixed(0)}',
                                    isHighlighted: true,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          
                          SizedBox(height: 16),
                          
                          // Customer information card
                          Card(
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
                                    'Customer Information',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue[900],
                                    ),
                                  ),
                                  SizedBox(height: 12),
                                  _buildInfoRow(
                                    icon: Icons.person,
                                    label: 'Name',
                                    value: currentBooking.userName,
                                  ),
                                  Divider(height: 24),
                                  _buildInfoRow(
                                    icon: Icons.phone,
                                    label: 'Phone',
                                    value: currentBooking.userPhone,
                                  ),
                                  Divider(height: 24),
                                  _buildInfoRow(
                                    icon: Icons.location_on,
                                    label: 'Address',
                                    value: currentBooking.bookingAddress,
                                  ),
                                  if (currentBooking.bookingDescription.isNotEmpty) ...[
                                    Divider(height: 24),
                                    _buildInfoRow(
                                      icon: Icons.note,
                                      label: 'Notes',
                                      value: currentBooking.bookingDescription,
                                    ),
                                  ],
                                  if (selectedImages.isNotEmpty) ...[
                                    Divider(height: 24),
                                    _buildInfoRow(
                                      icon: Icons.photo,
                                      label: 'Photos to Upload',
                                      value: '${selectedImages.length} photo(s) selected',
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
       
                          SizedBox(height: 24),
                          
                          // Terms and conditions
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 24,
                                width: 24,
                                child: Checkbox(
                                  value: _agreedToTerms,
                                  activeColor: Colors.blue[900],
                                  onChanged: (value) {
                                    setState(() {
                                      _agreedToTerms = value!;
                                    });
                                  },
                                ),
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'I agree to the terms and conditions, including the cancellation policy and service provider guidelines.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                  
                  // Confirm booking button - ✅ Updated with transaction logic
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: (_agreedToTerms && !_isSubmitting) 
                        ? () async {
                            print('Creating final booking...');
                            
                            setState(() {
                              _isSubmitting = true;
                            });

                            try {
                              // ✅ Transaction will handle the time slot validation
                              // No need for pre-check, as the transaction ensures atomicity
                              
                              String? bookingID = await bookingService.createFinalBooking()
                                  .timeout(
                                Duration(seconds: 30),
                                onTimeout: () {
                                  print('Booking creation timed out after 30 seconds');
                                  throw TimeoutException('Booking creation timed out', Duration(seconds: 30));
                                },
                              );
                              
                              print('Final booking creation result: $bookingID');
                              
                              if (bookingID != null && bookingID.isNotEmpty) {
                                print('Booking created successfully, navigating to homepage');
                                _showBookingSuccessAndNavigate(bookingID);
                              } else {
                                print('Booking creation failed - bookingID is null or empty');
                                if (mounted) {
                                  setState(() {
                                    _isSubmitting = false;
                                  });
                                  _showErrorDialog('Failed to create booking. Please try again.');
                                }
                              }
                            } on TimeoutException catch (e) {
                              print('Timeout error: $e');
                              if (mounted) {
                                setState(() {
                                  _isSubmitting = false;
                                });
                                _showErrorDialog('Request timed out. Please check your connection and try again.');
                              }
                            } catch (e) {
                              print('Error during booking creation: $e');
                              if (mounted) {
                                setState(() {
                                  _isSubmitting = false;
                                });
                                // ✅ Check if it's a time conflict error
                                if (e.toString().contains('already been booked') || 
                                    e.toString().contains('time slot')) {
                                  _showTimeConflictDialog();
                                } else {
                                  _showErrorDialog('An error occurred: ${e.toString()}');
                                }
                              }
                            }
                          } 
                        : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.yellow[700],
                          disabledBackgroundColor: Colors.grey[400],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isSubmitting
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  selectedImages.isNotEmpty ? 'Uploading images...' : 'Creating booking...',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              'Confirm Booking',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
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
}