import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:home_service_system/screens/user_filldetail.dart';
import 'package:home_service_system/models/models.dart';
import 'package:home_service_system/firebase_service/auth_service.dart';
import 'package:home_service_system/firebase_service/booking_service.dart';

class BookingSelectPage extends StatefulWidget {
  final String selectedService;
  
  const BookingSelectPage({super.key, required this.selectedService});

  @override
  _BookingSelectPageState createState() => _BookingSelectPageState();
}

class _BookingSelectPageState extends State<BookingSelectPage> {
  // Current step
  final int _currentStep = 0; // 0: Select services, 1: Fill Details, 2: Confirm booking
  
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
                color: _currentStep == 0 ? Colors.yellow[600] : Colors.grey[300],
                border: Border.all(color: _currentStep == 0 ? Colors.blue[900]! : Colors.grey[300]!, width: 2),
              ),
              child: Center(
                child: Text(
                  '1',
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
              width: 75,
              child: Text(
                'Select services',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: _currentStep == 0 ? FontWeight.bold : FontWeight.normal,
                  color: _currentStep == 0 ? Colors.blue[900] : Colors.grey[600],
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
          color: _currentStep > 0 ? Colors.blue[900] : Colors.grey[300],
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

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthService, BookingService>(
      builder: (context, authService, bookingService, child) {
        final subServices = bookingService.getSubServices(widget.selectedService);
        
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
                      widget.selectedService,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                  
                  // Subtitle
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Text(
                      'Select the specific service you need',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                  
                  // Sub-service list
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.all(16),
                      itemCount: subServices.length,
                      itemBuilder: (context, index) {
                        final subService = subServices[index];
                        return _buildSubServiceCard(
                          context, 
                          subService, 
                          authService, 
                          bookingService
                        );
                      },
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
  
// 在BookingSelectPage的_buildSubServiceCard方法中更新这部分：

Widget _buildSubServiceCard(
  BuildContext context, 
  SubService subService, 
  AuthService authService, 
  BookingService bookingService
) {
  return Card(
    margin: EdgeInsets.symmetric(vertical: 8),
    elevation: 2,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        // Check if user is logged in
        if (authService.currentUser == null) {
          _showLoginRequiredDialog(context);
          return;
        }

        try {
          // Create initial booking data with user information
          final currentUser = authService.currentUser!;
          final bookingData = BookingData(
            userID: currentUser.id,
            userName: currentUser.name,
            userEmail: currentUser.email,
            userPhone: currentUser.phoneNumber ?? '',
            serviceName: widget.selectedService,
            subService: subService,
            subserviceID: subService.subservicesID,
            bookingAddress: '', // Will be filled in next step
            bookingDate: DateTime.now().add(Duration(days: 1)),
            bookingTime: TimeOfDay(hour: 10, minute: 0),
            bookingDescription: '', // Will be filled in next step
            bookingQuotation: subService.subserviceApproxAmount,
            statusID: BookingStatus.pending.statusID,
            imageUrls: [], // 添加这行：空的图片URL列表
          );

          // Set the booking data in BookingService
          bookingService.setCurrentBooking(bookingData);

          // Navigate to FillDetailPage
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => FillDetailPage(
                selectedService: widget.selectedService,
                selectedSubService: subService,
              ),
            ),
          );
        } catch (e) {
          _showErrorDialog(context, 'Error preparing booking: $e');
        }
      },
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            // Service icon
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.yellow[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                subService.icon,
                size: 32,
                color: Colors.blue[900],
              ),
            ),
            SizedBox(width: 16),
            
            // Service name, description and price
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subService.subserviceName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subService.subserviceDescription,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Starting from RM${subService.subserviceApproxAmount.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.green[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            
            // Arrow icon
            Icon(
              Icons.arrow_forward_ios,
              size: 20,
              color: Colors.black45,
            ),
          ],
        ),
      ),
    ),
  );
}

  void _showLoginRequiredDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Login Required'),
          content: Text('Please log in to continue with your booking.'),
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

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Error'),
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
}