import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'register_page.dart';
import 'user_homepage.dart';
import 'admin_dashboardpage.dart';
import 'technician_ownschedule.dart';
import '../firebase_service/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String _selectedRole = 'User';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final authService = Provider.of<AuthService>(context, listen: false);
        await authService.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
          expectedRole: _selectedRole,
        );

        if (mounted) {
          _navigateToRoleBasedPage(_selectedRole.toLowerCase());
        }
      } on FirebaseAuthException catch (e) {
        if (mounted) {
          _showErrorMessage(e.message ?? 'Login failed. Please try again.');
        }
      } catch (e) {
        if (mounted) {
          _showErrorMessage('An unexpected error occurred. Please try again.');
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _navigateToRoleBasedPage(String role) {
    Widget targetPage;

    switch (role) {
      case 'user':
        targetPage = UserHomePage();
        break;
      case 'admin':
        targetPage = AdminDashboardPage();
        break;
      case 'technician':
        targetPage = const TechnicianOwnSchedulePage();
        break;
      default:
        _showErrorMessage('Unknown user role: $role');
        return;
    }

    Navigator.pushReplacement(
      context,
      CupertinoPageRoute(builder: (context) => targetPage),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            constraints: BoxConstraints(
              minHeight: size.height - MediaQuery.of(context).padding.top,
            ),
            width: double.infinity,
            child: Stack(
              children: [
                // Decorative top shape
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    width: size.width,
                    height: size.height * 0.25,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.yellow[50]!,
                          Colors.yellow[50]!,
                          Colors.white.withOpacity(0.0),
                        ],
                      ),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(60),
                        bottomRight: Radius.circular(60),
                      ),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 20),
                    // Back button with slide effect
                    Padding(
                      padding: const EdgeInsets.only(left: 16.0),
                      child: IconButton(
                        icon: Icon(Icons.arrow_back_ios, color: Colors.black),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                    SizedBox(height: 10),
                    
                    // Logo and title 
                    Center(
                      child: Column(
                        children: [
                          // App Logo
                          Icon(
                            Icons.home_repair_service,
                            size: isTablet ? 80 : 100,
                            color: Colors.black,
                          ),
                          
                          SizedBox(height: 10),
                          // App name
                          Text(
                            'Home Repair Service',
                            style: TextStyle(
                              color: Colors.blue[900]!,
                              fontSize: isTablet ? 20 : 24,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                          Text(
                            'Booking System',
                            style: TextStyle(
                              color: Colors.blue[900]!,
                              fontSize: isTablet ? 20 : 24,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(height: 30),
                    
                    // Login form
                    Center(
                      child: Container(
                        width: double.infinity,
                        constraints: BoxConstraints(
                          maxWidth: isTablet ? 500 : double.infinity,
                        ),
                        margin: EdgeInsets.symmetric(horizontal: 30),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Login title
                              Padding(
                                padding: const EdgeInsets.only(left: 5.0, bottom: 15.0),
                                child: Text(
                                  'Login',
                                  style: TextStyle(
                                    color: Colors.blue[900],
                                    fontSize: 29,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              
                              // Email field
                              _buildTextField(
                                controller: _emailController,
                                labelText: 'Email',
                                hintText: 'Enter your email',
                                prefixIcon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              SizedBox(height: 20),
                              
                              // Password field
                              _buildTextField(
                                controller: _passwordController,
                                labelText: 'Password',
                                hintText: 'Enter your password',
                                prefixIcon: Icons.lock_outline,
                                obscureText: _obscurePassword,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your password';
                                  }
                                  if (value.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),
                              
                              SizedBox(height: 20),
                              
                              // Role selection
                              Padding(
                                padding: const EdgeInsets.only(left: 5.0),
                                child: Text(
                                  'Login As:',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              SizedBox(height: 8),
                              
                              // Role selection buttons
                              Column(
                                children: [
                                  // First row: User and Admin
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildRoleRadio(
                                          title: 'User',
                                          icon: Icons.person,
                                          value: 'User',
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: _buildRoleRadio(
                                          title: 'Admin',
                                          icon: Icons.admin_panel_settings,
                                          value: 'Admin',
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  // Second row: Technician
                                  _buildRoleRadio(
                                    title: 'Technician',
                                    icon: Icons.engineering,
                                    value: 'Technician',
                                  ),
                                ],
                              ),
                              
                              SizedBox(height: 25),
                              
                              // Login button
                              SizedBox(
                                width: double.infinity,
                                height: 55,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.yellow[600]!,
                                    foregroundColor: Colors.blue[900]!,
                                    disabledBackgroundColor: Colors.grey[300],
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                    elevation: 5,
                                  ),
                                  child: _isLoading
                                      ? SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            color: Colors.blue[900],
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          'Login',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                              SizedBox(height: 25),
                              
                              // Register link - only show when User is selected
                              if (_selectedRole == 'User')
                                Center(
                                  child: RichText(
                                    text: TextSpan(
                                      text: 'Don\'t have an account? ',
                                      style: TextStyle(color: Colors.black54),
                                      children: [
                                        TextSpan(
                                          text: 'Register here',
                                          style: TextStyle(
                                            color: Colors.blue[700],
                                            fontWeight: FontWeight.bold,
                                            decoration: TextDecoration.underline,
                                          ),
                                          recognizer: TapGestureRecognizer()
                                            ..onTap = () {
                                              Navigator.push(
                                                context,
                                                CupertinoPageRoute(
                                                  builder: (context) => RegisterPage(),
                                                ),
                                              );
                                            },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              SizedBox(height: 30),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleRadio({
    required String title,
    required IconData icon,
    required String value,
  }) {
    final isSelected = _selectedRole == value;
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedRole = value;
        });
      },
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.yellow[50] : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? Colors.yellow[600]! : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon, 
              color: isSelected ? Colors.yellow[700] : Colors.grey,
              size: 24,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? Colors.yellow[800] : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 16,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: _selectedRole,
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedRole = newValue;
                  });
                }
              },
              activeColor: Colors.yellow[600],
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData prefixIcon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: Icon(prefixIcon, color: Colors.grey),
        suffixIcon: suffixIcon,
        contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey.shade400),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.blue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
      validator: validator,
    );
  }
}