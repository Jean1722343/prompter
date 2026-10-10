import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/storage.dart';
import '../models/prompter_settings.dart';
import '../models/script.dart';
import '../services/overlay_bridge.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import '../widgets/pinch_detector.dart';
import '../widgets/prompter_view.dart';

/// Modo oscuro de la ventana flotante (vive en su propio isolate).
final _overlayDark = ValueNotifier<bool>(false);

/// App que vive dentro de la ventana flotante (otro motor de Flutter).
class OverlayApp extends StatelessWidget {
  const OverlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _overlayDark,
      builder: (context, dark, _) {
        AppColors.dark = dark;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          color: Colors.transparent,
          themeAnimationDuration: Duration.zero,
          theme: buildTheme().copyWith(scaffoldBackgroundColor: Colors.transparent),
          home: const Material(type: MaterialType.transparency, child: OverlayPanel()),
        );
      },
    );
  }
}

enum _Panel { none, opacity, settings }

class OverlayPanel extends StatefulWidget {
  const OverlayPanel({super.key});

  @override
  State<OverlayPanel> createState() => _OverlayPanelState();
}

class _OverlayPanelState extends State<OverlayPanel> with WidgetsBindingObserver {
  static const _bubbleSize = 60.0;
  static const _minSize = Size(260, 170);
  static const _radius = 28.0;

  final _controller = PrompterController();
  Script? _script;
  PrompterSettings _settings = PrompterSettings.overlay;
  bool _minimized = false;
  _Panel _panel = _Panel.none;
  bool _pinching = false;
  Size _restoreSize = const Size(360, 260);
  Size _gestureStart = Size.zero;
  Size _screen = const Size(400, 800);
  Timer? _saveDebounce;

  // Aviso breve de velocidad ("x3.5") al pulsar − / +.
  String? _toast;
  Timer? _toastTimer;

  // Cola de redimensionado: como mucho una llamada en vuelo.
  Size? _pendingSize;
  bool _resizing = false;

  // Para no confundir "arrastrar la burbuja" con "tocarla".
  Offset? _bubbleDownOffset;

