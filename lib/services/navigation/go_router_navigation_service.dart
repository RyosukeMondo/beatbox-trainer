import 'package:go_router/go_router.dart';
import 'i_navigation_service.dart';

/// Implementation of [INavigationService] using go_router.
///
/// This service wraps go_router navigation methods, providing a clean
/// abstraction layer for dependency injection and testing. It delegates
/// all navigation operations to the provided [GoRouter] instance.
///
/// Thread Safety: All navigation methods must be called from the UI thread.
/// go_router handles navigation state internally, making this service
/// inherently thread-safe when used correctly.
///
/// Example usage:
/// ```dart
/// final router = GoRouter(routes: [...]);
/// final navigationService = GoRouterNavigationService(router);
///
/// // Navigate to training screen
/// navigationService.goTo('/training');
///
/// // Navigate back
/// if (navigationService.canGoBack()) {
///   navigationService.goBack();
/// }
/// ```
class GoRouterNavigationService implements INavigationService {
  /// The go_router instance to delegate navigation calls to
  final GoRouter _router;

  /// Create a navigation service wrapping the provided [GoRouter] instance.
  ///
  /// Parameters:
  /// - [router]: The go_router instance to use for navigation operations
  ///
  /// Example:
  /// ```dart
  /// final router = GoRouter(routes: [...]);
  /// final service = GoRouterNavigationService(router);
  /// ```
  GoRouterNavigationService(this._router);

  @override
  void goTo(String route) {
    _router.go(route);
  }

  @override
  void goBack() {
    _router.pop();
  }

  @override
  void replace(String route) {
    _router.replace(route);
  }

  @override
  bool canGoBack() {
    return _router.canPop();
  }
}
