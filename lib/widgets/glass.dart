import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Panel de "cristal líquido" claro, como en iOS: desenfoca lo que hay
/// detrás, lo cubre con un blanco esmerilado y lo remata con un borde
/// especular y una sombra muy suave.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    this.child,
    this.radius = 26,
    this.circle = false,
    this.blur = 28,
    this.tint,
    this.tintOpacity = 0.0,
    this.strength = 1.0,
    this.padding,
    this.width,
    this.height,
    this.blurBackground = true,
    this.shadow = true,
  });

  final Widget? child;
  final double radius;
  final bool circle;
  final double blur;

  /// Color que tiñe el cristal (p. ej. el acento en avisos).
  final Color? tint;
  final double tintOpacity;

  /// Cuánto blanco lleva el cristal (0 = invisible, 1 = normal).
  final double strength;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;

  /// Desactívalo cuando no haya nada que desenfocar (ahorra GPU).
  final bool blurBackground;

  /// Sombra suave bajo el cristal.
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final shape = circle
        ? const CircleBorder()
        : RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(radius));
    final s = strength.clamp(0.0, 1.5);
    Color white(double v) => Colors.white.withValues(alpha: (v * s).clamp(0.0, 1.0));

    Widget body = DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [white(0.82), white(0.64), white(0.56), white(0.72)],
          stops: const [0, 0.35, 0.7, 1],
        ),
      ),
      position: DecorationPosition.background,
      // El tinte va entre el cristal y el contenido, nunca encima del texto.
      child: DecoratedBox(
        position: DecorationPosition.background,
        decoration: ShapeDecoration(
          shape: shape,
          color: tint != null && tintOpacity > 0 ? tint!.withValues(alpha: tintOpacity) : null,
        ),
        child: CustomPaint(
          foregroundPainter: _RimPainter(shape: shape, strength: s),
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ),
      ),
    );

    if (blurBackground) {
      body = BackdropFilter.grouped(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur, tileMode: TileMode.mirror),
        child: body,
      );
    }

    final shadowAlpha = s.clamp(0.0, 1.0);
    return Container(
      width: width,
      height: height,
      decoration: shadow && shadowAlpha > 0
          ? ShapeDecoration(
              shape: shape,
              shadows: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.07 * shadowAlpha),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(color: Colors.black.withValues(alpha: 0.03 * shadowAlpha), blurRadius: 2),
              ],
            )
          : null,
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: body,
      ),
    );
  }
}

class _RimPainter extends CustomPainter {
  _RimPainter({required this.shape, required this.strength});

  final ShapeBorder shape;
  final double strength;

  Color _w(double v) => Colors.white.withValues(alpha: (v * strength).clamp(0.0, 1.0));

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Línea finísima oscura por fuera para separar el cristal de fondos claros.
    canvas.drawPath(
      shape.getOuterPath(rect.deflate(0.3)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = Colors.black.withValues(alpha: (0.07 * strength).clamp(0.0, 1.0)),
    );

    // Borde especular: brilla arriba a la izquierda y abajo a la derecha.
    final path = shape.getInnerPath(rect.deflate(0.9));
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_w(1), _w(0.5), _w(0.2), _w(0.85)],
          stops: const [0, 0.3, 0.65, 1],
        ).createShader(rect),
    );

    // Brillo interior en la parte superior, como la luz sobre un cristal curvo.
    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, math.min(size.height, 36)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_w(0.5), _w(0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, math.min(size.height, 36))),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RimPainter old) => old.strength != strength || old.shape != shape;
}

