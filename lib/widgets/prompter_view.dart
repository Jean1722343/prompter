import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme.dart';

/// Estado del teleprompter: reproducir, pausar, cuenta atrás y progreso.
class PrompterController extends ChangeNotifier {
  bool _playing = false;
  int? _countdown;
  double _progress = 0;
  bool _atEnd = false;
  Timer? _countdownTimer;
  _PrompterViewState? _view;

  bool get playing => _playing;

  /// 3, 2, 1… mientras cuenta; `null` si no hay cuenta atrás.
  int? get countdown => _countdown;

  /// Busy = reproduciendo o contando.
  bool get busy => _playing || _countdown != null;
  double get progress => _progress;
  bool get atEnd => _atEnd;

  void play({bool countdown = true}) {
    if (busy) return;
    if (_atEnd) _view?._jumpTo(0);
    if (countdown && _progress < 0.001) {
      _countdown = 3;
      notifyListeners();
      _countdownTimer = Timer.periodic(const Duration(milliseconds: 850), (t) {
        final next = (_countdown ?? 1) - 1;
        if (next <= 0) {
          t.cancel();
          _countdown = null;
          _playing = true;
        } else {
          _countdown = next;
        }
        notifyListeners();
      });
    } else {
      _playing = true;
      notifyListeners();
    }
  }

  void pause() {
    _countdownTimer?.cancel();
    if (!busy) return;
    _countdown = null;
    _playing = false;
    notifyListeners();
  }

  void toggle() => busy ? pause() : play();

  void restart() {
    pause();
    _view?._jumpTo(0);
  }

  /// Salta a una posición del guion (0 = inicio, 1 = final).
  void seek(double fraction) => _view?._seek(fraction);

  /// Avanza o retrocede unas líneas a mano.
  void nudge(double lines) => _view?._nudge(lines);

  void _setProgress(double value, bool atEnd) {
    if ((value - _progress).abs() < 0.0005 && atEnd == _atEnd) return;
    _progress = value;
    _atEnd = atEnd;
    notifyListeners();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }
}

/// Texto que sube solo, con una guía de lectura y bordes difuminados.
class PrompterView extends StatefulWidget {
  const PrompterView({
    super.key,
    required this.text,
    required this.controller,
    required this.fontSize,
    required this.speed,
    this.mirror = false,
    this.textShadow = false,
    this.textColor = Colors.white,
    this.guidePosition = 0.28,
    this.horizontalPadding = 24,
    this.userScroll = true,
    this.onTap,
  });

  final String text;
  final PrompterController controller;
  final double fontSize;
  final double speed;
  final bool mirror;

  /// Sombra bajo las letras para leer sobre fondos transparentes.
  final bool textShadow;

  /// Color del texto. La sombra se adapta: oscura para letra clara y
  /// halo blanco para letra oscura.
  final Color textColor;

  /// Altura de la línea de lectura, de 0 (arriba) a 1 (abajo).
  final double guidePosition;
  final double horizontalPadding;

  /// Permite arrastrar el texto con un dedo.
  final bool userScroll;

  /// Si es null, tocar el texto pausa/reanuda.
  final VoidCallback? onTap;

  static const lineHeight = 1.45;

  @override
  State<PrompterView> createState() => _PrompterViewState();
}

class _PrompterViewState extends State<PrompterView> with SingleTickerProviderStateMixin {
  final _scroll = ScrollController();
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  double _position = 0;
  bool _dragging = false;
  bool _resumeAfterDrag = false;

