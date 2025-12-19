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
    final isTablet = screenSize.width > 800;
    final isSmallScreen = screenSize.height < 700;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1E3A5F),
              const Color(0xFF2C5282),
              const Color(0xFF1A365D),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: isSmallScreen ? 32.0 : 48.0,
                    left: 24.0,
                    right: 24.0,
                    bottom: 24.0,
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.factory,
                              size: 48,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PWMS',
                                style: TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 2,
                                ),
                              ),
                              Text(
                                'Production & Warehouse Management',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.8),
                                  fontWeight: FontWeight.w300,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 48),
                      Text(
                        'Vyberte sekciu',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Správa výroby a skladu betónových prvkov',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.7),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 48.0 : 24.0,
                  vertical: 24.0,
                ),
                sliver: isTablet
                    ? SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 2.5,
                          crossAxisSpacing: 24,
                          mainAxisSpacing: 24,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _MenuCard(
                            menuItem: _menuItems[index],
                            onTap: () => _navigateToScreen(context, index),
                          ),
                          childCount: _menuItems.length,
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _MenuCard(
                              menuItem: _menuItems[index],
                              onTap: () => _navigateToScreen(context, index),
                            ),
                          ),
                          childCount: _menuItems.length,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToScreen(BuildContext context, int index) {
    final routes = [
      () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ProductionScreen()),
          ),
      () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const WarehouseScreen()),
          ),
      () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const QRCodeScreen()),
          ),
      () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BatchesScreen()),
          ),
      () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ProductionPlansScreen(),
            ),
          ),
      () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ReportsScreen()),
          ),
      () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NotificationsScreen(),
            ),
          ),
    ];
    routes[index]();
  }

  static const List<_MenuItem> _menuItems = [
    _MenuItem(
      title: 'Výroba',
      subtitle: 'Evidencia a správa výroby',
      icon: Icons.inventory_2_rounded,
      color: Color(0xFF10B981),
      gradient: [Color(0xFF10B981), Color(0xFF059669)],
    ),
    _MenuItem(
      title: 'Sklad',
      subtitle: 'Správa zásob materiálov',
      icon: Icons.warehouse_rounded,
      color: Color(0xFFF59E0B),
      gradient: [Color(0xFFF59E0B), Color(0xFFD97706)],
    ),
    _MenuItem(
      title: 'QR Kód',
      subtitle: 'Skenovanie a generovanie QR kódov',
      icon: Icons.qr_code_2_rounded,
      color: Color(0xFF8B5CF6),
      gradient: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
    ),
    _MenuItem(
      title: 'Šarže',
      subtitle: 'Sledovanie a správa šarží',
      icon: Icons.inventory_rounded,
      color: Color(0xFF14B8A6),
      gradient: [Color(0xFF14B8A6), Color(0xFF0D9488)],
    ),
    _MenuItem(
      title: 'Výrobné plány',
      subtitle: 'Plánovanie a kalendár výroby',
      icon: Icons.calendar_month_rounded,
      color: Color(0xFF6366F1),
      gradient: [Color(0xFF6366F1), Color(0xFF4F46E5)],
    ),
    _MenuItem(
      title: 'Reporty',
      subtitle: 'Analýzy a prehľady',
      icon: Icons.analytics_rounded,
      color: Color(0xFF9333EA),
      gradient: [Color(0xFF9333EA), Color(0xFF7E22CE)],
    ),
    _MenuItem(
      title: 'Notifikácie',
      subtitle: 'Upozornenia a varovania',
      icon: Icons.notifications_active_rounded,
      color: Color(0xFFEF4444),
      gradient: [Color(0xFFEF4444), Color(0xFFDC2626)],
    ),
  ];
}

class _MenuItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<Color> gradient;

  const _MenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.gradient,
  });
}

class _MenuCard extends StatefulWidget {
  final _MenuItem menuItem;
  final VoidCallback onTap;

  const _MenuCard({
    required this.menuItem,
    required this.onTap,
  });

  @override
  State<_MenuCard> createState() => _MenuCardState();
}

class _MenuCardState extends State<_MenuCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        transform: Matrix4.identity()
          ..scale(_isHovered ? 1.02 : 1.0),
        child: Card(
          elevation: _isHovered ? 12 : 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    Colors.grey.shade50,
                  ],
                ),
                boxShadow: _isHovered
                    ? [
                        BoxShadow(
                          color: widget.menuItem.color.withOpacity(0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : [],
              ),
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: widget.menuItem.gradient,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: widget.menuItem.color.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.menuItem.icon,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.menuItem.title,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: widget.menuItem.color,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.menuItem.subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isHovered ? 0.25 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: widget.menuItem.color,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