/// Encoge un poco al pulsar y vuelve con un muelle, al estilo iOS.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.95,
    this.haptic = true,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool haptic;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
    reverseDuration: const Duration(milliseconds: 420),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  @override
  Widget build(BuildContext context) {
    final anim = CurvedAnimation(parent: _c, curve: Curves.easeOut, reverseCurve: Curves.elasticOut);
    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => _c.forward() : null,
        onTapCancel: () => _c.reverse(),
        onTapUp: (_) => _c.reverse(),
        onTap: widget.onTap == null
            ? null
            : () {
                if (widget.haptic) HapticFeedback.selectionClick();
                widget.onTap!();
              },
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                _c.reverse();
                HapticFeedback.mediumImpact();
                widget.onLongPress!();
              },
        child: AnimatedBuilder(
          animation: anim,
          builder: (context, child) => Transform.scale(scale: 1 - (1 - widget.scale) * anim.value, child: child),
          child: AnimatedOpacity(
            opacity: _enabled ? 1 : 0.4,
            duration: const Duration(milliseconds: 200),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Botón redondo de cristal con un icono.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 44,
    this.iconSize,
    this.tinted = false,
    this.active = false,
    this.semanticLabel,
    this.blurBackground = true,
    this.iconColor,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double? iconSize;

  /// Relleno con el azul de acento (acción principal).
  final bool tinted;

  /// Estado "encendido" para botones de alternar.
  final bool active;
  final String? semanticLabel;
  final bool blurBackground;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final color = tinted ? Colors.white : (iconColor ?? (active ? AppColors.accent : AppColors.label));
    final iconWidget = Icon(icon, size: iconSize ?? size * 0.44, color: color);
    return Pressable(
      onTap: onTap,
      scale: 0.88,
      semanticLabel: semanticLabel,
      child: tinted
          ? AccentOrb(size: size, child: iconWidget)
          : Glass(
              circle: true,
              width: size,
              height: size,
              tint: active ? AppColors.accent : null,
              tintOpacity: active ? 0.14 : 0,
              blurBackground: blurBackground,
              child: Center(child: iconWidget),
            ),
    );
  }
}

/// Esfera azul con un reflejo superior, como un botón de cristal tintado.
class AccentOrb extends StatelessWidget {
  const AccentOrb({super.key, required this.size, this.child, this.glow = true});

  final double size;
  final Widget? child;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.accentGradient,
        boxShadow: glow
            ? [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.35),
                  blurRadius: size * 0.4,
                  offset: Offset(0, size * 0.12),
                ),
              ]
            : null,
      ),
      foregroundDecoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [Colors.white.withValues(alpha: 0.35), Colors.white.withValues(alpha: 0)],
        ),
      ),
      child: Center(child: child),
    );
  }
}

/// Cápsula de cristal con icono y texto.
class GlassPill extends StatelessWidget {
  const GlassPill({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.tinted = false,
    this.height = 50,
    this.expand = false,
    this.fontSize = 16,
    this.blurBackground = true,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool tinted;
  final double height;
  final bool expand;
  final double fontSize;
  final bool blurBackground;

  @override
  Widget build(BuildContext context) {
    final fg = tinted ? Colors.white : AppColors.label;
    final content = Padding(
      padding: EdgeInsets.symmetric(horizontal: height * 0.42),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[Icon(icon, size: fontSize + 4, color: fg), SizedBox(width: fontSize * 0.45)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.headline.copyWith(fontSize: fontSize, color: fg),
            ),
          ),
        ],
      ),
    );

    final radius = BorderRadius.circular(height / 2);
    return Pressable(
      onTap: onTap,
      scale: 0.94,
      child: tinted
          ? Container(
              height: height,
              decoration: BoxDecoration(
                borderRadius: radius,
                gradient: AppColors.accentGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.35),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              foregroundDecoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [Colors.white.withValues(alpha: 0.28), Colors.white.withValues(alpha: 0)],
                ),
              ),
              child: content,
            )
          : Glass(radius: height / 2, height: height, blurBackground: blurBackground, child: content),
    );
  }
}

/// Fondo claro con manchas de color pastel que se mueven despacio. Le da al
/// cristal algo que refractar, como los fondos de pantalla de iOS.
class AmbientBackground extends StatefulWidget {
  const AmbientBackground({super.key, required this.child, this.intensity = 1});

  final Widget child;
  final double intensity;

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(seconds: 28))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Stack(
      children: [
        Positioned.fill(
          child: ColoredBox(
            color: AppColors.background,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _OrbsPainter(reduceMotion ? const AlwaysStoppedAnimation(0.15) : _c, widget.intensity),
              ),
            ),
          ),
        ),
        Positioned.fill(child: widget.child),
      ],
    );
  }
}

