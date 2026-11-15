import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'dashboard.dart';
import 'loans_screen.dart';
import 'profile.dart';

class AppBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final BuildContext parentContext;

  const AppBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.parentContext,
  });

  void _selectPage(int index) {
    if (index == currentIndex) return;
    switch (index) {
      case 0:
        Navigator.pushAndRemoveUntil(
          parentContext,
          MaterialPageRoute(builder: (_) => const Dashboard()),
          (route) => false,
        );
        break;
      case 1:
        Navigator.pushAndRemoveUntil(
          parentContext,
          MaterialPageRoute(builder: (_) => const LoansScreen()),
          (route) => false,
        );
        break;
      case 2:
        Navigator.pushAndRemoveUntil(
          parentContext,
          MaterialPageRoute(builder: (_) => const ProfileScreen()),
          (route) => false,
        );
        break;
    }
  }

  Widget _buildNavItem(
    BuildContext context,
    IconData icon,
    String label,
    int index,
  ) {
    final isSelected = currentIndex == index;
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
                Icon(
                  icon,
                  color: isSelected
                      ? AppTheme.primaryGreen
                      : AppTheme.mutedGray,
                  size: 24,
                ),
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
              _buildNavItem(context, Icons.home, 'Home', 0),
              _buildNavItem(context, Icons.payments, 'Loans', 1),
              _buildNavItem(context, Icons.person, 'Profile', 2),
            ],
          ),
        ),
      ),
    );
  }
}
