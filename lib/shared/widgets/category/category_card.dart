import 'package:flutter/material.dart';
import 'package:kidia_store_app/shared/widgets/common/app_network_image.dart';

class CategoryCard extends StatelessWidget {
  const CategoryCard({
    required this.name,
    required this.imageUrl,
    super.key,
    this.onTap,
    this.semanticLabel,
    this.imageSize = 78,
    this.showName = true,
    this.compact = false,
    this.count = 0,
    this.showCount = false,
    this.style = 'circle',
    this.imageAspectRatio = 1,
  });

  final String name;
  final String imageUrl;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final double imageSize;
  final bool showName;
  final bool compact;
  final int count;
  final bool showCount;
  final String style;
  final double imageAspectRatio;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;

    final double resolvedImageSize = compact ? imageSize * 0.92 : imageSize;

    final bool circle = style == 'circle';
    final bool overlay = style == 'overlay';
    final double radius = circle
        ? resolvedImageSize / 2
        : style == 'square'
        ? 8
        : (compact ? 16 : 18);
    final double imageHeight = resolvedImageSize / imageAspectRatio;

    return Semantics(
      button: onTap != null,
      label: semanticLabel ?? name,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 3 : 5,
              vertical: compact ? 3 : 5,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: resolvedImageSize,
                  height: imageHeight,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(radius),
                    border: Border.all(color: colorScheme.outlineVariant),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AppNetworkImage(
                        imageUrl: imageUrl,
                        width: resolvedImageSize,
                        height: imageHeight,
                        fit: BoxFit.cover,
                        semanticLabel: name,
                      ),
                      if (overlay && showName)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 7,
                            ),
                            color: Colors.black.withValues(alpha: 0.58),
                            child: Text(
                              showCount ? '$name ($count)' : name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (showName && !overlay) ...[
                  SizedBox(height: compact ? 7 : 9),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: resolvedImageSize + 12,
                    ),
                    child: Text(
                      showCount ? '$name ($count)' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
