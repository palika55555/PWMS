import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/notification.dart' as models;
import '../services/api_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<models.Notification> _notifications = [];
  bool _isLoading = true;
  bool _showOnlyUnread = false;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final notifications = await apiService.getNotifications();
      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba pri načítaní notifikácií: $e')),
        );
      }
    }
  }

  Future<void> _markAsRead(models.Notification notification) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.markNotificationAsRead(notification.id);
      _loadNotifications();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chyba: $e')),
        );
      }
    }
  }

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'critical':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'low_stock':
        return Icons.inventory_2;
      case 'maintenance_due':
        return Icons.build;
      case 'quality_issue':
        return Icons.warning;
      default:
        return Icons.info;
    }
  }

  List<models.Notification> get _filteredNotifications {
    if (_showOnlyUnread) {
      return _notifications.where((n) => !n.read).toList();
    }
    return _notifications;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikácie'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(_showOnlyUnread ? Icons.filter_list : Icons.filter_list_off),
            onPressed: () {
              setState(() => _showOnlyUnread = !_showOnlyUnread);
            },
            tooltip: _showOnlyUnread ? 'Zobraziť všetky' : 'Zobraziť len neprečítané',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _filteredNotifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _showOnlyUnread
                            ? 'Žiadne neprečítané notifikácie'
                            : 'Žiadne notifikácie',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredNotifications.length,
                  itemBuilder: (context, index) {
                    final notification = _filteredNotifications[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      color: notification.read
                          ? null
                          : _getSeverityColor(notification.severity)
                              .withOpacity(0.1),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getSeverityColor(notification.severity),
                          child: Icon(
                            _getTypeIcon(notification.type),
                            color: Colors.white,
                          ),
                        ),
                        title: Text(
                          notification.title,
                          style: TextStyle(
                            fontWeight: notification.read
                                ? FontWeight.normal
                                : FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(notification.message),
                            if (notification.createdAt != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  DateFormat('dd.MM.yyyy HH:mm')
                                      .format(notification.createdAt!),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                          ],
                        ),
                        trailing: notification.read
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.check),
                                onPressed: () => _markAsRead(notification),
                                tooltip: 'Označiť ako prečítané',
                              ),
                        onTap: () {
                          if (!notification.read) {
                            _markAsRead(notification);
                          }
                        },
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
    );
  }
}

