import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:home_service_system/screens/welcome_page.dart';
import 'package:home_service_system/firebase_service/auth_service.dart';
import 'package:home_service_system/firebase_service/booking_service.dart';
import 'package:home_service_system/firebase_service/technician_service.dart';
import 'package:home_service_system/firebase_service/technician_booking_service.dart';
import 'package:home_service_system/firebase_service/quotation_service.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('❌ Firebase initialization failed: $e');
  }

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => BookingService()),
        ChangeNotifierProvider(create: (_) => TechnicianService()),
        ChangeNotifierProvider(create: (_) => TechnicianBookingService()),
        ChangeNotifierProvider(create: (_) => QuotationService()), 
      ],
      child: MaterialApp(
        title: 'Home Repair Service',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
          fontFamily: 'Roboto',
          
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
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
              borderSide: BorderSide(color: Colors.blue),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            labelStyle: TextStyle(color: Colors.grey[600]),
            hintStyle: TextStyle(color: Colors.grey[400]),
          ),
          
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.yellow[600],
              foregroundColor: Colors.blue[900],
              padding: EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 5,
              textStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue[700],
              textStyle: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.blue[900],
            elevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(
              color: Colors.blue[900],
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            iconTheme: IconThemeData(
              color: Colors.blue[900],
            ),
          ),
          
          dialogTheme: DialogTheme(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 10,
            titleTextStyle: TextStyle(
              color: Colors.blue[900],
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            contentTextStyle: TextStyle(
              color: Colors.grey[700],
              fontSize: 16,
            ),
          ),
          
          snackBarTheme: SnackBarThemeData(
            backgroundColor: Colors.grey[800],
            contentTextStyle: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            behavior: SnackBarBehavior.floating,
          ),
          
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            primary: Colors.blue[700]!,
            secondary: Colors.yellow[600]!,
            surface: Colors.white,
            background: Colors.grey[50]!,
            error: Colors.red[600]!,
          ),
        ),
        
        home: WelcomePage(),
      ),
    );
  }
}