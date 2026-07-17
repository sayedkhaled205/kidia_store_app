import 'package:flutter/material.dart';

/// One stable commerce header for catalog, product, and wishlist screens.
///
/// When supplied, the title inherits the app-wide AppBar typography and color,
/// which keeps it identical to the Account screen while centering it on every
/// supported text direction. Product details intentionally omit the title.
class CommerceAppBar extends StatelessWidget implements PreferredSizeWidget {
  const CommerceAppBar({
    super.key,
    this.title,
    this.actions = const <Widget>[],
    this.leading,
    this.automaticallyImplyLeading = true,
  });

  final String? title;
  final List<Widget> actions;
  final Widget? leading;
  final bool automaticallyImplyLeading;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final String? appBarTitle = title;
    return AppBar(
      key: const Key('commerce-app-bar'),
      centerTitle: true,
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: leading,
      title: appBarTitle == null
          ? null
          : Text(
              appBarTitle,
              key: const Key('commerce-app-bar-title'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      actions: actions,
    );
  }
}
