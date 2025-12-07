import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; 
import 'login_page.dart';
import 'register_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Get device dimensions for responsive design
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      // 确保背景渐变应用于整个页面
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              // 使用LayoutBuilder获取实际可用空间
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      children: [
                        // 顶部Logo和标题区域
                        Padding(
                          padding: EdgeInsets.only(top: size.height * 0.05),
                          child: Column(
                            children: [
                              // App logo
                              Icon(
                                Icons.home_repair_service,
                                size: size.width * 0.2 > 100 ? 100 : size.width * 0.2,
                                color: Colors.black,
                              ),
                              SizedBox(height: 10),
                              // App name
                              Text(
                                'Home Repair Service\nBooking System',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.blue[900],
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // 中间图片和标语区域 - 使用Expanded确保空间分配
                        Expanded(
                          flex: 3,
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 20.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // 图片容器 - 使用AspectRatio确保比例正确
                                Expanded(
                                  child: AspectRatio(
                                    aspectRatio: 16 / 9, // 使用标准宽高比
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 20.0),
                                      child: Image.asset(
                                        'assets/images/repairpic.png',  
                                        fit: BoxFit.contain, // 改为contain以确保完整显示
                                        errorBuilder: (context, error, stackTrace) {
                                          // 如果图片加载失败，显示占位图标
                                          return Container(
                                            color: Colors.grey[200],
                                            child: Center(
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.construction,
                                                    size: 80,
                                                    color: Colors.blue[300],
                                                  ),
                                                  SizedBox(height: 10),
                                                  Text(
                                                    'Repair Service Image',
                                                    style: TextStyle(
                                                      color: Colors.blue[300],
                                                      fontSize: 16,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 20),
                                // Tagline
                                Text(
                                  'Your trusted repair partner',
                                  style: TextStyle(
                                    color: Colors.black87,
                                    fontSize: 18,
                                     fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // 底部按钮区域
                        Padding(
                          padding: EdgeInsets.only(bottom: size.height * 0.05),
                          child: Column(
                            children: [
                              // Login button
                              _buildButton(
                                context,
                                'Login',
                                Icons.login,
                                Colors.blue[900]!,
                                Colors.yellow[600]!,
                                () => Navigator.push(
                                  context,
                                  CupertinoPageRoute(builder: (context) => LoginPage()),
                                ),
                              ),
                              SizedBox(height: 16),
                              // Register button
                              _buildButton(
                                context,
                                'Register',
                                Icons.person_add,
                                Colors.blue[900]!,
                                Colors.white,
                                () => Navigator.push(
                                  context,
                                  CupertinoPageRoute(builder: (context) => RegisterPage()),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
          ),
        ),
      ),
    );
  }

  Widget _buildButton(
    BuildContext context,
    String text,
    IconData icon,
    Color textColor,
    Color bgColor,
    VoidCallback onPressed,
  ) {
    final size = MediaQuery.of(context).size;
    return SizedBox(
      width: size.width * 0.8,
      height: 55,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 5,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon),
            SizedBox(width: 10),
            Text(
              text,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}