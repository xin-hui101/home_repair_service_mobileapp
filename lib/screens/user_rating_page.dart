// lib/screens/user_rating_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:home_service_system/models/models.dart';
import 'package:home_service_system/models/rating_model.dart';
import 'package:home_service_system/firebase_service/rating_service.dart';
import 'package:home_service_system/firebase_service/auth_service.dart';

class UserRatingPage extends StatefulWidget {
  final BookingData booking;
  final RatingModel? existingRating; // If user has already rated

  const UserRatingPage({
    super.key,
    required this.booking,
    this.existingRating,
  });

  @override
  State<UserRatingPage> createState() => _UserRatingPageState();
}

class _UserRatingPageState extends State<UserRatingPage> {
  int _selectedRating = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;
  bool _isLoadingTechnician = false;
  TechnicianModel? _technician;
  final RatingService _ratingService = RatingService();

  @override
  void initState() {
    super.initState();
    // If editing existing rating, populate the fields
    if (widget.existingRating != null) {
      _selectedRating = widget.existingRating!.rating;
      _commentController.text = widget.existingRating!.comment;
    }
    
    // Load technician info
    if (widget.booking.technicianID != null && widget.booking.technicianID!.isNotEmpty) {
      _loadTechnicianInfo();
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadTechnicianInfo() async {
    setState(() {
      _isLoadingTechnician = true;
    });

    try {
      // Query technicians collection where technician_ID field matches
      final querySnapshot = await FirebaseFirestore.instance
          .collection('technicians')
          .where('technician_ID', isEqualTo: widget.booking.technicianID)
          .limit(1)
          .get();
      
      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        setState(() {
          _technician = TechnicianModel.fromMap(doc.data());
          _isLoadingTechnician = false;
        });
      } else {
        setState(() {
          _isLoadingTechnician = false;
        });
      }
    } catch (e) {
      print('Error loading technician: $e');
      setState(() {
        _isLoadingTechnician = false;
      });
    }
  }

  // Get status color (same as booking detail page)
  Color getStatusColor(String status) {
    switch (status) {
      case 'All':
        return Colors.grey[600]!;
      case 'Pending':
        return Colors.amber[600]!;
      case 'Accepted':
        return Colors.lightGreen[600]!;
      case 'Quotation Sent':
        return Colors.blue[600]!;
      case 'Scheduled':
        return Colors.purple[600]!;
      case 'In Progress':
        return Colors.orange[600]!;
      case 'Completed':
        return Colors.teal[700]!;
      case 'Cancelled':
        return Colors.red[600]!;
      default:
        return Colors.grey[600]!;
    }
  }

  // NEW: 更新 Firebase 中 booking 的评分状态
  Future<void> _updateBookingRatingStatus(String bookingId) async {
    try {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .update({
        'has_rated': true,
        'updated_at': FieldValue.serverTimestamp(),
      });
      print('Updated booking $bookingId has_rated status to true');
    } catch (e) {
      print('Error updating booking rating status: $e');
      // 即使更新失败，也不影响评分提交
    }
  }

  Future<void> _submitRating() async {
    if (_selectedRating == 0) {
      _showErrorSnackBar('Please select a rating');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userData = await authService.getUserData(role: 'user');

      if (userData == null) {
        _showErrorSnackBar('User data not found');
        return;
      }

      bool success;
      if (widget.existingRating != null) {
        // Update existing rating
        success = await _ratingService.updateRating(
          ratingId: widget.existingRating!.ratingId,
          rating: _selectedRating,
          comment: _commentController.text.trim(),
        );
      } else {
        // Submit new rating
        success = await _ratingService.submitRating(
          bookingId: widget.booking.bookingID!,
          userId: userData.id,
          technicianId: widget.booking.technicianID!,
          rating: _selectedRating,
          comment: _commentController.text.trim(),
        );
        
        // NEW: 如果是新评分，更新 booking 的 has_rated 状态
        if (success) {
          await _updateBookingRatingStatus(widget.booking.bookingID!);
        }
      }

      if (success) {
        _showSuccessDialog();
      } else {
        _showErrorSnackBar('Failed to submit rating. Please try again.');
      }
    } catch (e) {
      _showErrorSnackBar('An error occurred: $e');
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // 修改成功对话框，确保返回成功标志
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  color: Colors.green[600],
                  size: 40,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Title
              Text(
                'Thank you!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Message
              Text(
                widget.existingRating != null
                    ? 'Your rating has been updated successfully.'
                    : 'Your rating has been submitted successfully.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              
              const SizedBox(height: 20),
              
              // OK button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context, true); // 返回 true 表示评分成功
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String displayStatus = BookingStatusConstants.getDisplayName(widget.booking.statusID);
    
    return Scaffold(
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
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios,
                        color: Colors.black87,
                        size: 24,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Text(
                        widget.existingRating != null ? 'Edit Rating' : 'Rate Service',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                        ),
                      ),
                    ),
                    const SizedBox(width: 40),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Booking information card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Booking ID',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.booking.bookingID ?? 'N/A',
                                      style: const TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: getStatusColor(displayStatus).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: getStatusColor(displayStatus).withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    displayStatus,
                                    style: TextStyle(
                                      color: getStatusColor(displayStatus),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              widget.booking.serviceName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.booking.subService.subserviceName,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Rating section with technician info
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'How was the service?',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[900],
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_isLoadingTechnician)
                              Text(
                                'Loading technician information...',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              )
                            else if (_technician != null)
                              Text(
                                'Rate your experience with ${_technician!.technicianName}',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              )
                            else
                              Text(
                                'Rate your experience with the technician',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            const SizedBox(height: 20),
                            
                            // Star rating
                            Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(5, (index) {
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedRating = index + 1;
                                      });
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 4),
                                      child: Icon(
                                        Icons.star,
                                        size: 40,
                                        color: index < _selectedRating
                                            ? Colors.amber[600]
                                            : Colors.grey[300],
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // Rating text
                            if (_selectedRating > 0)
                              Center(
                                child: Text(
                                  _getRatingText(_selectedRating),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.amber[700],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Comment section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Add a comment (Optional)',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[900],
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _commentController,
                              maxLines: 4,
                              maxLength: 500,
                              decoration: InputDecoration(
                                hintText: 'Write your comment here...',
                                hintStyle: TextStyle(color: Colors.grey[400]),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.grey[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: Colors.blue[600]!),
                                ),
                                contentPadding: const EdgeInsets.all(16),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              // Submit button (without icon)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitRating,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedRating > 0 ? Colors.yellow[600] : Colors.grey[300],
                    foregroundColor: _selectedRating > 0 ? Colors.blue[900] : Colors.grey[600],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        )
                      : Text(
                          widget.existingRating != null
                              ? 'Update Rating'
                              : 'Submit Rating',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }
}