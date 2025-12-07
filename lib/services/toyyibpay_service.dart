// lib/services/toyyibpay_service.dart - 更新版本
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class ToyyibPayService {
  static const String _baseUrl = 'https://dev.toyyibpay.com/index.php/api';
  static const String _createBillUrl = '$_baseUrl/createBill';
  static const String _getBillUrl = '$_baseUrl/getBillTransactions';
  
  static const String _userSecretKey = 'izi7wjml-ahgm-p4uu-u2id-gvnbqs9ysuuv';
  static const String _categoryCode = '7lf61pvs';

  static Future<bool> testConnection() async {
    try {
      print('Testing connection to ToyyibPay...');
      final response = await http.get(
        Uri.parse('https://dev.toyyibpay.com'),
        headers: {'User-Agent': 'Flutter App'},
      ).timeout(const Duration(seconds: 10));
      
      print('Connection test result: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      print('Connection test failed: $e');
      return false;
    }
  }

  /// 方案：不设置returnUrl，让ToyyibPay显示默认确认页面
  static Future<Map<String, dynamic>?> createBill({
    required String billName,
    required String billDescription,
    required double billAmount,
    required String billTo,
    required String billEmail,
    required String billPhone,
    String? billExternalReferenceNo,
    String? billCallbackUrl,
    String? billReturnUrl, // 这个参数会被忽略
  }) async {
    try {
      print('=== TOYYIBPAY CREATE BILL DEBUG (无returnUrl方案) ===');
      print('Using No ReturnUrl Solution: Let ToyyibPay show default confirmation');
      
      final connectionOk = await testConnection();
      if (!connectionOk) {
        return {
          'success': false,
          'error': 'Cannot connect to ToyyibPay servers. Please check your internet connection.',
        };
      }

      print('Connection OK. Creating bill...');
      print('Bill Amount: $billAmount');
      print('Amount in cents: ${(billAmount * 100).toInt()}');

      final requestBody = {
        'userSecretKey': _userSecretKey,
        'categoryCode': _categoryCode,
        'billName': billName,
        'billDescription': billDescription,
        'billPriceSetting': '1',
        'billPayorInfo': '1',
        'billAmount': (billAmount * 100).toInt().toString(),
        
        // 不设置 billReturnUrl 和 billCallbackUrl，让 ToyyibPay 显示默认页面
        // 'billReturnUrl': '',
        // 'billCallbackUrl': '',
        
        'billExternalReferenceNo': billExternalReferenceNo ?? DateTime.now().millisecondsSinceEpoch.toString(),
        'billTo': billTo,
        'billEmail': billEmail,
        'billPhone': billPhone,
        'billSplitPayment': '0',
        'billSplitPaymentArgs': '',
        'billPaymentChannel': '0',
        'billContentEmail': 'Thank you for your payment!',
        'billChargeToCustomer': '1',
      };

      print('Request body (no returnUrl): $requestBody');

      final response = await http.post(
        Uri.parse(_createBillUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'Flutter App',
          'Accept': 'application/json',
        },
        body: requestBody,
      ).timeout(const Duration(seconds: 30));

      print('Response status code: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        try {
          final responseData = json.decode(response.body);
          print('Parsed response data: $responseData');
          
          if (responseData is List && responseData.isNotEmpty) {
            final billData = responseData[0];
            
            if (billData['BillCode'] != null) {
              return {
                'success': true,
                'billCode': billData['BillCode'],
                'paymentUrl': 'https://dev.toyyibpay.com/${billData['BillCode']}',
                'data': billData,
              };
            } else {
              return {
                'success': false,
                'error': 'Failed to create bill: ${billData['msg'] ?? 'No BillCode returned'}',
              };
            }
          } else {
            return {
              'success': false,
              'error': 'Invalid response format: Expected array but got ${responseData.runtimeType}',
            };
          }
        } catch (jsonError) {
          print('JSON parsing error: $jsonError');
          return {
            'success': false,
            'error': 'Invalid JSON response: $jsonError',
          };
        }
      } else {
        return {
          'success': false,
          'error': 'HTTP Error ${response.statusCode}: ${response.body}',
        };
      }
    } on SocketException catch (e) {
      print('SocketException: $e');
      return {
        'success': false,
        'error': 'Network connection failed. Please check your internet connection and try again.',
      };
    } on TimeoutException catch (e) {
      print('TimeoutException: $e');
      return {
        'success': false,
        'error': 'Connection timeout. Please check your internet connection and try again.',
      };
    } on FormatException catch (e) {
      print('FormatException: $e');
      return {
        'success': false,
        'error': 'Invalid response format from server.',
      };
    } catch (e) {
      print('Unexpected error creating ToyyibPay bill: $e');
      return {
        'success': false,
        'error': 'Unexpected error: $e',
      };
    }
  }

  static Future<Map<String, dynamic>?> getBillStatus(String billCode) async {
    try {
      print('=== CHECKING BILL STATUS ===');
      print('Bill Code: $billCode');

      final response = await http.post(
        Uri.parse(_getBillUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'User-Agent': 'Flutter App',
        },
        body: {
          'userSecretKey': _userSecretKey,
          'billCode': billCode,
        },
      ).timeout(const Duration(seconds: 30));

      print('Bill Status Response Status: ${response.statusCode}');
      print('Bill Status Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return {
          'success': true,
          'data': responseData,
        };
      } else {
        return {
          'success': false,
          'error': 'HTTP Error ${response.statusCode}: ${response.body}',
        };
      }
    } on SocketException catch (e) {
      print('SocketException checking bill status: $e');
      return {
        'success': false,
        'error': 'Network connection failed',
      };
    } on TimeoutException catch (e) {
      print('TimeoutException checking bill status: $e');
      return {
        'success': false,
        'error': 'Connection timeout',
      };
    } catch (e) {
      print('Error checking bill status: $e');
      return {
        'success': false,
        'error': 'Error: $e',
      };
    }
  }

  static Future<bool> launchPaymentUrl(String paymentUrl) async {
    try {
      print('Launching payment URL: $paymentUrl');
      final Uri uri = Uri.parse(paymentUrl);
      final bool launched = await launchUrl(
        uri, 
        mode: LaunchMode.externalApplication,
        webViewConfiguration: const WebViewConfiguration(
          enableJavaScript: true,
          enableDomStorage: true,
        ),
      );
      print('URL launched successfully: $launched');
      return launched;
    } catch (e) {
      print('Error launching payment URL: $e');
      return false;
    }
  }

  static bool validateCredentials() {
    if (_userSecretKey.isEmpty || _userSecretKey == 'YOUR_USER_SECRET_KEY') {
      print('ERROR: User Secret Key not set correctly');
      return false;
    }
    
    if (_categoryCode.isEmpty || _categoryCode == 'YOUR_CATEGORY_CODE') {
      print('ERROR: Category Code not set correctly');
      return false;
    }
    
    print('Credentials validation passed');
    return true;
  }
}