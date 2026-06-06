import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum FrostedSurfaceTone { surface, strong, control, brand }

class FrostedGlassTokens {
  static const double blurSigma = 18.0;
  static const double strongBlurSigma = 22.0;
  static const double controlBlurSigma = 14.0;

  static Color tintFor(
    BuildContext context, {
    FrostedSurfaceTone tone = FrostedSurfaceTone.surface,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    switch (tone) {
      case FrostedSurfaceTone.strong:
        return (isDark ? const Color(0xFF15202B) : Colors.white).withOpacity(
          isDark ? 0.86 : 0.82,
        );
      case FrostedSurfaceTone.control:
        return (isDark ? const Color(0xFF192734) : const Color(0xFFE1E8ED))
            .withOpacity(isDark ? 0.74 : 0.68);
      case FrostedSurfaceTone.brand:
        return theme.colorScheme.primary.withOpacity(isDark ? 0.78 : 0.82);
      case FrostedSurfaceTone.surface:
        return (isDark ? const Color(0xFF15202B) : Colors.white).withOpacity(
          isDark ? 0.78 : 0.74,
        );
    }
  }

  static BorderSide subtleBorderSide(
    BuildContext context, {
    double opacity = 0.34,
    double width = 0.5,
  }) {
    return BorderSide(
      color: Theme.of(context).dividerColor.withOpacity(opacity),
      width: width,
    );
  }

  static List<BoxShadow> materialDepth(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return [
      BoxShadow(
        color: Colors.black.withOpacity(isDark ? 0.24 : 0.12),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ];
  }
}

class FrostedLayer extends StatelessWidget {
  final Widget? child;
  final double blur;
  final Color? tint;
  final FrostedSurfaceTone tone;

  const FrostedLayer({
    super.key,
    this.child,
    this.blur = FrostedGlassTokens.blurSigma,
    this.tint,
    this.tone = FrostedSurfaceTone.surface,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: ColoredBox(
          color: tint ?? FrostedGlassTokens.tintFor(context, tone: tone),
          child: child ?? const SizedBox.expand(),
        ),
      ),
    );
  }
}

class FrostedSurface extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final BoxConstraints? constraints;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry? alignment;
  final BorderRadiusGeometry borderRadius;
  final BoxShape shape;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final Color? tint;
  final double blur;
  final FrostedSurfaceTone tone;
  final Clip clipBehavior;

  const FrostedSurface({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.constraints,
    this.margin,
    this.padding,
    this.alignment,
    this.borderRadius = BorderRadius.zero,
    this.shape = BoxShape.rectangle,
    this.border,
    this.boxShadow,
    this.tint,
    this.blur = FrostedGlassTokens.blurSigma,
    this.tone = FrostedSurfaceTone.surface,
    this.clipBehavior = Clip.antiAlias,
  });

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: tint ?? FrostedGlassTokens.tintFor(context, tone: tone),
      border: border,
      borderRadius: shape == BoxShape.rectangle ? borderRadius : null,
      shape: shape,
    );

    Widget frosted = BackdropFilter(
      filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
      child: DecoratedBox(
        decoration: decoration,
        child: padding == null
            ? child
            : Padding(padding: padding!, child: child),
      ),
    );

    frosted = shape == BoxShape.circle
        ? ClipOval(clipBehavior: clipBehavior, child: frosted)
        : ClipRRect(
            borderRadius: borderRadius,
            clipBehavior: clipBehavior,
            child: frosted,
          );

    if (boxShadow != null && boxShadow!.isNotEmpty) {
      frosted = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: shape == BoxShape.rectangle ? borderRadius : null,
          shape: shape,
          boxShadow: boxShadow,
        ),
        child: frosted,
      );
    }

    return Container(
      width: width,
      height: height,
      constraints: constraints,
      margin: margin,
      alignment: alignment,
      child: frosted,
    );
  }
}

