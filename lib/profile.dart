import 'dart:async';

import 'package:flutter/material.dart';
import 'quickaccesssetupscreen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'responsive.dart';
import 'app_bottom_navigation_bar.dart';
import 'services/supabase_service.dart';
import 'services/database_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final DatabaseService _dbService = DatabaseService();
  final _auth = Supabase.instance.client.auth;
  late final StreamSubscription<AuthState> _authSubscription;
  Map<String, dynamic>? _userData;
  String? _userId;
  bool _isLoading = false;
  int _loadVersion = 0;

  @override
  void initState() {
    super.initState();
    _authSubscription = _auth.onAuthStateChange.listen((_) {
      if (_auth.currentUser?.id != _userId) _loadUserData();
    });
    _loadUserData();
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final version = ++_loadVersion;
    final userId = _auth.currentUser?.id;
    setState(() {
      _userId = userId;
      _userData = null;
      _isLoading = userId != null;
    });
    if (userId == null) return;

    Map<String, dynamic>? member;
    try {
      member = await _dbService.getMember(userId);
    } catch (_) {
      // The screen offers a retry without showing backend error details.
    }
    if (!mounted ||
        version != _loadVersion ||
        _auth.currentUser?.id != userId) {
      return;
    }
    setState(() {
      _userData = member;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            const ProfileAppBar(),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.horizontalPadding(context),
                        vertical: AppTheme.spacingL,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_userData case final member?) ...[
                            ProfileHeaderCard(userData: member),
                            const SizedBox(height: AppTheme.spacingL),
                            PersonalInformationCard(userData: member),
                          ] else ...[
                            Center(
                              child: Text(
                                _userId == null
                                    ? 'Sign in to view your profile.'
                                    : 'Unable to load your profile.',
                              ),
                            ),
                            if (_userId != null)
                              TextButton(
                                onPressed: _loadUserData,
                                child: const Text('Retry'),
                              ),
                          ],
                          const SizedBox(height: AppTheme.spacingL),
                          const SettingsMenuCard(),
                          const SizedBox(height: AppTheme.spacingL),
                          SignOutButton(),
                        ],
                      ),
                    ),
            ),
            AppBottomNavigationBar(currentIndex: 2, parentContext: context),
          ],
        ),
      ),
    );
  }
}

