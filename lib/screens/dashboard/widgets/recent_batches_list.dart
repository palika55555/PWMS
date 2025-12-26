import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/models.dart';

class RecentBatchesList extends StatelessWidget {
  final List<Batch> batches;

  const RecentBatchesList({super.key, required this.batches});

  @override
  Widget build(BuildContext context) {
    if (batches.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Text(
              'Žiadne šarže',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Column(
        children: batches.map((batch) {
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(batch.qualityStatus).withOpacity(0.2),
              child: Icon(
                _getStatusIcon(batch.qualityStatus),
                color: _getStatusColor(batch.qualityStatus),
                size: 20,
              ),
            ),
            title: Text(
              batch.batchNumber,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              DateFormat('d. M. yyyy', 'sk_SK').format(
                DateTime.parse(batch.productionDate),
              ),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${batch.quantity} ks',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getStatusColor(batch.qualityStatus).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _getStatusText(batch.qualityStatus),
                    style: TextStyle(
                      fontSize: 10,
                      color: _getStatusColor(batch.qualityStatus),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'pending':
        return Icons.pending;
      default:
        return Icons.help_outline;
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'approved':
        return 'Schválené';
      case 'rejected':
        return 'Zamietnuté';
      case 'pending':
        return 'Čaká';
      default:
        return 'Neznámy';
    }
  }
}

