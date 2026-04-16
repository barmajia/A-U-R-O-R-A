// ============================================================================
// Aurora Notification Center Screen
// ============================================================================
// 
// Displays user notifications with real-time updates
// Features:
// - List all notifications
// - Mark as read/unread
// - Mark all as read
// - Filter by type
// - Delete notifications
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:aurora/services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String? _filterType;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          // Mark all as read button
          Consumer<NotificationService>(
            builder: (context, service, child) {
              if (service.hasUnreadNotifications) {
                return IconButton(
                  icon: const Icon(Icons.done_all),
                  tooltip: 'Mark all as read',
                  onPressed: () async {
                    await service.markAllAsRead();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('All notifications marked as read'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              context.read<NotificationService>().refresh();
            },
          ),
        ],
      ),
      body: Consumer<NotificationService>(
        builder: (context, service, child) {
          if (service.isLoading && service.notifications.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          // Filter notifications
          final notifications = _filterType == null
              ? service.notifications
              : service.notifications
                  .where((n) => n.type == _filterType)
                  .toList();

          if (notifications.isEmpty) {
            return _buildEmptyState(service.isLoading);
          }

          return Column(
            children: [
              // Filter chips
              _buildFilterChips(),
              
              // Notifications list
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => service.refresh(),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: notifications.length,
                    separatorBuilder: (context, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final notification = notifications[index];
                      return _buildNotificationTile(notification, service);
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChips() {
    final types = [
      null, // All
      'order',
      'message',
      'deal',
      'product',
      'system',
    ];

    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: types.length,
        itemBuilder: (context, index) {
          final type = types[index];
          final isSelected = _filterType == type;
          
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: Text(type ?? 'All'),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _filterType = selected ? type : null;
                });
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationTile(
    NotificationModel notification,
    NotificationService service,
  ) {
    final isUrgent = notification.isUrgent;
    final isRead = notification.isRead;

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Notification'),
            content: const Text('Are you sure you want to delete this notification?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        await service.deleteNotification(notification.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Notification deleted')),
          );
        }
      },
      child: Container(
        color: isRead ? null : Colors.blue[50],
        child: ListTile(
          leading: _buildNotificationIcon(notification.type),
          title: Text(
            notification.title,
            style: TextStyle(
              fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(notification.message),
              const SizedBox(height: 2),
              Text(
                DateFormat('MMM dd, yyyy • HH:mm').format(notification.createdAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          trailing: isUrgent
              ? Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.priority_high, color: Colors.white, size: 20),
                )
              : null,
          onTap: () async {
            // Mark as read
            if (!isRead) {
              await service.markAsRead(notification.id);
            }

            // Navigate to action URL if available
            if (notification.actionUrl != null && notification.actionUrl!.isNotEmpty) {
              // TODO: Navigate to appropriate screen
              debugPrint('Navigate to: ${notification.actionUrl}');
            }
          },
        ),
      ),
    );
  }

  Widget _buildNotificationIcon(String type) {
    IconData icon;
    Color color;

    switch (type) {
      case 'order':
        icon = Icons.shopping_bag_outlined;
        color = Colors.blue;
        break;
      case 'message':
        icon = Icons.message_outlined;
        color = Colors.green;
        break;
      case 'deal':
        icon = Icons.handshake_outlined;
        color = Colors.orange;
        break;
      case 'product':
        icon = Icons.inventory_2_outlined;
        color = Colors.purple;
        break;
      case 'payment':
        icon = Icons.payment_outlined;
        color = Colors.teal;
        break;
      case 'shipping':
        icon = Icons.local_shipping_outlined;
        color = Colors.indigo;
        break;
      case 'review':
        icon = Icons.star_outline;
        color = Colors.amber;
        break;
      case 'promotion':
        icon = Icons.local_offer_outlined;
        color = Colors.pink;
        break;
      case 'security':
        icon = Icons.security_outlined;
        color = Colors.red;
        break;
      default:
        icon = Icons.notifications_outlined;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color),
    );
  }

  Widget _buildEmptyState(bool isLoading) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            _filterType == null
                ? 'No notifications yet'
                : 'No $_filterType notifications',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'When you get notifications, they\'ll appear here',
            style: TextStyle(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
