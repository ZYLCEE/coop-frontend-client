import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'dashboard.dart';
import 'profile.dart';
import 'loans_screen.dart';

class AppBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final BuildContext parentContext;

  const AppBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.parentContext,
  });

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
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home, 'Home', 0),
              _buildNavItem(Icons.payments, 'Loans', 1),
              _buildNavItem(Icons.person, 'Profile', 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () {
        if (index == currentIndex) {
          // Already on this tab, do nothing
          return;
        }

        switch (index) {
          case 0: // Home
            Navigator.pushAndRemoveUntil(
              parentContext,
              MaterialPageRoute(builder: (_) => const Dashboard()),
              (route) => false,
            );
            break;
          case 1: // Loans
            Navigator.pushAndRemoveUntil(
              parentContext,
              MaterialPageRoute(builder: (_) => const LoansScreen()),
              (route) => false,
            );
            break;
          case 2: // Profile
            Navigator.pushAndRemoveUntil(
              parentContext,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
              (route) => false,
            );
            break;
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected ? AppTheme.primaryGreen : AppTheme.mutedGray,
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
    );
  }
}
