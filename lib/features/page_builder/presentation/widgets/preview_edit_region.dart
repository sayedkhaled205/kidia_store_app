import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../../../core/config/app_config.dart';
import '../providers/cms_preview_layout_bridge.dart';

/// Editor metadata only. Native builds return the original child unchanged.
class PreviewEditRegion extends StatelessWidget {
  const PreviewEditRegion({
    required this.target,
    required this.child,
    this.page,
    this.item,
    super.key,
  });

  final String? page;
  final String target;
  final String? item;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.isCmsPreview) return child;
    final resolvedPage = page ?? PreviewEditScope.maybeOf(context);
    if (resolvedPage == null) return child;
    return _EditMetadata(
      selection: PreviewEditSelection(resolvedPage, target, item),
      child: child,
    );
  }
}

class PreviewEditScope extends InheritedWidget {
  const PreviewEditScope({required this.page, required super.child, super.key});
  final String page;
  static String? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PreviewEditScope>()?.page;
  @override
  bool updateShouldNotify(PreviewEditScope oldWidget) => page != oldWidget.page;
}

@immutable
class PreviewEditSelection {
  const PreviewEditSelection(this.page, this.target, this.item);
  final String page;
  final String target;
  final String? item;
}

class _EditMetadata extends SingleChildRenderObjectWidget {
  const _EditMetadata({required this.selection, required super.child});
  final PreviewEditSelection selection;
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _EditRenderBox(selection);
  @override
  void updateRenderObject(BuildContext context, _EditRenderBox renderObject) {
    renderObject.selection = selection;
  }
}

class _EditRenderBox extends RenderProxyBox {
  _EditRenderBox(this.selection);
  PreviewEditSelection selection;
  @override
  bool hitTestSelf(Offset position) => true;
}

/// The outline is painted above the app but cannot receive pointer events.
/// Only the small corner button participates in hit testing. Real hit-test
/// geometry (including transforms, clipping and scrolling) picks the deepest
/// editable region, rather than guessing sections from screen coordinates.
class PreviewEditInspector extends StatefulWidget {
  const PreviewEditInspector({required this.child, this.onEdit, super.key});
  final Widget child;
  final ValueChanged<PreviewEditSelection>? onEdit;
  @override
  State<PreviewEditInspector> createState() => _PreviewEditInspectorState();
}

class _PreviewEditInspectorState extends State<PreviewEditInspector> {
  final _surfaceKey = GlobalKey();
  _EditRenderBox? _target;
  Offset? _pointer;
  Rect? _rect;
  Rect? _buttonRect;
  bool _refreshPending = false;
  bool _buttonHovered = false;

  void _inspect(Offset globalPosition) {
    _pointer = globalPosition;
    final surface =
        _surfaceKey.currentContext?.findRenderObject() as RenderBox?;
    // A fast jump from the pencil can arrive before its mouse-exit callback.
    // Freeze selection only while the pointer is actually over the pencil.
    if (_buttonHovered && _buttonRect != null && surface != null) {
      if (_buttonRect!.contains(surface.globalToLocal(globalPosition))) return;
      _buttonHovered = false;
    }
    final result = HitTestResult();
    RendererBinding.instance.hitTestInView(
      result,
      globalPosition,
      View.of(context).viewId,
    );
    _EditRenderBox? target;
    for (final entry in result.path) {
      if (entry.target is _EditRenderBox) {
        target = entry.target as _EditRenderBox;
        break;
      }
    }
    Rect? rect;
    if (target != null && target.attached && surface != null) {
      rect = MatrixUtils.transformRect(
        target.getTransformTo(surface),
        Offset.zero & target.size,
      ).intersect(Offset.zero & surface.size);
      if (rect.width < 24 || rect.height < 24) rect = null;
    }
    if (_target != target || _rect != rect) {
      setState(() {
        _target = target;
        _rect = rect;
        _buttonRect = rect == null || surface == null
            ? null
            : _placeButton(rect, surface.size);
      });
    }
  }

  // A pencil must never cover the normal tap at the center of a small icon.
  // Keep large-section pencils in the corner; put small-item pencils just
  // outside the item, clamped to the preview viewport.
  Rect _placeButton(Rect rect, Size viewport) {
    Rect fit(Offset point) => Rect.fromLTWH(
      point.dx.clamp(0, (viewport.width - 28).clamp(0, double.infinity)),
      point.dy.clamp(0, (viewport.height - 28).clamp(0, double.infinity)),
      28,
      28,
    );
    final candidates = [
      Offset(rect.right - 28, rect.top),
      Offset(rect.right - 14, rect.top - 14),
      Offset(rect.center.dx - 14, rect.top - 28),
      Offset(rect.left - 28, rect.center.dy - 14),
      Offset(rect.right, rect.center.dy - 14),
      Offset(rect.center.dx - 14, rect.bottom),
    ].map(fit);
    final tapCenter = Rect.fromCenter(
      center: rect.center,
      width: 16,
      height: 16,
    );
    return candidates.firstWhere(
      (candidate) => !candidate.overlaps(tapCenter),
      orElse: () => candidates.first,
    );
  }

  void _refresh() {
    if (_refreshPending || _pointer == null) return;
    _refreshPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshPending = false;
      if (mounted && _pointer != null) {
        _buttonHovered = false;
        _inspect(_pointer!);
      }
    });
  }

  void _clear() {
    if (_pointer == null && _rect == null) return;
    setState(() {
      _pointer = null;
      _target = null;
      _rect = null;
      _buttonRect = null;
      _buttonHovered = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final rect = _target?.attached == true ? _rect : null;
    final arabic = Localizations.localeOf(context).languageCode == 'ar';
    const accent = Color(0xFF278573);
    return MouseRegion(
      onHover: (event) => _inspect(event.position),
      onExit: (_) => _clear(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (_) {
          _refresh();
          return false;
        },
        child: Listener(
          onPointerDown: (event) {
            if (event.kind != PointerDeviceKind.mouse) _clear();
          },
          child: Stack(
            key: _surfaceKey,
            fit: StackFit.expand,
            children: [
              widget.child,
              if (rect != null) ...[
                Positioned.fromRect(
                  rect: rect,
                  child: IgnorePointer(
                    child: DecoratedBox(
                      key: const Key('preview-edit-outline'),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: accent.withValues(alpha: .7),
                          width: 1.2,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: _buttonRect!.top,
                  right: null,
                  left: _buttonRect!.left,
                  child: MouseRegion(
                    onEnter: (_) => _buttonHovered = true,
                    onExit: (_) => _buttonHovered = false,
                    child: Material(
                      color: accent,
                      borderRadius: BorderRadius.circular(4),
                      child: Semantics(
                        container: true,
                        label: arabic
                            ? 'تعديل إعدادات العنصر'
                            : 'Edit element settings',
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: IconButton(
                            key: const Key('preview-edit-button'),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            iconSize: 17,
                            color: Colors.white,
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () {
                              final selection = _target?.selection;
                              if (selection == null ||
                                  _target?.attached != true) {
                                return;
                              }
                              if (widget.onEdit != null) {
                                widget.onEdit!(selection);
                              } else {
                                CmsPreviewLayoutBridge.editElement(
                                  selection.page,
                                  selection.target,
                                  selection.item,
                                );
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
