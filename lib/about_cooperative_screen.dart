import 'package:flutter/material.dart';
import 'app_theme.dart';

class AboutCooperativeScreen extends StatelessWidget {
  const AboutCooperativeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.cardWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppTheme.darkText,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'About the Cooperative',
          style: TextStyle(
            color: AppTheme.darkText,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          children: [
            _buildInfoCard(
              icon: Icons.flag,
              title: 'Mission',
              content:
                  'To provide accessible, reliable, and sustainable financial services that improve the lives of cooperative members.',
            ),
            const SizedBox(height: AppTheme.spacingL),
            _buildInfoCard(
              icon: Icons.visibility,
              title: 'Vision',
              content:
                  'To become a trusted and progressive cooperative that promotes financial security and community development.',
            ),
            const SizedBox(height: AppTheme.spacingL),
            _buildInfoCard(
              icon: Icons.history,
              title: 'Background',
              content:
                  'The CSUCCERMPC was established to provide financial assistance, savings opportunities, and other member services for employees and qualified members of Caraga State University.',
              contentWidget: const Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'The ',
                      style: TextStyle(color: AppTheme.primaryText),
                    ),
                    TextSpan(
                      text: 'CSUCC',
                      style: TextStyle(color: Color(0xFFFFD817)),
                    ),
                    TextSpan(
                      text: 'ERMPC',
                      style: TextStyle(color: Colors.white),
                    ),
                    TextSpan(
                      text:
                          ' was established to provide financial assistance, savings opportunities, and other member services for employees and qualified members of Caraga State University.',
                      style: TextStyle(color: AppTheme.primaryText),
                    ),
                  ],
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
    Widget? contentWidget,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingL),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primaryGreen, size: 24),
          ),
          const SizedBox(width: AppTheme.spacingL),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.mutedGray,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: AppTheme.spacingS),
                contentWidget ??
                    Text(
                      content,
                      style: const TextStyle(
                        color: AppTheme.primaryText,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
