import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// ---------------- Colors ----------------
class KColors {
  static const background = Color(0xFF121212);
  static const floatingBarBase = Color(0xFF1E1E1E);

  static const activeIcon = Color(0xFF00BFA5);
  static const inactiveIcon = Color(0xFF888888);
  static const activeTabHighlight = Color(0xFF004D40);

  static const textPrimary = Colors.white;
  static const textSecondary = Colors.white54;

  static const cardBackground = Color(0xFF1E1E1E);
  static const cardShadow = Colors.black;

  static const accentPositive = Color(0xFF00C49A);
  static const accentNegative = Color(0xFFFF6B6B);
  static const intervalUnselected = Colors.white12;

  static const progressBackground = Color(0xFF2A2A2A);
  static const progressForeground = Color(0xFF00A885);
}

/// ---------------- Sizes ----------------
class KSizes {
  // Navigation
  static const navBarHeight = 70.0;
  static const navBarHorizontalPadding = 16.0;
  static const navBarVerticalPadding = 12.0;
  static const navIconSize = 28.0;
  static const navIconPadding = 12.0;
  static const navIconBorderRadius = 16.0;
  static const navBarBorderRadius = 30.0;
  static const navIconSelectedScale = 1.2;
  static const navIconUnselectedScale = 1.0;

  // Token Card
  static const tokenCardHeight = 120.0;
  static const tokenCardPadding = 16.0;
  static const tokenCardBorderRadius = 20.0;

  static const tokenCardMetricSpacing = 6.0;
  static const tokenMetricVerticalSpacing = 6.0;
  static const tokenMetricHorizontalSpacing = 10.0;

  static const tokenMetricMinWidth = 80.0;
  static const tokenMetricsAreaFraction = 0.44;

  static const tokenSparklineHeight = 40.0;
  static const tokenSparklineVerticalSpacing = 6.0;

  static const indicatorIconSize = 16.0;

  // Interval Selector
  static const intervalButtonHeight = 36.0;
  static const intervalButtonMinWidth = 44.0;
  static const intervalButtonHorizontalPadding = 16.0;
  static const intervalButtonVerticalPadding = 8.0;
  static const intervalButtonBorderRadius = 12.0;
  static const intervalButtonSpacing = 6.0;

  // IntervalCountdown
  static const countdownProgressHeight = 6.0;
  static const countdownProgressBorderRadius = 3.0;
  static const countdownGlowWidth = 12.0;
  static const countdownGlowHeight = 6.0;

  // HomeScreen
  static const homeScreenVerticalSpacing = 12.0;
  static const listViewHorizontalPadding = 16.0;
  static const listViewBottomPadding = 12.0;
}

/// ---------------- Spacing ----------------
class KSpacing {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
}

/// ---------------- Durations ----------------
class KDurations {
  static const navAnimation = Duration(milliseconds: 250);
  static const fastAnimation = Duration(milliseconds: 220);
  static const dummySparklineAnimation = Duration(seconds: 1);
}

/// ---------------- TextStyles ----------------
class KTextStyles {
  static const appBarTitle = TextStyle(
    color: KColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w600,
  );

  static const tokenName = TextStyle(
    color: KColors.textPrimary,
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  static const tokenPrice = TextStyle(
    color: KColors.textPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  static const tokenMetricLabel = TextStyle(
    color: KColors.textSecondary,
    fontSize: 12,
  );

  static const tokenMetricValue = TextStyle(
    color: KColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  );

  static const interval = TextStyle(
    color: KColors.textPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w600,
  );

  static const intervalSelected = TextStyle(
    color: KColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.bold,
  );

  static const intervalCountdown = TextStyle(
    color: KColors.textPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );

  static const indicatorLabel = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: KColors.textSecondary,
  );

  static const indicatorValue = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: KColors.textPrimary,
  );
}

/// ---------------- Effects ----------------
class KEffects {
  // Glass / Blur
  static const navGlassBlurSigma = 20.0;
  static const tokenCardBlurSigma = 14.0;

  // Opacity
  static const navGlassOpacity = 0.2;
  static const tokenCardBackgroundOpacity = 0.48;

  // Other FX
  static const activeTabHighlightOpacity = 0.3;
}

/// ---------------- Decorations ----------------
class KDecorations {
  static final countdownForeground = BoxDecoration(
    color: KColors.progressForeground.withAlpha(230),
    borderRadius: BorderRadius.circular(KSizes.countdownProgressBorderRadius),
    boxShadow: [KShadows.countdown],
  );
  static final countdownBackground = BoxDecoration(
    gradient: KGradients.countdown,
  );
}

/// ---------------- Shadows ----------------
class KShadows {
  static const nav = BoxShadow(
    color: KColors.cardShadow,
    blurRadius: 10.0,
    offset: Offset(0, 5.0),
  );

  static const tokenCard = BoxShadow(
    color: KColors.cardShadow,
    blurRadius: 12.0,
    offset: Offset(0, 6.0),
  );

  static final countdown = BoxShadow(
    color: KColors.progressForeground.withAlpha(204),
    blurRadius: 4,
    spreadRadius: 1,
  );
}

/// ---------------- Gradients ----------------
class KGradients {
  static const navGlass = LinearGradient(
    colors: [Color(0x33FFFFFF), Color(0x11FFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const tokenCard = LinearGradient(
    colors: [Color(0x22FFFFFF), Color(0x11FFFFFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static final countdown = LinearGradient(
    colors: [
      KColors.progressForeground.withAlpha(230),
      KColors.progressForeground,
      KColors.progressForeground.withAlpha(179),
    ],
    stops: const [0.0, 0.5, 1.0],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

/// ---------------- Icons ----------------
class KIcons {
  static const navHome = CupertinoIcons.graph_circle;
  static const navAlert = CupertinoIcons.bell;
}