  Appearance _appearance = Appearance.system;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    OverlayWindow.setReloadHandler(_load);
    _load();
  }

  @override
  void didChangePlatformBrightness() {
    if (_appearance == Appearance.system) _applyAppearance();
  }

  void _applyAppearance() {
    final dark = _appearance.resolve(WidgetsBinding.instance.platformDispatcher.platformBrightness);
    AppColors.dark = dark;
    _overlayDark.value = dark;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveDebounce?.cancel();
    _toastTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final script = await OverlayWindow.script() ?? await Storage.overlayScript();
    final settings = await Storage.overlaySettings();
    final geo = await OverlayWindow.geometry();
    _appearance = await OverlayWindow.appearance() ?? await Storage.appearance();
    if (!mounted) return;
    _applyAppearance();
    setState(() {
      _script = script;
      _settings = settings;
      _minimized = false;
      _panel = _Panel.none;
      if (geo != null) _screen = geo.screen;
    });
    _controller.restart();
    // Si se cerró minimizada o muy pequeña, vuelve a un tamaño cómodo.
    if (geo != null && (geo.size.width < _minSize.width || geo.size.height < _minSize.height)) {
      await OverlayWindow.resize(Size(_screen.width * 0.92, _screen.height * 0.32), shift: true, persist: true);
    }
  }

  void _updateSettings(PrompterSettings s) {
    setState(() => _settings = s);
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), () => Storage.saveOverlaySettings(s));
  }

  void _changeSpeed(double delta) {
    final s = _settings.copyWith(speed: _settings.speed + delta);
    _updateSettings(s);
    _showToast('Velocidad x${s.speed.toStringAsFixed(1)}');
  }

  void _showToast(String text) {
    _toastTimer?.cancel();
    setState(() => _toast = text);
    _toastTimer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _toast = null);
    });
  }

  void _togglePanel(_Panel p) => setState(() => _panel = _panel == p ? _Panel.none : p);

  // region Tamaño

  Size _clampSize(Size s) => Size(
    s.width.clamp(_minSize.width, math.max(_minSize.width, _screen.width)),
    s.height.clamp(_minSize.height, math.max(_minSize.height, _screen.height)),
  );

  void _requestResize(Size size) {
    _pendingSize = _clampSize(size);
    if (_resizing) return;
    _flushResize();
  }

  Future<void> _flushResize() async {
    final size = _pendingSize;
    if (size == null) return;
    _pendingSize = null;
    _resizing = true;
    final geo = await OverlayWindow.resize(size);
    _resizing = false;
    if (geo != null) _screen = geo.screen;
    if (_pendingSize != null) _flushResize();
  }

  void _persistSize() {
    final size = _pendingSize ?? MediaQuery.sizeOf(context);
    OverlayWindow.resize(_clampSize(size), persist: true);
  }

  // endregion

  Future<void> _minimize() async {
    _controller.pause();
    _restoreSize = MediaQuery.sizeOf(context);
    setState(() {
      _minimized = true;
      _panel = _Panel.none;
    });
    await OverlayWindow.resize(const Size(_bubbleSize, _bubbleSize));
  }

  Future<void> _restore() async {
    setState(() => _minimized = false);
    await OverlayWindow.resize(_clampSize(_restoreSize), shift: true);
  }

  Future<void> _onBubbleDown() async {
    OverlayWindow.beginMove();
    _bubbleDownOffset = (await OverlayWindow.geometry())?.offset;
  }

  Future<void> _onBubbleTap() async {
    final before = _bubbleDownOffset;
    final now = (await OverlayWindow.geometry())?.offset;
    if (before != null && now != null && (now - before).distance > 6) return; // Fue un arrastre.
    HapticFeedback.selectionClick();
    _restore();
  }

  @override
  Widget build(BuildContext context) {
    if (_minimized) return _buildBubble();

    final size = MediaQuery.sizeOf(context);
    final o = _settings.opacity;
    final shape = RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(_radius));

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final playing = _controller.playing && _panel == _Panel.none;
        return Stack(
          children: [
            SizedBox(
              width: size.width,
              height: size.height,
              child: Glass(
                radius: _radius,
                blurBackground: false,
                shadow: false,
                tint: AppColors.dark ? Colors.black : Colors.white,
                tintOpacity: o * (AppColors.dark ? 0.7 : 0.6),
                // Con opacidad 0 queda solo el borde de cristal.
                strength: 0.03 + 0.97 * o,
                child: ClipPath(
                  clipper: ShapeBorderClipper(shape: shape),
                  child: Column(
                    children: [
                      AnimatedOpacity(
                        opacity: playing ? 0.85 : 1,
                        duration: const Duration(milliseconds: 300),
                        child: _chrome(top: true, child: _buildHeader()),
                      ),
                      Expanded(child: _buildBody()),
                      _chrome(top: false, child: _buildControls(size.width)),
                    ],
                  ),
                ),
              ),
            ),
            // Esquina para redimensionar: arrastra hacia fuera o hacia dentro.
            Positioned(
              right: 0,
              bottom: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => _gestureStart = MediaQuery.sizeOf(context),
                onPanUpdate: (d) {
                  _gestureStart = Size(_gestureStart.width + d.delta.dx, _gestureStart.height + d.delta.dy);
                  _requestResize(_gestureStart);
                },
                onPanEnd: (_) => _persistSize(),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: CustomPaint(
                    painter: _ResizeCornerPainter(
                      radius: _radius,
                      color: AppColors.label.withValues(alpha: 0.3),
                      halo: _halo != null,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          // Zona para mover la ventana: toda la parte izquierda de la barra.
          Expanded(
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => OverlayWindow.beginMove(),
              child: Padding(
                padding: const EdgeInsets.only(left: 14),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.label.withValues(alpha: 0.25),
                        boxShadow: _halo == null ? null : [BoxShadow(color: _haloColor, blurRadius: 6)],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _script?.displayTitle ?? 'Prompter',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.headline.copyWith(fontSize: 13.5, shadows: _halo),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _MiniButton(
            icon: CupertinoIcons.drop_fill,
            active: _panel == _Panel.opacity,
            label: 'Opacidad',
            halo: _halo,
            onTap: () => _togglePanel(_Panel.opacity),
          ),
          _MiniButton(
            icon: CupertinoIcons.textformat_size,
            active: _panel == _Panel.settings,
            label: 'Letra y más',
            halo: _halo,
            onTap: () => _togglePanel(_Panel.settings),
          ),
          _MiniButton(icon: CupertinoIcons.minus, label: 'Minimizar', halo: _halo, onTap: _minimize),
          _MiniButton(icon: CupertinoIcons.xmark, label: 'Cerrar', halo: _halo, onTap: OverlayWindow.close),
          const SizedBox(width: 6),
        ],
      ),
    );
  }

  /// Barras de arriba y de controles. También siguen la opacidad, para que
  /// con la ventana transparente no quede un marco opaco alrededor.
  Widget _chrome({required bool top, required Widget child}) {
    final o = _settings.opacity;
    final line = BorderSide(color: AppColors.separator.withValues(alpha: AppColors.separator.a * o), width: 0.5);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.glass.withValues(alpha: 0.02 + 0.94 * o),
        border: Border(top: top ? BorderSide.none : line, bottom: top ? line : BorderSide.none),
      ),
      child: child,
    );
  }

  /// Con la ventana casi transparente, iconos y textos llevan un halo que
  /// contrasta con cualquier imagen de la cámara.
  List<Shadow>? get _halo => _settings.opacity < 0.6
      ? [Shadow(color: _haloColor, blurRadius: 4), Shadow(color: _haloColor, blurRadius: 10)]
      : null;

  Color get _haloColor => AppColors.dark ? const Color(0xD9000000) : const Color(0xF2FFFFFF);

  /// Letra del guion: en modo claro pasa de negra a blanca cuando el fondo
  /// es casi transparente; en modo oscuro siempre es blanca.
  bool get _darkText => !AppColors.dark && _settings.opacity >= 0.45;

  Widget _buildBody() {
    return Stack(
      children: [
        Positioned.fill(
          child: PinchDetector(
            onStart: () {
              _gestureStart = MediaQuery.sizeOf(context);
              setState(() => _pinching = true);
            },
            onUpdate: (sx, sy, _) => _requestResize(Size(_gestureStart.width * sx, _gestureStart.height * sy)),
            onEnd: () {
              setState(() => _pinching = false);
              _persistSize();
            },
            child: PrompterView(
              text: _script?.content ?? '',
              controller: _controller,
              fontSize: _settings.fontSize,
              speed: _settings.speed,
              textColor: _darkText ? AppColors.label : Colors.white,
              textShadow: _settings.opacity < 0.75,
              guidePosition: 0.16,
              horizontalPadding: 20,
              userScroll: !_pinching,
            ),
          ),
        ),
        // Aviso de velocidad.
        Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: _toast == null
                    ? const SizedBox.shrink()
                    : Glass(
                        key: ValueKey(_toast),
                        radius: 18,
                        blurBackground: false,
                        tint: Colors.black,
                        tintOpacity: 0.6,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                        child: Text(_toast!, style: AppText.headline.copyWith(fontSize: 15, color: Colors.white)),
                      ),
              ),
            ),
          ),
        ),
        // Paneles rápidos (opacidad / letra).
        Positioned(
          left: 8,
          right: 8,
          top: 0,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, -0.15), end: Offset.zero).animate(anim),
                child: child,
              ),
            ),
            child: switch (_panel) {
              _Panel.none => const SizedBox.shrink(),
              _Panel.opacity => _buildOpacityPanel(),
              _Panel.settings => _buildSettingsPanel(),
            },
          ),
        ),
      ],
    );
  }

  Widget _panelGlass({required Key key, required Widget child}) => Glass(
    key: key,
    radius: 20,
    blurBackground: false,
    tint: AppColors.glass,
    tintOpacity: AppColors.dark ? 0.92 : 0.85,
    padding: const EdgeInsets.fromLTRB(14, 4, 10, 4),
    child: child,
  );

  Widget _buildOpacityPanel() {
    final s = _settings;
    return _panelGlass(
      key: const ValueKey('opacity'),
      child: GlassSlider(
        compact: true,
        icon: CupertinoIcons.drop,
        label: 'Opacidad',
        display: '${(s.opacity * 100).round()}%',
        value: s.opacity,
        min: 0,
        max: 1,
        onChanged: (v) => _updateSettings(s.copyWith(opacity: v)),
      ),
    );
  }

  Widget _buildSettingsPanel() {
    final s = _settings;
    return _panelGlass(
      key: const ValueKey('settings'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassSlider(
            compact: true,
            icon: CupertinoIcons.textformat_size,
            label: 'Letra',
            display: '${s.fontSize.round()}',
            value: s.fontSize.clamp(14, 64),
            min: 14,
            max: 64,
            onChanged: (v) => _updateSettings(s.copyWith(fontSize: v.roundToDouble())),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 2),
            child: Row(
              children: [
                Expanded(
                  child: GlassPill(
                    icon: CupertinoIcons.backward_end_fill,
                    label: 'Al inicio',
                    height: 36,
                    fontSize: 13,
                    expand: true,
                    onTap: () {
                      _controller.restart();
                      setState(() => _panel = _Panel.none);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GlassPill(
                    icon: CupertinoIcons.arrow_up_right_square,
                    label: 'Abrir app',
                    height: 36,
                    fontSize: 13,
                    expand: true,
                    onTap: OverlayWindow.openApp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls(double width) {
    final c = _controller;
    final showSpeedLabel = width >= 320;
    final playIcon = c.atEnd
        ? CupertinoIcons.arrow_counterclockwise
        : c.busy
        ? CupertinoIcons.pause_fill
        : CupertinoIcons.play_fill;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 30, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barra de progreso: arrástrala para saltar a cualquier parte.
          SizedBox(
            height: 20,
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                activeTrackColor: AppColors.accent,
                inactiveTrackColor: AppColors.fill,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6, elevation: 2),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(value: c.progress.clamp(0.0, 1.0), onChanged: c.seek),
            ),
          ),
          Row(
            children: [
              _MiniButton(
                icon: CupertinoIcons.minus_circle,
                label: 'Más lento',
                halo: _halo,
                size: 40,
                onTap: () => _changeSpeed(-0.5),
              ),
              if (showSpeedLabel)
                SizedBox(
                  width: 42,
                  child: Text(
                    'x${_settings.speed.toStringAsFixed(1)}',
                    textAlign: TextAlign.center,
                    style: AppText.footnote.copyWith(
                      color: AppColors.label,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      shadows: _halo,
                    ),
                  ),
                ),
              _MiniButton(
                icon: CupertinoIcons.plus_circle,
                label: 'Más rápido',
                halo: _halo,
                size: 40,
                onTap: () => _changeSpeed(0.5),
              ),
              const Spacer(),
              _MiniButton(
                icon: CupertinoIcons.backward_fill,
                label: 'Retroceder',
                halo: _halo,
                size: 40,
                onTap: () => c.nudge(-3),
              ),
              const SizedBox(width: 4),
              Pressable(
                onTap: c.atEnd ? () => c.play() : c.toggle,
                scale: 0.86,
                semanticLabel: c.busy ? 'Pausar' : 'Reproducir',
                child: AccentOrb(
                  size: 44,
                  glow: false,
                  child: Padding(
                    padding: EdgeInsets.only(left: playIcon == CupertinoIcons.play_fill ? 3 : 0),
                    child: Icon(playIcon, size: 21, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _MiniButton(
                icon: CupertinoIcons.forward_fill,
                label: 'Adelantar',
                halo: _halo,
                size: 40,
                onTap: () => c.nudge(3),
              ),
              const Spacer(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBubble() {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _onBubbleDown(),
      child: GestureDetector(
        onTap: _onBubbleTap,
        child: const AccentOrb(
          size: _bubbleSize,
          glow: false,
          child: Icon(CupertinoIcons.text_alignleft, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({
    required this.icon,
    required this.onTap,
    required this.label,
    this.active = false,
    this.size = 34,
    this.halo,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String label;
  final bool active;
  final double size;
  final List<Shadow>? halo;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.82,
      semanticLabel: label,
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: size - 4,
            height: size - 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? AppColors.accent.withValues(alpha: 0.14) : Colors.transparent,
            ),
            child: Icon(icon, size: size * 0.5, color: active ? AppColors.accent : AppColors.label, shadows: halo),
          ),
        ),
      ),
    );
  }
}

/// Arco en la esquina inferior derecha, siguiendo la curva de la ventana
/// (como el asa de redimensionar de iPadOS).
class _ResizeCornerPainter extends CustomPainter {
  const _ResizeCornerPainter({required this.radius, required this.color, required this.halo});

  final double radius;
  final Color color;
  final bool halo;

  @override
  void paint(Canvas canvas, Size size) {
    final inset = 7.0;
    final r = radius - inset;
    final corner = Offset(size.width - inset, size.height - inset);
    final rect = Rect.fromCircle(center: corner - Offset(r, r), radius: r);
    Paint stroke(Color c, double w) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..color = c;
    if (halo) {
      final glow = color.computeLuminance() > 0.5 ? Colors.black : Colors.white;
      canvas.drawArc(rect, 0.12, math.pi / 2 - 0.24, false, stroke(glow.withValues(alpha: 0.5), 7));
    }
    canvas.drawArc(rect, 0.12, math.pi / 2 - 0.24, false, stroke(color, 4));
  }

  @override
  bool shouldRepaint(_ResizeCornerPainter old) => old.radius != radius || old.color != color || old.halo != halo;
}