class _OrbsPainter extends CustomPainter {
  _OrbsPainter(this.t, this.intensity) : super(repaint: t);

  final Animation<double> t;
  final double intensity;

  static const _orbs = [
    (color: AppColors.blue, x: 0.10, y: 0.04, r: 0.80, phase: 0.0, a: 0.26),
    (color: AppColors.cyan, x: 0.98, y: 0.30, r: 0.60, phase: 0.33, a: 0.22),
    (color: AppColors.purple, x: 0.02, y: 0.66, r: 0.70, phase: 0.66, a: 0.16),
    (color: AppColors.pink, x: 0.90, y: 0.94, r: 0.62, phase: 0.5, a: 0.12),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final v = t.value * 2 * math.pi;
    final unit = math.max(size.width, size.height * 0.6);
    for (final o in _orbs) {
      final cx = (o.x + 0.08 * math.sin(v + o.phase * 6.28)) * size.width;
      final cy = (o.y + 0.05 * math.cos(v * 1.3 + o.phase * 6.28)) * size.height;
      final r = o.r * unit;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            o.color.withValues(alpha: o.a * intensity),
            o.color.withValues(alpha: o.a * 0.35 * intensity),
            o.color.withValues(alpha: 0),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r));
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }
  }

  @override
  bool shouldRepaint(_OrbsPainter old) => old.intensity != intensity;
}

/// Hoja inferior de cristal (sustituye a la de Material).
Future<T?> showGlassSheet<T>(BuildContext context, {required WidgetBuilder builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: Colors.black.withValues(alpha: 0.2),
    builder: (context) => Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 8, 8 + MediaQuery.paddingOf(context).bottom),
      child: BackdropGroup(
        child: Glass(
          radius: 38,
          blur: 40,
          tint: Colors.white,
          tintOpacity: 0.45,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 38,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              Flexible(child: builder(context)),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Diálogo de cristal centrado.
Future<T?> showGlassDialog<T>(BuildContext context, {required WidgetBuilder builder}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar',
    barrierColor: Colors.black.withValues(alpha: 0.22),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (context, _, _) => Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Material(
          type: MaterialType.transparency,
          child: BackdropGroup(
            child: Glass(radius: 34, blur: 40, tint: Colors.white, tintOpacity: 0.5, child: builder(context)),
          ),
        ),
      ),
    ),
    transitionBuilder: (context, anim, _, child) {
      final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: Tween(begin: 1.12, end: 1.0).animate(curved), child: child),
      );
    },
  );
}

/// Fila con icono, etiqueta, deslizador al estilo iOS y valor.
class GlassSlider extends StatelessWidget {
  const GlassSlider({
    super.key,
    required this.icon,
    required this.label,
    required this.display,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final String display;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fs = compact ? 13.0 : 15.0;
    return SizedBox(
      height: compact ? 38 : 46,
      child: Row(
        children: [
          Icon(icon, size: compact ? 17 : 20, color: AppColors.secondaryLabel),
          const SizedBox(width: 10),
          SizedBox(
            width: compact ? 62 : 82,
            child: Text(
              label,
              style: AppText.headline.copyWith(fontSize: fs, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: compact ? 5 : 6,
                thumbShape: RoundSliderThumbShape(enabledThumbRadius: compact ? 10 : 12, elevation: 3),
                overlayShape: RoundSliderOverlayShape(overlayRadius: compact ? 14 : 18),
              ),
              child: Slider(value: value.clamp(min, max), min: min, max: max, onChanged: onChanged),
            ),
          ),
          SizedBox(
            width: compact ? 40 : 46,
            child: Text(
              display,
              textAlign: TextAlign.right,
              style: AppText.headline.copyWith(fontSize: fs, fontFeatures: const [ui.FontFeature.tabularFigures()]),
            ),
          ),
        ],
      ),
    );
  }
}
