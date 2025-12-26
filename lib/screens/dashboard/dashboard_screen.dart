import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/database_provider.dart';
import 'dashboard_provider.dart';
import 'widgets/kpi_card.dart';
import 'widgets/production_chart.dart';
import 'widgets/stock_chart.dart';
import 'widgets/recent_batches_list.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late DashboardProvider _dashboardProvider;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _dashboardProvider = DashboardProvider();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _loading = true);
    final dbProvider = Provider.of<DatabaseProvider>(context, listen: false);
    await _dashboardProvider.loadDashboardData(dbProvider);
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
            tooltip: 'Obnoviť',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome section
                    Text(
                      'Vitajte späť!',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      DateFormat('EEEE, d. MMMM yyyy', 'sk_SK').format(DateTime.now()),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: 24),
                    
                    // KPI Cards
                    Text(
                      'Kľúčové ukazovatele',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    _buildKPIGrid(),
                    const SizedBox(height: 24),
                    
                    // Charts Row
                    Row(
                      children: [
                        Expanded(
                          child: _buildProductionChart(),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildStockChart(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Recent Batches
                    Text(
                      'Nedávne šarže',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    RecentBatchesList(
                      batches: _dashboardProvider.recentBatches,
                    ),
                    const SizedBox(height: 24),
                    
                    // Low Stock Alerts
                    if (_dashboardProvider.lowStockMaterials.isNotEmpty)
                      _buildLowStockAlert(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildKPIGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        KPICard(
          title: 'Šarže dnes',
          value: '${_dashboardProvider.todayBatches}',
          icon: Icons.today,
          color: Colors.blue,
          subtitle: '${_dashboardProvider.todayQuantity} ks',
        ),
        KPICard(
          title: 'Šarže tento mesiac',
          value: '${_dashboardProvider.monthBatches}',
          icon: Icons.calendar_month,
          color: Colors.green,
          subtitle: '${_dashboardProvider.monthQuantity} ks',
        ),
        KPICard(
          title: 'Nízky stav',
          value: '${_dashboardProvider.lowStockCount}',
          icon: Icons.warning,
          color: Colors.orange,
          subtitle: 'materiálov',
        ),
        KPICard(
          title: 'Schválené',
          value: '${_dashboardProvider.approvedBatches}',
          icon: Icons.check_circle,
          color: Colors.teal,
          subtitle: '${_dashboardProvider.approvedPercentage}%',
        ),
      ],
    );
  }

  Widget _buildProductionChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Výroba (7 dní)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: ProductionChart(
                data: _dashboardProvider.weeklyProduction,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Stav skladu',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: StockChart(
                materials: _dashboardProvider.topMaterials,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLowStockAlert() {
    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Text(
                  'Upozornenie na nedostatok',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[900],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
                    ..._dashboardProvider.lowStockMaterials.take(5).map((material) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          material.name,
                          style: TextStyle(color: Colors.orange[900]),
                        ),
                      ),
                      Text(
                        '${material.currentStock} / ${material.minStock} ${material.unit}',
                        style: TextStyle(
                          color: Colors.orange[900],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

