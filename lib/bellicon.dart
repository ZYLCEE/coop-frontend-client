import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'app_bottom_navigation_bar.dart';
import 'services/database_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with WidgetsBindingObserver {
  List<NotificationItem> _notifications = [];
  bool _loading = true;
  String? _error;
  RealtimeChannel? _notificationChannel;
  Timer? _refreshDebounce;
  Timer? _refreshFallback;
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadNotifications();
    _listenForNotificationChanges();
    _refreshFallback = Timer.periodic(const Duration(seconds: 30), (_) {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      if (lifecycle == null || lifecycle == AppLifecycleState.resumed) {
        _queueNotificationRefresh();
      }
    });
  }

  void _listenForNotificationChanges() {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;
    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'user_id',
      value: user.id,
    );
    _notificationChannel = client
        .channel('member-notifications-${user.id}-${identityHashCode(this)}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: filter,
          callback: (_) => _queueNotificationRefresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'notifications',
          filter: filter,
          callback: (_) => _queueNotificationRefresh(),
        )
        .subscribe();
  }

  void _queueNotificationRefresh() {
    if (!mounted) return;
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 200), () {
      if (mounted) _loadNotifications(background: true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _queueNotificationRefresh();
  }

  @override
  void dispose() {
    _loadGeneration++;
    _refreshDebounce?.cancel();
    _refreshFallback?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    final channel = _notificationChannel;
    if (channel != null) {
      unawaited(
        Supabase.instance.client.removeChannel(channel).then<void>((_) {}),
      );
    }
    super.dispose();
  }

  Future<void> _loadNotifications({bool background = false}) async {
    if (!mounted) return;
    final generation = ++_loadGeneration;
    if (!background) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw StateError('Sign in to view your notifications.');
      final rows = await DatabaseService().getNotifications(user.id);
      if (!mounted || generation != _loadGeneration) return;
      if (Supabase.instance.client.auth.currentUser?.id != user.id) {
        setState(() => _notifications = []);
        return;
      }
      setState(() {
        _notifications = rows.map(NotificationItem.fromDatabase).toList();
        _error = null;
      });
    } catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      setState(
        () => _error = error is StateError
            ? error.message
            : 'Unable to load your notifications. Try again.',
      );
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _markAsRead(NotificationItem item) async {
    if (!item.isHighlighted) return;
    try {
      await DatabaseService().markNotificationAsRead(item.id);
      if (mounted) setState(() => item.isHighlighted = false);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not mark this notification as read.'),
        ),
      );
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
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadNotifications,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(AppTheme.spacingL),
                        children: [
                          if (_error != null) ...[
                            Text(_error!, textAlign: TextAlign.center),
                            TextButton(
                              onPressed: _loadNotifications,
                              child: const Text('Retry'),
                            ),
                          ] else if (_notifications.isEmpty)
                            const Center(child: Text('No notifications yet.'))
                          else
                            ..._notifications.map((notification) {
                              return Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppTheme.spacingM,
                                ),
                                child: notification.isHighlighted
                                    ? GestureDetector(
                                        onTap: () => _markAsRead(notification),
                                        child: HighlightedNotificationCard(
                                          notification: notification,
                                        ),
                                      )
                                    : NotificationCard(
                                        notification: notification,
                                      ),
                              );
                            }),
                        ],
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
  final String id;
  final String title;
  final String timestamp;
  final String description;
  final String? actionText;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  bool isHighlighted;

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
  });

  factory NotificationItem.fromDatabase(Map<String, dynamic> row) {
    final date = DateTime.tryParse('${row['created_at']}')?.toLocal();
    final type = '${row['type']}'.toLowerCase();
    final icon = switch (type) {
      'warning' => Icons.warning_amber_outlined,
      'success' => Icons.check_circle_outline,
      'announcement' => Icons.campaign_outlined,
      _ => Icons.notifications_none,
    };
    return NotificationItem(
      id: row['id'] as String,
      title: row['title'] as String,
      description: row['message'] as String,
      timestamp: date == null ? '' : DateFormat.yMMMd().add_jm().format(date),
      icon: icon,
      iconColor: AppTheme.primaryGreen,
      iconBgColor: AppTheme.backButtonBg,
      isHighlighted: row['read'] != true,
    );
  }
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

  const NotificationCard({super.key, required this.notification});

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
