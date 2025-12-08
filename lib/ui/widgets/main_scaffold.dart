import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Main scaffold with bottom navigation bar for app-wide navigation.
///
/// Wraps child screens and provides consistent navigation between
/// Training, Calibration, and Settings screens. Each child screen
/// provides its own Scaffold with AppBar - this widget only adds
/// the bottom navigation.
class MainScaffold extends StatelessWidget {
  /// The current screen content (should be a Scaffold)
  final Widget child;

  /// Current navigation index (0 = Training, 1 = Calibration, 2 = Settings)
  final int currentIndex;

  const MainScaffold({
    super.key,
    required this.child,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: child),
        NavigationBarTheme(
          data: NavigationBarThemeData(
            labelTextStyle: WidgetStateProperty.resolveWith(
              (states) => TextStyle(
                color: states.contains(WidgetState.selected)
                    ? Colors.white
                    : Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          child: NavigationBar(
            backgroundColor: Colors.black.withValues(alpha: 0.65),
            indicatorColor: Colors.deepPurple.withValues(alpha: 0.35),
            elevation: 6,
            selectedIndex: currentIndex,
            onDestinationSelected: (index) => _onNavigate(context, index),
            destinations: const [
              NavigationDestination(
                icon: ImageIcon(
                  AssetImage('assets/images/icons/icon_play.png'),
                  color: Colors.white54,
                ),
                selectedIcon: ImageIcon(
                  AssetImage('assets/images/icons/icon_play.png'),
                  color: Colors.white,
                ),
                label: 'Training',
              ),
              NavigationDestination(
                icon: ImageIcon(
                  AssetImage('assets/images/icons/icon_calibrate.png'),
                  color: Colors.white54,
                ),
                selectedIcon: ImageIcon(
                  AssetImage('assets/images/icons/icon_calibrate.png'),
                  color: Colors.white,
                ),
                label: 'Calibrate',
              ),
              NavigationDestination(
                icon: ImageIcon(
                  AssetImage('assets/images/icons/icon_settings.png'),
                  color: Colors.white54,
                ),
                selectedIcon: ImageIcon(
                  AssetImage('assets/images/icons/icon_settings.png'),
                  color: Colors.white,
                ),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _onNavigate(BuildContext context, int index) {
    if (index == currentIndex) return;

    switch (index) {
      case 0:
        context.go('/training');
        break;
      case 1:
        context.go('/calibration');
        break;
      case 2:
        context.go('/settings');
        break;
    }
  }
}
