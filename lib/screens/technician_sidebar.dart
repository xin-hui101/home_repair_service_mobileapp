import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:home_service_system/screens/welcome_page.dart';

// ========== TECHNICIAN HEADER ==========

class TechnicianHeader extends StatelessWidget {
  final String title;
  final bool isSidebarCollapsed;
  final VoidCallback onToggleSidebar;
  final Widget? trailing;

  const TechnicianHeader({
    super.key,
    required this.title,
    required this.isSidebarCollapsed,
    required this.onToggleSidebar,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            // Menu toggle button
            IconButton(
              icon: Icon(
                isSidebarCollapsed ? Icons.menu : Icons.menu_open,
                size: 28,
                color: const Color(0xFF1F2937),
              ),
              onPressed: onToggleSidebar,
              tooltip: isSidebarCollapsed ? 'Expand sidebar' : 'Collapse sidebar',
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),
          ],
        ),
        trailing ?? const SizedBox(),
      ],
    );
  }
}

// ========== TECHNICIAN HEADER WITH NOTIFICATION ==========

class TechnicianHeaderWithNotification extends StatelessWidget {
  final String title;
  final bool isSidebarCollapsed;
  final VoidCallback onToggleSidebar;
  final int notificationCount;
  final VoidCallback onNotificationTap;

  const TechnicianHeaderWithNotification({
    super.key,
    required this.title,
    required this.isSidebarCollapsed,
    required this.onToggleSidebar,
    required this.notificationCount,
    required this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    return TechnicianHeader(
      title: title,
      isSidebarCollapsed: isSidebarCollapsed,
      onToggleSidebar: onToggleSidebar,
      trailing: Stack(
        children: [
          IconButton(
            icon: const Icon(
              Icons.notifications_outlined,
              size: 28,
              color: Color(0xFF1F2937),
            ),
            onPressed: onNotificationTap,
          ),
          if (notificationCount > 0)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  notificationCount > 99 ? '99+' : notificationCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ========== TECHNICIAN SIDEBAR ==========

class TechnicianSidebar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final bool isCollapsed;
  final String technicianName;
  final VoidCallback? onCollapse; // 新增：收起回调

  const TechnicianSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    this.isCollapsed = false,
    required this.technicianName,
    this.onCollapse, // 新增参数
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isCollapsed ? 0 : 280,
      color: const Color(0xFF1F2937),
      child: isCollapsed
          ? const SizedBox.shrink()
          : SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // 收起按钮 - 独立一行在图标上方
                  if (onCollapse != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16.0),
                        child: IconButton(
                          icon: const Icon(
                            Icons.arrow_back_ios,
                            size: 20,
                            color: Colors.white,
                          ),
                          onPressed: onCollapse,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Collapse sidebar',
                        ),
                      ),
                    ),
                  // Logo图标
                  Icon(
                    Icons.home_repair_service,
                    size: 100,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
                  const SizedBox(height: 20),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0),
                    padding: const EdgeInsets.all(12.0),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Technician',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                technicianName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildNavItem(0, 'My Schedule', Icons.calendar_today),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: InkWell(
                      onTap: () {
                        FirebaseAuth.instance.signOut();
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const WelcomePage()),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: const [
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

  Widget _buildNavItem(int index, String title, IconData icon) {
    final isSelected = selectedIndex == index;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: InkWell(
        onTap: () {
          onItemSelected(index);
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
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey,
                size: 24,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}