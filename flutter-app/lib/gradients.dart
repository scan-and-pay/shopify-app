import 'package:flutter/material.dart';
import 'package:scan__pay/theme.dart';

class AppGradients {
  // Primary gradients using the main purple color
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      LightModeColors.lightPrimary,
      LightModeColors.lightSecondary,
    ],
  );
  
  static const LinearGradient primaryVertical = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      LightModeColors.lightPrimary,
      LightModeColors.lightSecondary,
    ],
  );
  
  static const LinearGradient primaryHorizontal = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      LightModeColors.lightPrimary,
      LightModeColors.lightSecondary,
    ],
  );
  
  // Subtle gradients for backgrounds
  static const LinearGradient subtleBackground = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      LightModeColors.lightPrimaryContainer,
      LightModeColors.lightSurface,
    ],
  );
  
  // Button gradients
  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      LightModeColors.lightPrimary,
      Color(0xFF8B5CF6), // Slightly darker purple
    ],
  );
  
  // Radial gradients for special effects
  static const RadialGradient radialPrimary = RadialGradient(
    colors: [
      LightModeColors.lightPrimary,
      LightModeColors.lightSecondary,
      LightModeColors.lightPrimaryContainer,
    ],
    stops: [0.0, 0.7, 1.0],
  );
  
  // Dark mode gradients
  static const LinearGradient darkPrimaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      DarkModeColors.darkPrimary,
      DarkModeColors.darkSecondary,
    ],
  );
  
  static const LinearGradient darkSubtleBackground = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      DarkModeColors.darkPrimaryContainer,
      DarkModeColors.darkSurface,
    ],
  );
  
  // Dynamic gradient that adapts to theme
  static LinearGradient getThemeGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkPrimaryGradient : primaryGradient;
  }
  
  static LinearGradient getThemeBackgroundGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkSubtleBackground : subtleBackground;
  }
  
  // Shimmer gradient for loading effects
  static const LinearGradient shimmerGradient = LinearGradient(
    begin: Alignment(-1.0, -2.0),
    end: Alignment(1.0, 2.0),
    colors: [
      LightModeColors.lightPrimaryContainer,
      Color.fromRGBO(153, 109, 247, 0.3), // Semi-transparent purple
      LightModeColors.lightPrimaryContainer,
    ],
    stops: [0.0, 0.5, 1.0],
  );
}