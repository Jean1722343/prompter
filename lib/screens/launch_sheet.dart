import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app.dart';
import '../models/script.dart';
import '../services/overlay_bridge.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/glass.dart';
import 'reader_screen.dart';

/// Hoja inferior para elegir cómo leer un guion.
Future<void> showLaunchSheet(BuildContext context, Script script) {
  return showGlassSheet<void>(context, builder: (_) => _LaunchSheet(script: script));
}

class _LaunchSheet extends StatefulWidget {
  const _LaunchSheet({required this.script});

  final Script script;

  @override
  State<_LaunchSheet> createState() => _LaunchSheetState();
}

class _LaunchSheetState extends State<_LaunchSheet> with WidgetsBindingObserver {
  static const _autoCameraKey = 'auto_camera';
  final _prefs = SharedPreferencesAsync();
  bool _autoCamera = true;
  bool _waitingPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _prefs.getBool(_autoCameraKey).then((v) {
      if (mounted && v != null) setState(() => _autoCamera = v);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    // Al volver de los ajustes del sistema, si ya hay permiso, seguimos solos.
    if (state == AppLifecycleState.resumed && _waitingPermission) {
      _waitingPermission = false;
      if (await OverlayBridge.hasPermission()) _startFloating();
    }
  }

  Future<void> _onFloatingTap() async {
    if (!OverlayBridge.isSupported) return;
    if (await OverlayBridge.hasPermission()) {
      _startFloating();
      return;
    }
    if (!mounted) return;
    final ok = await showGlassDialog<bool>(context, builder: (context) => const _PermissionDialog());
    if (ok == true) {
      _waitingPermission = true;
      await OverlayBridge.requestPermission();
    }
  }

  Future<void> _startFloating() async {
    await OverlayBridge.show(widget.script, appearance: AppearanceScope.of(context).appearance);
    if (!mounted) return;
    Navigator.of(context).pop();
    if (_autoCamera && await OverlayBridge.openCamera()) return;
    await OverlayBridge.minimizeApp();
  }

  void _openReader() {
    final navigator = Navigator.of(context);
    navigator.pop();
    navigator.push(CupertinoPageRoute(fullscreenDialog: true, builder: (_) => ReaderScreen(script: widget.script)));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.script;
    final supported = OverlayBridge.isSupported;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.displayTitle,
            textAlign: TextAlign.center,
            style: AppText.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            '${pluralWords(s.wordCount)} · ≈ ${formatDuration(s.readingTime)} de lectura',
            textAlign: TextAlign.center,
            style: AppText.footnote,
          ),
          const SizedBox(height: 22),
          _ModeTile(
            primary: true,
            icon: CupertinoIcons.rectangle_on_rectangle,
            title: 'Flotante sobre la cámara',
            subtitle: supported
                ? 'Ventana de cristal encima de tu cámara. Muévela y cambia su tamaño con los dedos.'
                : 'Disponible solo en Android.',
            enabled: supported,
            onTap: _onFloatingTap,
          ),
          if (supported) ...[
            const SizedBox(height: 10),
            Glass(
              radius: 22,
              strength: 0.7,
              blurBackground: false,
              padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
              child: Row(
                children: [
                  Icon(CupertinoIcons.videocam_fill, color: AppColors.secondaryLabel, size: 22),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Abrir la cámara al empezar', style: AppText.headline),
                        SizedBox(height: 2),
                        Text('En modo vídeo, lista para grabar', style: AppText.footnote),
                      ],
                    ),
                  ),
                  CupertinoSwitch(
                    value: _autoCamera,
                    activeTrackColor: AppColors.green,
                    onChanged: (v) {
                      setState(() => _autoCamera = v);
                      _prefs.setBool(_autoCameraKey, v);
                    },
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          _ModeTile(
            icon: CupertinoIcons.fullscreen,
            title: 'Pantalla completa',
            subtitle: 'Lee en esta pantalla. Ideal para teleprompter de cristal (con modo espejo).',
            onTap: _openReader,
          ),
        ],
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.primary = false,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool primary;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: ShapeDecoration(
              color: primary ? Colors.white.withValues(alpha: 0.22) : AppColors.accent.withValues(alpha: 0.12),
              shape: RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(15)),
            ),
            child: Icon(icon, color: primary ? Colors.white : AppColors.accent, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.headline.copyWith(color: primary ? Colors.white : AppColors.label)),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: AppText.footnote.copyWith(
                    color: primary ? Colors.white.withValues(alpha: 0.9) : AppColors.secondaryLabel,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            CupertinoIcons.chevron_forward,
            color: primary ? Colors.white.withValues(alpha: 0.8) : AppColors.tertiaryLabel,
            size: 18,
          ),
        ],
      ),
    );

    final shape = RoundedSuperellipseBorder(borderRadius: BorderRadius.circular(26));
    return Pressable(
      onTap: enabled ? onTap : null,
      scale: 0.97,
      child: primary
          ? Container(
              decoration: ShapeDecoration(
                shape: shape,
                gradient: AppColors.accentGradient,
                shadows: [
                  BoxShadow(
                    color: AppColors.accent.withValues(alpha: 0.35),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              foregroundDecoration: ShapeDecoration(
                shape: shape.copyWith(side: BorderSide(color: Colors.white.withValues(alpha: 0.3))),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0)],
                ),
              ),
              child: content,
            )
          : Glass(radius: 26, strength: 0.9, blurBackground: false, child: content),
    );
  }
}

class _PermissionDialog extends StatelessWidget {
  const _PermissionDialog();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AccentOrb(size: 64, child: Icon(CupertinoIcons.layers_alt_fill, color: Colors.white, size: 30)),
          const SizedBox(height: 18),
          Text('Un permiso y listo', style: AppText.title, textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text(
            'Para mostrar el guion encima de la cámara, Android necesita que actives '
            '"Mostrar sobre otras apps" para Prompter.\n\nActívalo y vuelve: la ventana se abrirá sola.',
            textAlign: TextAlign.center,
            style: AppText.body,
          ),
          const SizedBox(height: 22),
          GlassPill(tinted: true, expand: true, label: 'Dar permiso', onTap: () => Navigator.pop(context, true)),
          const SizedBox(height: 8),
          CupertinoButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Ahora no', style: AppText.headline.copyWith(color: AppColors.secondaryLabel)),
          ),
        ],
      ),
    );
  }
}
