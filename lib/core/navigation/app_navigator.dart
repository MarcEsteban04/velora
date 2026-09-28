import 'package:flutter/widgets.dart';

/// The app's root navigator. Actions that must leave every screen (such as
/// "Start over") use it, since they can be triggered from above the
/// navigator, for example the lock screen.
final appNavigatorKey = GlobalKey<NavigatorState>();
