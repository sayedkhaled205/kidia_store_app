import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kidia_store_app/features/home/domain/entities/home_block.dart';
import 'package:kidia_store_app/shared/widgets/common/app_network_image.dart';
import 'package:video_player/video_player.dart';

class PromoStripBlockWidget extends StatefulWidget {
  const PromoStripBlockWidget({
    required this.block,
    required this.onAction,
    super.key,
  });

  final PromoStripBlock block;
  final ValueChanged<HomeAction> onAction;

  @override
  State<PromoStripBlockWidget> createState() => _PromoStripBlockWidgetState();
}

class _PromoStripBlockWidgetState extends State<PromoStripBlockWidget> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) {
      return const SizedBox.shrink();
    }

    final PromoStripBlock block = widget.block;
    final Color background = homeBlockColor(block.backgroundColor);
    final Color foreground = homeBlockColor(block.textColor);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(block.borderRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: block.action == null
              ? null
              : () => widget.onAction(block.action!),
          child: Padding(
            padding: EdgeInsets.all(block.padding),
            child: Row(
              children: [
                Icon(Icons.campaign_rounded, color: foreground, size: 21),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    block.text,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (block.buttonLabel != null && block.action != null)
                  TextButton(
                    onPressed: () => widget.onAction(block.action!),
                    style: TextButton.styleFrom(foregroundColor: foreground),
                    child: Text(block.buttonLabel!),
                  ),
                if (block.dismissible)
                  IconButton(
                    tooltip: 'إخفاء',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _dismissed = true),
                    icon: Icon(Icons.close_rounded, color: foreground),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CouponBannerBlockWidget extends StatelessWidget {
  const CouponBannerBlockWidget({
    required this.block,
    required this.onAction,
    super.key,
  });

  final CouponBannerBlock block;
  final ValueChanged<HomeAction> onAction;

  Future<void> _copyCoupon(BuildContext context) async {
    final String? code = block.couponCode;
    if (code == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('تم نسخ كود الخصم')));
  }

  @override
  Widget build(BuildContext context) {
    final Color background = homeBlockColor(block.backgroundColor);
    final Color foreground = homeBlockColor(block.textColor);
    final bool expired =
        block.expiresAt != null && block.expiresAt!.isBefore(DateTime.now());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: block.action == null ? null : () => onAction(block.action!),
          child: Row(
            children: [
              if (block.imageUrl != null)
                SizedBox(
                  width: 116,
                  height: 168,
                  child: AppNetworkImage(
                    imageUrl: block.imageUrl!,
                    fit: BoxFit.cover,
                    semanticLabel: block.title,
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        block.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (block.description != null) ...[
                        const SizedBox(height: 5),
                        Text(
                          block.description!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: foreground.withValues(alpha: 0.82),
                              ),
                        ),
                      ],
                      if (block.couponCode != null) ...[
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: expired
                              ? null
                              : () => _copyCoupon(context),
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          label: Text(
                            '${block.copyButtonLabel}: ${block.couponCode}',
                          ),
                        ),
                      ],
                      if (expired) ...[
                        const SizedBox(height: 5),
                        Text(
                          'انتهت صلاحية العرض',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: foreground,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                      if (block.buttonLabel != null &&
                          block.action != null) ...[
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: () => onAction(block.action!),
                          child: Text(block.buttonLabel!),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CountdownBlockWidget extends StatefulWidget {
  const CountdownBlockWidget({
    required this.block,
    required this.onAction,
    super.key,
  });

  final CountdownBlock block;
  final ValueChanged<HomeAction> onAction;

  @override
  State<CountdownBlockWidget> createState() => _CountdownBlockWidgetState();
}

class _CountdownBlockWidgetState extends State<CountdownBlockWidget> {
  Timer? _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _refresh());
  }

  @override
  void didUpdateWidget(covariant CountdownBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.endsAt != widget.block.endsAt) {
      _refresh();
    }
  }

  void _refresh() {
    final Duration next = widget.block.endsAt.difference(DateTime.now());
    if (!mounted) {
      _remaining = next.isNegative ? Duration.zero : next;
      return;
    }
    setState(() {
      _remaining = next.isNegative ? Duration.zero : next;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CountdownBlock block = widget.block;
    final bool expired = _remaining == Duration.zero;
    if (expired && block.endBehavior == 'hide') {
      return const SizedBox.shrink();
    }

    final Color background = homeBlockColor(block.backgroundColor);
    final Color foreground = homeBlockColor(block.textColor);
    final int days = _remaining.inDays;
    final int hours = _remaining.inHours.remainder(24);
    final int minutes = _remaining.inMinutes.remainder(60);
    final int seconds = _remaining.inSeconds.remainder(60);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(22),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: block.action == null
              ? null
              : () => widget.onAction(block.action!),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                if (block.title != null) ...[
                  Text(
                    block.title!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (expired)
                  Text(
                    block.expiredText,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _TimeUnit(
                        value: days,
                        label: block.daysLabel,
                        color: foreground,
                      ),
                      _TimeUnit(
                        value: hours,
                        label: block.hoursLabel,
                        color: foreground,
                      ),
                      _TimeUnit(
                        value: minutes,
                        label: block.minutesLabel,
                        color: foreground,
                      ),
                      _TimeUnit(
                        value: seconds,
                        label: block.secondsLabel,
                        color: foreground,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeUnit extends StatelessWidget {
  const _TimeUnit({
    required this.value,
    required this.label,
    required this.color,
  });

  final int value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value.toString().padLeft(2, '0'),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: color.withValues(alpha: 0.8)),
        ),
      ],
    );
  }
}

class VideoBannerBlockWidget extends StatefulWidget {
  const VideoBannerBlockWidget({
    required this.block,
    required this.onAction,
    super.key,
  });

  final VideoBannerBlock block;
  final ValueChanged<HomeAction> onAction;

  @override
  State<VideoBannerBlockWidget> createState() => _VideoBannerBlockWidgetState();
}

class _VideoBannerBlockWidgetState extends State<VideoBannerBlockWidget> {
  VideoPlayerController? _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant VideoBannerBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.block.videoUrl != widget.block.videoUrl) {
      _controller?.dispose();
      _controller = null;
      _error = null;
      _initialize();
    }
  }

  Future<void> _initialize() async {
    final VideoPlayerController controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.block.videoUrl),
    );
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(widget.block.loop);
      await controller.setVolume(widget.block.muted ? 0 : 1);
      if (widget.block.autoPlay) {
        await controller.play();
      }
      if (mounted) {
        setState(() {});
      }
    } on Object catch (error) {
      _error = error;
      await controller.dispose();
      if (identical(_controller, controller)) {
        _controller = null;
      }
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _togglePlayback() {
    final VideoPlayerController? controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      widget.onAction(
        widget.block.action ??
            HomeAction(type: 'external', value: widget.block.videoUrl),
      );
      return;
    }
    setState(() {
      controller.value.isPlaying ? controller.pause() : controller.play();
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final VideoBannerBlock block = widget.block;
    final VideoPlayerController? controller = _controller;
    final bool ready = controller?.value.isInitialized ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: AspectRatio(
        aspectRatio: block.aspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: ready
                    ? FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: controller!.value.size.width,
                          height: controller!.value.size.height,
                          child: VideoPlayer(controller!),
                        ),
                      )
                    : block.posterUrl != null
                    ? AppNetworkImage(
                        imageUrl: block.posterUrl!,
                        fit: BoxFit.cover,
                        semanticLabel: block.title,
                      )
                    : Center(
                        child: Icon(
                          _error == null
                              ? Icons.video_library_outlined
                              : Icons.videocam_off_outlined,
                          size: 48,
                        ),
                      ),
              ),
              if (block.overlayOpacity > 0)
                ColoredBox(
                  color: homeBlockColor(
                    block.overlayColor,
                  ).withValues(alpha: block.overlayOpacity),
                ),
              if (block.showControls || !ready)
                Center(
                  child: IconButton.filled(
                    onPressed: _togglePlayback,
                    iconSize: 32,
                    icon: Icon(
                      ready && controller!.value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                    ),
                  ),
                ),
              if (block.showControls && ready)
                PositionedDirectional(
                  start: 12,
                  end: 12,
                  bottom: 7,
                  child: VideoProgressIndicator(
                    controller!,
                    allowScrubbing: true,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    colors: VideoProgressColors(
                      playedColor: Theme.of(context).colorScheme.primary,
                      bufferedColor: Colors.white.withValues(alpha: 0.45),
                      backgroundColor: Colors.black.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              if (block.title != null || block.subtitle != null)
                PositionedDirectional(
                  start: 18,
                  end: 18,
                  bottom: block.showControls ? 30 : 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (block.title != null)
                        Text(
                          block.title!,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      if (block.subtitle != null)
                        Text(
                          block.subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(color: Colors.white),
                        ),
                    ],
                  ),
                ),
              if (block.buttonLabel != null && block.action != null)
                PositionedDirectional(
                  end: 14,
                  top: 14,
                  child: FilledButton.tonal(
                    onPressed: () => widget.onAction(block.action!),
                    child: Text(block.buttonLabel!),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class TextBlockWidget extends StatelessWidget {
  const TextBlockWidget({required this.block, super.key});

  final TextBlock block;

  @override
  Widget build(BuildContext context) {
    final TextAlign textAlign = switch (block.alignment) {
      'left' => TextAlign.left,
      'center' => TextAlign.center,
      _ => TextAlign.right,
    };
    final Color textColor = homeBlockColor(block.textColor);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: block.backgroundColor == null
              ? Colors.transparent
              : homeBlockColor(block.backgroundColor!),
          borderRadius: BorderRadius.circular(block.borderRadius),
        ),
        child: Padding(
          padding: EdgeInsets.all(block.padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (block.title != null) ...[
                Text(
                  block.title!,
                  textAlign: textAlign,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              if (block.content.isNotEmpty)
                SelectableText.rich(
                  _richTextFromHtml(
                    block.content,
                    Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: textColor,
                          fontSize: block.fontSize,
                          height: 1.55,
                        ) ??
                        TextStyle(
                          color: textColor,
                          fontSize: block.fontSize,
                          height: 1.55,
                        ),
                  ),
                  textAlign: textAlign,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class DividerBlockWidget extends StatelessWidget {
  const DividerBlockWidget({required this.block, super.key});

  final DividerBlock block;

  @override
  Widget build(BuildContext context) {
    final Alignment alignment = switch (block.alignment) {
      'left' => Alignment.centerLeft,
      'right' => Alignment.centerRight,
      _ => Alignment.center,
    };

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: block.margin),
      child: Align(
        alignment: alignment,
        child: FractionallySizedBox(
          widthFactor: block.widthPercent / 100,
          child: CustomPaint(
            painter: _DividerPainter(
              color: homeBlockColor(block.color),
              thickness: block.thickness,
              style: block.style,
            ),
            child: SizedBox(height: block.thickness),
          ),
        ),
      ),
    );
  }
}

class _DividerPainter extends CustomPainter {
  const _DividerPainter({
    required this.color,
    required this.thickness,
    required this.style,
  });

  final Color color;
  final double thickness;
  final String style;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = style == 'dotted' ? StrokeCap.round : StrokeCap.butt;
    if (style == 'solid') {
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        paint,
      );
      return;
    }

    final double dash = style == 'dotted' ? thickness : thickness * 5;
    final double gap = style == 'dotted' ? thickness * 2.5 : thickness * 3;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset((x + dash).clamp(0, size.width).toDouble(), size.height / 2),
        paint,
      );
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DividerPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.thickness != thickness ||
        oldDelegate.style != style;
  }
}

class ResponsiveSpacerBlockWidget extends StatelessWidget {
  const ResponsiveSpacerBlockWidget({required this.block, super.key});

  final SpacerBlock block;

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final double height = width >= 1024
        ? block.desktopHeight
        : width >= 600
        ? block.tabletHeight
        : block.height;
    return SizedBox(height: height);
  }
}

Color homeBlockColor(String value) {
  final String normalized = value.replaceFirst('#', '');
  final String withAlpha = normalized.length == 6
      ? 'FF$normalized'
      : normalized;
  return Color(int.tryParse(withAlpha, radix: 16) ?? 0xFF000000);
}

TextSpan _richTextFromHtml(String html, TextStyle baseStyle) {
  final String normalized = html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ')
      .replaceAll(RegExp(r'</li\s*>', caseSensitive: false), '\n');
  final Iterable<RegExpMatch> tokens = RegExp(
    r'<[^>]+>|[^<]+',
  ).allMatches(normalized);
  final List<InlineSpan> spans = <InlineSpan>[];
  int boldDepth = 0;
  int italicDepth = 0;
  int underlineDepth = 0;
  int headingLevel = 0;

  for (final RegExpMatch match in tokens) {
    final String token = match.group(0) ?? '';
    if (token.startsWith('<')) {
      final String tag = token
          .replaceAll(RegExp(r'[<>]'), '')
          .trim()
          .toLowerCase();
      final bool closing = tag.startsWith('/');
      final String name = tag.replaceFirst('/', '').split(RegExp(r'\s+')).first;
      switch (name) {
        case 'b' || 'strong':
          boldDepth = (boldDepth + (closing ? -1 : 1)).clamp(0, 100).toInt();
        case 'i' || 'em':
          italicDepth = (italicDepth + (closing ? -1 : 1))
              .clamp(0, 100)
              .toInt();
        case 'u' || 'a':
          underlineDepth = (underlineDepth + (closing ? -1 : 1))
              .clamp(0, 100)
              .toInt();
        case 'h1' || 'h2' || 'h3' || 'h4' || 'h5' || 'h6':
          headingLevel = closing ? 0 : int.parse(name.substring(1));
          if (closing) {
            spans.add(const TextSpan(text: '\n'));
          }
      }
      continue;
    }

    final String text = _decodeHtmlEntities(token);
    if (text.isEmpty) {
      continue;
    }
    final double headingScale = switch (headingLevel) {
      1 => 1.6,
      2 => 1.45,
      3 => 1.3,
      4 => 1.2,
      _ => 1,
    };
    spans.add(
      TextSpan(
        text: text,
        style: baseStyle.copyWith(
          fontSize: (baseStyle.fontSize ?? 16) * headingScale,
          fontWeight: boldDepth > 0 || headingLevel > 0
              ? FontWeight.w800
              : baseStyle.fontWeight,
          fontStyle: italicDepth > 0 ? FontStyle.italic : baseStyle.fontStyle,
          decoration: underlineDepth > 0
              ? TextDecoration.underline
              : baseStyle.decoration,
        ),
      ),
    );
  }

  return TextSpan(style: baseStyle, children: spans);
}

String _decodeHtmlEntities(String value) {
  return value
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll('&#039;', "'");
}