class FrostedAppBar extends AppBar {
  FrostedAppBar({
    super.key,
    Widget? leading,
    bool automaticallyImplyLeading = true,
    Widget? title,
    List<Widget>? actions,
    Widget? flexibleSpace,
    PreferredSizeWidget? bottom,
    Color? backgroundColor,
    double? elevation,
    double? scrolledUnderElevation,
    Color? foregroundColor,
    IconThemeData? iconTheme,
    IconThemeData? actionsIconTheme,
    bool primary = true,
    bool? centerTitle,
    bool excludeHeaderSemantics = false,
    double? titleSpacing,
    double toolbarOpacity = 1.0,
    double bottomOpacity = 1.0,
    double? toolbarHeight,
    double? leadingWidth,
    TextStyle? toolbarTextStyle,
    TextStyle? titleTextStyle,
    SystemUiOverlayStyle? systemOverlayStyle,
    FrostedSurfaceTone tone = FrostedSurfaceTone.surface,
    double blur = FrostedGlassTokens.blurSigma,
  }) : super(
         leading: leading,
         automaticallyImplyLeading: automaticallyImplyLeading,
         title: title,
         actions: actions,
         flexibleSpace: Stack(
           fit: StackFit.expand,
           children: [
             FrostedLayer(
               blur: blur,
               tone: tone,
               tint:
                   backgroundColor == null ||
                       backgroundColor == Colors.transparent
                   ? null
                   : backgroundColor.withOpacity(
                       backgroundColor.opacity < 1
                           ? backgroundColor.opacity
                           : 0.78,
                     ),
             ),
             if (flexibleSpace != null) flexibleSpace,
           ],
         ),
         bottom: bottom,
         elevation: elevation ?? 0,
         scrolledUnderElevation: scrolledUnderElevation ?? 0,
         backgroundColor: Colors.transparent,
         foregroundColor: foregroundColor,
         shadowColor: Colors.transparent,
         surfaceTintColor: Colors.transparent,
         iconTheme: iconTheme,
         actionsIconTheme: actionsIconTheme,
         primary: primary,
         centerTitle: centerTitle,
         excludeHeaderSemantics: excludeHeaderSemantics,
         titleSpacing: titleSpacing,
         toolbarOpacity: toolbarOpacity,
         bottomOpacity: bottomOpacity,
         toolbarHeight: toolbarHeight,
         leadingWidth: leadingWidth,
         toolbarTextStyle: toolbarTextStyle,
         titleTextStyle: titleTextStyle,
         systemOverlayStyle: systemOverlayStyle,
       );
}

class FrostedAlertDialog extends StatelessWidget {
  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final EdgeInsetsGeometry? titlePadding;
  final EdgeInsetsGeometry? contentPadding;
  final EdgeInsetsGeometry? actionsPadding;
  final EdgeInsetsGeometry? buttonPadding;
  final EdgeInsets? insetPadding;
  final ShapeBorder? shape;
  final bool scrollable;
  final String? semanticLabel;
  final AlignmentGeometry? alignment;
  final Clip clipBehavior;

