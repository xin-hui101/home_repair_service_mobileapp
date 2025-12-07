// lib/screens/quotation_form_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/quotation_models.dart';
import '../models/material_model.dart';
import '../firebase_service/quotation_service.dart';
import '../firebase_service/material_service.dart';
import '../models/models.dart';

class QuotationFormPage extends StatefulWidget {
  final BookingData booking;
  final TechnicianModel technician;

  const QuotationFormPage({
    super.key,
    required this.booking,
    required this.technician,
  });

  @override
  _QuotationFormPageState createState() => _QuotationFormPageState();
}

class _QuotationFormPageState extends State<QuotationFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _materialService = MaterialService();

  // Form controllers
  final _problemAssessmentController = TextEditingController();
  final _recommendedSolutionController = TextEditingController();
  final _discountController = TextEditingController(text: '0');
  final _installationFeeController = TextEditingController(text: '0');
  final _transportationFeeController = TextEditingController(text: '0');

  // Items lists
  List<QuotationItem> _materialItems = [];
  List<MaterialModel> _availableMaterials = [];
  
  double _taxRate = 0.08; // Fixed 8% tax
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableMaterials();
  }

  Future<void> _loadAvailableMaterials() async {
    try {
      _availableMaterials = await _materialService.getActiveMaterials();
      setState(() {});
    } catch (e) {
      print('Error loading materials: $e');
    }
  }

  @override
  void dispose() {
    _problemAssessmentController.dispose();
    _recommendedSolutionController.dispose();
    _installationFeeController.dispose();
    _transportationFeeController.dispose();
    _discountController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  double get _materialSubtotal => _materialItems.fold(0.0, (sum, item) => sum + item.totalPrice);
  double get _installationFee => double.tryParse(_installationFeeController.text) ?? 0.0;
  double get _transportationFee => double.tryParse(_transportationFeeController.text) ?? 0.0;
  double get _subtotal => _materialSubtotal + _installationFee + _transportationFee;
  double get _taxAmount => _subtotal * _taxRate;
  double get _discount => double.tryParse(_discountController.text) ?? 0.0;
  double get _grandTotal => _subtotal + _taxAmount - _discount;

  void _addMaterialItem() {
    _showAddItemDialog();
  }

  void _showAddItemDialog() {
    showDialog(
      context: context,
      builder: (context) => _MaterialSelectionDialog(
        availableMaterials: _availableMaterials,
        onAdd: (item) {
          setState(() {
            _materialItems.add(item);
          });
        },
      ),
    );
  }

  Future<void> _sendQuotation() async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.booking.bookingID == null || widget.booking.bookingID!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: Booking ID is missing'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_problemAssessmentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Problem Assessment is required'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_recommendedSolutionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Recommended Solution is required'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      print('Starting to send quotation...');
      final quotationService = Provider.of<QuotationService>(context, listen: false);
      
      final quotation = QuotationData(
        quotationId: '',
        bookingId: widget.booking.bookingID!,
        technicianId: widget.technician.technicianID,
        technicianName: widget.technician.technicianName,
        problemAssessment: _problemAssessmentController.text.trim(),
        recommendedSolution: _recommendedSolutionController.text.trim(),
        materialItems: _materialItems,
        laborItems: [],
        installationFee: _installationFee,
        transportationFee: _transportationFee,
        taxRate: _taxRate,
        discountAmount: _discount,
        createdAt: DateTime.now(),
      );

      print('Creating quotation...');
      final quotationId = await quotationService.createQuotation(quotation);
      
      if (quotationId == null || quotationId.isEmpty) {
        throw Exception('Failed to create quotation - No ID returned');
      }

      print('Quotation created with ID: $quotationId');
      
      print('Sending quotation...');
      final sendSuccess = await quotationService.sendQuotation(quotationId);
      
      if (sendSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Quotation sent successfully! Booking status updated.'), 
            backgroundColor: Colors.green
          ),
        );
        Navigator.pop(context, true);
      } else {
        throw Exception('Failed to send quotation');
      }
    } catch (e) {
      print('Error in _sendQuotation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create Quotation'),
        elevation: 0,
        actions: [
          SizedBox(width: 8),
          ElevatedButton.icon(
            icon: Icon(Icons.send),
            label: Text('Send'),
            onPressed: _isLoading ? null : _sendQuotation,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Scrollbar(
                controller: _scrollController,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBookingInfo(),
                      SizedBox(height: 24),
                      _buildAssessmentSection(),
                      SizedBox(height: 24),
                      _buildMaterialsSection(),
                      SizedBox(height: 24),
                      _buildOthersFeesSection(),
                      SizedBox(height: 24),
                      _buildDiscountSection(),
                      SizedBox(height: 24),
                      _buildCalculationSummarySection(),
                      SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildBookingInfo() {
    // 检测屏幕宽度
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 600;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Booking Information', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 12),
            
            if (isCompact)
              // 垂直布局 - 手机
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Booking ID: ${widget.booking.bookingID}', 
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Customer: ${widget.booking.userName}'),
                  SizedBox(height: 4),
                  Text('Service: ${widget.booking.serviceName}'),
                  SizedBox(height: 4),
                  Text('Phone: ${widget.booking.userPhone}'),
                  SizedBox(height: 4),
                  Text('Address: ${widget.booking.bookingAddress}'),
                  SizedBox(height: 4),
                  Text('Technician: ${widget.technician.technicianName}'),
                ],
              )
            else
              // 水平布局 - 平板/桌面
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Booking ID: ${widget.booking.bookingID}', 
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('Customer: ${widget.booking.userName}'),
                        Text('Service: ${widget.booking.serviceName}'),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Phone: ${widget.booking.userPhone}'),
                        Text('Address: ${widget.booking.bookingAddress}'),
                        Text('Technician: ${widget.technician.technicianName}'),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssessmentSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Site Assessment', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 16),
            TextFormField(
              controller: _problemAssessmentController,
              decoration: InputDecoration(
                labelText: 'Problem Assessment *',
                hintText: 'Describe the issues found during assessment...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (value) => value?.isEmpty ?? true ? 'Required field' : null,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _recommendedSolutionController,
              decoration: InputDecoration(
                labelText: 'Recommended Solution *',
                hintText: 'Describe the proposed solution...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (value) => value?.isEmpty ?? true ? 'Required field' : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialsSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 600;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 响应式标题和按钮布局
            if (isCompact)
              // 手机:垂直堆叠
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Materials Fee', style: Theme.of(context).textTheme.titleLarge),
                  SizedBox(height: 12),
                  ElevatedButton.icon(
                    icon: Icon(Icons.add, size: 16, color: Colors.black),
                    label: Text('Add Material'),
                    onPressed: _addMaterialItem,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.yellow,
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                  ),
                ],
              )
            else
              // 平板/桌面:水平排列
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Materials Fee', style: Theme.of(context).textTheme.titleLarge),
                  ElevatedButton.icon(
                    icon: Icon(Icons.add, size: 16, color: Colors.black),
                    label: Text('Add Material'),
                    onPressed: _addMaterialItem,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.yellow,
                      foregroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    ),
                  ),
                ],
              ),
            
            SizedBox(height: 12),
            
            if (_materialItems.isEmpty)
              Container(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text('No materials added', style: TextStyle(color: Colors.grey)),
                ),
              )
            else
              Column(
                children: _materialItems.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  return _buildMaterialItemCard(item, index, isCompact);
                }).toList(),
              ),
            
            if (_materialItems.isNotEmpty) ...[
              Divider(),
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Materials Fee Subtotal:', 
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(
                      'RM${_materialSubtotal.toStringAsFixed(2)}', 
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialItemCard(QuotationItem item, int index, bool isCompact) {
    if (isCompact) {
      // 紧凑布局 - 手机
      return Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    item.description, 
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete, color: Colors.red, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                  onPressed: () {
                    setState(() {
                      _materialItems.removeAt(index);
                    });
                  },
                ),
              ],
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Qty: ${item.quantity} ${item.unit}', 
                    style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                Text('@ RM${item.unitPrice.toStringAsFixed(2)}', 
                    style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                Text('RM${item.totalPrice.toStringAsFixed(2)}', 
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      );
    } else {
      // 宽屏布局 - 平板/桌面
      return Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(item.description, style: TextStyle(fontWeight: FontWeight.w500)),
            ),
            Expanded(
              child: Text('${item.quantity} ${item.unit}', textAlign: TextAlign.center),
            ),
            Expanded(
              child: Text('RM${item.unitPrice.toStringAsFixed(2)}', textAlign: TextAlign.center),
            ),
            Expanded(
              child: Text('RM${item.totalPrice.toStringAsFixed(2)}', 
                    textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            IconButton(
              icon: Icon(Icons.delete, color: Colors.red, size: 20),
              onPressed: () {
                setState(() {
                  _materialItems.removeAt(index);
                });
              },
            ),
          ],
        ),
      );
    }
  }

  Widget _buildOthersFeesSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Others Fee', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 16),
            
            TextFormField(
              controller: _installationFeeController,
              decoration: InputDecoration(
                labelText: 'Installation/Labor Fee (RM)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) => setState(() {}),
            ),
            SizedBox(height: 12),
            
            TextFormField(
              controller: _transportationFeeController,
              decoration: InputDecoration(
                labelText: 'Transportation Fee (RM)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) => setState(() {}),
            ),
            SizedBox(height: 16),
            
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Tax Rate:', style: TextStyle(fontSize: 16)),
                  Text('8% (Fixed)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscountSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Discount', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 16),
            
            TextFormField(
              controller: _discountController,
              decoration: InputDecoration(
                labelText: 'Discount (RM)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              onChanged: (value) => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalculationSummarySection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Cost Summary', style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: 16),
            
            _buildCalculationRow('Materials Fee:', _materialSubtotal),
            _buildCalculationRow('Installation/Labor Fee:', _installationFee),
            _buildCalculationRow('Transportation Fee:', _transportationFee),
            _buildCalculationRow('Tax (8%):', _taxAmount),
            if (_discount > 0) _buildCalculationRow('Discount:', -_discount),
            Divider(thickness: 2),
            _buildCalculationRow('TOTAL:', _grandTotal, isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildCalculationRow(String label, double amount, {bool isTotal = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(label, style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 18 : 16,
            )),
          ),
          Text('RM${amount.toStringAsFixed(2)}', style: TextStyle(
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            fontSize: isTotal ? 18 : 16,
            color: isTotal ? Colors.red : null,
          )),
        ],
      ),
    );
  }
}

