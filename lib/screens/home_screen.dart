import 'package:flutter/material.dart';
import 'production_screen.dart';
import 'warehouse_screen.dart';
import 'qrcode_screen.dart';
import 'batches_screen.dart';
import 'production_plans_screen.dart';
import 'reports_screen.dart';
import 'notifications_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;
    final padding = isSmallScreen ? 16.0 : 32.0;
    final spacing = isSmallScreen ? 16.0 : 24.0;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.blue.shade700,
              Colors.blue.shade900,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: screenSize.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
              ),
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: isSmallScreen ? 20 : 40),
                    const Text(
                      'PWMS',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Vyberte sekciu',
                      style: TextStyle(
                        fontSize: 24,
                        color: Colors.white70,
                      ),
                    ),
                    SizedBox(height: spacing),
                    _MenuCard(
                      title: 'Výroba',
                      icon: Icons.inventory_2,
                      color: Colors.green,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProductionScreen(),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: spacing),
                    _MenuCard(
                      title: 'Sklad',
                      icon: Icons.warehouse,
                      color: Colors.orange,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const WarehouseScreen(),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: spacing),
                    _MenuCard(
                      title: 'QR Kód',
                      icon: Icons.qr_code,
                      color: Colors.purple,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const QRCodeScreen(),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: spacing),
                    _MenuCard(
                      title: 'Šarže',
                      icon: Icons.inventory,
                      color: Colors.teal,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BatchesScreen(),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: spacing),
                    _MenuCard(
                      title: 'Výrobné plány',
                      icon: Icons.calendar_today,
                      color: Colors.indigo,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProductionPlansScreen(),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: spacing),
                    _MenuCard(
                      title: 'Reporty',
                      icon: Icons.analytics,
                      color: Colors.deepPurple,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ReportsScreen(),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: spacing),
                    _MenuCard(
                      title: 'Notifikácie',
                      icon: Icons.notifications,
                      color: Colors.red,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const NotificationsScreen(),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: isSmallScreen ? 20 : 40),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MenuCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700;
    final isNarrowScreen = screenSize.width < 600;

    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(isSmallScreen ? 20.0 : 32.0),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: isSmallScreen ? 36 : 48,
                  color: color,
                ),
              ),
              SizedBox(width: isSmallScreen ? 16 : 24),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 22 : 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              if (!isNarrowScreen)
                Icon(
                  Icons.arrow_forward_ios,
                  color: color,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
