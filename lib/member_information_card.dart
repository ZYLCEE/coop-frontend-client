import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'services/database_service.dart';

class LiveMemberInformationCard extends StatefulWidget {
  const LiveMemberInformationCard({super.key});

  @override
  State<LiveMemberInformationCard> createState() =>
      _LiveMemberInformationCardState();
}

class _LiveMemberInformationCardState extends State<LiveMemberInformationCard> {
  late Future<Map<String, dynamic>> _member;

  Future<Map<String, dynamic>> _loadMember() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw StateError('Please sign in to view your member information.');
    }
    return DatabaseService().getMember(user.id);
  }

  @override
  void initState() {
    super.initState();
    _member = _loadMember();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _member,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Column(
              children: [
                const Text('Unable to load your member information.'),
                TextButton(
                  onPressed: () => setState(() => _member = _loadMember()),
                  child: const Text('Retry'),
                ),
              ],
            );
          }
          final member = snapshot.data!;
          final fields = <String, String>{
            'Full Name':
                '${member['first_name'] ?? ''} ${member['last_name'] ?? ''}'
                    .trim(),
            'Member ID': member['member_id']?.toString() ?? '',
            'Email Address': member['email']?.toString() ?? '',
            'Contact Number': member['phone']?.toString() ?? '',
            'Department': member['department']?.toString() ?? '',
            'Registered Address': member['address']?.toString() ?? '',
            'Membership Type': member['membership_type']?.toString() ?? '',
          };
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MEMBER INFORMATION',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.mutedGray,
                ),
              ),
              ...fields.entries.map(
                (field) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        field.key,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.mutedGray,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        field.value.isEmpty ? 'Not provided' : field.value,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
