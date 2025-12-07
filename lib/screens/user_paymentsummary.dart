// lib/screens/payment_summary_page.dart - 更新版本
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:app_links/app_links.dart';
import '../models/models.dart';
import '../models/quotation_models.dart';
import '../firebase_service/quotation_service.dart';
import '../firebase_service/booking_service.dart';
import '../services/toyyibpay_service.dart';

class PaymentSummaryPage extends StatefulWidget {
  final BookingData booking;
  
  const PaymentSummaryPage({super.key, required this.booking});

  @override
  State<PaymentSummaryPage> createState() => _PaymentSummaryPageState();
}

class _PaymentSummaryPageState extends State<PaymentSummaryPage> {
  String _selectedPaymentMethod = 'ToyyibPay';
  bool _isProcessing = false;
  bool _isLoading = true;
  
  QuotationData? _quotation;
  String _technicianName = 'Loading...';
  String? _currentBillCode;
  
  // Deep linking for payment callbacks
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  
  // 轮询检查相关
  Timer? _paymentCheckTimer;
  int _paymentCheckCount = 0;
  static const int MAX_PAYMENT_CHECKS = 20; // 最多检查20次，约10分钟
  bool _isPolling = false;

  @override
  void initState() {
    super.initState();
    _loadQuotationData();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _paymentCheckTimer?.cancel(); // 清理定时器
    super.dispose();
  }

