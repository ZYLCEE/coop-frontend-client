import 'package:flutter/material.dart';
import 'app_theme.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

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
          'Frequently Asked Questions',
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
            _buildFAQItem(
              question: 'How do I apply for a loan?',
              answer: 'Members can apply through the dashboard\'s "Apply for a Loan" button or visit the cooperative office.',
            ),
            const SizedBox(height: AppTheme.spacingM),
            _buildFAQItem(
              question: 'Can I have multiple loans?',
              answer: 'Yes. Qualified members may apply for Regular, Educational, Emergency, and other available loan products depending on eligibility.',
            ),
            const SizedBox(height: AppTheme.spacingM),
            _buildFAQItem(
              question: 'How do I pay my loan?',
              answer: 'Payments can be made through the cooperative cashier or accredited payment channels.',
            ),
            const SizedBox(height: AppTheme.spacingM),
            _buildFAQItem(
              question: 'How do I update my information?',
              answer: 'Please visit the cooperative office or contact the administrator.',
            ),
            const SizedBox(height: AppTheme.spacingM),
            _buildFAQItem(
              question: 'Where can I download my loan statement?',
              answer: 'Navigate to Profile > Download Loan Statement.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQItem({required String question, required String answer}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacingL,
          vertical: AppTheme.spacingS,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppTheme.spacingL,
          0,
          AppTheme.spacingL,
          AppTheme.spacingL,
        ),
        iconColor: AppTheme.primaryGreen,
        collapsedIconColor: AppTheme.primaryGreen,
        title: Text(
          question,
          style: const TextStyle(
            color: AppTheme.primaryText,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        children: [
          Text(
            answer,
            style: const TextStyle(
              color: AppTheme.mutedGray,
              fontSize: 13,
              fontWeight: FontWeight.w400,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
