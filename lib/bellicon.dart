import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'app_bottom_navigation_bar.dart';
import 'co_maker_invitation_screen.dart';
import 'documents_screen.dart';
import 'schedtracker.dart';
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
  bool _markingAllRead = false;
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

  Future<void> _markAllAsRead() async {
    if (_markingAllRead || !_notifications.any((item) => item.isHighlighted)) {
      return;
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    setState(() => _markingAllRead = true);
    try {
      await DatabaseService().markAllNotificationsAsRead(user.id);
      if (!mounted) return;
      setState(() {
        for (final notification in _notifications) {
          notification.isHighlighted = false;
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not mark notifications as read.')),
      );
    } finally {
      if (mounted) setState(() => _markingAllRead = false);
    }
  }

  Future<void> _openNotification(NotificationItem notification) async {
    if (notification.isHighlighted) {
      await _markAsRead(notification);
    }
    if (!mounted) return;
    final applicationId = notification.applicationId;
    final requestId = notification.data?['request_id'];
    final invitationRequestId =
        notification.type == 'co_maker_invitation' &&
            requestId is String &&
            requestId.isNotEmpty
        ? requestId
        : null;
    final notificationTitle = notification.title.toLowerCase();
    final opensDocuments =
        notificationTitle.contains('document replacement') ||
        notificationTitle.contains('application returned') ||
        notification.data?['action']?.toString() == 'document_reviewed' ||
        notification.data?['action']?.toString() == 'application_returned';
    final openLabel = invitationRequestId != null
        ? 'Review Invitation'
        : applicationId != null && opensDocuments
        ? 'Open Documents'
        : applicationId != null
        ? 'Open Loan Details'
        : null;
    final shouldOpen = await showDialog<bool>(
      context: context,
      builder: (_) => NotificationDetailsDialog(
        notification: notification,
        applicationId: applicationId,
        actionLabel: openLabel,
      ),
    );
    if (shouldOpen != true || !mounted) return;
    if (invitationRequestId != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              CoMakerInvitationReviewScreen(requestId: invitationRequestId),
        ),
      );
    } else if (applicationId != null && opensDocuments) {
      await Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const DocumentsScreen()));
    } else if (applicationId != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LoanDetailsScreen(applicationId: applicationId),
        ),
      );
    }
    if (mounted) await _loadNotifications(background: true);
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
                          else ...[
                            if (_notifications.any(
                              (notification) => notification.isHighlighted,
                            ))
                              Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: TextButton.icon(
                                    onPressed: _markingAllRead
                                        ? null
                                        : _markAllAsRead,
                                    icon: _markingAllRead
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.done_all),
                                    label: const Text('Mark all as read'),
                                  ),
                                ),
                              ),
                            ..._notifications.map((notification) {
                              return Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppTheme.spacingM,
                                ),
                                child: NotificationCard(
                                  notification: notification,
                                  onAction: notification.actionText == null
                                      ? null
                                      : () => _openNotification(notification),
                                  onMarkRead: notification.isHighlighted
                                      ? () => _markAsRead(notification)
                                      : null,
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    ),
            ),
            AppBottomNavigationBar(currentIndex: -1, parentContext: context),
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
  final String? databaseId;
  final String? type;
  final Map<String, dynamic>? data;

  String? get applicationId {
    final entityKey = data?['entityKey'];
    final value = data?['entityType'] == 'application' && entityKey is String
        ? entityKey
        : RegExp(
            r'\bLA-[A-Za-z0-9-]{1,100}\b',
          ).firstMatch(description)?.group(0);
    return value != null && RegExp(r'^[A-Za-z0-9_-]{1,100}$').hasMatch(value)
        ? value
        : null;
  }

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

  factory NotificationItem.fromDatabase(Map<String, dynamic> row) {
    final date = DateTime.tryParse('${row['created_at']}')?.toLocal();
    final type = '${row['type']}'.toLowerCase();
    final rawData = row['data'];
    final data = rawData is Map<String, dynamic>
        ? rawData
        : rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : null;
    final icon = switch (type) {
      'warning' => Icons.warning_amber_outlined,
      'success' => Icons.check_circle_outline,
      'announcement' => Icons.campaign_outlined,
      'co_maker_invitation' => Icons.handshake_outlined,
      _ => Icons.notifications_none,
    };
    final id = row['id']?.toString() ?? '';
    return NotificationItem(
      id: id,
      databaseId: id,
      type: type,
      data: data,
      actionText: 'View Details',
      title: row['title']?.toString() ?? 'Notification',
      description: row['message']?.toString() ?? '',
      timestamp: date == null ? '' : DateFormat.yMMMd().add_jm().format(date),
      icon: icon,
      iconColor: AppTheme.primaryGreen,
      iconBgColor: AppTheme.backButtonBg,
      isHighlighted: row['read'] != true,
    );
  }
}

