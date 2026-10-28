import 'package:flutter/material.dart';
import 'quickaccesssetupscreen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
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
  Map<String, dynamic>? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final memberData = await _dbService.getMember(user.id);
      if (mounted) {
        setState(() {
          _userData = memberData;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
                      padding: const EdgeInsets.all(AppTheme.spacingL),
                      child: Column(
                        children: [
                          ProfileHeaderCard(userData: _userData),
                          const SizedBox(height: AppTheme.spacingL),
                          PersonalInformationCard(userData: _userData),
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
    final firstName = userData?['first_name'] ?? 'Loading';
    final lastName = userData?['last_name'] ?? '...';
    final memberId = userData?['member_id'] ?? 'Loading';
    final initials = [firstName, lastName]
        .where((name) => name is String && name.trim().isNotEmpty)
        .map((name) => (name as String).trim()[0])
        .join()
        .toUpperCase();

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
                  '$firstName $lastName',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  memberId,
                  style: const TextStyle(
                    color: AppTheme.lightGrayGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingS),
                MemberBadge(status: userData?['status']),
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
    final isActive = status == 'active';
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
          Text(
            isActive ? 'Active Member' : 'Inactive',
            style: TextStyle(
              color: badgeColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class PersonalInformationCard extends StatelessWidget {
  final Map<String, dynamic>? userData;

  const PersonalInformationCard({super.key, this.userData});

  @override
  Widget build(BuildContext context) {
    final phone = userData?['phone'] ?? 'N/A';
    final email = userData?['email'] ?? 'N/A';
    final address = userData?['address'] ?? 'N/A';
    final dateJoined = userData?['date_joined'] ?? 'N/A';

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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ProfileInfoRow(label: 'Date Joined', value: dateJoined),
              const Divider(color: AppTheme.divider, height: 1),
              ProfileInfoRow(label: 'Mobile', value: phone),
              const Divider(color: AppTheme.divider, height: 1),
              ProfileInfoRow(label: 'Email', value: email),
              const Divider(color: AppTheme.divider, height: 1),
              ProfileInfoRow(label: 'Address', value: address),
            ],
          ),
        ],
      ),
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
            onTap: () {},
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
            onTap: () {},
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
