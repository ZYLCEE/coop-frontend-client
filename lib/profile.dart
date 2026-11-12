import 'package:flutter/material.dart';
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
                      padding: const EdgeInsets.all(AppTheme.spacingL),
                      child: Column(
                        children: [
                          ProfileHeaderCard(userData: _userData),
                          const SizedBox(height: AppTheme.spacingL),
                          PersonalInformationCard(
                            userData: _userData,
                            onEdit: _userData == null
                                ? null
                                : _editPersonalInformation,
                          ),
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
    final firstName = userData?['first_name']?.toString().trim() ?? 'Loading';
    final lastName = userData?['last_name']?.toString().trim() ?? '...';
    final memberId = userData?['member_id'] ?? 'Loading';
    final initials = [firstName, lastName]
        .where((name) => name.isNotEmpty)
        .map((name) => name.characters.first)
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
  final VoidCallback? onEdit;

  const PersonalInformationCard({super.key, this.userData, this.onEdit});

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
            onTap: () {},
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