class NotificationDetailsDialog extends StatelessWidget {
  const NotificationDetailsDialog({
    super.key,
    required this.notification,
    required this.applicationId,
    required this.actionLabel,
  });

  final NotificationItem notification;
  final String? applicationId;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final data = notification.data ?? const <String, dynamic>{};
    final action = data['action']?.toString();
    final category = data['category']?.toString();
    final actorName = data['actorName']?.toString();
    final actorRole = data['actorRole']?.toString();
    final documentName = _notificationDocumentName(notification, action);
    final approval = _notificationApprovalProgress(notification);

    return AlertDialog(
      backgroundColor: AppTheme.cardWhite,
      title: Text(notification.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (category != null && category.isNotEmpty)
              _NotificationDetailRow(
                label: 'Type',
                value: _humanizeNotificationValue(category),
              ),
            if (applicationId != null)
              _NotificationDetailRow(
                label: 'Loan application',
                value: applicationId!,
              ),
            if (documentName != null)
              _NotificationDetailRow(label: 'Document', value: documentName),
            if (actorName != null && actorName.isNotEmpty)
              _NotificationDetailRow(
                label: 'Recorded by',
                value: actorRole == null || actorRole.isEmpty
                    ? actorName
                    : '$actorName · ${_humanizeNotificationValue(actorRole)}',
              ),
            if (approval != null) ...[
              const SizedBox(height: AppTheme.spacingM),
              _CommitteeApprovalDetails(
                progress: approval,
                actorName: actorName,
                actorRole: actorRole,
                recordedAt: notification.timestamp,
              ),
            ],
            const SizedBox(height: AppTheme.spacingM),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppTheme.spacingM),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
              ),
              child: Text(
                notification.description,
                style: const TextStyle(
                  color: AppTheme.darkText,
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingM),
            _NotificationDetailRow(
              label: 'Received',
              value: notification.timestamp.isEmpty
                  ? 'Time unavailable'
                  : notification.timestamp,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Close'),
        ),
        if (actionLabel != null)
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class _NotificationDetailRow extends StatelessWidget {
  const _NotificationDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppTheme.mutedGray, fontSize: 12),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.darkText,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _CommitteeApprovalProgress {
  const _CommitteeApprovalProgress({
    required this.stage,
    required this.approved,
    required this.required,
  });

  final String stage;
  final int approved;
  final int required;
}

_CommitteeApprovalProgress? _notificationApprovalProgress(
  NotificationItem notification,
) {
  final match = RegExp(
    r'(\d+)\s+of\s+(\d+)\s+approvals?',
    caseSensitive: false,
  ).firstMatch(notification.description);
  if (match == null) return null;
  final approved = int.tryParse(match.group(1) ?? '');
  final required = int.tryParse(match.group(2) ?? '');
  if (approved == null || required == null || required <= 0) return null;
  final context = '${notification.title} ${notification.description}'
      .toUpperCase();
  final stage = context.contains('BOD') ? 'BOD' : 'CRECOM';
  return _CommitteeApprovalProgress(
    stage: stage,
    approved: approved > required ? required : approved,
    required: required,
  );
}

class _CommitteeReviewerDetail {
  const _CommitteeReviewerDetail({
    required this.name,
    required this.position,
    required this.approved,
    this.recordedAt,
  });

  final String name;
  final String position;
  final bool approved;
  final String? recordedAt;
}

class _CommitteeApprovalDetails extends StatelessWidget {
  const _CommitteeApprovalDetails({
    required this.progress,
    required this.actorName,
    required this.actorRole,
    required this.recordedAt,
  });

  final _CommitteeApprovalProgress progress;
  final String? actorName;
  final String? actorRole;
  final String recordedAt;

  List<_CommitteeReviewerDetail> _reviewers() {
    final positions = progress.stage == 'CRECOM'
        ? const ['CRECOM Member 1', 'CRECOM Member 2', 'CRECOM Chairperson']
        : const ['BOD Reviewer'];
    final reviewers = List.generate(
      positions.length,
      (index) => _CommitteeReviewerDetail(
        name: 'Awaiting reviewer',
        position: positions[index],
        approved: false,
      ),
    );
    final approvedCount = progress.approved.clamp(0, positions.length).toInt();
    for (var index = 0; index < approvedCount; index++) {
      reviewers[index] = _CommitteeReviewerDetail(
        name: 'Reviewer name unavailable',
        position: positions[index],
        approved: true,
      );
    }

    if (approvedCount > 0 &&
        actorName != null &&
        actorName!.trim().isNotEmpty) {
      final role = (actorRole ?? '').toLowerCase();
      var actorIndex = approvedCount - 1;
      if (progress.stage == 'CRECOM') {
        if (role.contains('chair')) {
          actorIndex = 2;
        } else if (role.contains('2') || role.contains('second')) {
          actorIndex = 1;
        } else if (role.contains('1') || role.contains('first')) {
          actorIndex = 0;
        }
      }
      if (actorIndex >= approvedCount) actorIndex = approvedCount - 1;
      reviewers[actorIndex] = _CommitteeReviewerDetail(
        name: actorName!.trim(),
        position: positions[actorIndex],
        approved: true,
        recordedAt: recordedAt.isEmpty ? null : recordedAt,
      );
    }
    return reviewers;
  }

  @override
  Widget build(BuildContext context) {
    final reviewers = _reviewers();
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        border: Border.all(color: const Color(0xFFDCE4ED)),
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Text(
              'Waiting for ${progress.stage} approval',
              style: const TextStyle(
                color: AppTheme.darkText,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          Container(
            color: AppTheme.backButtonBg,
            padding: const EdgeInsets.all(AppTheme.spacingM),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${progress.stage} confirmations',
                    style: const TextStyle(
                      color: AppTheme.darkText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _ApprovalCountBadge(progress: progress),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Row(
              children: const [
                Expanded(flex: 4, child: Text('Reviewer · Position')),
                Expanded(flex: 2, child: Text('Decision')),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFDCE4ED)),
          ...reviewers.map(
            (reviewer) => _CommitteeReviewerRow(reviewer: reviewer),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              progress.stage == 'CRECOM'
                  ? 'Both CRECOM members and the chairperson must approve before BOD review.'
                  : 'The BOD decision is recorded after committee review.',
              style: const TextStyle(
                color: AppTheme.mutedGray,
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovalCountBadge extends StatelessWidget {
  const _ApprovalCountBadge({required this.progress});

  final _CommitteeApprovalProgress progress;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF2C6),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      '${progress.approved} of ${progress.required} approved',
      style: const TextStyle(
        color: Color(0xFF8A4B08),
        fontWeight: FontWeight.w600,
        fontSize: 11,
      ),
    ),
  );
}

class _CommitteeReviewerRow extends StatelessWidget {
  const _CommitteeReviewerRow({required this.reviewer});

  final _CommitteeReviewerDetail reviewer;

  @override
  Widget build(BuildContext context) {
    final color = reviewer.approved
        ? const Color(0xFF166534)
        : const Color(0xFF8A4B08);
    final bg = reviewer.approved
        ? const Color(0xFFDCFCE7)
        : const Color(0xFFFFF2C6);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFDCE4ED))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  reviewer.name,
                  style: const TextStyle(
                    color: AppTheme.darkText,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reviewer.position,
                  style: const TextStyle(
                    color: AppTheme.mutedGray,
                    fontSize: 11,
                  ),
                ),
                if (reviewer.recordedAt != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Recorded · ${reviewer.recordedAt}',
                    style: const TextStyle(
                      color: AppTheme.mutedGray,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  reviewer.approved ? 'Approved' : 'Waiting',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String? _notificationDocumentName(
  NotificationItem notification,
  String? action,
) {
  if (action != 'document_reviewed') return null;
  final message = notification.description;
  final remainder = notification.applicationId == null
      ? message
      : message.replaceFirst(notification.applicationId!, '');
  final firstPart = remainder.split('·').first;
  final rawName = firstPart.contains(':')
      ? firstPart.substring(firstPart.lastIndexOf(':') + 1).trim()
      : firstPart.trim();
  if (rawName.isEmpty) return null;
  return switch (rawName.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '')) {
    'validid' => 'Valid ID',
    'payslip' => 'Pay Slip',
    'collateral' => 'Collateral Document',
    _ => _humanizeNotificationValue(rawName),
  };
}

String _humanizeNotificationValue(String value) {
  final normalized = value.replaceAll(RegExp(r'[_-]+'), ' ').trim();
  if (normalized.isEmpty) return 'General';
  return normalized
      .split(RegExp(r'\s+'))
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
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
    this.onMarkRead,
  });

  final VoidCallback? onAction;
  final VoidCallback? onMarkRead;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: notification.isHighlighted
            ? AppTheme.highlightedCard
            : AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        border: notification.isHighlighted
            ? Border.all(color: AppTheme.borderGold, width: 1)
            : null,
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
                if ((onAction != null && notification.actionText != null) ||
                    onMarkRead != null)
                  Wrap(
                    spacing: 4,
                    children: [
                      if (onAction != null && notification.actionText != null)
                        TextButton(
                          onPressed: onAction,
                          child: Text(notification.actionText!),
                        ),
                      if (onMarkRead != null)
                        TextButton.icon(
                          onPressed: onMarkRead,
                          icon: const Icon(Icons.mark_email_read_outlined),
                          label: const Text('Mark as read'),
                        ),
                    ],
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
