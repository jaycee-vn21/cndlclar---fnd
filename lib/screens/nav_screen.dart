import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cndlclar/providers/current_screen_index_provider.dart';
import 'package:cndlclar/screens/home_screen.dart';
import 'package:cndlclar/utils/constants.dart';

class NavScreen extends StatefulWidget {
  const NavScreen({super.key});

  @override
  State<NavScreen> createState() => _NavScreenState();
}

class _NavScreenState extends State<NavScreen> {
  final List<Widget> _screens = const [HomeScreen(), AlertsScreen()];
  final List<IconData> _icons = [KIcons.navHome, KIcons.navAlert];
  final List<String> _labels = ['Home', 'Alerts'];

  @override
  Widget build(BuildContext context) {
    final currentIndex = Provider.of<CurrentScreenIndexProvider>(
      context,
    ).currentScreenIndex;

    return Scaffold(
      backgroundColor: KColors.background,
      body: IndexedStack(index: currentIndex, children: _screens),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: KSizes.navBarHorizontalPadding,
          vertical: KSizes.navBarVerticalPadding,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(KSizes.navBarBorderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: KSizes.navGlassBlurSigma,
              sigmaY: KSizes.navGlassBlurSigma,
            ),
            child: Container(
              height: KSizes.navBarHeight,
              decoration: BoxDecoration(
                gradient: KGradients.navGlass,
                color: KColors.floatingBarBase.withOpacity(
                  KSizes.navGlassOpacity,
                ),
                borderRadius: BorderRadius.circular(KSizes.navBarBorderRadius),
                boxShadow: [KShadows.nav],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(_icons.length, (index) {
                  final bool isSelected = index == currentIndex;
                  return GestureDetector(
                    onTap: () => Provider.of<CurrentScreenIndexProvider>(
                      context,
                      listen: false,
                    ).setIndex(index),
                    child: AnimatedContainer(
                      duration: KDurations.navAnimation,
                      padding: EdgeInsets.symmetric(
                        horizontal: KSizes.navIconPadding,
                      ),
                      decoration: isSelected
                          ? BoxDecoration(
                              color: KColors.activeTabHighlight.withOpacity(
                                KSizes.activeTabHighlightOpacity,
                              ),
                              borderRadius: BorderRadius.circular(
                                KSizes.navIconBorderRadius,
                              ),
                            )
                          : null,
                      child: Semantics(
                        label: _labels[index],
                        selected: isSelected,
                        child: AnimatedScale(
                          scale: isSelected
                              ? KSizes.navIconSelectedScale
                              : KSizes.navIconUnselectedScale,
                          duration: KDurations.navAnimation,
                          child: Icon(
                            _icons[index],
                            size: KSizes.navIconSize,
                            color: isSelected
                                ? KColors.activeIcon
                                : KColors.inactiveIcon,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Alerts',
        style: KTextStyles.appBarTitle.copyWith(fontSize: 24),
      ),
    );
  }
}