  const FrostedAlertDialog({
    super.key,
    this.title,
    this.content,
    this.actions,
    this.backgroundColor,
    this.titlePadding,
    this.contentPadding,
    this.actionsPadding,
    this.buttonPadding,
    this.insetPadding,
    this.shape,
    this.scrollable = false,
    this.semanticLabel,
    this.alignment,
    this.clipBehavior = Clip.none,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(28);
    final baseTint = backgroundColor == null
        ? FrostedGlassTokens.tintFor(context, tone: FrostedSurfaceTone.strong)
        : backgroundColor!.withOpacity(
            backgroundColor!.opacity < 1
                ? backgroundColor!.opacity
                : Theme.of(context).brightness == Brightness.dark
                ? 0.86
                : 0.82,
          );

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      insetPadding: insetPadding,
      shape: shape ?? RoundedRectangleBorder(borderRadius: radius),
      alignment: alignment,
      clipBehavior: clipBehavior,
      child: FrostedSurface(
        borderRadius: radius,
        tint: baseTint,
        blur: FrostedGlassTokens.strongBlurSigma,
        border: Border.all(
          color: FrostedGlassTokens.subtleBorderSide(context).color,
        ),
        boxShadow: FrostedGlassTokens.materialDepth(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 280),
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title != null)
                  Padding(
                    padding:
                        titlePadding ??
                        const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    child: DefaultTextStyle(
                      style:
                          Theme.of(context).textTheme.headlineSmall ??
                          const TextStyle(fontSize: 24),
                      child: title!,
                    ),
                  ),
                if (content != null)
                  Padding(
                    padding:
                        contentPadding ??
                        const EdgeInsets.fromLTRB(24, 20, 24, 24),
                    child: DefaultTextStyle(
                      style:
                          Theme.of(context).textTheme.bodyMedium ??
                          const TextStyle(fontSize: 14),
                      child: scrollable
                          ? SingleChildScrollView(child: content!)
                          : content!,
                    ),
                  ),
                if (actions != null)
                  Padding(
                    padding:
                        actionsPadding ??
                        const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: OverflowBar(
                      alignment: MainAxisAlignment.end,
                      overflowAlignment: OverflowBarAlignment.end,
                      spacing: 8,
                      overflowSpacing: 4,
                      children: buttonPadding == null
                          ? actions!
                          : actions!
                                .map(
                                  (action) => Padding(
                                    padding: buttonPadding!,
                                    child: action,
                                  ),
                                )
                                .toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FrostedSimpleDialog extends StatelessWidget {
  final Widget? title;
  final List<Widget>? children;
  final Color? backgroundColor;
  final EdgeInsetsGeometry titlePadding;
  final EdgeInsetsGeometry contentPadding;
  final EdgeInsets? insetPadding;
  final ShapeBorder? shape;
  final String? semanticLabel;
  final Clip clipBehavior;

  const FrostedSimpleDialog({
    super.key,
    this.title,
    this.children,
    this.backgroundColor,
    this.titlePadding = const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 0.0),
    this.contentPadding = const EdgeInsets.fromLTRB(0.0, 12.0, 0.0, 16.0),
    this.insetPadding,
    this.shape,
    this.semanticLabel,
    this.clipBehavior = Clip.none,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(28);
    final tint = backgroundColor == null
        ? FrostedGlassTokens.tintFor(context, tone: FrostedSurfaceTone.strong)
        : backgroundColor!.withOpacity(
            backgroundColor!.opacity < 1
                ? backgroundColor!.opacity
                : Theme.of(context).brightness == Brightness.dark
                ? 0.86
                : 0.82,
          );

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      insetPadding: insetPadding,
      shape: shape ?? RoundedRectangleBorder(borderRadius: radius),
      clipBehavior: clipBehavior,
      child: FrostedSurface(
        borderRadius: radius,
        tint: tint,
        blur: FrostedGlassTokens.strongBlurSigma,
        border: Border.all(
          color: FrostedGlassTokens.subtleBorderSide(context).color,
        ),
        boxShadow: FrostedGlassTokens.materialDepth(context),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 280),
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title != null)
                  Padding(
                    padding: titlePadding,
                    child: DefaultTextStyle(
                      style:
                          Theme.of(context).textTheme.headlineSmall ??
                          const TextStyle(fontSize: 24),
                      child: title!,
                    ),
                  ),
                if (children != null)
                  Padding(
                    padding: contentPadding,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children!,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FrostedBottomSheet extends StatelessWidget {
  final Widget child;
  final BorderRadiusGeometry borderRadius;

  const FrostedBottomSheet({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(20)),
  });

  @override
  Widget build(BuildContext context) {
    return FrostedSurface(
      width: double.infinity,
      borderRadius: borderRadius,
      tint: FrostedGlassTokens.tintFor(
        context,
        tone: FrostedSurfaceTone.strong,
      ),
      blur: FrostedGlassTokens.strongBlurSigma,
      border: Border(top: FrostedGlassTokens.subtleBorderSide(context)),
      child: child,
    );
  }
}
