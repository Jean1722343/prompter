import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../data/script_store.dart';
import '../models/script.dart';
import '../theme.dart';
import '../utils/format.dart';
import '../widgets/glass.dart';
import 'launch_sheet.dart';

/// Crear o editar un guion. Se guarda solo mientras escribes.
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, this.scriptId});

  /// `null` para un guion nuevo.
  final String? scriptId;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final ScriptStore _store;
  late Script _script;
  late final TextEditingController _title;
  late final TextEditingController _content;
  final _contentFocus = FocusNode();
  Timer? _debounce;
  bool _saved = true;
  bool _initialized = false;

  bool get _isNew => widget.scriptId == null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _store = ScriptScope.read(context);
    final existing = widget.scriptId == null ? null : _store.byId(widget.scriptId!);
    _script = existing ?? Script.create();
    _title = TextEditingController(text: _script.title)..addListener(_onChanged);
    _content = TextEditingController(text: _script.content)..addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _title.dispose();
    _content.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (_title.text == _script.title && _content.text == _script.content) return;
    setState(() => _saved = false);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _save);
  }

  Future<void> _save() async {
    _debounce?.cancel();
    if (_title.text == _script.title && _content.text == _script.content) return;
    _script = _script.copyWith(title: _title.text, content: _content.text, updatedAt: DateTime.now());
    if (_script.isEmpty && _isNew) {
      await _store.delete(_script.id);
    } else {
      await _store.upsert(_script);
    }
    if (mounted) setState(() => _saved = true);
  }

  Future<void> _read() async {
    FocusScope.of(context).unfocus();
    await _save();
    if (!mounted) return;
    if (_content.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Escribe algo en el guion para poder leerlo')));
      _contentFocus.requestFocus();
      return;
    }
    showLaunchSheet(context, _script);
  }

  @override
  Widget build(BuildContext context) {
    final words = Script.countWords(_content.text);
    final duration = Script.estimateReadingTime(_content.text);
    final padding = MediaQuery.paddingOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    const barHeight = 52.0;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _save();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: AmbientBackground(
          intensity: 0.7,
          child: Stack(
            children: [
              // Hoja de escritura.
              Positioned.fill(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(22, padding.top + barHeight + 28, 22, keyboard + padding.bottom + 110),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _title,
                        autofocus: _isNew,
                        // Texto de una línea que se ajusta: "Intro" pasa al contenido.
                        keyboardType: TextInputType.text,
                        maxLines: 3,
                        minLines: 1,
                        inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[\r\n]'))],
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => _contentFocus.requestFocus(),
                        style: AppText.largeTitle.copyWith(fontSize: 32),
                        decoration: const InputDecoration(hintText: 'Título', isCollapsed: true),
                      ),
                      const SizedBox(height: 18),
                      Container(height: 0.5, color: AppColors.separator),
                      const SizedBox(height: 18),
                      TextField(
                        controller: _content,
                        focusNode: _contentFocus,
                        maxLines: null,
                        minLines: 12,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        style: AppText.body.copyWith(fontSize: 19, height: 1.6, color: AppColors.label),
                        decoration: const InputDecoration(
                          isCollapsed: true,
                          hintText:
                              'Escribe o pega aquí tu guion…\n\nUsa párrafos cortos: se leen mejor frente a la cámara.',
                          hintMaxLines: 4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Barra superior flotante.
              Positioned(
                top: padding.top + 8,
                left: 16,
                right: 16,
                child: BackdropGroup(
                  child: SizedBox(
                    height: barHeight,
                    child: Row(
                      children: [
                        GlassIconButton(
                          icon: CupertinoIcons.chevron_back,
                          size: 46,
                          semanticLabel: 'Volver',
                          onTap: () => Navigator.maybePop(context),
                        ),
                        const Spacer(),
                        Glass(
                          radius: 20,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 220),
                            child: Row(
                              key: ValueKey(_saved),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _saved ? CupertinoIcons.checkmark_alt_circle_fill : CupertinoIcons.cloud_upload,
                                  size: 15,
                                  color: _saved ? AppColors.secondaryLabel : AppColors.accent,
                                ),
                                const SizedBox(width: 6),
                                Text(_saved ? 'Guardado' : 'Guardando…', style: AppText.footnote),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GlassPill(
                          tinted: true,
                          icon: CupertinoIcons.play_fill,
                          label: 'Leer',
                          height: 46,
                          fontSize: 15,
                          onTap: _read,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Estadísticas flotantes, por encima del teclado.
              AnimatedPositioned(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                left: 0,
                right: 0,
                bottom: (keyboard > 0 ? keyboard : padding.bottom) + 14,
                child: Center(
                  child: BackdropGroup(
                    child: Glass(
                      radius: 22,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(CupertinoIcons.text_alignleft, size: 15, color: AppColors.secondaryLabel),
                          const SizedBox(width: 6),
                          Text(pluralWords(words), style: AppText.footnote.copyWith(color: AppColors.label)),
                          Container(
                            width: 0.5,
                            height: 14,
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            color: AppColors.separator,
                          ),
                          const Icon(CupertinoIcons.timer, size: 15, color: AppColors.secondaryLabel),
                          const SizedBox(width: 6),
                          Text(
                            '≈ ${formatDuration(duration)} de lectura',
                            style: AppText.footnote.copyWith(color: AppColors.label),
                          ),
                        ],
                      ),
                    ),
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
