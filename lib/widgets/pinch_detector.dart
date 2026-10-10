import 'package:flutter/widgets.dart';

/// Detecta un pellizco con dos dedos y reporta la escala por eje.
///
/// - Separar los dedos en horizontal → `scaleX` crece.
/// - En vertical → `scaleY` crece.
/// - Si los dedos empiezan muy juntos, se usa una escala uniforme.
///
/// No compite con otros gestos: el hijo sigue recibiendo los toques.
class PinchDetector extends StatefulWidget {
  const PinchDetector({super.key, required this.child, required this.onUpdate, this.onStart, this.onEnd});

  final Widget child;
  final VoidCallback? onStart;
  final void Function(double scaleX, double scaleY, double scale) onUpdate;
  final VoidCallback? onEnd;

  @override
  State<PinchDetector> createState() => _PinchDetectorState();
}

class _PinchDetectorState extends State<PinchDetector> {
  static const _minAxisSpan = 48.0;

  final _pointers = <int, Offset>{};
  Offset? _startSpan;

  Offset _span() {
    final p = _pointers.values.take(2).toList();
    final d = p[0] - p[1];
    return Offset(d.dx.abs(), d.dy.abs());
  }

  void _down(PointerDownEvent e) {
    _pointers[e.pointer] = e.position;
    if (_pointers.length == 2) {
      _startSpan = _span();
      widget.onStart?.call();
    }
  }

  void _move(PointerMoveEvent e) {
    if (!_pointers.containsKey(e.pointer)) return;
    _pointers[e.pointer] = e.position;
    final start = _startSpan;
    if (start == null || _pointers.length < 2) return;
    final now = _span();
    final uniform = start.distance < 1 ? 1.0 : now.distance / start.distance;
    final hasX = start.dx >= _minAxisSpan;
    final hasY = start.dy >= _minAxisSpan;
    if (!hasX && !hasY) {
      widget.onUpdate(uniform, uniform, uniform);
    } else {
      widget.onUpdate(hasX ? now.dx / start.dx : 1, hasY ? now.dy / start.dy : 1, uniform);
    }
  }

  void _up(PointerEvent e) {
    _pointers.remove(e.pointer);
    if (_startSpan != null && _pointers.length < 2) {
      _startSpan = null;
      widget.onEnd?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: widget.child,
    );
  }
}
