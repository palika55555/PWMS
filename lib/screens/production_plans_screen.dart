import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/production_plan.dart';
import '../services/api_service.dart';
import 'production_plan_form_screen.dart';

class ProductionPlansScreen extends StatefulWidget {
  const ProductionPlansScreen({super.key});

  @override
  State<ProductionPlansScreen> createState() => _ProductionPlansScreenState();
}

class _ProductionPlansScreenState extends State<ProductionPlansScreen> {
  List<ProductionPlan> _plans = [];
  bool _isLoading = true;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final plans = await apiService.getProductionPlans();
      setState(() {
        _plans = plans;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba pri načítaní plánov: $e')),
        );
      }
    }
  }

  List<ProductionPlan> _getPlansForDay(DateTime day) {
    return _plans.where((plan) {
      return plan.plannedDate.year == day.year &&
          plan.plannedDate.month == day.month &&
          plan.plannedDate.day == day.day;
    }).toList();
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'urgent':
        return Colors.red;
      case 'normal':
        return Colors.blue;
      case 'low':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Colors.orange;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Výrobné plány'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Card(
                  margin: const EdgeInsets.all(16.0),
                  child: TableCalendar<ProductionPlan>(
                    firstDay: DateTime.utc(2020, 1, 1),
                    lastDay: DateTime.utc(2030, 12, 31),
                    focusedDay: _focusedDay,
                    calendarFormat: _calendarFormat,
                    selectedDayPredicate: (day) {
                      return isSameDay(_selectedDay, day);
                    },
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    onFormatChanged: (format) {
                      setState(() {
                        _calendarFormat = format;
                      });
                    },
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                    },
                    eventLoader: _getPlansForDay,
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      markerDecoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: true,
                      titleCentered: true,
                    ),
                  ),
                ),
                Expanded(
                  child: _buildPlansList(),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ProductionPlanFormScreen(),
            ),
          );
          _loadData();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPlansList() {
    final dayPlans = _getPlansForDay(_selectedDay);

    if (dayPlans.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_today, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Žiadne plány pre ${DateFormat('dd.MM.yyyy').format(_selectedDay)}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: dayPlans.length,
      itemBuilder: (context, index) {
        final plan = dayPlans[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 8.0),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: _getPriorityColor(plan.priority),
              child: Text(
                plan.priority.substring(0, 1).toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(plan.productionTypeName ?? 'Neznámy typ'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Množstvo: ${plan.plannedQuantity.toStringAsFixed(2)}'),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(plan.status).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        plan.status,
                        style: TextStyle(
                          color: _getStatusColor(plan.status),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _getPriorityColor(plan.priority).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        plan.priority,
                        style: TextStyle(
                          color: _getPriorityColor(plan.priority),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () => _deletePlan(plan),
              color: Colors.red,
            ),
          ),
        );
      },
    );
  }

  Future<void> _deletePlan(ProductionPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Potvrdiť vymazanie'),
        content: Text('Naozaj chcete vymazať plán pre ${plan.productionTypeName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Zrušiť'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Vymazať'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final apiService = Provider.of<ApiService>(context, listen: false);
        await apiService.deleteProductionPlan(plan.id);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Plán bol vymazaný')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Chyba pri vymazávaní: $e')),
          );
        }
      }
    }
  }
}

