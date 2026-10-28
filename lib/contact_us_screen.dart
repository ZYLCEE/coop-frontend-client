import 'package:flutter/material.dart';
import 'app_theme.dart';

class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

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
          'Contact Us',
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
              icon: Icons.business,
              title: 'Cooperative Name',
              content: 'CSUCCERMPC',
              contentWidget: const Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'CSUCC',
                      style: TextStyle(color: Color(0xFFFFD817)),
                    ),
                    TextSpan(
                      text: 'ERMPC',
                      style: TextStyle(color: Colors.white),
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
            const SizedBox(height: AppTheme.spacingL),
            _buildInfoCard(
              icon: Icons.location_on,
              title: 'Address',
              content:
                  'Caraga State University\nCabadbaran Campus\nAgusan del Norte',
            ),
            const SizedBox(height: AppTheme.spacingL),
            _buildInfoCard(
              icon: Icons.phone,
              title: 'Phone Number',
              content: '(+63) 912 345 6789',
            ),
            const SizedBox(height: AppTheme.spacingL),
            _buildInfoCard(
              icon: Icons.email,
              title: 'Email',
              content: 'coop@csucc.edu.ph',
            ),
            const SizedBox(height: AppTheme.spacingL),
            _buildInfoCard(
              icon: Icons.access_time,
              title: 'Office Hours',
              content: 'Monday - Friday\n8:00 AM – 5:00 PM',
            ),
            const SizedBox(height: AppTheme.spacingL),
            _buildAboutCard(),
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

  Widget _buildAboutCard() {
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
            'About',
            style: TextStyle(
              color: AppTheme.mutedGray,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: AppTheme.spacingM),
          const Text.rich(
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
                      ' is committed to providing quality financial services, savings programs, and loan assistance to its members while promoting financial growth and community development.',
                  style: TextStyle(color: AppTheme.primaryText),
                ),
              ],
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
