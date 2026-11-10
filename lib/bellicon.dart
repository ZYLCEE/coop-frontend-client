import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'app_bottom_navigation_bar.dart';
import 'co_maker_invitation_screen.dart';
import 'services/database_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<NotificationItem> _notifications = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
        _error = 'Sign in to view notifications.';
      });
      return;
    }
    try {
      final rows = await DatabaseService().getNotifications(user.id);
      if (!mounted) return;
      _notifications
        ..clear()
        ..addAll(
          rows.map((row) {
            final data = row['data'];
            final payload = data is Map
                ? Map<String, dynamic>.from(data)
                : null;
            final type = row['type']?.toString() ?? 'info';
            final date = DateTime.tryParse(row['created_at']?.toString() ?? '');
            return NotificationItem(
              id: 0,
              databaseId: row['id']?.toString(),
              title: row['title']?.toString() ?? 'Notification',
              timestamp: date == null ? '' : _formatNotificationDate(date),
              description: row['message']?.toString() ?? '',
              actionText: type == 'co_maker_invitation'
                  ? 'Review Invitation'
                  : null,
              icon: type == 'co_maker_invitation'
                  ? Icons.handshake_outlined
                  : Icons.notifications_outlined,
              iconColor: AppTheme.primaryGreen,
              iconBgColor: AppTheme.primaryGreen.withOpacity(0.1),
              isHighlighted:
                  type == 'co_maker_invitation' && row['read'] != true,
              type: type,
              data: payload,
            );
          }),
        );
      setState(() {
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load notifications. Please try again.';
      });
    }
  }

  Future<void> _openNotification(NotificationItem notification) async {
    if (notification.type == 'co_maker_invitation') {
      final requestId = notification.data?['request_id'];
      if (requestId is! String || requestId.isEmpty) return;
      final notificationId = notification.databaseId;
      if (notificationId != null) {
        try {
          await DatabaseService().markNotificationAsRead(notificationId);
        } catch (_) {
          // The invitation page still performs its own authorization check.
        }
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CoMakerInvitationReviewScreen(requestId: requestId),
        ),
      );
      if (mounted) await _loadNotifications();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            const NotificationAppBar(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.spacingL),
                child: Column(
                  children: _loading
                      ? [
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: CircularProgressIndicator(),
                          ),
                        ]
                      : _error != null
                      ? [
                          Text(_error!),
                          TextButton(
                            onPressed: _loadNotifications,
                            child: const Text('Retry'),
                          ),
                        ]
                      : _notifications.isEmpty
                      ? [const Text('No notifications.')]
                      : _notifications.map((notification) {
                          return Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppTheme.spacingM,
                            ),
                            child: NotificationCard(
                              notification: notification,
                              onAction: notification.actionText == null
                                  ? null
                                  : () => _openNotification(notification),
                            ),
                          );
                        }).toList(),
                ),
              ),
            ),
            AppBottomNavigationBar(currentIndex: 0, parentContext: context),
          ],
        ),
      ),
    );
  }
}

class NotificationItem {
  final int id;
  final String title;
  final String timestamp;
  final String description;
  final String? actionText;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final bool isHighlighted;
  final String? databaseId;
  final String? type;
  final Map<String, dynamic>? data;

  NotificationItem({
    required this.id,
    required this.title,
    required this.timestamp,
    required this.description,
    this.actionText,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.isHighlighted,
    this.databaseId,
    this.type,
    this.data,
  });
}

String _formatNotificationDate(DateTime date) {
  final local = date.toLocal();
  return '${local.month}/${local.day}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

class NotificationAppBar extends StatelessWidget {
  const NotificationAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingL,
        vertical: AppTheme.spacingM,
      ),
      decoration: const BoxDecoration(color: AppTheme.cardWhite),
      child: Row(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: AppTheme.backButtonBg,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: AppTheme.darkText,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacingM),
          const Expanded(
            child: Text(
              'Notifications',
              style: TextStyle(
                color: AppTheme.darkText,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationCard extends StatelessWidget {
  final NotificationItem notification;

  const NotificationCard({
    super.key,
    required this.notification,
    this.onAction,
  });

  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NotificationIcon(
            icon: notification.icon,
            iconColor: notification.iconColor,
            iconBgColor: notification.iconBgColor,
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: const TextStyle(
                          color: AppTheme.primaryGreen,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      notification.timestamp,
                      style: const TextStyle(
                        color: AppTheme.mutedGray,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingS),
                Text(
                  notification.description,
                  style: const TextStyle(
                    color: AppTheme.darkText,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ),
                ),
                if (onAction != null && notification.actionText != null)
                  TextButton(
                    onPressed: onAction,
                    child: Text(notification.actionText!),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HighlightedNotificationCard extends StatelessWidget {
  final NotificationItem notification;

  const HighlightedNotificationCard({super.key, required this.notification});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: AppTheme.highlightedCard,
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        border: Border.all(color: AppTheme.borderGold, width: 1),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NotificationIcon(
            icon: notification.icon,
            iconColor: notification.iconColor,
            iconBgColor: notification.iconBgColor,
          ),
          const SizedBox(width: AppTheme.spacingM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        notification.title,
                        style: const TextStyle(
                          color: AppTheme.primaryGreen,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      notification.timestamp,
                      style: const TextStyle(
                        color: AppTheme.mutedGray,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingS),
                Text(
                  notification.description,
                  style: const TextStyle(
                    color: AppTheme.darkText,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ),
                ),
                if (notification.actionText != null) ...[
                  const SizedBox(height: AppTheme.spacingS),
                  GestureDetector(
                    child: Text(
                      notification.actionText!,
                      style: const TextStyle(
                        color: AppTheme.accentGold,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationIcon extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;

  const NotificationIcon({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: iconBgColor,
        borderRadius: BorderRadius.circular(AppTheme.iconContainerRadius),
      ),
      child: Icon(icon, color: iconColor, size: 20),
    );
  }
}
