import 'dart:async';

import 'package:flutter/material.dart';

class HomeLoadingSkeleton extends StatefulWidget {
  const HomeLoadingSkeleton({
    super.key,
  });

  @override
  State<HomeLoadingSkeleton> createState() {
    return _HomeLoadingSkeletonState();
  }
}

class _HomeLoadingSkeletonState extends State<HomeLoadingSkeleton> {
  static const Duration _animationDuration = Duration(
    milliseconds: 850,
  );

  Timer? _animationTimer;
  bool _isHighlighted = false;

  @override
  void initState() {
    super.initState();

    _animationTimer = Timer.periodic(
      _animationDuration,
          (_) {
        if (!mounted) {
          return;
        }

        setState(() {
          _isHighlighted = !_isHighlighted;
        });
      },
    );
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    final Color baseColor = colorScheme.surfaceContainerHighest;
    final Color highlightColor = colorScheme.surfaceContainerLow;

    final Color skeletonColor = _isHighlighted
        ? highlightColor
        : baseColor;

    return IgnorePointer(
      child: AnimatedContainer(
        duration: _animationDuration,
        curve: Curves.easeInOut,
        color: colorScheme.surface,
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            16,
            12,
            16,
            32,
          ),
          children: [
            _HomeHeaderSkeleton(
              color: skeletonColor,
            ),
            const SizedBox(height: 20),
            _SkeletonBox(
              height: 210,
              borderRadius: 24,
              color: skeletonColor,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.center,
              child: _SkeletonBox(
                width: 58,
                height: 8,
                borderRadius: 999,
                color: skeletonColor,
              ),
            ),
            const SizedBox(height: 28),
            _SectionHeaderSkeleton(
              color: skeletonColor,
            ),
            const SizedBox(height: 16),
            _CategoryGridSkeleton(
              color: skeletonColor,
            ),
            const SizedBox(height: 28),
            _SkeletonBox(
              height: 150,
              borderRadius: 22,
              color: skeletonColor,
            ),
            const SizedBox(height: 28),
            _SectionHeaderSkeleton(
              color: skeletonColor,
              showSubtitle: false,
            ),
            const SizedBox(height: 16),
            _ProductCarouselSkeleton(
              color: skeletonColor,
            ),
            const SizedBox(height: 30),
            _SectionHeaderSkeleton(
              color: skeletonColor,
            ),
            const SizedBox(height: 16),
            _BrandCarouselSkeleton(
              color: skeletonColor,
            ),
            const SizedBox(height: 30),
            _SectionHeaderSkeleton(
              color: skeletonColor,
              showSubtitle: false,
            ),
            const SizedBox(height: 16),
            _ProductGridSkeleton(
              color: skeletonColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeHeaderSkeleton extends StatelessWidget {
  const _HomeHeaderSkeleton({
    required this.color,
  });

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _SkeletonBox(
          width: 52,
          height: 52,
          borderRadius: 18,
          color: color,
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _SkeletonBox(
              width: 150,
              height: 24,
              borderRadius: 8,
              color: color,
            ),
            const SizedBox(height: 8),
            _SkeletonBox(
              width: 120,
              height: 14,
              borderRadius: 6,
              color: color,
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionHeaderSkeleton extends StatelessWidget {
  const _SectionHeaderSkeleton({
    required this.color,
    this.showSubtitle = true,
  });

  final Color color;
  final bool showSubtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _SkeletonBox(
          width: 68,
          height: 16,
          borderRadius: 6,
          color: color,
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _SkeletonBox(
              width: 160,
              height: 22,
              borderRadius: 8,
              color: color,
            ),
            if (showSubtitle) ...[
              const SizedBox(height: 8),
              _SkeletonBox(
                width: 210,
                height: 14,
                borderRadius: 6,
                color: color,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _CategoryGridSkeleton extends StatelessWidget {
  const _CategoryGridSkeleton({
    required this.color,
  });

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List<Widget>.generate(
        4,
            (int index) {
          return Expanded(
            child: Padding(
              padding: EdgeInsetsDirectional.only(
                start: index == 0 ? 0 : 6,
                end: index == 3 ? 0 : 6,
              ),
              child: Column(
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: _SkeletonBox(
                      borderRadius: 18,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 9),
                  _SkeletonBox(
                    width: 54,
                    height: 13,
                    borderRadius: 6,
                    color: color,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProductCarouselSkeleton extends StatelessWidget {
  const _ProductCarouselSkeleton({
    required this.color,
  });

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 290,
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (
            BuildContext context,
            int index,
            ) {
          return const SizedBox(width: 12);
        },
        itemBuilder: (
            BuildContext context,
            int index,
            ) {
          return SizedBox(
            width: 174,
            child: _ProductCardSkeleton(
              color: color,
            ),
          );
        },
      ),
    );
  }
}

class _ProductGridSkeleton extends StatelessWidget {
  const _ProductGridSkeleton({
    required this.color,
  });

  final Color color;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate:
      const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.62,
      ),
      itemBuilder: (
          BuildContext context,
          int index,
          ) {
        return _ProductCardSkeleton(
          color: color,
        );
      },
    );
  }
}

class _ProductCardSkeleton extends StatelessWidget {
  const _ProductCardSkeleton({
    required this.color,
  });

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _SkeletonBox(
                width: double.infinity,
                borderRadius: 0,
                color: color,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _SkeletonBox(
                    width: double.infinity,
                    height: 16,
                    borderRadius: 6,
                    color: color,
                  ),
                  const SizedBox(height: 8),
                  _SkeletonBox(
                    width: 105,
                    height: 16,
                    borderRadius: 6,
                    color: color,
                  ),
                  const SizedBox(height: 12),
                  _SkeletonBox(
                    width: 82,
                    height: 20,
                    borderRadius: 6,
                    color: color,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandCarouselSkeleton extends StatelessWidget {
  const _BrandCarouselSkeleton({
    required this.color,
  });

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 112,
      child: Row(
        children: List<Widget>.generate(
          3,
              (int index) {
            return Expanded(
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: index == 0 ? 0 : 6,
                  end: index == 2 ? 0 : 6,
                ),
                child: _SkeletonBox(
                  borderRadius: 18,
                  color: color,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.borderRadius,
    required this.color,
    this.width,
    this.height,
  });

  final double? width;
  final double? height;
  final double borderRadius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: _HomeLoadingSkeletonState._animationDuration,
      curve: Curves.easeInOut,
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}