  void _initDeepLinks() {
    _appLinks = AppLinks();
    
    // Listen for incoming app links while the app is running
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        print('Received payment callback: $uri');
        _handlePaymentCallback(uri);
      },
      onError: (err) {
        print('Deep link error: $err');
      },
    );

    // Check if app was launched from a link
    _appLinks.getInitialAppLink().then((Uri? uri) {
      if (uri != null) {
        print('App launched with URI: $uri');
        _handlePaymentCallback(uri);
      }
    });
  }

  void _handlePaymentCallback(Uri uri) {
    print('Handling payment callback: ${uri.path}');
    print('URI query parameters: ${uri.queryParameters}');
    
    if (uri.path == '/payment/success') {
      // 延迟5秒处理，让用户有时间看到ToyyibPay的成功页面
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Payment completed! Processing...'),
            ],
          ),
          backgroundColor: Colors.green[700],
          duration: Duration(seconds: 5),
        ),
      );

      // 延迟处理，让用户看到ToyyibPay的确认页面
      Timer(Duration(seconds: 5), () {
        if (mounted) {
          if (_currentBillCode != null) {
            _checkPaymentStatusAfterReturn();
          } else {
            _processPaymentSuccess();
          }
        }
      });
    } else if (uri.path == '/payment/callback') {
      // 对于callback也同样延迟处理
      Timer(Duration(seconds: 3), () {
        if (mounted && _currentBillCode != null) {
          _checkPaymentStatusAfterReturn();
        }
      });
    }
  }

  void _checkPaymentStatusAfterReturn() async {
    if (_currentBillCode == null) return;

    setState(() => _isProcessing = true);

    try {
      // Wait a moment for ToyyibPay to process
      await Future.delayed(const Duration(seconds: 2));
      
      final statusResult = await ToyyibPayService.getBillStatus(_currentBillCode!);
      
      if (statusResult != null && statusResult['success'] == true) {
        final transactions = statusResult['data'] as List;
        
        if (transactions.isNotEmpty) {
          final transaction = transactions.first;
          final status = transaction['billpaymentStatus'];
          
          if (status == '1') {
            // Payment successful
            _processPaymentSuccess();
          } else if (status == '3') {
            // Payment failed
            _showPaymentFailedDialog();
          } else {
            // Payment still pending
            _showPaymentPendingDialog();
          }
        } else {
          // No transactions found, assume success for now
          _processPaymentSuccess();
        }
      } else {
        // If can't check status, assume success based on return
        _processPaymentSuccess();
      }
    } catch (e) {
      print('Error checking payment status after return: $e');
      // Assume success if we can't verify
      _processPaymentSuccess();
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // 处理支付成功后的逻辑 (在线支付)
  void _processPaymentSuccess() async {
    try {
      print('=== PROCESSING PAYMENT SUCCESS ===');
      print('Current booking status: ${widget.booking.statusID}');
      
      // 1. 更新booking状态从 "quotation sent" 到 "in progress"
      final bookingService = Provider.of<BookingService>(context, listen: false);
      
      // 检查当前状态是否为 "quotation sent" (STATUS003)
      if (widget.booking.statusID == 'STATUS003') {
        print('Booking status is STATUS003 (Quotation Sent), updating to STATUS005 (In Progress)');
        
        bool statusUpdated = await bookingService.updateBookingStatusById(
          widget.booking.bookingID!, 
          'STATUS005' // In Progress
        );
        
        if (statusUpdated) {
          print('✅ Successfully updated booking status to In Progress');
        } else {
          print('❌ Failed to update booking status');
        }
      } else {
        print('Current booking status is not STATUS003, current: ${widget.booking.statusID}');
      }
      
      // 2. 显示支付成功对话框
      _showPaymentSuccessDialog(isCash: false);
      
    } catch (e) {
      print('❌ Error processing payment success: $e');
      print('Stack trace: ${StackTrace.current}');
      // 即使状态更新失败，也显示支付成功
      _showPaymentSuccessDialog(isCash: false);
    }
  }

  // 为现金支付单独创建状态更新方法
  void _processPaymentSuccessForCash() async {
    try {
      print('=== PROCESSING CASH PAYMENT SUCCESS ===');
      print('Current booking status: ${widget.booking.statusID}');
      
      // 1. 更新booking状态从 "quotation sent" 到 "in progress"
      final bookingService = Provider.of<BookingService>(context, listen: false);
      
      // 检查当前状态是否为 "quotation sent" (STATUS003)
      if (widget.booking.statusID == 'STATUS003') {
        print('Booking status is STATUS003 (Quotation Sent), updating to STATUS005 (In Progress)');
        
        bool statusUpdated = await bookingService.updateBookingStatusById(
          widget.booking.bookingID!, 
          'STATUS005' // In Progress
        );
        
        if (statusUpdated) {
          print('✅ Successfully updated booking status to In Progress (Cash Payment)');
        } else {
          print('❌ Failed to update booking status (Cash Payment)');
        }
      } else {
        print('Current booking status is not STATUS003, current: ${widget.booking.statusID}');
      }
      
      // 2. 显示支付成功对话框
      _showPaymentSuccessDialog(isCash: true);
      
    } catch (e) {
      print('❌ Error processing cash payment success: $e');
      print('Stack trace: ${StackTrace.current}');
      // 即使状态更新失败，也显示支付成功
      _showPaymentSuccessDialog(isCash: true);
    }
  }

  Future<void> _loadQuotationData() async {
    setState(() => _isLoading = true);
    
    try {
      print('=== PAYMENT SUMMARY DEBUG ===');
      print('Booking ID: ${widget.booking.bookingID}');
      
      final quotationService = Provider.of<QuotationService>(context, listen: false);
      
      // Get quotations for this booking
      final quotations = await quotationService.getQuotationsForBooking(widget.booking.bookingID!);
      
      print('Found ${quotations.length} quotations for this booking');
      
      if (quotations.isNotEmpty) {
        // Print all quotations
        for (var q in quotations) {
          print('  - Quotation ID: ${q.quotationId}, Status: ${q.status}');
        }
        
        // Get the latest sent quotation
        _quotation = quotations.firstWhere(
          (q) => q.status == 'sent',
          orElse: () => quotations.first,
        );
        
        print('Selected Quotation ID: ${_quotation!.quotationId}');
        print('Quotation Status: ${_quotation!.status}');
        print('Technician Name: ${_quotation!.technicianName}');
        print('Material Subtotal: RM${_quotation!.materialSubtotal}');
        print('Installation Fee: RM${_quotation!.installationFee}');
        print('Transportation Fee: RM${_quotation!.transportationFee}');
        print('Subtotal: RM${_quotation!.subtotal}');
        print('Tax Amount: RM${_quotation!.taxAmount}');
        print('Discount: RM${_quotation!.discountAmount}');
        print('Grand Total: RM${_quotation!.grandTotal}');
        
        _technicianName = _quotation!.technicianName;
      } else {
        print('WARNING: No quotations found for booking ${widget.booking.bookingID}');
        print('Falling back to booking data');
        _technicianName = widget.booking.technicianID ?? 'Unknown';
      }
      
      print('=== END DEBUG ===');
    } catch (e) {
      print('ERROR loading quotation data: $e');
      print('Stack trace: ${StackTrace.current}');
      _technicianName = widget.booking.technicianID ?? 'Unknown';
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  double get _materialFee => _quotation?.materialSubtotal ?? 0.0;
  double get _installationFee => _quotation?.installationFee ?? 0.0;
  double get _transportationFee => _quotation?.transportationFee ?? 0.0;
  double get _subtotal => _quotation?.subtotal ?? widget.booking.bookingQuotation;
  double get _taxAmount => _quotation?.taxAmount ?? (_subtotal * 0.08);
  double get _discount => _quotation?.discountAmount ?? 0.0;
  double get _totalAmount => _quotation?.grandTotal ?? (_subtotal + _taxAmount - _discount);

  Future<void> _downloadQuotation() async {
    if (_quotation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No quotation available to download'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 12),
              Text('Generating PDF...'),
            ],
          ),
          backgroundColor: Colors.blue[700],
          duration: const Duration(seconds: 3),
        ),
      );

      final pdf = await _generatePDF();
      final file = await _savePDF(pdf);
      
      if (file != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('PDF downloaded successfully!')),
              ],
            ),
            backgroundColor: Colors.green[600],
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () => _openPDF(file),
            ),
          ),
        );
      }
    } catch (e) {
      print('Error downloading quotation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

Future<pw.Document> _generatePDF() async {
  final pdf = pw.Document();
  
  // Page 1 - Service Details and Assessment
  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Header without icon
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: PdfColors.amber100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'QUOTATION',
                        style: pw.TextStyle(
                          fontSize: 28,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'ID: ${_quotation!.quotationId}',
                        style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Home Repair Service',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                      pw.Text(
                        'Booking System',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            pw.SizedBox(height: 16),
            
            // Service Details
            _buildPDFSection('Service Details', [
              _buildPDFRow('Booking ID', widget.booking.bookingID ?? 'N/A'),
              _buildPDFRow('Service', widget.booking.serviceName),
              _buildPDFRow('Sub-service', widget.booking.subService.subserviceName),
              _buildPDFRow('Date', DateFormat('yyyy/MM/dd').format(widget.booking.bookingDate)),
              _buildPDFRow('Time', '${widget.booking.bookingTime.hour.toString().padLeft(2, '0')}:${widget.booking.bookingTime.minute.toString().padLeft(2, '0')}'),
              _buildPDFRow('Address', widget.booking.bookingAddress),
              _buildPDFRow('Technician', _technicianName),
              _buildPDFRow('Customer', widget.booking.userName),
            ]),
            
            pw.SizedBox(height: 16),
            
            // Assessment
            _buildPDFSection('Assessment', [
              pw.Text('Problem Assessment:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.SizedBox(height: 4),
              pw.Text(_quotation!.problemAssessment, style: const pw.TextStyle(fontSize: 11)),
              pw.SizedBox(height: 8),
              pw.Text('Recommended Solution:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
              pw.SizedBox(height: 4),
              pw.Text(_quotation!.recommendedSolution, style: const pw.TextStyle(fontSize: 11)),
            ]),
          ],
        );
      },
    ),
  );
  
  // Page 2 - Cost Breakdown
  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Page header
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.amber100,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Quotation ID: ${_quotation!.quotationId}',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.Text(
                    'Page 2',
                    style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
                  ),
                ],
              ),
            ),
            
            pw.SizedBox(height: 20),
            
            // Cost Breakdown with detailed material items
            _buildPDFSection('Cost Details', [
              // Material Items Detail
              if (_quotation!.materialItems.isNotEmpty) ...[
                pw.Text('Material Items:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.blue900)),
                pw.SizedBox(height: 8),
                // Table header
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 3, child: pw.Text('Description', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                      pw.Expanded(flex: 1, child: pw.Text('Qty', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                      pw.Expanded(flex: 1, child: pw.Text('Unit Price', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                      pw.Expanded(flex: 1, child: pw.Text('Total', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                    ],
                  ),
                ),
                pw.SizedBox(height: 4),
                // Material items
                ..._quotation!.materialItems.map((item) => pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 3, child: pw.Text(item.description, style: const pw.TextStyle(fontSize: 10))),
                      pw.Expanded(flex: 1, child: pw.Text('${item.quantity}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 10))),
                      pw.Expanded(flex: 1, child: pw.Text('RM${item.unitPrice.toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10))),
                      pw.Expanded(flex: 1, child: pw.Text('RM${item.totalPrice.toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
                )),
                pw.SizedBox(height: 8),
                _buildPDFRow('Material Subtotal', 'RM${_materialFee.toStringAsFixed(2)}'),
                pw.SizedBox(height: 8),
              ],
              
              // Other fees
              if (_installationFee > 0) _buildPDFRow('Installation/Labor Fee', 'RM${_installationFee.toStringAsFixed(2)}'),
              if (_transportationFee > 0) _buildPDFRow('Transportation Fee', 'RM${_transportationFee.toStringAsFixed(2)}'),
              
              pw.Divider(thickness: 1),
              _buildPDFRow('Subtotal', 'RM${_subtotal.toStringAsFixed(2)}'),
              _buildPDFRow('Tax (8%)', 'RM${_taxAmount.toStringAsFixed(2)}'),
              if (_discount > 0) _buildPDFRow('Discount', '-RM${_discount.toStringAsFixed(2)}'),
              pw.Divider(thickness: 2),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TOTAL AMOUNT', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.Text('RM${_totalAmount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  ],
                ),
              ),
            ]),
          ],
        );
      },
    ),
  );
  
  return pdf;
}

  pw.Widget _buildPDFSection(String title, List<pw.Widget> children) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
          pw.SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  pw.Widget _buildPDFRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          pw.Text(value, style: const pw.TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

Future<File?> _savePDF(pw.Document pdf) async {
  try {
    Directory? directory;
    
    if (Platform.isAndroid) {
      directory = await getExternalStorageDirectory();
      
      if (directory != null) {
        final downloadPath = '${directory.path}/Quotations';
        final downloadDir = Directory(downloadPath);
        
        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }
        
        directory = downloadDir;
      }
    } else {
      directory = await getApplicationDocumentsDirectory();
    }
    
    if (directory == null) {
      throw Exception('Could not access storage');
    }
    
    final fileName = 'Quotation_${_quotation!.quotationId}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${directory.path}/$fileName');
    
    await file.writeAsBytes(await pdf.save());
    
    print('PDF saved to: ${file.path}');
    return file;
  } catch (e) {
    print('Error saving PDF: $e');
    return null;
  }
}

  Future<void> _openPDF(File file) async {
    try {
      await OpenFilex.open(file.path);
    } catch (e) {
      print('Error opening PDF: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Summary', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.amber[50],
        elevation: 0,
        foregroundColor: Colors.black87,
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.amber[50]!, Colors.white, Colors.amber[50]!],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle('Service Details', Icons.home_repair_service),
                            const SizedBox(height: 16),
                            _buildServiceDetailsCard(),
                            const SizedBox(height: 24),
                            _buildSectionTitle('Quotation', Icons.description),
                            const SizedBox(height: 16),
                            _buildQuotationCard(),
                            const SizedBox(height: 24),
                            _buildSectionTitle('Payment Methods', Icons.credit_card),
                            const SizedBox(height: 16),
                            _buildPaymentMethodCard('ToyyibPay', Icons.payment, 'FPX, Online Banking, Card'),
                            _buildPaymentMethodCard('Cash', Icons.money, 'Pay cash to technician'),
                            const SizedBox(height: 80),
                          ],
                        ),
                      ),
                    ),
                    _buildPayButtonContainer(),
                  ],
                ),
        ),
      ),
    );
  }
  
  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.amber[800], size: 24),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }
  
  Widget _buildServiceDetailsCard() {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildInfoRow('Booking ID:', widget.booking.bookingID ?? 'N/A'),
            _buildInfoRow('Service:', widget.booking.serviceName),
            _buildInfoRow('Sub-service:', widget.booking.subService.subserviceName),
            _buildInfoRow('Date:', DateFormat('yyyy/MM/dd').format(widget.booking.bookingDate)),
            _buildInfoRow('Time:', '${widget.booking.bookingTime.hour.toString().padLeft(2, '0')}:${widget.booking.bookingTime.minute.toString().padLeft(2, '0')}'),
            _buildInfoRow('Address:', widget.booking.bookingAddress),
            _buildInfoRow('Technician:', _technicianName),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(label, style: TextStyle(fontSize: 15, color: Colors.grey[700]))),
          Expanded(flex: 3, child: Text(value, style: TextStyle(fontSize: 15, fontWeight: isBold ? FontWeight.bold : FontWeight.normal), textAlign: TextAlign.end)),
        ],
      ),
    );
  }
  
  Widget _buildQuotationCard() {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                  child: Icon(Icons.picture_as_pdf, color: Colors.red[600], size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _quotation != null ? 'Quotation_${_quotation!.quotationId}.pdf' : 'Quotation.pdf',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _quotation != null ? 'Created: ${DateFormat('MMM dd, yyyy').format(_quotation!.createdAt)}' : 'No quotation available',
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _quotation != null ? _downloadQuotation : null,
                icon: const Icon(Icons.download),
                label: const Text('Download Quotation'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.green[600],
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  disabledBackgroundColor: Colors.grey[300],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text('Quotation Summary:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey[800])),
            const SizedBox(height: 12),
            if (_materialFee > 0) _buildInfoRow('Material Fee:', 'RM${_materialFee.toStringAsFixed(2)}'),
            if (_installationFee > 0) _buildInfoRow('Installation Fee:', 'RM${_installationFee.toStringAsFixed(2)}'),
            if (_transportationFee > 0) _buildInfoRow('Transportation Fee:', 'RM${_transportationFee.toStringAsFixed(2)}'),
            _buildInfoRow('Tax (8%):', 'RM${_taxAmount.toStringAsFixed(2)}'),
            if (_discount > 0) _buildInfoRow('Discount:', '-RM${_discount.toStringAsFixed(2)}'),
            const Divider(height: 16),
            _buildInfoRow('Total Amount:', 'RM${_totalAmount.toStringAsFixed(2)}', isBold: true),
          ],
        ),
      ),
    );
  }
  
  Widget _buildPaymentMethodCard(String name, IconData icon, String description) {
    bool isSelected = _selectedPaymentMethod == name;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: isSelected ? 4 : 1,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isSelected ? Colors.amber.shade700 : Colors.grey.shade300, width: isSelected ? 2 : 1),
      ),
      child: InkWell(
        onTap: () => setState(() => _selectedPaymentMethod = name),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icon, color: Colors.blue[700], size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(description, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
              ),
              Radio<String>(
                value: name,
                groupValue: _selectedPaymentMethod,
                onChanged: (value) => setState(() => _selectedPaymentMethod = value!),
                activeColor: Colors.amber[700],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildPayButtonContainer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, -2))],
      ),
      child: Column(
        children: [
          _buildPayButton(),
          if (_currentBillCode != null && !_isPolling) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isProcessing ? null : () {
                  _startPaymentStatusPolling();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Check Payment Status'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildPayButton() {
    return ElevatedButton(
      onPressed: _isProcessing ? null : _processPayment,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.yellow[600],
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24), // 增加左右内间距
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _isProcessing
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.blue[900])),
                const SizedBox(width: 12),
                Text('Processing...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[900])),
              ],
            )
          : Text(
              _selectedPaymentMethod == 'Cash' ? 'Confirm Payment' : 'Pay Now - RM${_totalAmount.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue[900]),
            ),
    );
  }

  void _processPayment() async {
    if (_selectedPaymentMethod == 'Cash') {
      _processCashPayment();
      return;
    }

    // Validate ToyyibPay credentials
    if (!ToyyibPayService.validateCredentials()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ToyyibPay credentials not configured correctly'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // ToyyibPay payment
    setState(() => _isProcessing = true);

    try {
      // 创建ToyyibPay bill，不设置returnUrl，让用户看到完整确认页面
      final billResult = await ToyyibPayService.createBill(
        billName: 'Home Repair Service Payment',
        billDescription: 'Payment for booking ${widget.booking.bookingID}',
        billAmount: _totalAmount,
        billTo: widget.booking.userName,
        billEmail: 'customer@example.com',
        billPhone: widget.booking.userPhone,
        billExternalReferenceNo: widget.booking.bookingID,
        // 不设置returnUrl和callbackUrl，让ToyyibPay显示默认确认页面
      );

      if (billResult != null && billResult['success'] == true) {
        _currentBillCode = billResult['billCode'];
        
        // Launch payment URL
        final launched = await ToyyibPayService.launchPaymentUrl(billResult['paymentUrl']);
        
        if (launched) {
          // 显示支付处理中的消息并开始轮询
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.open_in_browser, color: Colors.white),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Payment page opened. Complete payment and return to check status.'),
                  ),
                ],
              ),
              backgroundColor: Colors.blue[700],
              duration: Duration(seconds: 5),
            ),
          );

          // 开始轮询检查支付状态
          _startPaymentStatusPolling();
        } else {
          throw Exception('Failed to launch payment URL');
        }
      } else {
        throw Exception(billResult?['error'] ?? 'Failed to create payment');
      }
    } catch (e) {
      print('Payment error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isProcessing = false);
    }
  }

  void _processCashPayment() {
    setState(() => _isProcessing = true);
    
    Future.delayed(const Duration(seconds: 2), () {
      setState(() => _isProcessing = false);
      // 现金支付也需要更新状态
      _processPaymentSuccessForCash();
    });
  }

  void _showPaymentSuccessDialog({required bool isCash}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.green[500],
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 24),
              
              // Title
              Text(
                'Payment Successful',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              
              // Amount
              Text(
                'RM${_totalAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[600],
                ),
              ),
              const SizedBox(height: 20),
              
              // Message
              Text(
                isCash 
                    ? 'Please pay cash to the technician when service is provided.'
                    : 'Payment completed successfully.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              
              Text(
                'Service will be provided as scheduled.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // OK button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Go back to previous page
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
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

  void _showPaymentFailedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Failed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            const Text('Your payment was not successful.'),
            const SizedBox(height: 8),
            const Text('Please try again or contact support.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Try Again'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _startPaymentStatusPolling() {
    if (_currentBillCode == null) {
      setState(() => _isProcessing = false);
      return;
    }

    _paymentCheckCount = 0;
    _isPolling = true;
    
    // 每30秒检查一次支付状态
    _paymentCheckTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      _checkPaymentStatus();
    });

    // 显示轮询状态
    _showPaymentPollingDialog();
  }

  void _checkPaymentStatus() async {
    if (_currentBillCode == null) {
      _stopPaymentStatusPolling();
      return;
    }

    _paymentCheckCount++;
    print('Checking payment status: attempt $_paymentCheckCount');

    try {
      final statusResult = await ToyyibPayService.getBillStatus(_currentBillCode!);
      
      if (statusResult != null && statusResult['success'] == true) {
        final transactions = statusResult['data'] as List;
        
        if (transactions.isNotEmpty) {
          final transaction = transactions.first;
          final status = transaction['billpaymentStatus'];
          
          if (status == '1') {
            // Payment successful
            _stopPaymentStatusPolling();
            Navigator.of(context).pop(); // Close polling dialog
            _processPaymentSuccess();
            return;
          } else if (status == '3') {
            // Payment failed
            _stopPaymentStatusPolling();
            Navigator.of(context).pop(); // Close polling dialog
            _showPaymentFailedDialog();
            return;
          }
        }
      }
    } catch (e) {
      print('Error checking payment status: $e');
    }

    // 如果达到最大检查次数，停止轮询
    if (_paymentCheckCount >= MAX_PAYMENT_CHECKS) {
      _stopPaymentStatusPolling();
      Navigator.of(context).pop(); // Close polling dialog
      _showPaymentTimeoutDialog();
    }
  }

  void _stopPaymentStatusPolling() {
    _paymentCheckTimer?.cancel();
    _paymentCheckTimer = null;
    _isPolling = false;
    setState(() => _isProcessing = false);
  }

  void _showPaymentPollingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Simple loading indicator
              Container(
                width: 60,
                height: 60,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  shape: BoxShape.circle,
                ),
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Colors.blue[600],
                ),
              ),
              const SizedBox(height: 20),
              
              Text(
                'Checking Payment',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 12),
              
              Text(
                'Please wait...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),
              
              // Simple progress indicator
              LinearProgressIndicator(
                value: _paymentCheckCount / MAX_PAYMENT_CHECKS,
                backgroundColor: Colors.grey[200],
                color: Colors.blue[600],
              ),
              const SizedBox(height: 24),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _stopPaymentStatusPolling();
                        Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _checkPaymentStatus();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('Check Now'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentTimeoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Payment Status Check Timeout'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.access_time, color: Colors.orange, size: 64),
            SizedBox(height: 16),
            Text('We couldn\'t confirm your payment status automatically.'),
            SizedBox(height: 8),
            Text('If you completed the payment, it may take a few minutes to process.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startPaymentStatusPolling(); // Start polling again
            },
            child: Text('Check Again'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPaymentPendingDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Payment Pending'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_empty, color: Colors.orange, size: 64),
            const SizedBox(height: 16),
            const Text('Your payment is being processed.'),
            const SizedBox(height: 8),
            const Text('Please wait or check again in a few minutes.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _checkPaymentStatus();
            },
            child: const Text('Check Again'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}