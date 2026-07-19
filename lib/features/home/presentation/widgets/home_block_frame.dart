import 'package:flutter/material.dart';
import 'package:kidia_store_app/features/home/domain/entities/home_block.dart';

class HomeBlockFrame extends StatelessWidget {
  const HomeBlockFrame({
    required this.block,
    required this.child,
    super.key,
  });

  final HomeBlock block;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final HomeBlockPresentation style = block.presentation;
    final double screenScale = homeResponsiveScale(context);
    // An unset block background must remain transparent. Falling back to the
    // theme surface introduced the grey bands that were not present in the
    // Builder preview.
    final Color background =
        _optionalColor(style.backgroundColor) ?? Colors.transparent;

    return Padding(
      key: Key('home-block-frame-${block.id}'),
      padding: EdgeInsets.fromLTRB(
        style.marginHorizontal * screenScale,
        style.marginTop * screenScale,
        style.marginHorizontal * screenScale,
        style.marginBottom * screenScale,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(
          style.borderRadius * screenScale,
        ),
        child: ColoredBox(
          color: background,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: style.paddingHorizontal * screenScale,
              vertical: style.paddingVertical * screenScale,
            ),
            child: HomeResponsiveScope(
              scale: screenScale * style.contentScale,
              child: Builder(
                builder: (BuildContext context) {
                  final double contentScale = HomeResponsiveScope.of(context);
                  final MediaQueryData media = MediaQuery.of(context);
                  final double systemTextScale = media.textScaler.scale(1);
                  return MediaQuery(
                    data: media.copyWith(
                      textScaler: TextScaler.linear(
                        systemTextScale * contentScale,
                      ),
                    ),
                    child: IconTheme.merge(
                      data: IconThemeData(size: 24 * contentScale),
                      child: child,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeResponsiveScope extends InheritedWidget {
  const HomeResponsiveScope({
    required this.scale,
    required super.child,
    super.key,
  });

  final double scale;

  static double of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<HomeResponsiveScope>()
            ?.scale ??
        homeResponsiveScale(context);
  }

  @override
  bool updateShouldNotify(HomeResponsiveScope oldWidget) {
    return scale != oldWidget.scale;
  }
}

double homeResponsiveScale(BuildContext context) {
  final double width = MediaQuery.sizeOf(context).width;
  return (width / 390).clamp(0.84, 1.18).toDouble();
}

Color? _optionalColor(String? value) {
  if (value == null) {
    return null;
  }
  final String hex = value.replaceFirst('#', '');
  final int? parsed = int.tryParse(hex, radix: 16);
  return parsed == null || hex.length != 6
      ? null
      : Color(0xFF000000 | parsed);
}
