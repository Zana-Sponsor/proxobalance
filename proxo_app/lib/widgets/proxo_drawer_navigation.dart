import 'package:flutter/widgets.dart';

/// Sync Android's ahead-of-time Back registration after drawer local history
/// changes. Flutter 3.47's Drawer closes correctly on a Flutter pop, but opening
/// it on the root route does not dispatch this navigation notification itself.
/// Without it, Android can finish the activity before Flutter receives Back.
void syncProxoDrawerBackNavigation(BuildContext context) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!context.mounted) return;
    final route = ModalRoute.of(context);
    NavigationNotification(
      canHandlePop: Navigator.of(context).canPop() ||
          route?.popDisposition == RoutePopDisposition.doNotPop,
    ).dispatch(context);
  });
}
