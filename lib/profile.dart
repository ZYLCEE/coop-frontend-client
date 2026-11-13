import 'dart:async';

import 'package:flutter/material.dart';
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

  Future<void> _editPersonalInformation() async {
    final member = _userData;
    if (member == null) return;

    final updated = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditPersonalInformationDialog(member: member),
    );
    if (!mounted || updated == null) return;

    setState(() => _userData = updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Personal information updated.')),
    );
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
                            PersonalInformationCard(
                              userData: member,
                              onEdit: _editPersonalInformation,
                            ),
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
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
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
    final badgeColor = isActive ? AppTheme.accentGold : AppTheme.danger;

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
  final VoidCallback? onEdit;

  const PersonalInformationCard({super.key, this.userData, this.onEdit});

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
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'PERSONAL INFORMATION',
                  style: TextStyle(
                    color: AppTheme.primaryGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              if (onEdit != null)
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit Info'),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingL),
          _ProfileInfoSection(
            title: 'Membership · Read only',
            fields: membership,
          ),
          const SizedBox(height: AppTheme.spacingL),
          _ProfileInfoSection(
            title: 'Name and contact information',
            fields: contact,
          ),
          const Divider(color: AppTheme.divider, height: 1),
          const SizedBox(height: AppTheme.spacingM),
          const Text(
            'Other member details are read only.',
            style: AppTheme.bodyBold,
          ),
          const SizedBox(height: AppTheme.spacingXS),
          const Text(
            'Edit your name, contact number, or address above. For corrections '
            'to your Member ID, membership type, department, status, or join date, '
            'visit the CSUCC cooperative office and ask authorized staff.',
            style: AppTheme.bodyRegular,
          ),
        ],
      ),
    );
  }
}

class _EditPersonalInformationDialog extends StatefulWidget {
  const _EditPersonalInformationDialog({required this.member});

  final Map<String, dynamic> member;

  @override
  State<_EditPersonalInformationDialog> createState() =>
      _EditPersonalInformationDialogState();
}

class _EditPersonalInformationDialogState
    extends State<_EditPersonalInformationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _changes = <String, String>{};
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    final form = _formKey.currentState!;
    if (_saving || !form.validate()) return;
    _changes.clear();
    form.save();
    if (_changes.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await DatabaseService().updateOwnMemberInfo(
        userId: widget.member['user_id'] as String,
        firstName: _changes['first_name'],
        lastName: _changes['last_name'],
        phone: _changes['phone'],
        address: _changes['address'],
      );
      if (mounted) Navigator.of(context).pop(updated);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save your changes. Please try again.';
      });
    }
  }

  Widget _field(
    String column,
    String label, {
    required int maxLength,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String)? validate,
  }) {
    final initial = widget.member[column]?.toString().trim() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
      child: TextFormField(
        initialValue: initial,
        enabled: !_saving,
        keyboardType: keyboardType,
        maxLines: maxLines,
        textInputAction: maxLines == 1 ? TextInputAction.next : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          errorMaxLines: 2,
        ),
        validator: (value) {
          final text = value?.trim() ?? '';
          if (text == initial) return null;
          if (text.isEmpty) return '$label is required.';
          if (text.runes.length > maxLength) {
            return 'Use $maxLength characters or fewer.';
          }
          return validate?.call(text);
        },
        onSaved: (value) {
          final text = value?.trim() ?? '';
          if (text != initial) _changes[column] = text;
        },
      ),
    );
  }

  String? _validatePhone(String phone) {
    final digitCount = phone.replaceAll(RegExp(r'\D'), '').length;
    if (!RegExp(r'^\+?[0-9() .-]+$').hasMatch(phone) ||
        digitCount < 7 ||
        digitCount > 15) {
      return 'Enter a contact number with 7 to 15 digits.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        scrollable: true,
        title: const Text('Edit Personal Information'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _field('first_name', 'First Name', maxLength: 100),
              _field('last_name', 'Last Name', maxLength: 100),
              _field(
                'phone',
                'Contact Number',
                maxLength: 20,
                keyboardType: TextInputType.phone,
                validate: _validatePhone,
              ),
              _field(
                'address',
                'Address',
                maxLength: 500,
                keyboardType: TextInputType.multiline,
                maxLines: 3,
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save Changes'),
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
        borderRadius: BorderRadius.circular(AppTheme.cardBorderRadius),
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
            onTap: () {},
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
            backgroundColor: AppTheme.danger,
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
            borderRadius: BorderRadius.circular(AppTheme.buttonBorderRadius),
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
