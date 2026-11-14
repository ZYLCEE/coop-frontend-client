import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'dashboard.dart';
import 'loans_screen.dart';
import 'profile.dart';
import 'services/database_service.dart';

class AppBottomNavigationBar extends StatefulWidget {
  final int currentIndex;
  final BuildContext parentContext;

  const AppBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.parentContext,
  });

  @override
  State<AppBottomNavigationBar> createState() =>
      _AppBottomNavigationBarState();
}

class _AppBottomNavigationBarState extends State<AppBottomNavigationBar> {
  final DatabaseService _database = DatabaseService();
  Timer? _refreshTimer;
  StreamSubscription<AuthState>? _authSubscription;
  RealtimeChannel? _notificationChannel;
  String? _boundUserId;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _bindCurrentUser();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (_) => _bindCurrentUser(),
    );
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _refreshUnreadCount();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _authSubscription?.cancel();
    final channel = _notificationChannel;
    if (channel != null) {
      unawaited(
        Supabase.instance.client.removeChannel(channel).then<void>((_) {}),
      );
    }
    super.dispose();
  }

  void _bindCurrentUser() {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (_boundUserId == userId) {
      _refreshUnreadCount();
      return;
    }
    _boundUserId = userId;
    final previousChannel = _notificationChannel;
    _notificationChannel = null;
    if (previousChannel != null) {
      unawaited(client.removeChannel(previousChannel).then<void>((_) {}));
    }
    if (userId == null) {
      if (mounted) setState(() => _unreadCount = 0);
      return;
    }

    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'user_id',
      value: userId,
    );
    _notificationChannel = client
        .channel('member-nav-notifications-$userId-${identityHashCode(this)}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: filter,
          callback: (_) => _refreshUnreadCount(),
        )
        .subscribe();
    _refreshUnreadCount();
  }

  Future<void> _refreshUnreadCount() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      if (mounted && _unreadCount != 0) setState(() => _unreadCount = 0);
      return;
    }
    try {
      final notifications = await _database.getNotifications(userId);
      if (!mounted ||
          Supabase.instance.client.auth.currentUser?.id != userId) {
        return;
      }
      final unread = notifications
          .where((notification) => notification['read'] != true)
          .length;
      if (unread != _unreadCount) setState(() => _unreadCount = unread);
    } catch (_) {
      // Retain the last known count while the connection is unavailable.
    }
  }

  void _selectPage(int index) {
    if (index == widget.currentIndex) return;
    switch (index) {
      case 0:
        Navigator.pushAndRemoveUntil(
          widget.parentContext,
          MaterialPageRoute(builder: (_) => const Dashboard()),
          (route) => false,
        );
        break;
      case 1:
        Navigator.pushAndRemoveUntil(
          widget.parentContext,
          MaterialPageRoute(builder: (_) => const LoansScreen()),
          (route) => false,
        );
        break;
      case 2:
        Navigator.pushAndRemoveUntil(
          widget.parentContext,
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
          (route) => false,
        );
        break;
      case 3:
        Navigator.pushNamed(widget.parentContext, '/notifications');
        break;
    }
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = widget.currentIndex == index;
    final item = Icon(
      icon,
      color: isSelected ? AppTheme.primaryGreen : AppTheme.mutedGray,
      size: 24,
    );
    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _selectPage(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (index == 3)
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      item,
                      if (_unreadCount > 0)
                        Positioned(
                          top: -7,
                          right: -11,
                          child: Container(
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppTheme.danger,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppTheme.cardWhite,
                                width: 1.2,
                              ),
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
                  )
                else
                  item,
                const SizedBox(height: AppTheme.spacingXS),
                if (isSelected)
                  Container(
                    width: 4,
                    height: 4,
                    decoration: const BoxDecoration(
                      color: AppTheme.accentGold,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        boxShadow: AppTheme.navBarShadow,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacingL,
            vertical: AppTheme.spacingM,
          ),
          child: Row(
            children: [
              _buildNavItem(Icons.home, 'Home', 0),
              _buildNavItem(Icons.payments, 'Loans', 1),
              _buildNavItem(Icons.notifications, 'Notifications', 3),
              _buildNavItem(Icons.person, 'Profile', 2),
            ],
          ),
        ),
      ),
    );
  }
}
