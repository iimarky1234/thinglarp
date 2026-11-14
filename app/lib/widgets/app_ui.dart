import 'package:flutter/material.dart';
import '../providers/theme_provider.dart';
import '../theme/app_theme.dart';

/// Quick 1-tap Light/Dark theme toggle button for AppBars and toolbars.
class AppThemeToggleButton extends StatelessWidget {
  final bool showLabel;

  const AppThemeToggleButton({super.key, this.showLabel = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final themeProvider = ThemeProvider.maybeOf(context, listen: false);

    final tooltip = isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode';
    final icon = isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded;
    final iconColor = isDark ? colors.warning : colors.primary;

    if (showLabel) {
      return OutlinedButton.icon(
        onPressed: () => themeProvider?.toggleBrightness(brightness),
        icon: Icon(icon, size: 18, color: iconColor),
        label: Text(isDark ? 'Light' : 'Dark'),
        style: OutlinedButton.styleFrom(
          backgroundColor: colors.surfaceCard,
          side: BorderSide(color: colors.border),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          visualDensity: VisualDensity.compact,
        ),
      );
    }

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => themeProvider?.toggleBrightness(brightness),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.border),
          ),
          child: Icon(icon, size: 19, color: iconColor),
        ),
      ),
    );
  }
}

/// Brand emblem icon used on the sign-in screen and top navigation.
class AppBrandMark extends StatelessWidget {
  final double size;

  const AppBrandMark({super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primary, colors.accentTeal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Icon(
        Icons.hub_rounded,
        color: Colors.white,
        size: size * 0.56,
      ),
    );
  }
}

/// Elevated container matching the current theme surface and border tokens.
class AppSurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final Color? borderColor;
  final Color? backgroundColor;
  final VoidCallback? onTap;

  const AppSurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderRadius = 16,
    this.borderColor,
    this.backgroundColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final card = Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? colors.surfaceCard,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor ?? colors.border),
        boxShadow: [
          BoxShadow(
            color: colors.shadow,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(borderRadius),
        child: onTap != null
            ? InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(borderRadius),
                child: Padding(padding: padding, child: child),
              )
            : Padding(padding: padding, child: child),
      ),
    );
    return card;
  }
}

/// Compact pill badge with high contrast across both Light and Dark themes.
class AppStatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool showDot;

  const AppStatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 5),
                ],
              ),
            ),
            const SizedBox(width: 6),
          ] else if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Centers content cleanly up to [maxWidth] on wide desktop and web viewports.
class ResponsiveCenter extends StatelessWidget {
  final double maxWidth;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const ResponsiveCenter({
    super.key,
    this.maxWidth = 1200,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
