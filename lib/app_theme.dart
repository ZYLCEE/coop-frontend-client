import 'package:flutter/material.dart';

class AppTheme {
  // Color Palette
  static const Color primaryGreen = Color(0xFF206A3B);
  static const Color headerGreen = Color(0xFF1F6B3A);
  static const Color accentGold = Color(0xFFC8A64A);
  static const Color background = Color(0xFFF3F5F4);
  static const Color cardWhite = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF153D22);
  static const Color captionGray = Color(0xFF7C8B82);
  static const Color positiveGreen = Color(0xFF5E9F66);
  static const Color darkText = Color(0xFF1F2E24);
  static const Color mutedGray = Color(0xFF7D8A82);
  static const Color highlightedCard = Color(0xFFFFF9EC);
  static const Color borderGold = Color(0xFFD8B24D);
  static const Color iconPurple = Color(0xFF9C27B0);
  static const Color iconOrange = Color(0xFFFF9800);
  static const Color iconGreen = Color(0xFF206A3B);
  static const Color backButtonBg = Color(0xFFF5F5F5);
  static const Color timelineGray = Color(0xFFD9D9D9);
  static const Color completedGreen = Color(0xFF206A3B);
  static const Color lightGreenText = Color(0xFF4CAF50);
  static const Color lightGrayGreen = Color(0xFFB8C4B8);
  static const Color primaryText = Color(0xFF183A24);
  static const Color divider = Color(0xFFE6E6E6);
  static const Color danger = Color(0xFFFF5A5F);
  static const Color dangerBackground = Color(0xFFFFF2F2);
  static const Color dangerBorder = Color(0xFFFFB3B3);
  static const Color darkOlive = Color(0xFF2D5A3D);

  // Border Radius
  static const double cardBorderRadius = 18.0;
  static const double buttonBorderRadius = 16.0;
  static const double pillBorderRadius = 999.0;
  static const double iconContainerRadius = 12.0;

  // Spacing
  static const double spacingXS = 4.0;
  static const double spacingS = 8.0;
  static const double spacingM = 12.0;
  static const double spacingL = 16.0;
  static const double spacingXL = 20.0;
  static const double spacingXXL = 24.0;

  // Typography
  static const String fontFamily = 'Roboto';

  static const TextStyle headingBold = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: textDark,
  );

  static const TextStyle titleBold = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: textDark,
  );

  static const TextStyle bodyBold = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textDark,
  );

  static const TextStyle bodyRegular = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: textDark,
  );

  static const TextStyle captionBold = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: captionGray,
  );

  static const TextStyle captionRegular = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: captionGray,
  );

  static const TextStyle smallBold = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: captionGray,
  );

  static const TextStyle smallRegular = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: captionGray,
  );

  // Shadows
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get elevatedCardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 15,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get navBarShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, -2),
        ),
      ];
}
