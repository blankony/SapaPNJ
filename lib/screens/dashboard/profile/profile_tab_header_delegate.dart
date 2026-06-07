import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

class ProfileTabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  ProfileTabHeaderDelegate(this.tabBar, this.backgroundColor);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return FrostedLayer(
      tint: backgroundColor.withValues(
        alpha: Theme.of(context).brightness == Brightness.dark ? 0.78 : 0.74,
      ),
      blur: FrostedGlassTokens.controlBlurSigma,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(ProfileTabHeaderDelegate oldDelegate) => true;
}
