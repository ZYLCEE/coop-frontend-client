import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';

/// The view and its underlying RLS return only published, due announcements.
class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final _client = Supabase.instance.client;
  final List<Map<String, dynamic>> _items = [];
  bool _loading = false;
  bool _hasMore = true;
  String? _error;
  static const _columns = 'id,title,content,category,published_at,author_name';

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Map<String, dynamic> _parse(dynamic value) {
    final row = Map<String, dynamic>.from(value as Map);
    if (row['id'] is! String ||
        row['title'] is! String ||
        row['content'] is! String ||
        row['category'] is! String ||
        row['published_at'] is! String ||
        DateTime.tryParse(row['published_at'] as String) == null) {
      throw const FormatException('Unsupported announcement record.');
    }
    return row;
  }

  String _date(String value) {
    // Philippine time has a fixed UTC+08 offset; no device-timezone dependency.
    final local = DateTime.parse(value).toUtc().add(const Duration(hours: 8));
    return '${DateFormat('MMM d, y · h:mm a').format(local)} PHT';
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final offset = reset ? 0 : _items.length;
      final response = await _client
          .from('member_announcements')
          .select(_columns)
          .order('published_at', ascending: false)
          .order('id', ascending: false)
          .range(offset, offset + 20);
      final rows = (response as List).map(_parse).toList();
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        final seen = _items.map((row) => row['id']).toSet();
        _items.addAll(rows.take(20).where((row) => seen.add(row['id'])));
        _hasMore = rows.length > 20;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Announcements could not be loaded. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _open(Map<String, dynamic> item) async {
    try {
      // Recheck visibility in case the announcement has since been archived.
      final response = await _client
          .from('member_announcements')
          .select(_columns)
          .eq('id', item['id'])
          .maybeSingle();
      if (!mounted) return;
      if (response == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This announcement is no longer available.'),
          ),
        );
        await _load(reset: true);
        return;
      }
      final row = _parse(response);
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: AppTheme.cardWhite,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: .75,
          minChildSize: .35,
          maxChildSize: .95,
          expand: false,
          builder: (context, controller) => SingleChildScrollView(
            controller: controller,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: 'Close announcement',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ),
                Text(
                  row['category'] as String,
                  style: const TextStyle(
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Text(row['title'] as String, style: AppTheme.headingBold),
                const SizedBox(height: 8),
                Text(
                  _date(row['published_at'] as String),
                  style: AppTheme.captionRegular,
                ),
                const SizedBox(height: 20),
                SelectableText(
                  row['content'] as String,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.65,
                    color: AppTheme.darkText,
                  ),
                ),
                if (row['author_name'] is String)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: Text(
                      'By ${row['author_name']}',
                      style: AppTheme.captionRegular,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to open this announcement. Please try again.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.background,
    appBar: AppBar(
      title: const Text('Announcements'),
      backgroundColor: AppTheme.primaryGreen,
      foregroundColor: Colors.white,
    ),
    body: RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (_error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    TextButton(
                      onPressed: _loading
                          ? null
                          : () => _load(reset: _items.isEmpty),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          if (!_loading && _error == null && _items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(
                    Icons.campaign_outlined,
                    color: AppTheme.primaryGreen,
                    size: 36,
                  ),
                  SizedBox(height: 12),
                  Text('No announcements yet.', style: AppTheme.titleBold),
                  SizedBox(height: 8),
                  Text(
                    'Cooperative updates will appear here once published.',
                    textAlign: TextAlign.center,
                    style: AppTheme.captionRegular,
                  ),
                ],
              ),
            ),
          ..._items.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                color: AppTheme.cardWhite,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: AppTheme.divider),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _open(row),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row['category'] as String,
                          style: const TextStyle(
                            color: AppTheme.primaryGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(row['title'] as String, style: AppTheme.titleBold),
                        const SizedBox(height: 8),
                        Text(
                          row['content'] as String,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.6,
                            color: AppTheme.captionGray,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _date(row['published_at'] as String),
                          style: AppTheme.captionRegular,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(color: AppTheme.primaryGreen),
              ),
            ),
          if (!_loading && _hasMore && _items.isNotEmpty)
            Center(
              child: TextButton(
                onPressed: () => _load(),
                child: const Text('Load more announcements'),
              ),
            ),
        ],
      ),
    ),
  );
}
