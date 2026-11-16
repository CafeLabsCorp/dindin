import 'package:flutter/foundation.dart';

/// True while the navigation menu (the dropdown behind the page title) is
/// open. The menu is a dialog on the ROOT navigator, so a page can't see it
/// through its own route (`ModalRoute.isCurrent` stays true); the tutorial
/// host reads this instead, so a tutorial never starts on top of the menu.
final ValueNotifier<bool> navMenuOpen = ValueNotifier<bool>(false);
