/// Navigation service interface for dependency injection and testing.
///
/// This interface abstracts routing operations, enabling dependency injection
/// in screens and mocking in tests. It decouples widgets from go_router
/// implementation details, making navigation testable.
///
/// The interface supports the core navigation operations required by the app:
/// navigating to routes, going back, replacing routes, and checking navigation
/// state.
abstract class INavigationService {
  /// Navigate to the specified route.
  ///
  /// Uses push-based navigation, adding the new route to the navigation stack.
  /// The user can navigate back from the new route to the previous screen.
  ///
  /// Parameters:
  /// - [route]: The route path to navigate to (e.g., '/training', '/calibration')
  ///
  /// Example:
  /// ```dart
  /// navigationService.goTo('/training');
  /// ```
  void goTo(String route);

  /// Navigate back to the previous screen.
  ///
  /// Pops the current route from the navigation stack, returning to the
  /// previous screen. If there is no previous screen (i.e., on the root route),
  /// this is a no-op.
  ///
  /// Example:
  /// ```dart
  /// navigationService.goBack();
  /// ```
  void goBack();

  /// Replace the current route with a new route.
  ///
  /// Replaces the current route in the navigation stack with the specified
  /// route, preventing the user from navigating back to the replaced route.
  /// Useful for flow completion (e.g., after calibration, replace with training).
  ///
  /// Parameters:
  /// - [route]: The route path to replace with (e.g., '/training')
  ///
  /// Example:
  /// ```dart
  /// // After completing calibration, replace with training screen
  /// navigationService.replace('/training');
  /// ```
  void replace(String route);

  /// Check if the user can navigate back.
  ///
  /// Returns true if there is a previous route in the navigation stack that
  /// the user can navigate back to. Returns false if on the root route.
  ///
  /// Useful for conditional UI (e.g., showing/hiding back buttons) or
  /// preventing navigation back in certain states.
  ///
  /// Returns:
  /// - true if navigation back is possible
  /// - false if on the root route
  ///
  /// Example:
  /// ```dart
  /// if (navigationService.canGoBack()) {
  ///   navigationService.goBack();
  /// }
  /// ```
  bool canGoBack();
}