// Material Selection Dialog
class _MaterialSelectionDialog extends StatefulWidget {
  final List<MaterialModel> availableMaterials;
  final Function(QuotationItem) onAdd;

  const _MaterialSelectionDialog({
    required this.availableMaterials,
    required this.onAdd,
  });

  @override
  State<_MaterialSelectionDialog> createState() => _MaterialSelectionDialogState();
}

class _MaterialSelectionDialogState extends State<_MaterialSelectionDialog> {
  bool _useCustom = false;
  MaterialModel? _selectedMaterial;

  final _customDescriptionController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _customUnitPriceController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    // 检测屏幕尺寸
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 600;

    return AlertDialog(
      title: Text('Add Material'),
      content: SizedBox(
        width: isCompact ? double.maxFinite : 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Toggle between database and custom - 响应式
              if (isCompact)
                // 手机:垂直堆叠按钮
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      icon: Icon(Icons.inventory, color: Colors.black),
                      label: Text('From Database'),
                      onPressed: () {
                        setState(() {
                          _useCustom = false;
                          _selectedMaterial = null;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: !_useCustom ? Colors.yellow : Colors.grey[200],
                        foregroundColor: Colors.black,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    SizedBox(height: 8),
                    ElevatedButton.icon(
                      icon: Icon(Icons.edit, color: Colors.black),
                      label: Text('Custom Item'),
                      onPressed: () {
                        setState(() {
                          _useCustom = true;
                          _selectedMaterial = null;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _useCustom ? Colors.yellow : Colors.grey[200],
                        foregroundColor: Colors.black,
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                )
              else
                // 平板/桌面:使用 SegmentedButton
                SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(
                      value: false,
                      label: Text('From Database'),
                      icon: Icon(Icons.inventory, color: Colors.black),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('Custom Item'),
                      icon: Icon(Icons.edit, color: Colors.black),
                    ),
                  ],
                  selected: {_useCustom},
                  onSelectionChanged: (Set<bool> selection) {
                    setState(() {
                      _useCustom = selection.first;
                      _selectedMaterial = null;
                    });
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith<Color>(
                      (Set<WidgetState> states) {
                        if (states.contains(WidgetState.selected)) {
                          return Colors.yellow;
                        }
                        return Colors.grey[200]!;
                      },
                    ),
                    foregroundColor: WidgetStateProperty.all(Colors.black),
                  ),
                ),
              
              SizedBox(height: 16),

              if (!_useCustom) ...[
                // Database selection
                DropdownButtonFormField<MaterialModel>(
                  value: _selectedMaterial,
                  decoration: InputDecoration(
                    labelText: 'Select Material *',
                    border: OutlineInputBorder(),
                  ),
                  isExpanded: true,
                  items: widget.availableMaterials.map((material) {
                    return DropdownMenuItem(
                      value: material,
                      child: Text(
                        '${material.materialName} - RM${material.unitPrice.toStringAsFixed(2)}/${material.unit}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedMaterial = value;
                    });
                  },
                ),
              ] else ...[
                // Custom item
                TextFormField(
                  controller: _customDescriptionController,
                  decoration: InputDecoration(
                    labelText: 'Description *',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                SizedBox(height: 12),
                TextFormField(
                  controller: _customUnitPriceController,
                  decoration: InputDecoration(
                    labelText: 'Unit Price (RM) *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                ),
              ],

              SizedBox(height: 12),
              TextFormField(
                controller: _quantityController,
                decoration: InputDecoration(
                  labelText: 'Quantity *',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (!_useCustom && _selectedMaterial == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Please select a material'), backgroundColor: Colors.red),
              );
              return;
            }

            if (_useCustom && _customDescriptionController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Please enter a description'), backgroundColor: Colors.red),
              );
              return;
            }

            if (_quantityController.text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Please enter quantity'), backgroundColor: Colors.red),
              );
              return;
            }

            final quantity = int.tryParse(_quantityController.text) ?? 0;
            if (quantity <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Quantity must be greater than 0'), backgroundColor: Colors.red),
              );
              return;
            }

            QuotationItem item;
            
            if (_useCustom) {
              final unitPrice = double.tryParse(_customUnitPriceController.text) ?? 0.0;
              if (unitPrice <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Unit price must be greater than 0'), backgroundColor: Colors.red),
                );
                return;
              }
              
              item = QuotationItem(
                description: _customDescriptionController.text,
                quantity: quantity,
                unitPrice: unitPrice,
                unit: 'pieces',
              );
            } else {
              item = QuotationItem(
                description: _selectedMaterial!.materialName,
                quantity: quantity,
                unitPrice: _selectedMaterial!.unitPrice,
                unit: _selectedMaterial!.unit,
              );
            }

            widget.onAdd(item);
            Navigator.pop(context);
          },
          child: Text('Add'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _customDescriptionController.dispose();
    _quantityController.dispose();
    _customUnitPriceController.dispose();
    super.dispose();
  }
}