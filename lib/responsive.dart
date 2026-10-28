import 'package:flutter/material.dart';

class Responsive {
  static const double smallPhone = 360;
  static const double standardPhone = 390;
  static const double largePhone = 414;
  static const double tablet = 768;

  static bool isSmallPhone(BuildContext context) {
    return MediaQuery.of(context).size.width < smallPhone;
  }

  static bool isStandardPhone(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= smallPhone && width < largePhone;
  }

  static bool isLargePhone(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= largePhone && width < tablet;
  }

  static bool isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= tablet;
  }

  // Responsive spacing
  static double spacing(BuildContext context, double baseSpacing) {
    final width = MediaQuery.of(context).size.width;
    if (isSmallPhone(context)) {
      return baseSpacing * 0.85;
    } else if (isTablet(context)) {
      return baseSpacing * 1.2;
    }
    return baseSpacing;
  }

  static double horizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (isSmallPhone(context)) {
      return 12;
    } else if (isTablet(context)) {
      return 32;
    }
    return 16;
  }

  static double verticalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (isSmallPhone(context)) {
      return 12;
    } else if (isTablet(context)) {
      return 24;
    }
    return 16;
  }

  // Responsive font sizes
  static double fontSize(BuildContext context, double baseFontSize) {
    final width = MediaQuery.of(context).size.width;
    if (isSmallPhone(context)) {
      return baseFontSize * 0.9;
    } else if (isTablet(context)) {
      return baseFontSize * 1.1;
    }
    return baseFontSize;
  }

  static double headingSize(BuildContext context) {
    return fontSize(context, 24);
  }

  static double titleSize(BuildContext context) {
    return fontSize(context, 18);
  }

  static double bodySize(BuildContext context) {
    return fontSize(context, 14);
  }

  static double captionSize(BuildContext context) {
    return fontSize(context, 12);
  }

  // Responsive card padding
  static double cardPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (isSmallPhone(context)) {
      return 16;
    } else if (isTablet(context)) {
      return 28;
    }
    return 20;
  }

  // Responsive icon sizes
  static double iconSize(BuildContext context, double baseSize) {
    final width = MediaQuery.of(context).size.width;
    if (isSmallPhone(context)) {
      return baseSize * 0.85;
    } else if (isTablet(context)) {
      return baseSize * 1.15;
    }
    return baseSize;
  }

  // Responsive button height
  static double buttonHeight(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (isSmallPhone(context)) {
      return 48;
    } else if (isTablet(context)) {
      return 56;
    }
    return 52;
  }

  // Responsive border radius
  static double borderRadius(BuildContext context, double baseRadius) {
    final width = MediaQuery.of(context).size.width;
    if (isSmallPhone(context)) {
      return baseRadius * 0.9;
    } else if (isTablet(context)) {
      return baseRadius * 1.1;
    }
    return baseRadius;
  }
}