  PrompterController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _c._view = this;
    _c.addListener(_syncTicker);
    _scroll.addListener(_reportProgress);
  }

  @override
  void didUpdateWidget(PrompterView old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_syncTicker);
      if (old.controller._view == this) old.controller._view = null;
      widget.controller._view = this;
      widget.controller.addListener(_syncTicker);
    }
    if (old.text != widget.text) {
      _c.pause();
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpTo(0));
    } else if (old.fontSize != widget.fontSize || old.mirror != widget.mirror) {
      // Mantiene el punto de lectura al cambiar el tamaño de letra.
      final fraction = _c.progress;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_ready) return;
        _jumpTo(fraction * _scroll.position.maxScrollExtent);
      });
    }
  }

  @override
  void dispose() {
    _c.removeListener(_syncTicker);
    if (_c._view == this) _c._view = null;
    _ticker.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _syncTicker() {
    final shouldRun = _c.playing && !_dragging;
    if (shouldRun && !_ticker.isActive) {
      _lastTick = Duration.zero;
      if (_scroll.hasClients) _position = _scroll.offset;
      _ticker.start();
    } else if (!shouldRun && _ticker.isActive) {
      _ticker.stop();
    }
    if (mounted) setState(() {});
  }

  /// Píxeles por segundo: velocidad 1 ≈ 0.12 líneas/s, 10 ≈ 1.2 líneas/s.
  double get _pixelsPerSecond => widget.speed * 0.12 * widget.fontSize * PrompterView.lineHeight;

  void _onTick(Duration elapsed) {
    if (!_ready) return;
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    if (dt <= 0 || dt > 0.25) return;
    final max = _scroll.position.maxScrollExtent;
    _position = (_position + _pixelsPerSecond * dt).clamp(0.0, max);
    _scroll.jumpTo(_position);
    if (_position >= max) _c.pause();
  }

  bool get _ready => _scroll.hasClients && _scroll.position.hasContentDimensions;

  void _jumpTo(double offset) {
    if (!_ready) {
      _position = 0;
      return;
    }
    _position = offset.clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.jumpTo(_position);
    _reportProgress();
  }

  void _seek(double fraction) {
    if (!_ready) return;
    _jumpTo(fraction.clamp(0.0, 1.0) * _scroll.position.maxScrollExtent);
  }

  void _nudge(double lines) {
    if (!_ready) return;
    final target = (_scroll.offset + lines * widget.fontSize * PrompterView.lineHeight).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    _position = target;
    _scroll.animateTo(target, duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
  }

  void _reportProgress() {
    if (!_ready) return;
    final max = _scroll.position.maxScrollExtent;
    final progress = max <= 0 ? 1.0 : (_scroll.offset / max).clamp(0.0, 1.0);
    _c._setProgress(progress, max > 0 && _scroll.offset >= max - 0.5);
  }

  void _onDragStart(DragStartDetails _) {
    _dragging = true;
    _resumeAfterDrag = _c.playing;
    _syncTicker();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (!widget.userScroll || !_ready) return;
    _jumpTo(_scroll.offset - d.delta.dy);
  }

  void _onDragEnd([DragEndDetails? _]) {
    _dragging = false;
    if (_resumeAfterDrag) _position = _scroll.hasClients ? _scroll.offset : _position;
    _syncTicker();
  }

  @override
  Widget build(BuildContext context) {
    final lightText = widget.textColor.computeLuminance() > 0.5;
    final style = TextStyle(
      fontFamily: 'Inter',
      color: widget.textColor,
      fontSize: widget.fontSize,
      fontWeight: FontWeight.w600,
      height: PrompterView.lineHeight,
      letterSpacing: -0.2,
      shadows: !widget.textShadow
          ? null
          : lightText
          ? const [
              Shadow(color: Color(0xCC000000), blurRadius: 6, offset: Offset(0, 1)),
              Shadow(color: Color(0x99000000), blurRadius: 14),
            ]
          : const [Shadow(color: Color(0xEEFFFFFF), blurRadius: 6), Shadow(color: Color(0xAAFFFFFF), blurRadius: 14)],
    );

    return LayoutBuilder(
      builder: (context, box) {
        final h = box.maxHeight;
        // La ventana flotante puede medir 0 en su primer frame.
        if (!h.isFinite || h <= 0 || box.maxWidth <= widget.horizontalPadding * 2) {
          return const SizedBox.expand();
        }
        final guideY = h * widget.guidePosition;
        final firstLineCenter = guideY + widget.fontSize * PrompterView.lineHeight / 2;

        Widget text = SingleChildScrollView(
          controller: _scroll,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            widget.horizontalPadding,
            guideY,
            widget.horizontalPadding,
            math.max(0, h - firstLineCenter + 8),
          ),
          child: Text(widget.text.isEmpty ? '…' : widget.text, style: style),
        );

        if (widget.mirror) {
          text = Transform(alignment: Alignment.center, transform: Matrix4.diagonal3Values(-1, 1, 1), child: text);
        }

        final fadeTop = (widget.guidePosition * 0.9).clamp(0.05, 0.9);
        text = ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [
              Color(0x00000000),
              Color(0x66000000),
              Color(0xFF000000),
              Color(0xFF000000),
              Color(0x00000000),
            ],
            stops: [0, fadeTop * 0.5, fadeTop, 0.86, 1],
          ).createShader(rect),
          child: text,
        );

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap ?? _c.toggle,
          onVerticalDragStart: _onDragStart,
          onVerticalDragUpdate: _onDragUpdate,
          onVerticalDragEnd: _onDragEnd,
          onVerticalDragCancel: _onDragEnd,
          child: Stack(
            children: [
              Positioned.fill(child: text),
              // Marcas de la línea de lectura.
              Positioned(left: 4, top: firstLineCenter - 7, child: const _GuideMark(pointsRight: true)),
              Positioned(right: 4, top: firstLineCenter - 7, child: const _GuideMark(pointsRight: false)),
              Positioned.fill(
                child: IgnorePointer(
                  child: ListenableBuilder(
                    listenable: _c,
                    builder: (context, _) => _Countdown(value: _c.countdown, size: h),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GuideMark extends StatelessWidget {
  const _GuideMark({required this.pointsRight});

  final bool pointsRight;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(10, 14), painter: _TrianglePainter(pointsRight));
  }
}

class _TrianglePainter extends CustomPainter {
  _TrianglePainter(this.pointsRight);

  final bool pointsRight;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (pointsRight) {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width, size.height / 2)
        ..lineTo(0, size.height);
    } else {
      path
        ..moveTo(size.width, 0)
        ..lineTo(0, size.height / 2)
        ..lineTo(size.width, size.height);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = AppColors.accent);
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.pointsRight != pointsRight;
}

class _Countdown extends StatelessWidget {
  const _Countdown({required this.value, required this.size});

  final int? value;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fontSize = (size * 0.45).clamp(36.0, 160.0);
    return Center(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween(begin: 1.6, end: 1.0).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
            child: child,
          ),
        ),
        child: value == null
            ? const SizedBox.shrink(key: ValueKey('none'))
            : Text(
                '$value',
                key: ValueKey(value),
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  color: AppColors.accent,
                  height: 1,
                  shadows: const [Shadow(color: Color(0x66000000), blurRadius: 18)],
                ),
              ),
      ),
    );
  }
}