class ProfileAppBar extends StatelessWidget {
  const ProfileAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingL,
        vertical: AppTheme.spacingM,
      ),
      decoration: const BoxDecoration(color: AppTheme.cardWhite),
      child: const Center(
        child: Text(
          'Profile',
          style: TextStyle(
            color: AppTheme.darkText,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class ProfileHeaderCard extends StatelessWidget {
  final Map<String, dynamic>? userData;

  const ProfileHeaderCard({super.key, this.userData});

  @override
  Widget build(BuildContext context) {
    final names = [
      _profileValue(userData, 'first_name'),
      _profileValue(userData, 'last_name'),
    ].nonNulls;
    final fullName = names.join(' ');
    final initials = names
        .map((name) => name.characters.first)
        .join()
        .toUpperCase();
    final memberId = _profileValue(userData, 'member_id');
    final status = _memberStatus(userData);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.elevatedCardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.accentGold,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  color: AppTheme.primaryGreen,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacingL),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullName.isEmpty ? 'Member profile' : fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (memberId != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    memberId,
                    style: const TextStyle(
                      color: AppTheme.lightGrayGreen,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
                if (status != null) ...[
                  const SizedBox(height: AppTheme.spacingS),
                  MemberBadge(status: status),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MemberBadge extends StatelessWidget {
  final String? status;

  const MemberBadge({super.key, this.status});

  @override
  Widget build(BuildContext context) {
    final isActive = status == 'Active';
    final badgeColor = isActive ? AppTheme.accentGold : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.darkOlive,
        borderRadius: BorderRadius.circular(AppTheme.pillBorderRadius),
        border: Border.all(color: badgeColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              isActive ? 'Active Member' : status ?? '',
              style: TextStyle(
                color: badgeColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String? _profileValue(Map<String, dynamic>? member, String field) {
  final value = member?[field];
  if (value is! String) return null;
  final text = value.trim();
  return text.isEmpty ? null : text;
}

String? _memberStatus(Map<String, dynamic>? member) =>
    switch (_profileValue(member, 'status')?.toLowerCase()) {
      'active' => 'Active',
      'inactive' => 'Inactive',
      'suspended' => 'Suspended',
      _ => null,
    };

class PersonalInformationCard extends StatelessWidget {
  final Map<String, dynamic>? userData;

  const PersonalInformationCard({super.key, this.userData});

  @override
  Widget build(BuildContext context) {
    final fullName = [
      _profileValue(userData, 'first_name'),
      _profileValue(userData, 'last_name'),
    ].nonNulls.join(' ');
    final memberId = _profileValue(userData, 'member_id');
    final membershipType = _profileValue(userData, 'membership_type');
    final department = _profileValue(userData, 'department');
    final status = _memberStatus(userData);
    final membership = {
      'Member ID': ?memberId,
      'Membership Type': ?membershipType,
      'Department': ?department,
      'Membership Status': ?status,
      'Date Joined': _profileValue(userData, 'date_joined') ?? 'Not available',
    };
    final contact = {
      'Full Name': fullName.isEmpty ? 'Not available' : fullName,
      'Mobile Number': _profileValue(userData, 'phone') ?? 'Not available',
      'Email Address': _profileValue(userData, 'email') ?? 'Not available',
      'Residential Address':
          _profileValue(userData, 'address') ?? 'Not available',
    };

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PERSONAL INFORMATION',
            style: TextStyle(
              color: AppTheme.primaryGreen,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: AppTheme.spacingL),
          _ProfileInfoSection(
            title: 'Membership · Read only',
            fields: membership,
          ),
          const SizedBox(height: AppTheme.spacingL),
          _ProfileInfoSection(
            title: 'Name and contact information · Read only',
            fields: contact,
          ),
          const Divider(color: AppTheme.divider, height: 1),
          const SizedBox(height: AppTheme.spacingM),
          const Text(
            'Need to update your information?',
            style: AppTheme.bodyBold,
          ),
          const SizedBox(height: AppTheme.spacingXS),
          const Text(
            'To update or correct your registered information, visit the CSUCC '
            'cooperative office and ask authorized staff for assistance.',
            style: AppTheme.bodyRegular,
          ),
        ],
      ),
    );
  }
}

class _ProfileInfoSection extends StatelessWidget {
  const _ProfileInfoSection({required this.title, required this.fields});

  final String title;
  final Map<String, String> fields;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title, style: AppTheme.captionBold),
        for (final field in fields.entries) ...[
          if (field.key != fields.keys.first)
            const Divider(color: AppTheme.divider, height: 1),
          ProfileInfoRow(label: field.key, value: field.value),
        ],
      ],
    );
  }
}

class ProfileInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const ProfileInfoRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.mutedGray,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
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
}

class SettingsMenuCard extends StatelessWidget {
  const SettingsMenuCard({super.key});

  void _showAvailability(BuildContext context, String title, String message) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        scrollable: true,
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          SettingsMenuItem(
            icon: Icons.notifications_none,
            title: 'Notification Preferences',
            onTap: () => _showAvailability(
              context,
              'Notification Preferences',
              'Notification preferences are currently unavailable in the app.',
            ),
          ),
          const Divider(color: AppTheme.divider, height: 1, indent: 56),
          SettingsMenuItem(
            icon: Icons.fingerprint,
            title: 'Change PIN / Biometric',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QuickAccessSetupScreen()),
            ),
          ),
          const Divider(color: AppTheme.divider, height: 1, indent: 56),
          SettingsMenuItem(
            icon: Icons.description,
            title: 'Download Loan Statement',
            onTap: () => _showAvailability(
              context,
              'Download Loan Statement',
              'Loan statement downloads are currently unavailable in the app. '
                  'Contact the cooperative office to request a statement.',
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const SettingsMenuItem({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primaryGreen, size: 24),
            const SizedBox(width: AppTheme.spacingM),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppTheme.darkText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: AppTheme.mutedGray, size: 20),
          ],
        ),
      ),
    );
  }
}

class SignOutButton extends StatelessWidget {
  const SignOutButton({super.key});

  Future<void> _handleSignOut(BuildContext context) async {
    try {
      await SupabaseService().signOut();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign out failed: ${error.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => _handleSignOut(context),
        style: OutlinedButton.styleFrom(
          backgroundColor: AppTheme.dangerBackground,
          foregroundColor: AppTheme.danger,
          side: const BorderSide(color: AppTheme.dangerBorder, width: 1),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.logout, size: 20),
            SizedBox(width: AppTheme.spacingS),
            Text(
              'Sign Out',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
