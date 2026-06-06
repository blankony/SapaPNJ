import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FrostedGlass extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final bool isDark;

  const FrostedGlass({
    super.key,
    required this.child,
    this.borderRadius = 12.0,
    this.padding = EdgeInsets.zero,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightnessIsDark = theme.brightness == Brightness.dark;

    // "Use translucent matte surfaces with real background blur."
    // "Use restrained opacity so the background is softened but not visually noisy."
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: brightnessIsDark
                ? Colors.black.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: brightnessIsDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              width: 1.0,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class FrostedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final double elevation;
  final Color? backgroundColor;
  final IconThemeData? iconTheme;
  final dynamic systemOverlayStyle; // SystemUiOverlayStyle
  final Widget? flexibleSpace;
  final PreferredSizeWidget? bottom;

  const FrostedAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.centerTitle = false,
    this.elevation = 0,
    this.backgroundColor,
    this.iconTheme,
    this.systemOverlayStyle,
    this.flexibleSpace,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
        child: AppBar(
          title: title,
          actions: actions,
          leading: leading,
          centerTitle: centerTitle,
          elevation: elevation,
          iconTheme: iconTheme,
          systemOverlayStyle: systemOverlayStyle,
          flexibleSpace: flexibleSpace,
          backgroundColor: backgroundColor ?? (isDark 
              ? Colors.black.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.35)),
          bottom: bottom ?? PreferredSize(
            preferredSize: const Size.fromHeight(1.0),
            child: Container(
              color: isDark 
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              height: 1.0,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 1.0));
}

class FrostedBottomNavBar extends StatelessWidget {
  final List<BottomNavigationBarItem> items;
  final int currentIndex;
  final ValueChanged<int>? onTap;

  const FrostedBottomNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0),
        child: Container(
          decoration: BoxDecoration(
            color: isDark 
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.4),
            border: Border(
              top: BorderSide(
                color: isDark 
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
                width: 1.0,
              ),
            ),
          ),
          child: BottomNavigationBar(
            items: items,
            currentIndex: currentIndex,
            onTap: onTap,
            backgroundColor: Colors.transparent,
            elevation: 0,
          ),
        ),
      ),
    );
  }
}

class FrostedCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final ShapeBorder? shape;
  final double? elevation;
  final Color? shadowColor;
  final Color? backgroundColor;

  const FrostedCard({
    super.key,
    required this.child,
    this.margin,
    this.borderRadius = 16.0,
    this.shape,
    this.elevation,
    this.shadowColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin ?? const EdgeInsets.all(4.0),
      child: FrostedGlass(
        borderRadius: borderRadius,
        child: child,
      ),
    );
  }
}

class FrostedFAB extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;
  final Object? heroTag;
  final Color? backgroundColor;
  final double? elevation;

  const FrostedFAB({
    super.key,
    required this.onPressed,
    required this.child,
    this.heroTag,
    this.backgroundColor,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return ClipRRect(
      borderRadius: BorderRadius.circular(16.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
        child: Container(
          decoration: BoxDecoration(
            color: theme.primaryColor.withValues(alpha: 0.75), // Slightly transparent brand color
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.2),
              width: 1.0,
            ),
          ),
          child: FloatingActionButton(
            heroTag: heroTag,
            onPressed: onPressed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            focusElevation: 0,
            hoverElevation: 0,
            highlightElevation: 0,
            child: child,
          ),
        ),
      ),
    );
  }
}

class FrostedDrawer extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;
  final double? elevation;
  final ShapeBorder? shape;
  final double? width;
  
  const FrostedDrawer({
    super.key, 
    required this.child,
    this.backgroundColor,
    this.elevation,
    this.shape,
    this.width,
  });
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: shape,
      width: width,
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25.0, sigmaY: 25.0),
          child: Container(
            decoration: BoxDecoration(
              color: isDark 
                  ? Colors.black.withValues(alpha: 0.4)
                  : Colors.white.withValues(alpha: 0.5),
              border: Border(
                right: BorderSide(
                  color: isDark 
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                  width: 1.0,
                ),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class GlobalBackground extends StatelessWidget {
  const GlobalBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // A subtle, calming mesh gradient or abstract shape background 
    // to give the frosted glass something to blur.
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F1722) : const Color(0xFFF0F4F8),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -150,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SisapaTheme.blue.withValues(alpha: isDark ? 0.15 : 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -200,
            right: -150,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isDark ? Colors.purple : Colors.indigo).withValues(alpha: isDark ? 0.1 : 0.05),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
