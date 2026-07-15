import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/kidia_colors.dart';
import '../core/theme/kidia_typography.dart';
import '../features/account/presentation/account_screen.dart';
import '../features/cart/presentation/cart_screen.dart';
import '../features/categories/presentation/categories_screen.dart';
import '../features/home/presentation/pages/home_page.dart';
import '../features/home/presentation/providers/home_providers.dart';
import '../features/search/presentation/search_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  String _locale = 'ar';

  static const List<Widget> _screens = <Widget>[
    HomePage(),
    CategoriesScreen(),
    SearchScreen(),
    CartScreen(),
    AccountScreen(),
  ];

  static const List<_NavigationItem> _items = <_NavigationItem>[
    _NavigationItem(
      label: 'الرئيسية',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    _NavigationItem(
      label: 'الأقسام',
      icon: Icons.grid_view_outlined,
      selectedIcon: Icons.grid_view_rounded,
    ),
    _NavigationItem(
      label: 'البحث',
      icon: Icons.search_outlined,
      selectedIcon: Icons.search_rounded,
    ),
    _NavigationItem(
      label: 'السلة',
      icon: Icons.shopping_cart_outlined,
      selectedIcon: Icons.shopping_cart_rounded,
      showBadge: true,
    ),
    _NavigationItem(
      label: 'حسابي',
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _locale = Localizations.localeOf(context).languageCode;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.invalidate(homeLayoutProvider(_locale));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: KidiaColors.surface,
            border: Border(
              top: BorderSide(color: KidiaColors.divider),
            ),
          ),
          child: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (int index) {
              setState(() => _currentIndex = index);
            },
            destinations: _items.map((_NavigationItem item) {
              return NavigationDestination(
                icon: _NavigationIcon(
                  icon: item.icon,
                  showBadge: item.showBadge,
                ),
                selectedIcon: _NavigationIcon(
                  icon: item.selectedIcon,
                  showBadge: item.showBadge,
                  selected: true,
                ),
                label: item.label,
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _NavigationIcon extends StatelessWidget {
  const _NavigationIcon({
    required this.icon,
    this.showBadge = false,
    this.selected = false,
  });

  final IconData icon;
  final bool showBadge;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final Widget iconWidget = Icon(
      icon,
      color: selected ? KidiaColors.primaryDark : KidiaColors.textSecondary,
    );

    if (!showBadge) {
      return iconWidget;
    }

    return Badge(
      label: Text(
        '0',
        style: KidiaTypography.labelMedium.copyWith(
          color: Colors.white,
          fontSize: 10,
        ),
      ),
      backgroundColor: KidiaColors.secondary,
      child: iconWidget,
    );
  }
}

class _NavigationItem {
  const _NavigationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.showBadge = false,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool showBadge;
}
