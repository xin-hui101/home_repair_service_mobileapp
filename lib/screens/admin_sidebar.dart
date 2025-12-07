import 'package:flutter/material.dart';
import 'package:home_service_system/screens/admin_dashboardpage.dart';
import 'package:home_service_system/screens/admin_manageuserpage.dart';
import 'package:home_service_system/screens/admin_servicerequestpage.dart';
import 'package:home_service_system/screens/admin_techniciansch.dart';
import 'package:home_service_system/screens/admin_managematerial.dart';
import 'package:home_service_system/screens/admin_reports_page.dart';
import 'package:home_service_system/screens/welcome_page.dart';

class AdminSidebar extends StatefulWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final bool isCollapsed;
  final VoidCallback onToggleCollapse;

  const AdminSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.isCollapsed = false,
    required this.onToggleCollapse,
  });

  @override
  State<AdminSidebar> createState() => _AdminSidebarState();
}

class _AdminSidebarState extends State<AdminSidebar> {
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: widget.isCollapsed ? 0 : 280, // ✨ 完全隐藏：宽度设为 0
      color: const Color(0xFF1F2937),
      child: widget.isCollapsed 
          ? const SizedBox.shrink() // ✨ 折叠时完全不渲染内容
          : SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Logo and Title
                  const Icon(
                    Icons.home_repair_service,
                    size: 100,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                      'Home Repair Service\nBooking System',
                      style: TextStyle(
                        color: Colors.yellow,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Navigation items
                  Expanded(
                    child: ListView(
                      children: [
                        _buildNavItem(
                          index: 0,
                          title: 'Dashboard',
                          icon: Icons.dashboard_outlined,
                        ),
                        _buildNavItem(
                          index: 1,
                          title: 'Service Request Management',
                          icon: Icons.assignment_outlined,
                        ),
                        _buildNavItem(
                          index: 2,
                          title: 'Technician Schedule',
                          icon: Icons.calendar_today,
                        ),
                        _buildNavItem(
                          index: 3,
                          title: 'User Management',
                          icon: Icons.people_outline,
                        ),
                        _buildNavItem(
                          index: 4,
                          title: 'Material Management',
                          icon: Icons.inventory_2_outlined,
                        ),
                        _buildNavItem(
                          index: 5,
                          title: 'Reports',
                          icon: Icons.assessment_outlined,
                        ),
                      ],
                    ),
                  ),
                  
                  // Logout button
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: InkWell(
                      onTap: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const WelcomePage()),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12.0,
                          horizontal: 16.0,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.logout, color: Colors.white),
                            SizedBox(width: 12),
                            Text(
                              'Logout',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ✨ 只有展开状态的布局（折叠时不会调用这个方法）
  Widget _buildNavItem({
    required int index,
    required String title,
    required IconData icon,
  }) {
    final isSelected = widget.selectedIndex == index;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: InkWell(
        onTap: () {
          widget.onItemSelected(index);
          _navigateToPage(index);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.withOpacity(0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              // Icon with fixed size
              SizedBox(
                width: 24,
                height: 24,
                child: Icon(
                  icon,
                  color: isSelected ? Colors.white : Colors.grey,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Title text
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToPage(int index) {
    // Get current route name to avoid unnecessary navigation
    final currentRoute = ModalRoute.of(context)?.settings.name;
    
    Widget? targetPage;
    String? targetRoute;
    
    switch (index) {
      case 0:
        targetPage = const AdminDashboardPage();
        targetRoute = '/admin_dashboard';
        break;
      case 1:
        targetPage = const ServiceRequestManagementPage();
        targetRoute = '/service_request';
        break;
      case 2:
        targetPage = const TechnicianSchedulePage();
        targetRoute = '/technician_schedule';
        break;
      case 3:
        targetPage = const UserManagementPage();
        targetRoute = '/user_management';
        break;
      case 4:
        targetPage = const MaterialManagementPage();
        targetRoute = '/material_management';
        break;
      case 5:
        targetPage = const AdminReportsPage();
        targetRoute = '/reports';
        break;
    }
    
    // Only navigate if we're not already on that page
    if (targetPage != null && currentRoute != targetRoute) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => targetPage!,
          settings: RouteSettings(name: targetRoute),
        ),
      );
    }
  }
}