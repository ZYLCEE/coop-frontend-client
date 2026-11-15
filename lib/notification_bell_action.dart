import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'services/database_service.dart';

/// A shared bell action for authenticated member page headers.
class NotificationBellAction extends StatefulWidget {
  const NotificationBellAction({super.key, this.color});

  final Color? color;

  @override
  State<NotificationBellAction> createState() => _NotificationBellActionState();
}

class _NotificationBellActionState extends State<NotificationBellAction>
    with WidgetsBindingObserver {
  final DatabaseService _database = DatabaseService();
  int _unreadCount = 0;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      _,
    ) {
      _loadUnreadCount();
      if (mounted) setState(() {});
    });
    _loadUnreadCount();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_authSubscription?.cancel());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted && _unreadCount != 0) setState(() => _unreadCount = 0);
      return;
    }
    try {
      final notifications = await _database.getNotifications(userId);
      if (!mounted || Supabase.instance.client.auth.currentUser?.id != userId) {
        return;
      }
      final count = notifications
          .where((notification) => notification['read'] != true)
          .length;
      if (count != _unreadCount) setState(() => _unreadCount = count);
    } catch (_) {
      // Keep the last known badge count during a temporary network failure.
    }
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).pushNamed('/notifications');
    if (mounted) await _loadUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    if (Supabase.instance.client.auth.currentUser == null) {
      return const SizedBox.shrink();
    }
    final iconColor = widget.color ?? IconTheme.of(context).color;
    return IconButton(
      tooltip: 'Notifications',
      onPressed: _openNotifications,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.notifications_outlined, color: iconColor),
          if (_unreadCount > 0)
            Positioned(
              top: -6,
              right: -8,
              child: Container(
                constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.danger,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.cardWhite, width: 1.2),
                ),
                child: Text(
                  _unreadCount > 99 ? '99+' : '$_unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
