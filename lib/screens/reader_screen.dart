import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../data/storage.dart';
import '../models/prompter_settings.dart';
import '../models/script.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import '../widgets/pinch_detector.dart';
import '../widgets/prompter_view.dart';

/// Teleprompter a pantalla completa.
class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key, required this.script});

  final Script script;

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final _controller = PrompterController();
  PrompterSettings _settings = PrompterSettings.reader;
  double _pinchStartFont = 0;
  bool _pinching = false;
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();
    Storage.readerSettings().then((s) {
      if (mounted) setState(() => _settings = s);
    });
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    Storage.saveReaderSettings(_settings);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();
    _controller.dispose();
    super.dispose();
  }

  void _update(PrompterSettings s) {
    setState(() => _settings = s);
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), () => Storage.saveReaderSettings(s));
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final dark = _settings.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: dark ? Colors.black : Colors.white,
        body: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final showControls = !_controller.busy;
            return Stack(
              children: [
                Positioned.fill(
                  child: PinchDetector(
                    onStart: () {
                      _pinchStartFont = _settings.fontSize;
                      setState(() => _pinching = true);
                    },
                    onUpdate: (_, _, scale) => _update(_settings.copyWith(fontSize: _pinchStartFont * scale)),
                    onEnd: () => setState(() => _pinching = false),
                    child: SafeArea(
                      child: PrompterView(
                        text: widget.script.content,
                        controller: _controller,
                        fontSize: _settings.fontSize,
                        speed: _settings.speed,
                        mirror: _settings.mirror,
                        textColor: dark ? Colors.white : AppColors.label,
                        guidePosition: 0.3,
                        horizontalPadding: 32,
                        userScroll: !_pinching,
                      ),
                    ),
                  ),
                ),
                // Barra superior flotante.
                Positioned(
                  top: padding.top + 10,
                  left: 16,
                  right: 16,
                  child: _Fade(
                    visible: showControls,
                    child: BackdropGroup(
                      child: Row(
                        children: [
                          GlassIconButton(
                            icon: CupertinoIcons.xmark,
                            semanticLabel: 'Salir',
                            onTap: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Center(
                              child: Glass(
                                radius: 22,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Text(
                                  widget.script.displayTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppText.headline.copyWith(fontSize: 15),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          GlassIconButton(
                            icon: dark ? CupertinoIcons.sun_max_fill : CupertinoIcons.moon_fill,
                            semanticLabel: dark ? 'Fondo blanco' : 'Fondo negro',
                            onTap: () => _update(_settings.copyWith(dark: !dark)),
                          ),
                          const SizedBox(width: 8),
                          GlassIconButton(
                            icon: CupertinoIcons.arrow_right_arrow_left,
                            active: _settings.mirror,
                            semanticLabel: 'Modo espejo',
                            onTap: () => _update(_settings.copyWith(mirror: !_settings.mirror)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Panel de control inferior.
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: padding.bottom + 12,
                  child: _Fade(
                    visible: showControls,
                    child: BackdropGroup(
                      child: _Controls(controller: _controller, settings: _settings, onChanged: _update),
                    ),
                  ),
                ),
                // Progreso siempre visible, muy discreto.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: LinearProgressIndicator(
                      value: _controller.progress,
                      minHeight: 3,
                      backgroundColor: Colors.transparent,
                      valueColor: const AlwaysStoppedAnimation(AppColors.accent),
                    ),
                  ),
                ),
                if (_pinching)
                  Center(
                    child: BackdropGroup(
                      child: Glass(
                        radius: 22,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        child: Text('Letra ${_settings.fontSize.round()}', style: AppText.headline),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Fade extends StatelessWidget {
  const _Fade({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 0.08),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(opacity: visible ? 1 : 0, duration: const Duration(milliseconds: 260), child: child),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.controller, required this.settings, required this.onChanged});

  final PrompterController controller;
  final PrompterSettings settings;
  final ValueChanged<PrompterSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Glass(
      radius: 36,
      blur: 34,
      tint: Colors.white,
      tintOpacity: 0.3,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassSlider(
            icon: CupertinoIcons.speedometer,
            label: 'Velocidad',
            display: 'x${settings.speed.toStringAsFixed(1)}',
            value: settings.speed,
            min: PrompterSettings.minSpeed,
            max: PrompterSettings.maxSpeed,
            onChanged: (v) => onChanged(settings.copyWith(speed: (v * 2).round() / 2)),
          ),
          GlassSlider(
            icon: CupertinoIcons.textformat_size,
            label: 'Letra',
            display: '${settings.fontSize.round()}',
            value: settings.fontSize,
            min: 20,
            max: PrompterSettings.maxFont,
            onChanged: (v) => onChanged(settings.copyWith(fontSize: v.roundToDouble())),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              GlassIconButton(
                icon: CupertinoIcons.backward_end_fill,
                semanticLabel: 'Desde el principio',
                blurBackground: false,
                onTap: c.restart,
              ),
              GlassIconButton(
                icon: CupertinoIcons.backward_fill,
                semanticLabel: 'Retroceder',
                blurBackground: false,
                onTap: () => c.nudge(-3),
              ),
              Pressable(
                onTap: c.atEnd ? () => c.play() : c.toggle,
                scale: 0.9,
                semanticLabel: 'Reproducir',
                child: AccentOrb(
                  size: 72,
                  child: Padding(
                    padding: EdgeInsets.only(left: c.atEnd ? 0 : 4),
                    child: Icon(
                      c.atEnd ? CupertinoIcons.arrow_counterclockwise : CupertinoIcons.play_fill,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              GlassIconButton(
                icon: CupertinoIcons.forward_fill,
                semanticLabel: 'Avanzar',
                blurBackground: false,
                onTap: () => c.nudge(3),
              ),
              const SizedBox(width: 44),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Toca el texto para pausar · Pellizca para cambiar la letra', style: AppText.caption),
        ],
      ),
    );
  }
}
