// lib/screens/admin_managematerial.dart
import 'package:flutter/material.dart';
import 'package:home_service_system/firebase_service/material_service.dart';
import 'package:home_service_system/models/material_model.dart';
import 'admin_header.dart';
import 'package:home_service_system/screens/admin_sidebar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:home_service_system/firebase_service/fcm_sercive.dart';
import 'package:home_service_system/screens/admin_notifications_sidebar.dart';

class MaterialManagementPage extends StatefulWidget {
  const MaterialManagementPage({super.key});

  @override
  _MaterialManagementPageState createState() => _MaterialManagementPageState();
}

class _MaterialManagementPageState extends State<MaterialManagementPage> {
  bool _isLoading = true;
  bool _showAddMaterialDialog = false;
  bool _showEditMaterialDialog = false;
  String _searchQuery = '';
  MaterialModel? _selectedMaterial;
  int _selectedIndex = 4; 

  bool _isSidebarCollapsed = false;
  bool _showNotifications = false;

  List<MaterialModel> _materials = [];
  List<MaterialModel> _filteredMaterials = [];
  Map<String, dynamic> _statistics = {};

  final MaterialService _materialService = MaterialService();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadMaterials();
    _initializeFCM();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMaterials() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _materials = await _materialService.getAllMaterials();
      _statistics = await _materialService.getMaterialStatistics();
      _filterMaterials();
    } catch (e) {
      print('Error loading materials: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading materials: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _initializeFCM() async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    await FCMService.initialize(
      userType: UserType.admin,
      userId: currentUser.uid,
    );
  }
}

  void _filterMaterials() {
    _filteredMaterials = _materials.where((material) {
      bool matchesSearch = _searchQuery.isEmpty ||
          material.materialName.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesSearch && material.isActive;
    }).toList();

    setState(() {});
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _filterMaterials();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
        AdminSidebar(
          selectedIndex: _selectedIndex,
          onItemSelected: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          isCollapsed: _isSidebarCollapsed,
          onToggleCollapse: () {
            setState(() {
              _isSidebarCollapsed = !_isSidebarCollapsed;
            });
          },
        ),
          // Main content
          Expanded(
            child: Container(
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
              child: Stack(
                children: [
                  SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: _buildHeader(),
                        ),
                        Expanded(
                          child: _isLoading
                              ? const Center(child: CircularProgressIndicator())
                              : RefreshIndicator(
                                  onRefresh: _loadMaterials,
                                  child: ListView(
                                    padding: const EdgeInsets.all(24.0),
                                    children: [
                                      _buildSearchBar(),
                                      const SizedBox(height: 24),
                                      _buildMaterialsTable(),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                      if (_showNotifications)
                      AdminNotificationsSidebar(
                        adminId: 'admin_000',
                      onClose: () {
                        setState(() {
                        _showNotifications = false;
                        });
                      },
                    ),
                  if (_showAddMaterialDialog) _buildAddMaterialDialog(),
                  if (_showEditMaterialDialog && _selectedMaterial != null) 
                    _buildEditMaterialDialog(_selectedMaterial!),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

Widget _buildHeader() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // 使用新的 header 组件
      AdminHeaderWithNotification(
        title: 'Material Management',
        isSidebarCollapsed: _isSidebarCollapsed,
        onToggleSidebar: () {
          setState(() {
            _isSidebarCollapsed = !_isSidebarCollapsed;
          });
        },
        onNotificationTap: () {
          setState(() {
            _showNotifications = !_showNotifications;
          });
        },
      ),
      
      // 保留统计信息和 Add Material 按钮
      const SizedBox(height: 16),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total: ${_statistics['total'] ?? 0} materials',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add Material'),
            onPressed: () {
              setState(() {
                _showAddMaterialDialog = true;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    ],
  );
}

  Widget _buildSearchBar() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search materials by name...',
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.green, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                onChanged: _onSearchChanged,
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _searchQuery = '';
                });
              },
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reset'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[100],
                foregroundColor: Colors.grey[700],
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialsTable() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Materials List',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _filteredMaterials.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: Text(
                        'No materials found',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 30,
                      headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                      headingTextStyle: const TextStyle(
                        color: Color(0xFF1F2937),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      dataTextStyle: const TextStyle(
                        color: Color(0xFF1F2937),
                        fontSize: 13,
                      ),
                      columns: const [
                        DataColumn(label: Text('Material Name')),
                        DataColumn(label: Text('Unit Price (RM)')),
                        DataColumn(label: Text('Unit')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: _filteredMaterials.map((material) {
                        return DataRow(
                          cells: [
                            DataCell(
                              SizedBox(
                                width: 250,
                                child: Text(
                                  material.materialName,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                            ),
                            DataCell(Text('RM ${material.unitPrice.toStringAsFixed(2)}')),
                            DataCell(Text(material.unit)),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.green, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        _selectedMaterial = material;
                                        _showEditMaterialDialog = true;
                                      });
                                    },
                                    tooltip: 'Edit',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                    onPressed: () => _showDeleteConfirmation(material),
                                    tooltip: 'Delete',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(MaterialModel material) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Delete'),
        content: Text('Are you sure you want to delete "${material.materialName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              bool success = await _materialService.deleteMaterial(material.materialID);
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Material deleted successfully'),
                    backgroundColor: Colors.green,
                  ),
                );
                _loadMaterials();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to delete material'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildAddMaterialDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final unitPriceController = TextEditingController();
    String selectedUnit = MaterialUnit.pieces;
    bool isLoading = false;

    return StatefulBuilder(
      builder: (context, setDialogState) {
        return Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: Card(
                margin: const EdgeInsets.all(24),
                child: Container(
                  width: 500,
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Add New Material',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  setState(() {
                                    _showAddMaterialDialog = false;
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: 'Material Name *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.inventory),
                            ),
                            validator: (value) =>
                                value?.isEmpty ?? true ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: unitPriceController,
                                  decoration: const InputDecoration(
                                    labelText: 'Unit Price (RM) *',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.attach_money),
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  validator: (value) {
                                    if (value?.isEmpty ?? true) return 'Required';
                                    if (double.tryParse(value!) == null) return 'Invalid price';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: selectedUnit,
                                  decoration: const InputDecoration(
                                    labelText: 'Unit *',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: MaterialUnit.getAllUnits()
                                      .map((unit) => DropdownMenuItem(
                                            value: unit,
                                            child: Text(unit),
                                          ))
                                      .toList(),
                                  onChanged: (value) {
                                    setDialogState(() {
                                      selectedUnit = value!;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: isLoading
                                    ? null
                                    : () {
                                        setState(() {
                                          _showAddMaterialDialog = false;
                                        });
                                      },
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: isLoading
                                    ? null
                                    : () async {
                                        if (formKey.currentState!.validate()) {
                                          setDialogState(() {
                                            isLoading = true;
                                          });

                                          try {
                                            final material = MaterialModel(
                                              materialID: '',
                                              materialName: nameController.text.trim(),
                                              unit: selectedUnit,
                                              unitPrice: double.parse(unitPriceController.text),
                                              createdAt: DateTime.now(),
                                              updatedAt: DateTime.now(),
                                            );

                                            String? materialId =
                                                await _materialService.createMaterial(material);

                                            if (materialId != null) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Material created successfully!'),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                              setState(() {
                                                _showAddMaterialDialog = false;
                                              });
                                              _loadMaterials();
                                            } else {
                                              throw Exception('Failed to create material');
                                            }
                                          } catch (e) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Error: $e'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }

                                          setDialogState(() {
                                            isLoading = false;
                                          });
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Create Material'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditMaterialDialog(MaterialModel material) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: material.materialName);
    final unitPriceController = TextEditingController(text: material.unitPrice.toString());
    String selectedUnit = material.unit;
    bool isLoading = false;

    return StatefulBuilder(
      builder: (context, setDialogState) {
        return Positioned.fill(
          child: Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: Card(
                margin: const EdgeInsets.all(24),
                child: Container(
                  width: 500,
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Edit Material',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  setState(() {
                                    _showEditMaterialDialog = false;
                                    _selectedMaterial = null;
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: nameController,
                            decoration: const InputDecoration(
                              labelText: 'Material Name *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.inventory),
                            ),
                            validator: (value) =>
                                value?.isEmpty ?? true ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: unitPriceController,
                                  decoration: const InputDecoration(
                                    labelText: 'Unit Price (RM) *',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.attach_money),
                                  ),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  validator: (value) {
                                    if (value?.isEmpty ?? true) return 'Required';
                                    if (double.tryParse(value!) == null) return 'Invalid price';
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: selectedUnit,
                                  decoration: const InputDecoration(
                                    labelText: 'Unit *',
                                    border: OutlineInputBorder(),
                                  ),
                                  items: MaterialUnit.getAllUnits()
                                      .map((unit) => DropdownMenuItem(
                                            value: unit,
                                            child: Text(unit),
                                          ))
                                      .toList(),
                                  onChanged: (value) {
                                    setDialogState(() {
                                      selectedUnit = value!;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: isLoading
                                    ? null
                                    : () {
                                        setState(() {
                                          _showEditMaterialDialog = false;
                                          _selectedMaterial = null;
                                        });
                                      },
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: isLoading
                                    ? null
                                    : () async {
                                        if (formKey.currentState!.validate()) {
                                          setDialogState(() {
                                            isLoading = true;
                                          });

                                          try {
                                            final updatedMaterial = material.copyWith(
                                              materialName: nameController.text.trim(),
                                              unit: selectedUnit,
                                              unitPrice: double.parse(unitPriceController.text),
                                            );

                                            bool success =
                                                await _materialService.updateMaterial(updatedMaterial);

                                            if (success) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Material updated successfully!'),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                              setState(() {
                                                _showEditMaterialDialog = false;
                                                _selectedMaterial = null;
                                              });
                                              _loadMaterials();
                                            } else {
                                              throw Exception('Failed to update material');
                                            }
                                          } catch (e) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Error: $e'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }

                                          setDialogState(() {
                                            isLoading = false;
                                          });
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                ),
                                child: isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Update Material'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}